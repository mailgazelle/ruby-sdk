# frozen_string_literal: true

require "json"
require "mailgazelle/error"

module MailGazelle
  # Maps a non-success HTTP response onto a typed {Error}.
  module ErrorMapper
    CLASSES = {
      "unauthenticated" => AuthenticationError,
      "product_not_ready" => ProductNotReadyError,
      "validation_error" => ValidationError,
      "from_not_allowed" => FromNotAllowedError,
      "recipient_suppressed" => RecipientSuppressedError,
      "attachment_invalid" => AttachmentError,
      "attachment_too_large" => AttachmentTooLargeError,
      "quota_exceeded" => QuotaExceededError,
      "html_too_large" => HtmlTooLargeError,
      "message_too_large" => MessageTooLargeError,
      "rate_limited" => RateLimitError
    }.freeze

    module_function

    def from_response(response)
      payload = decode(response.body)
      code = string_or_nil(payload["code"]) || code_from_status(response.status_code)
      message = string_or_nil(payload["message"]) || "Unexpected Mail Gazelle API error."
      details = payload["details"].is_a?(Hash) ? payload["details"] : {}
      error_class = CLASSES.fetch(code, ApiError)
      error_class.new(message, code: code, http_status: response.status_code, details: details)
    end

    def decode(body)
      return {} if body.nil? || body.empty?

      decoded = JSON.parse(body)
      decoded.is_a?(Hash) ? decoded : {}
    rescue JSON::ParserError
      {}
    end

    def code_from_status(status)
      case status
      when 401 then "unauthenticated"
      when 403 then "product_not_ready"
      when 422 then "validation_error"
      when 429 then "rate_limited"
      else "unknown_error"
      end
    end

    def string_or_nil(value)
      value.is_a?(String) && !value.empty? ? value : nil
    end
  end
end
