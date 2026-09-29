# frozen_string_literal: true

require "uri"
require "mailgazelle/error"

module MailGazelle
  # An email address with an optional display name.
  class Address
    attr_reader :email, :name

    def initialize(email, name = nil)
      normalized = email.to_s.strip
      unless URI::MailTo::EMAIL_REGEXP.match?(normalized)
        raise ValidationError.new(
          "\"#{email}\" is not a valid email address.",
          code: "validation_error",
          http_status: 422
        )
      end

      @email = normalized
      cleaned = name.to_s.strip
      @name = cleaned.empty? ? nil : cleaned
      freeze
    end

    def to_h
      payload = { email: email }
      payload[:name] = name unless name.nil?
      payload
    end
  end
end
