# frozen_string_literal: true

require_relative '../ruby_proxy_headers'

begin
  require 'typhoeus'
rescue LoadError => e
  raise LoadError,
        'typhoeus ~> 1.7 is required for ruby_proxy_headers/typhoeus ' \
        "(#{e.message})"
end

module RubyProxyHeaders
  # Typhoeus adapter using libcurl's proxy-header list.
  #
  # Typhoeus 1.7 / Ethon 0.19 expose +:proxyheader+ (`CURLOPT_PROXYHEADER`)
  # and +:headeropt+ (`CURLOPT_HEADEROPT`). With +headeropt: :separate+,
  # proxy headers are sent only to the proxy. On HTTPS that is the CONNECT
  # request; +:headers+ stay on the tunneled origin request.
  #
  # libcurl records the CONNECT response as the first header block of
  # +response_headers+. Typhoeus's +response.headers+ is the last block (the
  # origin response) only. This adapter parses the CONNECT block into
  # +proxy_response_headers+ with lowercase names, matching Net::HTTP.
  #
  # @example
  #   response = RubyProxyHeaders::Typhoeus.get(
  #     'https://example.com',
  #     proxy: 'http://user:pass@proxy:8080',
  #     proxy_headers: { 'X-ProxyMesh-Country' => 'US' }
  #   )
  #   puts response.proxy_response_headers['x-proxymesh-ip']
  #
  module Typhoeus
    CONNECT_ESTABLISHED = /connection established/i

    class << self
      # Make a GET request with proxy headers.
      # @param url [String] Target URL
      # @param proxy [String] Proxy URL
      # @param proxy_headers [Hash] Custom headers to send to the proxy
      # @param options [Hash] Additional Typhoeus options
      # @return [ProxyResponse]
      def get(url, proxy:, proxy_headers: {}, **options)
        request(:get, url, proxy: proxy, proxy_headers: proxy_headers, **options)
      end

      # Make a POST request with proxy headers.
      # @param url [String] Target URL
      # @param proxy [String] Proxy URL
      # @param proxy_headers [Hash] Custom headers to send to the proxy
      # @param body [String, nil] Request body
      # @param options [Hash] Additional Typhoeus options
      # @return [ProxyResponse]
      def post(url, proxy:, proxy_headers: {}, body: nil, **options)
        request(:post, url, proxy: proxy, proxy_headers: proxy_headers, body: body, **options)
      end

      # Make a request with proxy headers.
      # @param method [Symbol] HTTP method
      # @param url [String] Target URL
      # @param proxy [String] Proxy URL
      # @param proxy_headers [Hash] Custom headers to send to the proxy
      # @param options [Hash] Additional Typhoeus options
      # @return [ProxyResponse]
      def request(method, url, proxy:, proxy_headers: {}, **options)
        typhoeus_options = options.merge(proxy: proxy, method: method)
        apply_proxy_headers!(typhoeus_options, proxy_headers || {})

        response = ::Typhoeus::Request.new(url, typhoeus_options).run
        ProxyResponse.new(response, extract_proxy_response_headers(response))
      end

      private

      # libcurl does not copy the CURLOPT_PROXYHEADER list. The Slist wrapper
      # stays referenced by the options hash passed to Typhoeus::Request, which
      # outlives the easy-handle reset Typhoeus performs before #run returns.
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
              'RubyProxyHeaders::Typhoeus requires Ethon >= 0.19 (:proxyheader and :headeropt) ' \
              'and libcurl with CURLOPT_PROXYHEADER. Install typhoeus ~> 1.7 and ethon ~> 0.19.'
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
        block = connect_response_block(response)
        return {} if block.nil?

        parse_header_block(block)
      end

      def connect_response_block(response)
        first = first_http_block(response)
        return nil if first.nil?

        status = first.lstrip.lines.first.to_s
        status.match?(CONNECT_ESTABLISHED) ? first : nil
      end

      def first_http_block(response)
        return nil unless response.respond_to?(:response_headers)

        raw = response.response_headers
        return nil if raw.nil? || raw.empty?

        raw.to_s.gsub("\r\n", "\n").split("\n\n").find { |block| block.lstrip.start_with?('HTTP/') }
      end

      def parse_header_block(block)
        headers = {}
        block.each_line do |line|
          name, value = header_pair(line)
          next if name.nil?

          key = name.downcase
          headers[key] = headers.key?(key) ? "#{headers[key]}, #{value}" : value
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

    # Response wrapper with proxy headers accessor.
    class ProxyResponse
      attr_reader :proxy_response_headers

      def initialize(response, proxy_headers)
        @response = response
        @proxy_response_headers = proxy_headers
      end

      def code
        @response.code
      end

      def body
        @response.body
      end

      def headers
        @response.headers
      end

      def success?
        @response.success?
      end

      def method_missing(method, *args, &block)
        @response.send(method, *args, &block)
      end

      def respond_to_missing?(method, include_private = false)
        @response.respond_to?(method, include_private) || super
      end
    end
  end
end
