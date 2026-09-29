# frozen_string_literal: true

require "socket"
require "mailgazelle/http/net_http_transport"
require "mailgazelle/http/request"

RSpec.describe MailGazelle::Http::NetHttpTransport do
  it "posts JSON and reads the response" do
    payload = '{"id":"01J","status":"queued"}'
    server = TCPServer.new("127.0.0.1", 0)
    port = server.addr[1]
    seen = Queue.new

    thread = Thread.new do
      socket = server.accept
      headers = +""
      while (line = socket.gets)
        headers << line
        break if line == "\r\n"
      end
      length = headers[/Content-Length: (\d+)/i, 1].to_i
      body = length.positive? ? socket.read(length) : ""
      seen << { headers: headers, body: body }
      response = "HTTP/1.1 202 Accepted\r\nContent-Type: application/json\r\n" \
                 "Content-Length: #{payload.bytesize}\r\nConnection: close\r\n\r\n#{payload}"
      socket.write(response)
      socket.close
    end

    response = described_class.new.perform(
      MailGazelle::Http::Request.new(
        http_method: "POST",
        url: "http://127.0.0.1:#{port}/api/v1/emails",
        headers: { "Authorization" => "Bearer tes_test", "Content-Type" => "application/json" },
        body: '{"subject":"Welcome"}',
        timeout: 2,
        connect_timeout: 2
      )
    )

    captured = seen.pop
    expect(response.status_code).to eq(202)
    expect(response.body).to eq(payload)
    expect(captured[:headers]).to include("POST /api/v1/emails")
    expect(captured[:headers]).to include("Authorization: Bearer tes_test")
    expect(captured[:body]).to eq('{"subject":"Welcome"}')
  ensure
    thread&.join(2)
    server&.close
  end
end
