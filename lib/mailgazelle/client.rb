# frozen_string_literal: true

require "mailgazelle/error"
require "mailgazelle/http/http_client"
require "mailgazelle/http/net_http_transport"
require "mailgazelle/version"
require "mailgazelle/emails_resource"
require "mailgazelle/domains_resource"

module MailGazelle
  # Entry point for the Mail Gazelle API.
  #
  # Construct one client per API token and reuse it.
  class Client
    DEFAULT_BASE_URL = "https://mailgazelle.com/api/v1"

    def initialize(api_token:, base_url: nil, transport: nil, timeout: 30, connect_timeout: 10,
                   user_agent_suffix: nil)
      token = api_token.to_s.strip
      raise ArgumentError, "A Mail Gazelle API token is required." if token.empty?

      timeout = Float(timeout)
      connect_timeout = Float(connect_timeout)
      raise ArgumentError, "Timeouts must be greater than zero." if timeout <= 0 || connect_timeout <= 0

      @http = Http::HttpClient.new(
        transport: transport || Http::NetHttpTransport.new,
        base_url: normalize_base_url(base_url),
        default_headers: {
          "Authorization" => "Bearer #{token}",
          "Accept" => "application/json",
          "User-Agent" => user_agent(user_agent_suffix)
        },
        timeout: timeout,
        connect_timeout: connect_timeout
      )
    end

    def emails
      @emails ||= EmailsResource.new(@http)
    end

    def domains
      @domains ||= DomainsResource.new(@http)
    end

    private

    def normalize_base_url(base_url)
      normalized = base_url.to_s.strip
      normalized = DEFAULT_BASE_URL if normalized.empty?
      normalized.sub(%r{/+\z}, "")
    end

    def user_agent(suffix)
      agent = "mailgazelle-ruby/#{VERSION}"
      extra = suffix.to_s.strip
      extra.empty? ? agent : "#{agent} #{extra}"
    end
  end
end
