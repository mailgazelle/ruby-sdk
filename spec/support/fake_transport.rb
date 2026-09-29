# frozen_string_literal: true

class FakeTransport
  attr_reader :requests

  def initialize(status: 202, body: '{"id":"01J","status":"queued"}', headers: {})
    @status = status
    @body = body
    @headers = headers
    @requests = []
  end

  def perform(request)
    requests << request
    MailGazelle::Http::Response.new(status_code: @status, body: @body, headers: @headers)
  end
end
