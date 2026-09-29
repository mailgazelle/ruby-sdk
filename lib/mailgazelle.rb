# frozen_string_literal: true

require "mailgazelle/version"
require "mailgazelle/error"
require "mailgazelle/configuration"
require "mailgazelle/address"
require "mailgazelle/attachment"
require "mailgazelle/email"
require "mailgazelle/client"

module MailGazelle
  class << self
    def configure
      yield config
      @client = nil
      config
    end

    def config
      @config ||= Configuration.new
    end

    def client
      @client ||= default_client
    end

    def reset!
      @config = Configuration.new
      @client = nil
    end

    private

    def default_client
      token = config.api_token
      raise ApiTokenMissing if token.nil? || token.to_s.strip.empty?

      Client.new(
        api_token: token,
        base_url: config.api_base,
        timeout: config.timeout || 30,
        connect_timeout: config.connect_timeout || 10,
        user_agent_suffix: config.user_agent_suffix
      )
    end
  end
end

require "mailgazelle/railtie" if defined?(Rails::Railtie)
