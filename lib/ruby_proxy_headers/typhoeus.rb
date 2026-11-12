# frozen_string_literal: true

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
  # +response_headers+. Typhoeus's +response.headers+ is only the last block,
  # the origin response. This adapter copies the CONNECT block into
  # +proxy_response_headers+.
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
        typhoeus_options = options.merge(proxy: proxy, method: method)
        apply_proxy_headers!(typhoeus_options, proxy_headers || {})

        response = ::Typhoeus::Request.new(url, typhoeus_options).run
        ProxyResponse.new(response, extract_proxy_response_headers(response))
      end

      private

      # The Slist must remain referenced by the options hash stored on the
      # Typhoeus request. libcurl does not copy CURLOPT_PROXYHEADER, and Ethon
      # drops its own reference during Easy#reset before the transfer returns.
      def apply_proxy_headers!(typhoeus_options, proxy_headers)
        return if proxy_headers.empty?

        ensure_proxyheader_support!
        typhoeus_options[:proxyheader] = proxyheader_slist(proxy_headers)
        typhoeus_options[:headeropt] = :separate
      end

      def ensure_proxyheader_support!
        curl_options = ::Ethon::Curl.easy_options(nil)
        return if curl_options.key?(:proxyheader) && curl_options.key?(:headeropt)

        raise LoadError,
              'RubyProxyHeaders::Typhoeus requires Ethon >= 0.19.1 (:proxyheader and :headeropt) ' \
              'and libcurl with CURLOPT_PROXYHEADER. Install typhoeus ~> 1.7 and ethon >= 0.19.1.'
      end

      def proxyheader_slist(proxy_headers)
        lines = proxy_headers.map { |name, value| proxy_header_line(name, value) }
        pointer = ::Ethon::Curl::Slist.build(lines)
        raise ArgumentError, 'failed to build the proxy header list' if pointer.nil? || pointer.null?

        ::Ethon::Curl::Slist.new(pointer)
      end

      def proxy_header_line(name, value)
        RubyProxyHeaders.validate_header!(name, value)
        "#{name}: #{value}"
      end

      def extract_proxy_response_headers(response)
        blocks = http_blocks(response)
        return HeaderMap.new if blocks.empty?

        first = blocks.first
        return HeaderMap.new unless connect_response?(first)

        parse_header_block(first)
      end

      def http_blocks(response)
        return [] unless response.respond_to?(:response_headers)

        raw = response.response_headers
        return [] if raw.nil? || raw.empty?

        raw.to_s.split(/\r?\n\r?\n/).filter_map do |block|
          text = block.strip
          text if text.lstrip.start_with?('HTTP/')
        end
      end

      def connect_response?(block)
        block.lstrip.lines.first.to_s.match?(CONNECT_ESTABLISHED)
      end

      def parse_header_block(block)
        headers = HeaderMap.new
        block.each_line do |line|
          name, value = header_pair(line)
          next if name.nil?

          headers[name] = headers.key?(name) ? "#{headers[name]}, #{value}" : value
        end
        headers
      end

      def header_pair(line)
        stripped = line.strip
        return if stripped.empty? || stripped.start_with?('HTTP/')

        name, value = stripped.split(':', 2)
        return if name.nil? || value.nil?

        [name.strip, value.strip]
      end
    end

    # Typhoeus response plus the CONNECT response headers.
    class ProxyResponse
      attr_reader :proxy_response_headers

      def initialize(response, proxy_headers)
        @response = response
        @proxy_response_headers = proxy_headers
      end

      def method_missing(name, *args, &block)
        if @response.respond_to?(name)
          @response.public_send(name, *args, &block)
        else
          super
        end
      end

      def respond_to_missing?(name, include_private = false)
        @response.respond_to?(name, include_private) || super
      end
    end
  end
end
