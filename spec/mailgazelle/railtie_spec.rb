# frozen_string_literal: true

require "rails"
require "action_mailer/railtie"
require "mailgazelle/railtie"

class MailGazelleTestApp < Rails::Application
  config.load_defaults Rails::VERSION::STRING.to_f
  config.eager_load = false
  config.secret_key_base = "mailgazelle-test-secret-key-base-value"
  config.logger = ActiveSupport::Logger.new(File::NULL)
  config.action_mailer.delivery_method = :test
end

RSpec.describe MailGazelle::Railtie do
  it "registers the mailgazelle delivery method when Rails boots" do
    MailGazelleTestApp.initialize! unless MailGazelleTestApp.initialized?

    expect(ActionMailer::Base.delivery_methods[:mailgazelle]).to eq(MailGazelle::Mailer)
  end
end
