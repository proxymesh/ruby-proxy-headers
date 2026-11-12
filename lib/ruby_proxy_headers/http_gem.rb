# frozen_string_literal: true

require 'delegate'
require 'openssl'
require 'uri'
require_relative '../ruby_proxy_headers'

begin
  require 'http'
rescue LoadError => e
  raise LoadError, "the http gem >= 6 is required for ruby_proxy_headers/http_gem (#{e.message})"
end

module RubyProxyHeaders
  # HTTP.rb (the +http+ gem) sends +proxy_headers+ on CONNECT and returns them
  # as +response.proxy_headers+. This wrapper adds +proxy_response_headers+,
  # matching the other adapters.
  #
  # @example
  #   client = RubyProxyHeaders::HTTPGem.create_client(
  #     proxy: 'http://user:pass@proxy.example.com:31280',
  #     proxy_headers: { 'X-ProxyMesh-Country' => 'US' }
  #   )
  #   response = client.get('https://example.com')
  #   puts response.proxy_response_headers['X-ProxyMesh-IP']
  module HTTPGem
    def self.create_client(proxy:, proxy_headers: {}, **options)
      ProxyClient.new(proxy: proxy, proxy_headers: proxy_headers, **options)
    end

    def self.get(url, proxy:, proxy_headers: {}, **options)
      create_client(proxy: proxy, proxy_headers: proxy_headers).get(url, **options)
    end

    def self.post(url, proxy:, proxy_headers: {}, body: nil, **options)
      create_client(proxy: proxy, proxy_headers: proxy_headers).post(url, body: body, **options)
    end

    # HTTP.rb client that sends proxy_headers on CONNECT.
    class ProxyClient
      attr_reader :last_proxy_response_headers

      REQUEST_OPTIONS = %i[open_timeout read_timeout headers body verify_ssl].freeze

      def initialize(proxy:, proxy_headers: {}, **options)
        @proxy = proxy
        @proxy_headers = proxy_headers
        @default_options = options
      end

      def get(url, **options)
        request(:get, url, **options)
      end

      def post(url, body: nil, **options)
        request(:post, url, body: body, **options)
      end

      def put(url, body: nil, **options)
        request(:put, url, body: body, **options)
      end

      def delete(url, **options)
        request(:delete, url, **options)
      end

      private

      def request(method, url, **options)
        options = @default_options.merge(options)
        unknown = options.keys - REQUEST_OPTIONS
        raise ArgumentError, "unknown option: #{unknown.first}" unless unknown.empty?

        @proxy_headers.each { |key, value| RubyProxyHeaders.validate_header!(key, value) }
        proxy_uri = URI.parse(@proxy)
        user = proxy_uri.user && URI.decode_www_form_component(proxy_uri.user)
        password = proxy_uri.password && URI.decode_www_form_component(proxy_uri.password)
        client = ::HTTP.via(proxy_uri.host, proxy_uri.port, user, password, @proxy_headers)
        timeouts = {}
        timeouts[:connect] = options[:open_timeout] if options[:open_timeout]
        timeouts[:read] = options[:read_timeout] if options[:read_timeout]
        client = client.timeout(timeouts) unless timeouts.empty?

        request_options = {}
        request_options[:headers] = options[:headers] if options[:headers]
        request_options[:body] = options[:body] unless options[:body].nil?
        if options[:verify_ssl] == false
          context = OpenSSL::SSL::SSLContext.new
          context.verify_mode = OpenSSL::SSL::VERIFY_NONE
          request_options[:ssl_context] = context
        end

        response = client.request(method, url, **request_options)
        # HTTP::Headers is not a Hash. Copy into HeaderMap so callers can
        # read X-ProxyMesh-IP the same way as the other adapters.
        mapped = HeaderMap.new
        response.proxy_headers.each do |name, value|
          mapped[name] = mapped.key?(name) ? "#{mapped[name]}, #{value}" : value
        end
        @last_proxy_response_headers = mapped
        ProxyResponse.new(response, mapped)
      end
    end

    # HTTP::Response plus +proxy_response_headers+.
    class ProxyResponse < SimpleDelegator
      attr_reader :proxy_response_headers

      def initialize(response, proxy_headers)
        super(response)
        @proxy_response_headers = proxy_headers
      end
    end
  end
end
