# frozen_string_literal: true

require "uri"
require "mailgazelle/email"
require "mailgazelle/emails/email_record"
require "mailgazelle/emails/queued_email"
require "mailgazelle/error"

module MailGazelle
  # Send and inspect transactional emails.
  class EmailsResource
    def initialize(http)
      @http = http
    end

    # Persist a message and queue a send. Returns immediately on HTTP 202.
    #
    # The same idempotency key returns the original message and does not send again.
    def send(email)
      raise ArgumentError, "Expected a MailGazelle::Email" unless email.is_a?(Email)

      QueuedEmail.from_h(@http.request("POST", "/emails", json: email.to_payload))
    end

    # Fetch status, timestamps, provider message id, last event, and attachment metadata.
    def get(id)
      trimmed = id.to_s.strip
      if trimmed.empty?
        raise ValidationError.new("An email id is required.", code: "validation_error", http_status: 422)
      end

      EmailRecord.from_h(@http.request("GET", "/emails/#{URI.encode_uri_component(trimmed)}"))
    end
  end
end
