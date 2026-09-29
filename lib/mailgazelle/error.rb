# frozen_string_literal: true

module MailGazelle
  # Base error for SDK failures and API error responses.
  #
  # Catch this class when any Mail Gazelle failure should take the same path.
  # Use a subclass when recovery depends on the cause.
  class Error < StandardError
    attr_reader :code, :http_status, :details

    def initialize(message, code:, http_status: 0, details: {})
      super(message)
      @code = code
      @http_status = http_status
      @details = details
    end
  end

  # Raised when the mailer or default client is used without a token.
  class ApiTokenMissing < Error
    def initialize(message = "A Mail Gazelle API token is required. Set MAILGAZELLE_API_TOKEN or " \
                             "config.action_mailer.mailgazelle_settings[:api_token].")
      super(message, code: "api_token_missing", http_status: 0)
    end
  end

  # DNS, TLS, timeout, and other failures before an API response arrives.
  class TransportError < Error
    def initialize(message, code: "transport_error", http_status: 0, details: {})
      super
    end
  end

  # An API error that does not map to a more specific class.
  class ApiError < Error; end

  # 401 unauthenticated, including a token for an archived product.
  class AuthenticationError < Error; end

  # 403 product_not_ready.
  class ProductNotReadyError < Error; end

  # 422 validation_error.
  class ValidationError < Error; end

  # 422 from_not_allowed.
  class FromNotAllowedError < Error; end

  # 422 recipient_suppressed. The address was stored as rejected and was not sent.
  class RecipientSuppressedError < Error; end

  # 422 attachment_invalid.
  class AttachmentError < Error; end

  # 422 attachment_too_large.
  class AttachmentTooLargeError < Error; end

  # 422 quota_exceeded.
  class QuotaExceededError < Error; end

  # 422 html_too_large.
  class HtmlTooLargeError < Error; end

  # 422 message_too_large.
  class MessageTooLargeError < Error; end

  # 429 rate_limited. The limit is 60 requests per minute per token.
  class RateLimitError < Error; end
end
