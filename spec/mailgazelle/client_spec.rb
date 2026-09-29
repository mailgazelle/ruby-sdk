# frozen_string_literal: true

RSpec.describe MailGazelle::Client do
  def client(transport, **options)
    described_class.new(api_token: "tes_test", transport: transport, base_url: "https://mailgazelle.test/api/v1/",
                        **options)
  end

  it "sends a queued email and authenticates the request" do
    transport = FakeTransport.new
    queued = client(transport, user_agent_suffix: "MyApp/2").emails.send(
      MailGazelle::Email.to("user@example.com").subject("Welcome").text("Thanks")
    )

    request = transport.requests.first
    expect(queued.id).to eq("01J")
    expect(queued.status).to eq("queued")
    expect(request.http_method).to eq("POST")
    expect(request.url).to eq("https://mailgazelle.test/api/v1/emails")
    expect(request.headers["Authorization"]).to eq("Bearer tes_test")
    expect(request.headers["User-Agent"]).to eq("mailgazelle-ruby/#{MailGazelle::VERSION} MyApp/2")
    expect(JSON.parse(request.body)).to include("subject" => "Welcome", "text" => "Thanks")
  end

  it "keeps unknown fields when fetching an email" do
    body = {
      data: {
        id: "01J",
        status: "queued",
        provider_message_id: "ses-1",
        last_event: "delivered",
        created_at: "2026-01-02T03:04:05Z",
        future_field: "kept",
        attachments: [{ filename: "invoice.pdf", content_type: "application/pdf", size: "12", extra: true }]
      }
    }.to_json
    transport = FakeTransport.new(status: 200, body: body)
    record = client(transport).emails.get("a/b")

    expect(transport.requests.first.url).to end_with("/emails/a%2Fb")
    expect(record.id).to eq("01J")
    expect(record.known_status).to eq("queued")
    expect(record.message_id).to eq("ses-1")
    expect(record.last_event_type).to eq("delivered")
    expect(record.created_at).to eq(Time.iso8601("2026-01-02T03:04:05Z"))
    expect(record.to_h["future_field"]).to eq("kept")
    expect(record.attachments.first.filename).to eq("invoice.pdf")
    expect(record.attachments.first.size).to eq(12)
    expect(record.attachments.first.to_h["extra"]).to be(true)
  end

  it "falls back to the SES message id" do
    transport = FakeTransport.new(status: 200, body: { ses_message_id: "ses-9", status: "accepted" }.to_json)
    record = client(transport).emails.get("01J")

    expect(record.message_id).to eq("ses-9")
    expect(record.known_status).to be_nil
  end

  it "lists domains from an array, a data wrapper, or one object" do
    array_client = client(FakeTransport.new(status: 200, body: [
      { name: "example.com", type: "primary", verification: { dkim: "success" } }
    ].to_json))
    wrapped_client = client(FakeTransport.new(status: 200, body: {
      domains: [{ domain: "notif.example.com", kind: "sending", dkim: "pending" }]
    }.to_json))
    object_client = client(FakeTransport.new(status: 200, body: { host: "bounce.example.com" }.to_json))

    expect(array_client.domains.list.first.name).to eq("example.com")
    expect(array_client.domains.list.first.verification_statuses).to eq("dkim" => "success")
    expect(wrapped_client.domains.list.first.name).to eq("notif.example.com")
    expect(wrapped_client.domains.list.first.type).to eq("sending")
    expect(wrapped_client.domains.list.first.verification_statuses).to eq("dkim" => "pending")
    expect(object_client.domains.list.first.name).to eq("bounce.example.com")
  end

  it "maps API error codes, missing codes, and non-JSON bodies" do
    suppressed = client(FakeTransport.new(
                          status: 422,
                          body: { message: "This recipient is suppressed.", code: "recipient_suppressed",
                                  details: { email: "user@example.com" } }.to_json
                        ))
    limited = client(FakeTransport.new(status: 429, body: { message: "Slow down." }.to_json))
    broken = client(FakeTransport.new(status: 500, body: "<html>nope</html>"))

    expect { suppressed.emails.send(MailGazelle::Email.to("user@example.com").subject("Hi").text("Hi")) }
      .to raise_error(MailGazelle::RecipientSuppressedError) { |error|
        expect(error.code).to eq("recipient_suppressed")
        expect(error.http_status).to eq(422)
        expect(error.details).to eq("email" => "user@example.com")
      }

    expect { limited.domains.list }.to raise_error(MailGazelle::RateLimitError) { |error|
      expect(error.code).to eq("rate_limited")
    }

    expect { broken.domains.list }.to raise_error(MailGazelle::ApiError) { |error|
      expect(error.code).to eq("unknown_error")
      expect(error.http_status).to eq(500)
    }
  end

  it "requires a token and positive timeouts" do
    expect { described_class.new(api_token: "  ") }.to raise_error(ArgumentError, /token is required/)
    expect { described_class.new(api_token: "tes_test", timeout: 0) }.to raise_error(ArgumentError, /Timeouts/)
  end

  it "raises when the default client has no token" do
    expect { MailGazelle.client }.to raise_error(MailGazelle::ApiTokenMissing)

    MailGazelle.configure { |config| config.api_token = "tes_global" }
    expect(MailGazelle.client).to be_a(described_class)
  end

  it "rejects an empty email id before calling the API" do
    transport = FakeTransport.new
    expect { client(transport).emails.get("  ") }.to raise_error(MailGazelle::ValidationError, /email id/)
    expect(transport.requests).to be_empty
  end
end
