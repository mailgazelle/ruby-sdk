# frozen_string_literal: true

require "mailgazelle/domain"

module MailGazelle
  # List the product domains associated with the current API token.
  class DomainsResource
    def initialize(http)
      @http = http
    end

    def list
      items(@http.request("GET", "/domains")).filter_map do |item|
        Domain.from_h(item) if item.is_a?(Hash)
      end
    end

    private

    def items(payload)
      return payload if payload.is_a?(Array)
      return [] unless payload.is_a?(Hash)

      %w[data domains].each do |key|
        value = payload[key] || payload[key.to_sym]
        return Array(value) if value.is_a?(Array)
      end

      [payload]
    end
  end
end
