# frozen_string_literal: true

module MailGazelle
  # Attachment metadata returned by +GET /emails/{id}+.
  #
  # File bytes are never included.
  class AttachmentMeta
    attr_reader :filename, :content_type, :size

    def self.from_h(payload)
      data = string_keyed(payload)
      new(
        filename: data["filename"].is_a?(String) ? data["filename"] : "",
        content_type: data["content_type"].is_a?(String) ? data["content_type"] : nil,
        size: integer_or_nil(data["size"]),
        raw: data
      )
    end

    def initialize(filename:, content_type:, size:, raw:)
      @filename = filename
      @content_type = content_type
      @size = size
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

    def self.integer_or_nil(value)
      return value if value.is_a?(Integer)
      return Integer(value) if value.is_a?(String) && value.match?(/\A-?\d+\z/)
      return value.to_i if value.is_a?(Numeric)

      nil
    end
    private_class_method :integer_or_nil
  end
end
