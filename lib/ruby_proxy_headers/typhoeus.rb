# frozen_string_literal: true

require 'delegate'
require_relative '../ruby_proxy_headers'

begin
  require 'typhoeus'
rescue LoadError => e
  raise LoadError, "typhoeus ~> 1.7 is required for ruby_proxy_headers/typhoeus (#{e.message})"
end

module RubyProxyHeaders
  # Typhoeus adapter using libcurl's proxy-header list.
  #
  # Typhoeus 1.7 / Ethon 0.19 expose +:proxyheader+ (`CURLOPT_PROXYHEADER`) and
  # +:headeropt+ (`CURLOPT_HEADEROPT`). With +headeropt: :separate+, those
  # headers are sent only to the proxy. On HTTPS that is the CONNECT request.
  # +:headers+ stay on the tunneled origin request.
  #
  # libcurl records the CONNECT response as the first header block of
  # +response_headers+. Typhoeus's +response.headers+ is only the last block.
  # +proxy_response_headers+ is that CONNECT block.
  #
  # @example
  #   response = RubyProxyHeaders::Typhoeus.get(
  #     'https://api.ipify.org?format=json',
  #     proxy: 'http://user:pass@proxy.example.com:31280',
  #     proxy_headers: { 'X-ProxyMesh-Country' => 'US' }
  #   )
  #   puts response.proxy_response_headers['X-ProxyMesh-IP']
  module Typhoeus
    CONNECT_ESTABLISHED = /connection established/i

    class << self
      def get(url, proxy:, proxy_headers: {}, **options)
        request(:get, url, proxy: proxy, proxy_headers: proxy_headers, **options)
      end

      def post(url, proxy:, proxy_headers: {}, body: nil, **options)
        request(:post, url, proxy: proxy, proxy_headers: proxy_headers, body: body, **options)
      end

      def request(method, url, proxy:, proxy_headers: {}, **options)
        proxy_headers ||= {}
        typhoeus_options = options.merge(proxy: proxy, method: method)
        unless proxy_headers.empty?
          lines = proxy_headers.map do |name, value|
            RubyProxyHeaders.validate_header!(name, value)
            "#{name}: #{value}"
          end
          # The Slist has to stay in the options Typhoeus keeps. libcurl does not
          # copy CURLOPT_PROXYHEADER, and Ethon clears its own reference on reset.
          typhoeus_options[:proxyheader] = ::Ethon::Curl::Slist.new(::Ethon::Curl::Slist.build(lines))
          typhoeus_options[:headeropt] = :separate
        end

        response = ::Typhoeus::Request.new(url, typhoeus_options).run
        ProxyResponse.new(response, connect_headers(response))
      end

      private

      def connect_headers(response)
        raw = response.response_headers.to_s
        block = raw.split(/\r?\n\r?\n/).map(&:strip).find { |part| part.start_with?('HTTP/') }
        return HeaderMap.new if block.nil?
        return HeaderMap.new unless block.lines.first.to_s.match?(CONNECT_ESTABLISHED)

        headers = HeaderMap.new
        block.each_line do |line|
          stripped = line.strip
          next if stripped.empty? || stripped.start_with?('HTTP/')

          name, value = stripped.split(':', 2)
          next if name.nil? || value.nil?

          name = name.strip
          value = value.strip
          headers[name] = headers.key?(name) ? "#{headers[name]}, #{value}" : value
        end
        headers
      end
    end

    # Typhoeus response plus the CONNECT response headers.
    class ProxyResponse < SimpleDelegator
      attr_reader :proxy_response_headers

      def initialize(response, proxy_headers)
        super(response)
        @proxy_response_headers = proxy_headers
      end
    end
  end
end
