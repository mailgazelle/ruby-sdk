# frozen_string_literal: true

require_relative "lib/mailgazelle/version"

Gem::Specification.new do |spec|
  spec.name = "mailgazelle"
  spec.version = MailGazelle::VERSION
  spec.authors = ["Srdjan Marjanovic"]
  spec.email = ["srdjan@foobar.rs"]
  spec.summary = "Ruby and Rails SDK for sending transactional email through Mail Gazelle."
  spec.description = "Send transactional email with the Mail Gazelle API from Ruby, and from Rails via ActionMailer."
  spec.homepage = "https://mailgazelle.com"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.files = Dir["lib/**/*", "docs/**/*", "LICENSE", "README.md", "CHANGELOG.md"]
  spec.require_paths = ["lib"]

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/mailgazelle/ruby-sdk"
  spec.metadata["changelog_uri"] = "https://github.com/mailgazelle/ruby-sdk/blob/main/CHANGELOG.md"
  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["rubygems_mfa_required"] = "true"
end
