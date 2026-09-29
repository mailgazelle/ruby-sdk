# frozen_string_literal: true

require "net/http"
require "openssl"
require "uri"
require "mailgazelle/error"
require "mailgazelle/http/request"
require "mailgazelle/http/response"

module MailGazelle
  module Http
    # Default transport backed by +Net::HTTP+. Inject another object with +perform+
    # when an application wants a different HTTP stack or a test double.
    class NetHttpTransport
      METHODS = {
        "GET" => Net::HTTP::Get,
        "POST" => Net::HTTP::Post,
        "PATCH" => Net::HTTP::Patch,
        "PUT" => Net::HTTP::Put,
        "DELETE" => Net::HTTP::Delete
      }.freeze

      def perform(request)
        uri = URI.parse(request.url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = request.connect_timeout
        http.read_timeout = request.timeout
        http.write_timeout = request.timeout if http.respond_to?(:write_timeout=)

        response = http.request(build_request(uri, request))
        headers = {}
        response.each_header { |key, value| headers[key.downcase] = value }

        Response.new(status_code: response.code.to_i, body: response.body.to_s, headers: headers)
      rescue Timeout::Error, IOError, SocketError, SystemCallError, OpenSSL::SSL::SSLError => e
        message = e.message.to_s
        message = "The HTTP request failed." if message.empty?
        raise TransportError.new(message, details: { "error_class" => e.class.name }), cause: e
      end

      private

      def build_request(uri, request)
        klass = METHODS[request.http_method.to_s.upcase]
        raise TransportError, "Unsupported HTTP method #{request.http_method.inspect}." if klass.nil?

        http_request = klass.new(uri.request_uri)
        request.headers.each { |name, value| http_request[name] = value }
        http_request.body = request.body unless request.body.nil?
        http_request
      end
    end
  end
end
