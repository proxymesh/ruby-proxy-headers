# frozen_string_literal: true

require 'spec_helper'
require 'net/http'
require 'socket'
require 'timeout'

RSpec.describe 'RubyProxyHeaders::NetHTTP CONNECT target validation' do
  before do
    WebMock.allow_net_connect!
    RubyProxyHeaders::NetHTTP.patch!
  end

  after do
    WebMock.disable_net_connect!
  end

  def proxied_https(host, port)
    http = Net::HTTP.new(host, port, '127.0.0.1', 9)
    http.use_ssl = true
    http.open_timeout = 1
    http.read_timeout = 1
    http
  end

  def connect!(http)
    http.send(:connect)
  end

  it 'rejects CONNECT host containing CR' do
    expect { connect!(proxied_https("evil.com\r\nX-Injected: smuggled", 443)) }
      .to raise_error(ArgumentError, /target host.*invalid/i)
  end

  it 'rejects CONNECT host containing LF' do
    expect { connect!(proxied_https("evil.com\nX-Injected: smuggled", 443)) }
      .to raise_error(ArgumentError, /target host.*invalid/i)
  end

  it 'rejects CONNECT host containing NUL' do
    expect { connect!(proxied_https("evil.com\0hidden", 443)) }
      .to raise_error(ArgumentError, /target host.*invalid/i)
  end

  it 'rejects CONNECT port containing CR' do
    expect { connect!(proxied_https('example.com', "443\r\nX-Port-Injected: yes")) }
      .to raise_error(ArgumentError, /target port.*invalid/i)
  end

  it 'does not reject a clean host and port at the CONNECT target check' do
    expect do
      connect!(proxied_https('example.com', 443))
    rescue ArgumentError
      raise
    rescue StandardError
      nil
    end.not_to raise_error
  end

  it 'does not write a CONNECT request when the target host contains CRLF' do
    server = TCPServer.new('127.0.0.1', 0)
    port = server.addr[1]
    received = Queue.new
    thr = Thread.new do
      begin
        sock = Timeout.timeout(0.3) { server.accept }
        received << sock.readpartial(4096)
        sock.close
      rescue Timeout::Error, EOFError, Errno::ECONNRESET, Errno::EAGAIN
        received << :none
      end
    end

    http = Net::HTTP.new("evil.com\r\nX-Injected: smuggled", 443, '127.0.0.1', port)
    http.use_ssl = true
    http.open_timeout = 1
    http.read_timeout = 1

    expect { connect!(http) }.to raise_error(ArgumentError, /target host.*invalid/i)

    payload = begin
      Timeout.timeout(0.5) { received.pop }
    rescue Timeout::Error
      :none
    end
    expect(payload).to eq(:none)

    thr.kill
    server.close
  end
end
