# frozen_string_literal: true

require "time"
require "mailgazelle/emails/attachment_meta"
require "mailgazelle/emails/email_status"

module MailGazelle
  # Status record returned by +GET /emails/{id}+.
  #
  # HTML, text, and attachment bytes are not included. Unknown JSON keys stay
  # on {#to_h} so later API fields do not break older clients.
  class EmailRecord
    attr_reader :id, :status, :message_id, :last_event_type, :created_at, :updated_at, :sent_at, :attachments

    def self.from_h(payload)
      data = unwrap(payload)
      attachments = Array(data["attachments"]).filter_map do |item|
        AttachmentMeta.from_h(item) if item.is_a?(Hash)
      end

      new(
        id: string_value(data, "id") || "",
        status: string_value(data, "status") || "",
        message_id: string_value(data, "message_id") ||
          string_value(data, "provider_message_id") ||
          string_value(data, "ses_message_id"),
        last_event_type: string_value(data, "last_event_type") || string_value(data, "last_event"),
        created_at: timestamp(data, "created_at"),
        updated_at: timestamp(data, "updated_at"),
        sent_at: timestamp(data, "sent_at"),
        attachments: attachments.freeze,
        raw: data
      )
    end

    def initialize(id:, status:, message_id:, last_event_type:, created_at:, updated_at:, sent_at:, attachments:, raw:)
      @id = id
      @status = status
      @message_id = message_id
      @last_event_type = last_event_type
      @created_at = created_at
      @updated_at = updated_at
      @sent_at = sent_at
      @attachments = attachments
      @raw = raw
      freeze
    end

    # The documented status when this SDK version knows it, otherwise +nil+.
    def known_status
      EmailStatus.known?(status) ? status : nil
    end

    def to_h
      @raw
    end

    def self.unwrap(payload)
      data = string_keyed(payload)
      nested = data["data"]
      data = string_keyed(nested) if nested.is_a?(Hash)
      data
    end
    private_class_method :unwrap

    def self.string_keyed(payload)
      return {} unless payload.is_a?(Hash)

      payload.each_with_object({}) do |(key, value), result|
        result[key.to_s] = value
      end
    end
    private_class_method :string_keyed

    def self.string_value(data, key)
      value = data[key]
      value.is_a?(String) && !value.empty? ? value : nil
    end
    private_class_method :string_value

    def self.timestamp(data, key)
      value = data[key]
      return nil unless value.is_a?(String) && !value.empty?

      Time.iso8601(value)
    rescue ArgumentError
      nil
    end
    private_class_method :timestamp
  end
end
