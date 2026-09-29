# frozen_string_literal: true

require "mailgazelle"
require_relative "support/fake_transport"

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
  end
  config.order = :random
  Kernel.srand config.seed

  config.after { MailGazelle.reset! }
end
