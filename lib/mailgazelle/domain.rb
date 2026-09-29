# frozen_string_literal: true

module MailGazelle
  # A product domain and its verification statuses from +GET /domains+.
  #
  # Unknown JSON keys stay on {#to_h}.
  class Domain
    attr_reader :name, :type, :verification_statuses

    def self.from_h(payload)
      data = string_keyed(payload)
      raw_name = data["name"] || data["domain"] || data["host"] || ""
      raw_type = data["type"] || data["kind"]

      new(
        name: raw_name.is_a?(String) ? raw_name : "",
        type: raw_type.is_a?(String) && !raw_type.empty? ? raw_type : nil,
        verification_statuses: statuses(data).freeze,
        raw: data
      )
    end

    def initialize(name:, type:, verification_statuses:, raw:)
      @name = name
      @type = type
      @verification_statuses = verification_statuses
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

    def self.statuses(data)
      candidates = data["verification"] || data["verification_statuses"] || data["statuses"]
      return direct_statuses(data) unless candidates.is_a?(Hash)

      candidates.each_with_object({}) do |(key, value), result|
        if value.is_a?(String)
          result[key.to_s] = value
        elsif value.is_a?(Hash) && value["status"].is_a?(String)
          name = value["name"].is_a?(String) ? value["name"] : key.to_s
          result[name] = value["status"]
        end
      end
    end
    private_class_method :statuses

    def self.direct_statuses(data)
      %w[dkim mail_from spf dmarc].each_with_object({}) do |key, result|
        result[key] = data[key] if data[key].is_a?(String)
      end
    end
    private_class_method :direct_statuses
  end
end
