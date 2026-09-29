# frozen_string_literal: true

require "mailgazelle/mailer"

module MailGazelle
  # Registers the +:mailgazelle+ ActionMailer delivery method when Rails boots.
  class Railtie < Rails::Railtie
    initializer "mailgazelle.action_mailer" do
      ActiveSupport.on_load(:action_mailer) do
        add_delivery_method :mailgazelle, MailGazelle::Mailer
      end
    end
  end
end
