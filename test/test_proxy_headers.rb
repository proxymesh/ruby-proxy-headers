#!/usr/bin/env ruby
# frozen_string_literal: true

# Integration test for ruby-proxy-headers.
# Tests all supported libraries with actual proxy connections.
#
# Configuration via environment variables:
#   PROXY_URL           - Proxy URL (required)
#   TEST_URL            - URL to request (default: https://api.ipify.org?format=json)
#   PROXY_HEADER        - Header name to check in response (optional)
#   SEND_PROXY_HEADER   - Header name to send to proxy (optional)
#   SEND_PROXY_VALUE    - Header value to send to proxy (optional)
#
# Usage:
#   ruby test/test_proxy_headers.rb           # Run all tests
#   ruby test/test_proxy_headers.rb net_http  # Run specific test
#   ruby test/test_proxy_headers.rb -l        # List available tests
#   ruby test/test_proxy_headers.rb -v        # Verbose output

require_relative '../lib/ruby_proxy_headers'

AVAILABLE_TESTS = {
  'net_http' => {
    name: 'Net::HTTP',
    run: lambda do |config|
      response = RubyProxyHeaders::NetHTTP.get(
        config[:test_url],
        proxy: config[:proxy_url],
        proxy_headers: config[:proxy_headers_to_send]
      )
      {
        status: response.code,
        body: response.body,
        proxy_headers: response.proxy_response_headers
      }
    end
  },
  'faraday' => {
    name: 'Faraday',
    run: lambda do |config|
      require 'faraday'
      conn = Faraday.new do |f|
        f.use RubyProxyHeaders::Faraday::Middleware,
              proxy: config[:proxy_url],
              proxy_headers: config[:proxy_headers_to_send]
        f.adapter Faraday.default_adapter
      end
      response = conn.get(config[:test_url])
      {
        status: response.status,
        body: response.body,
        proxy_headers: response.env[:proxy_response_headers] || {}
      }
    end
  },
  'httparty' => {
    name: 'HTTParty',
    run: lambda do |config|
      response = RubyProxyHeaders::HTTParty.get(
        config[:test_url],
        proxy: config[:proxy_url],
        proxy_headers: config[:proxy_headers_to_send]
      )
      {
        status: response.code,
        body: response.body,
        proxy_headers: response.proxy_response_headers
      }
    end
  },
  'http_gem' => {
    name: 'HTTP.rb',
    run: lambda do |config|
      client = RubyProxyHeaders::HTTPGem.create_client(
        proxy: config[:proxy_url],
        proxy_headers: config[:proxy_headers_to_send]
      )
      response = client.get(config[:test_url])
      {
        status: response.code,
        body: response.body,
        proxy_headers: client.last_proxy_response_headers || {}
      }
    end
  },
  'typhoeus' => {
    name: 'Typhoeus',
    run: lambda do |config|
      response = RubyProxyHeaders::Typhoeus.get(
        config[:test_url],
        proxy: config[:proxy_url],
        proxy_headers: config[:proxy_headers_to_send]
      )
      {
        status: response.code,
        body: response.body,
        proxy_headers: response.proxy_response_headers
      }
    end
  },
  'excon' => {
    name: 'Excon',
    run: lambda do |config|
      response = RubyProxyHeaders::Excon.get(
        config[:test_url],
        proxy: config[:proxy_url],
        proxy_headers: config[:proxy_headers_to_send]
      )
      {
        status: response.code,
        body: response.body,
        proxy_headers: response.proxy_response_headers
      }
    end
  },
  'rest_client' => {
    name: 'RestClient',
    run: lambda do |config|
      response = RubyProxyHeaders::RestClient.get(
        config[:test_url],
        proxy: config[:proxy_url],
        proxy_headers: config[:proxy_headers_to_send]
      )
      {
        status: response.code,
        body: response.body,
        proxy_headers: response.proxy_response_headers
      }
    end
  }
}.freeze

def parse_args(args)
  options = {
    verbose: false,
    list: false,
    help: false,
    tests: []
  }

  args.each do |arg|
    case arg
    when '-v', '--verbose'
      options[:verbose] = true
    when '-l', '--list'
      options[:list] = true
    when '-h', '--help'
      options[:help] = true
    else
      options[:tests] << arg unless arg.start_with?('-')
    end
  end

  options
end

def show_help
  puts <<~HELP
    ruby-proxy-headers Integration Tests

    Usage:
      ruby test/test_proxy_headers.rb [options] [test1] [test2] ...

    Options:
      -v, --verbose    Show detailed output
      -l, --list       List available tests
      -h, --help       Show this help message

    Environment Variables:
      PROXY_URL           Proxy URL (required)
      TEST_URL            URL to request (default: https://api.ipify.org?format=json)
      PROXY_HEADER        Header name to check in response
      SEND_PROXY_HEADER   Header name to send to proxy
      SEND_PROXY_VALUE    Header value to send to proxy

    Examples:
      PROXY_URL='http://proxy:8080' ruby test/test_proxy_headers.rb
      ruby test/test_proxy_headers.rb net_http faraday
  HELP
end

def list_tests
  puts 'Available tests:'
  AVAILABLE_TESTS.each do |key, test|
    puts "  #{key.ljust(15)} #{test[:name]}"
  end
end

def mask_password(url)
  url.sub(/:[^:@]+@/, ':****@')
end

def check_header(headers, header_name)
  return nil unless header_name && headers

  normalized = header_name.downcase.gsub('_', '-')
  headers.each do |name, value|
    return value if name.downcase.gsub('_', '-') == normalized
  end
  nil
end

def run_test(test_key, test_info, config, verbose)
  print "Testing #{test_info[:name]}... "

  begin
    result = test_info[:run].call(config)

    if verbose
      puts
      puts "  Status: #{result[:status]}"
      puts "  Body: #{result[:body]&.slice(0, 100)}"
      puts "  Proxy Headers: #{result[:proxy_headers]}"
    end

    if config[:proxy_header]
      header_value = check_header(result[:proxy_headers], config[:proxy_header])
      if header_value
        puts verbose ? "  #{config[:proxy_header]}: #{header_value}" : "OK (#{config[:proxy_header]}=#{header_value})"
        return true
      else
        puts "FAILED (header '#{config[:proxy_header]}' not found)"
        return false
      end
    end

    puts 'OK'
    true
  rescue StandardError => e
    puts "FAILED"
    puts "  Error: #{e.message}" if verbose
    false
  end
end

def main
  options = parse_args(ARGV)

  if options[:help]
    show_help
    exit 0
  end

  if options[:list]
    list_tests
    exit 0
  end

  proxy_url = ENV['PROXY_URL'] || ENV['HTTPS_PROXY']
  unless proxy_url
    warn 'Error: Set PROXY_URL environment variable'
    warn "\nExample:"
    warn "  export PROXY_URL='http://user:pass@proxy:8080'"
    exit 1
  end

  config = {
    proxy_url: proxy_url,
    test_url: ENV['TEST_URL'] || 'https://api.ipify.org?format=json',
    proxy_header: ENV['PROXY_HEADER'],
    proxy_headers_to_send: {}
  }

  if ENV['SEND_PROXY_HEADER'] && ENV['SEND_PROXY_VALUE']
    config[:proxy_headers_to_send][ENV['SEND_PROXY_HEADER']] = ENV['SEND_PROXY_VALUE']
  end

  tests_to_run = if options[:tests].any?
    AVAILABLE_TESTS.select { |k, _| options[:tests].include?(k) }
  else
    AVAILABLE_TESTS
  end

  puts '=' * 60
  puts 'ruby-proxy-headers Integration Tests'
  puts '=' * 60
  puts "Proxy URL:       #{mask_password(config[:proxy_url])}"
  puts "Test URL:        #{config[:test_url]}"
  puts "Proxy Header:    #{config[:proxy_header] || '(not checking)'}"
  puts "Send Headers:    #{config[:proxy_headers_to_send].empty? ? '(none)' : config[:proxy_headers_to_send]}"
  puts "Tests:           #{tests_to_run.length}"
  puts '=' * 60
  puts

  passed = 0
  failed = 0

  tests_to_run.each do |key, test_info|
    if run_test(key, test_info, config, options[:verbose])
      passed += 1
    else
      failed += 1
    end
  end

  puts
  puts '=' * 60
  puts "Results: #{passed} passed, #{failed} failed"
  puts '=' * 60

  exit(failed.positive? ? 1 : 0)
end

main if __FILE__ == $PROGRAM_NAME
