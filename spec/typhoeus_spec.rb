# frozen_string_literal: true

require 'spec_helper'
require 'ruby_proxy_headers/typhoeus'
require 'timeout'
require_relative 'support/typhoeus_connect_proxy'

RSpec.describe RubyProxyHeaders::Typhoeus do
  let(:proxy) { 'http://127.0.0.1:9' }

  def header_response(*blocks)
    raw = blocks.join("\r\n\r\n")
    ::Typhoeus::Response.new(response_code: 200, response_headers: raw, response_body: 'origin-ok')
  end

  describe '.request' do
    it 'sends proxy headers on a separate proxyheader list and reads the CONNECT block' do
      response = header_response(
        "HTTP/1.1 200 Connection established\r\nX-ProxyMesh-IP: 203.0.113.10",
        "HTTP/1.1 302 Found\r\nLocation: https://example.test/next",
        "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nX-ProxyMesh-IP: from-origin"
      )
      captured = nil
      allow(::Typhoeus::Request).to receive(:new) do |_url, options|
        captured = options
        instance_double(::Typhoeus::Request, run: response)
      end

      result = described_class.get(
        'https://example.test/resource',
        proxy: proxy,
        proxy_headers: { 'X-ProxyMesh-Country' => 'US' },
        headers: { 'X-App-Secret' => 'should-not-leak' }
      )

      expect(captured[:proxy]).to eq(proxy)
      expect(captured[:method]).to eq(:get)
      expect(captured[:headeropt]).to eq(:separate)
      expect(captured[:headers]).to include('X-App-Secret' => 'should-not-leak')
      expect(captured[:proxyheader]).to be_a(::Ethon::Curl::Slist)
      expect(captured[:proxyheader].to_a).to eq(['X-ProxyMesh-Country: US'])
      expect(result.code).to eq(200)
      expect(result.proxy_response_headers).to eq('x-proxymesh-ip' => '203.0.113.10')
      expect(result.headers['x-proxymesh-ip']).to eq('from-origin')
      expect(result.headers['content-type']).to eq('text/plain')
    end

    it 'does not set proxyheader when no proxy headers are given' do
      response = header_response(
        "HTTP/1.1 200 Connection established\r\nX-ProxyMesh-IP: 203.0.113.4",
        "HTTP/1.1 200 OK\r\nContent-Type: application/json"
      )
      captured = nil
      allow(::Typhoeus::Request).to receive(:new) do |_url, options|
        captured = options
        instance_double(::Typhoeus::Request, run: response)
      end

      result = described_class.post(
        'https://example.test/items',
        proxy: proxy,
        body: 'payload'
      )

      expect(captured[:method]).to eq(:post)
      expect(captured[:body]).to eq('payload')
      expect(captured).not_to have_key(:proxyheader)
      expect(captured).not_to have_key(:headeropt)
      expect(result.proxy_response_headers['x-proxymesh-ip']).to eq('203.0.113.4')
    end

    it 'ignores header blocks that are not a CONNECT response' do
      response = header_response(
        "HTTP/1.1 302 Found\r\nLocation: https://example.test/next",
        "HTTP/1.1 200 OK\r\nContent-Type: text/plain"
      )
      allow(::Typhoeus::Request).to receive(:new) do |_url, _options|
        instance_double(::Typhoeus::Request, run: response)
      end

      result = described_class.get('http://example.test/', proxy: proxy, proxy_headers: {})

      expect(result.proxy_response_headers).to eq({})
    end

    it 'rejects proxy header values that could inject extra headers' do
      expect(::Typhoeus::Request).not_to receive(:new)

      expect do
        described_class.get(
          'https://example.test/',
          proxy: proxy,
          proxy_headers: { 'X-ProxyMesh-Country' => "US\r\nX-Injected: yes" }
        )
      end.to raise_error(ArgumentError, /header value.*invalid/)
    end
  end

  describe 'local CONNECT proxy', :network do
    around do |example|
      WebMock.allow_net_connect!
      example.run
    ensure
      WebMock.disable_net_connect!
    end

    it 'sends proxy headers only on CONNECT and returns X-ProxyMesh-IP' do
      origin = TyphoeusConnectLab::Origin.new
      proxy_server = TyphoeusConnectLab::Proxy.new

      result = Timeout.timeout(10) do
        described_class.get(
          "https://127.0.0.1:#{origin.port}/tunnel",
          proxy: "http://127.0.0.1:#{proxy_server.port}",
          proxy_headers: { 'X-ProxyMesh-Country' => 'US' },
          headers: { 'X-App-Secret' => 'should-not-leak' },
          ssl_verifypeer: false,
          ssl_verifyhost: 0,
          http_version: :httpv1_1,
          timeout: 5
        )
      end

      connect = proxy_server.connect_request.to_s
      origin_request = origin.request.to_s

      expect(connect).to start_with('CONNECT 127.0.0.1:')
      expect(connect).to include('X-ProxyMesh-Country: US')
      expect(connect).not_to include('X-App-Secret')
      expect(connect).not_to include('should-not-leak')
      expect(origin_request).to include('X-App-Secret: should-not-leak')
      expect(origin_request).not_to include('X-ProxyMesh-Country')
      expect(result.code).to eq(200)
      expect(result.body).to eq('origin-ok')
      expect(result.proxy_response_headers['x-proxymesh-ip']).to eq('203.0.113.10')
      expect(result.headers['x-proxymesh-ip']).to be_nil
      expect(proxy_server.error).to be_nil
      expect(origin.error).to be_nil
    ensure
      proxy_server&.stop
      origin&.stop
    end
  end
end
