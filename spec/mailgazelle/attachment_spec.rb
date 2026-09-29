# frozen_string_literal: true

require "tmpdir"

RSpec.describe MailGazelle::Attachment do
  it "encodes file bytes and guesses the content type" do
    attachment = described_class.from_contents("invoice.pdf", "pdf-bytes")

    expect(attachment.to_h).to eq(
      filename: "invoice.pdf",
      content: Base64.strict_encode64("pdf-bytes"),
      content_type: "application/pdf"
    )
    expect(attachment.decoded_size).to eq("pdf-bytes".bytesize)
  end

  it "reads a file from disk" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "notes.txt")
      File.binwrite(path, "hello")

      attachment = described_class.from_path(path)
      expect(attachment.filename).to eq("notes.txt")
      expect(attachment.content_type).to eq("text/plain")
      expect(Base64.strict_decode64(attachment.content)).to eq("hello")
    end
  end

  it "accepts content that is already base64 and strips content ids" do
    encoded = Base64.strict_encode64("terms")
    attachment = described_class.from_base64("terms.pdf", encoded, content_id: "cid:<terms>")

    expect(attachment.content).to eq(encoded)
    expect(attachment.content_id).to eq("terms")
    expect(attachment.content_type).to eq("application/pdf")
  end

  it "rejects path segments, empty files, and invalid base64" do
    expect { described_class.from_contents("../secret.txt", "x") }
      .to raise_error(MailGazelle::AttachmentError, /basename/)
    expect { described_class.from_contents("empty.txt", "") }
      .to raise_error(MailGazelle::AttachmentError, /empty/)
    expect { described_class.from_base64("bad.txt", "!!!!") }
      .to raise_error(MailGazelle::AttachmentError, /base64/)
    expect { described_class.from_path("/tmp/mailgazelle-missing-file.txt") }
      .to raise_error(MailGazelle::AttachmentError, /Unable to read/)
    expect { described_class.from_contents("logo.png", "x", content_id: "has space") }
      .to raise_error(MailGazelle::AttachmentError, /content ids/)
  end
end
