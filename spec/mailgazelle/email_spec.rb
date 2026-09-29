# frozen_string_literal: true

RSpec.describe MailGazelle::Email do
  def email
    described_class.to("user@example.com", "Ada").subject("Welcome").text("Thanks")
  end

  it "omits optional fields so product defaults apply" do
    payload = email.to_payload

    expect(payload).to eq(
      to: [{ email: "user@example.com", name: "Ada" }],
      subject: "Welcome",
      text: "Thanks"
    )
  end

  it "sends html and text together, plus cc, bcc, from, headers, tags, and idempotency" do
    payload = email
      .html("<p>Thanks</p>")
      .add_to("other@example.com")
      .cc("billing@example.com", "Billing")
      .bcc("audit@example.com")
      .from("notif@example.com", "App")
      .reply_to("support@example.com")
      .header("Message-ID", "<welcome-42@example.com>")
      .tag("campaign", "welcome")
      .idempotency_key("welcome-user-42")
      .to_payload

    expect(payload[:html]).to eq("<p>Thanks</p>")
    expect(payload[:cc]).to eq([{ email: "billing@example.com", name: "Billing" }])
    expect(payload[:bcc]).to eq([{ email: "audit@example.com" }])
    expect(payload[:from]).to eq({ email: "notif@example.com", name: "App" })
    expect(payload[:reply_to]).to eq([{ email: "support@example.com" }])
    expect(payload[:headers]).to eq({ "Message-ID" => "<welcome-42@example.com>" })
    expect(payload[:tags]).to eq({ "campaign" => "welcome" })
    expect(payload[:idempotency_key]).to eq("welcome-user-42")
    expect(payload[:to]).to eq(
      [
        { email: "user@example.com", name: "Ada" },
        { email: "other@example.com" }
      ]
    )
  end

  it "sends an empty reply_to array only when reply-to is explicitly omitted" do
    expect(email.without_reply_to.to_payload[:reply_to]).to eq([])
    expect(email.without_reply_to.reply_to("support@example.com").to_payload[:reply_to]).to eq(
      [{ email: "support@example.com" }]
    )
  end

  it "omits a blank idempotency key" do
    expect(email.idempotency_key("").to_payload).not_to have_key(:idempotency_key)
  end

  it "rejects a missing subject or body" do
    expect { described_class.to("user@example.com").text("Hi").to_payload }
      .to raise_error(MailGazelle::ValidationError, "A subject is required.")
    expect { described_class.to("user@example.com").subject("Hi").to_payload }
      .to raise_error(MailGazelle::ValidationError, "Either html or text is required.")
  end

  it "rejects an invalid address and more than 50 recipients" do
    expect { described_class.to("not-an-email") }.to raise_error(MailGazelle::ValidationError, /not a valid email/)

    message = described_class.to("user@example.com").subject("Hi").text("Hi")
    49.times { |index| message = message.cc("person-#{index}@example.com") }

    expect { message.cc("overflow@example.com") }
      .to raise_error(MailGazelle::ValidationError, /at most 50 recipients/)
  end

  it "rejects invalid tags, reserved names, and more than 48 tags" do
    expect { email.tag("has space", "welcome") }.to raise_error(MailGazelle::ValidationError, /Tag names/)
    expect { email.tag("team_id", "1") }.to raise_error(MailGazelle::ValidationError, /reserved/)

    message = email
    described_class::MAX_TAGS.times { |index| message = message.tag("tag#{index}", "ok") }
    expect { message.tag("extra", "ok") }.to raise_error(MailGazelle::ValidationError, /at most 48 tags/)
  end

  it "rejects invalid headers and html over 512 KB" do
    expect { email.header("Bad Header", "x") }.to raise_error(MailGazelle::ValidationError, /Header names/)
    expect { email.header("X-Test", "a\nb") }.to raise_error(MailGazelle::ValidationError, /line breaks/)
    expect { email.header("X-Test", "a" * (described_class::MAX_HEADER_VALUE_LENGTH + 1)) }
      .to raise_error(MailGazelle::ValidationError, /8192/)

    expect { email.html("a" * (described_class::MAX_HTML_BYTES + 1)).to_payload }
      .to raise_error(MailGazelle::HtmlTooLargeError)
  end

  it "rejects decoded attachments over the 7 MB platform ceiling" do
    blob = "a" * described_class::MAX_ATTACHMENT_BYTES
    attachment = MailGazelle::Attachment.from_contents("notes.txt", blob)
    extra = MailGazelle::Attachment.from_contents("more.txt", "b")

    expect { email.attach(attachment).attach(extra).to_payload }
      .to raise_error(MailGazelle::AttachmentTooLargeError)
  end

  it "rejects a duplicate content id" do
    first = MailGazelle::Attachment.from_contents("a.png", "a", content_id: "logo")
    second = MailGazelle::Attachment.from_contents("b.png", "b", content_id: "cid:<logo>")

    expect { email.attach(first).attach(second) }
      .to raise_error(MailGazelle::AttachmentError, /unique/)
  end
end
