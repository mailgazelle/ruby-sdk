# frozen_string_literal: true

require "mailgazelle/emails/email_status"

module MailGazelle
  # Immediate 202 result of +POST /emails+.
  #
  # The message is persisted and queued. Delivery happens asynchronously.
  class QueuedEmail
    attr_reader :id, :status

    def self.from_h(payload)
      data = string_keyed(payload)
      new(
        id: data["id"].is_a?(String) ? data["id"] : "",
        status: data["status"].is_a?(String) ? data["status"] : EmailStatus::QUEUED,
        raw: data
      )
    end

    def initialize(id:, status:, raw:)
      @id = id
      @status = status
      @raw = raw
      freeze
    end

    def to_h
      @raw
    end

    def self.string_keyed(payload)
      return {} unless payload.is_a?(Hash)

      payload.each_with_object({}) do |(key, value), result|
        result[key.to_s] = value
      end
    end
    private_class_method :string_keyed
  end
end
