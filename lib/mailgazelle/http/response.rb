# frozen_string_literal: true

module MailGazelle
  module Http
    # HTTP response returned by a transport. Header names are lower-case.
    Response = Data.define(:status_code, :body, :headers)
  end
end
