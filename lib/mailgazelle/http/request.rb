# frozen_string_literal: true

module MailGazelle
  module Http
    # Outgoing HTTP request passed to a transport.
    #
    # A transport is any object that implements +perform+ and returns a {Response}.
    Request = Data.define(:http_method, :url, :headers, :body, :timeout, :connect_timeout)
  end
end
