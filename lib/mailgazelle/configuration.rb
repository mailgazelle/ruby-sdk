# frozen_string_literal: true

module MailGazelle
  # Process-wide defaults used by {MailGazelle.client} and ActionMailer.
  class Configuration
    attr_accessor :api_token, :api_base, :timeout, :connect_timeout, :user_agent_suffix

    def initialize
      @api_token = nil
      @api_base = nil
      @timeout = 30
      @connect_timeout = 10
      @user_agent_suffix = nil
    end
  end
end
