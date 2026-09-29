# frozen_string_literal: true

require "mail"
require "mailgazelle/mailer"

RSpec.describe MailGazelle::Mailer do
  def deliver(message, transport, **settings)
    described_class.new({ api_token: "tes_mailer", transport: transport }.merge(settings)).deliver!(message)
  end

  it "converts a multipart message, tags, idempotency, and an inline attachment" do
    transport = FakeTransport.new(body: '{"id":"01JMAIL","status":"queued"}')
    message = Mail.new
    message.from = "App <notif@example.com>"
    message.to = "Ada <ada@example.com>"
    message.cc = "billing@example.com"
    message.bcc = "audit@example.com"
    message.reply_to = "support@example.com"
    message.subject = "Invoice"
    message.text_part = Mail::Part.new { body "Thanks" }
    message.html_part = Mail::Part.new { body "<p>Thanks</p>" }
    message.attachments["invoice.pdf"] = "pdf-bytes"
    message.attachments.inline["logo.png"] = "png-bytes"
    message["Message-ID"] = "<invoice-42@example.com>"
    message["X-Entity-Ref-ID"] = "42"
    message["MailGazelle-Idempotency-Key"] = "invoice-42"
    message["tags"] = { "campaign" => "welcome" }

    queued = deliver(message, transport)

    payload = JSON.parse(transport.requests.first.body)
    expect(queued.id).to eq("01JMAIL")
    expect(message["X-MailGazelle-Message-Id"].value).to eq("01JMAIL")
    expect(payload["from"]).to eq("email" => "notif@example.com", "name" => "App")
    expect(payload["to"]).to eq([{ "email" => "ada@example.com", "name" => "Ada" }])
    expect(payload["cc"]).to eq([{ "email" => "billing@example.com" }])
    expect(payload["bcc"]).to eq([{ "email" => "audit@example.com" }])
    expect(payload["reply_to"]).to eq([{ "email" => "support@example.com" }])
    expect(payload["subject"]).to eq("Invoice")
    expect(payload["text"]).to eq("Thanks")
    expect(payload["html"]).to eq("<p>Thanks</p>")
    expect(payload["idempotency_key"]).to eq("invoice-42")
    expect(payload["tags"]).to eq("campaign" => "welcome")
    expect(payload["headers"]).to include("Message-ID" => "<invoice-42@example.com>", "X-Entity-Ref-ID" => "42")
    expect(payload["headers"].keys.map(&:downcase)).not_to include("date", "content-type", "mime-version", "subject")
    filenames = payload["attachments"].map { |item| item["filename"] }
    expect(filenames).to contain_exactly("invoice.pdf", "logo.png")
    inline = payload["attachments"].find { |item| item["filename"] == "logo.png" }
    expect(inline["content_id"]).not_to be_nil
    expect(inline["content_type"]).to eq("image/png")
  end

  it "uses the configured token when the delivery settings omit one" do
    MailGazelle.configure { |config| config.api_token = "tes_global" }
    transport = FakeTransport.new
    message = Mail.new
    message.to = "user@example.com"
    message.subject = "Welcome"
    message.body = "Thanks"

    described_class.new(transport: transport).deliver!(message)

    expect(transport.requests.first.headers["Authorization"]).to eq("Bearer tes_global")
    expect(transport.requests.first.headers["User-Agent"]).to include("rails")
    payload = JSON.parse(transport.requests.first.body)
    expect(payload["text"]).to eq("Thanks")
    expect(payload).not_to have_key("from")
  end

  it "raises when no token is configured" do
    message = Mail.new
    message.to = "user@example.com"
    message.subject = "Welcome"
    message.body = "Thanks"

    expect { described_class.new.deliver!(message) }.to raise_error(MailGazelle::ApiTokenMissing)
  end
end
