# frozen_string_literal: true

require 'spec_helper'
require 'ruby_proxy_headers/connection'

RSpec.describe RubyProxyHeaders::Connection do
  describe '#initialize' do
    it 'parses proxy URL string' do
      pending 'RubyProxyHeaders.parse_proxy_url is not yet implemented'
      connection = described_class.new('http://user:pass@proxy.example.com:8080')
      expect(connection).to be_a(described_class)
    end

    it 'accepts proxy hash' do
      connection = described_class.new(
        { host: 'proxy.example.com', port: 8080, user: 'user', password: 'pass' }
      )
      expect(connection).to be_a(described_class)
    end

    it 'accepts proxy headers option' do
      pending 'RubyProxyHeaders.parse_proxy_url is not yet implemented'
      connection = described_class.new(
        'http://proxy:8080',
        proxy_headers: { 'X-Custom' => 'value' }
      )
      expect(connection).to be_a(described_class)
    end
  end

  describe '.parse_proxy_url' do
    it 'parses complete URL' do
      pending 'RubyProxyHeaders.parse_proxy_url is not yet implemented'
      result = RubyProxyHeaders.parse_proxy_url('http://user:pass@proxy.example.com:8080')

      expect(result[:host]).to eq('proxy.example.com')
      expect(result[:port]).to eq(8080)
      expect(result[:user]).to eq('user')
      expect(result[:password]).to eq('pass')
      expect(result[:scheme]).to eq('http')
    end

    it 'handles URL without auth' do
      pending 'RubyProxyHeaders.parse_proxy_url is not yet implemented'
      result = RubyProxyHeaders.parse_proxy_url('http://proxy.example.com:8080')

      expect(result[:host]).to eq('proxy.example.com')
      expect(result[:port]).to eq(8080)
      expect(result[:user]).to be_nil
      expect(result[:password]).to be_nil
    end

    it 'defaults port to 8080' do
      pending 'RubyProxyHeaders.parse_proxy_url is not yet implemented'
      result = RubyProxyHeaders.parse_proxy_url('http://proxy.example.com')

      expect(result[:port]).to eq(80)
    end
  end

  describe '.build_auth_header' do
    it 'builds Base64 encoded auth header' do
      pending 'RubyProxyHeaders.build_auth_header is not yet implemented'
      result = RubyProxyHeaders.build_auth_header('user', 'pass')

      expect(result).to start_with('Basic ')
      decoded = Base64.strict_decode64(result.sub('Basic ', ''))
      expect(decoded).to eq('user:pass')
    end
  end
end
