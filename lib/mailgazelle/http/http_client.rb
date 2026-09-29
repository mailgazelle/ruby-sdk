# frozen_string_literal: true

require "json"
require "mailgazelle/error"
require "mailgazelle/error_mapper"
require "mailgazelle/http/request"

module MailGazelle
  module Http
    # Authenticates requests, encodes JSON, and maps API errors to exceptions.
    class HttpClient
      def initialize(transport:, base_url:, default_headers:, timeout:, connect_timeout:)
        @transport = transport
        @base_url = base_url
        @default_headers = default_headers
        @timeout = timeout
        @connect_timeout = connect_timeout
      end

      # Send an authenticated JSON request and return the decoded object or list.
      def request(method, path, json: nil)
        headers = @default_headers.dup
        body = nil

        unless json.nil?
          body = encode(json)
          headers["Content-Type"] = "application/json"
        end

        response = @transport.perform(
          Request.new(
            http_method: method.to_s.upcase,
            url: url(path),
            headers: headers,
            body: body,
            timeout: @timeout,
            connect_timeout: @connect_timeout
          )
        )

        raise ErrorMapper.from_response(response) unless response.status_code.between?(200, 299)

        decode_success(response)
      end

      def url(path)
        "#{@base_url}/#{path.to_s.sub(%r{\A/}, '')}"
      end

      private

      def encode(json)
        JSON.generate(json)
      rescue JSON::GeneratorError => e
        raise ApiError.new(
          "Failed to encode the request body as JSON.",
          code: "invalid_request",
          http_status: 0
        ), cause: e
      end

      def decode_success(response)
        return {} if response.body.nil? || response.body.empty?

        decoded = JSON.parse(response.body)
        unless decoded.is_a?(Hash) || decoded.is_a?(Array)
          raise ApiError.new(
            "API returned a non-object JSON payload.",
            code: "invalid_response",
            http_status: response.status_code
          )
        end

        decoded
      rescue JSON::ParserError => e
        raise ApiError.new(
          "Failed to decode the API response.",
          code: "invalid_response",
          http_status: response.status_code
        ), cause: e
      end
    end
  end
end
