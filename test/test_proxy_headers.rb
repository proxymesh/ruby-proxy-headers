#!/usr/bin/env ruby
# frozen_string_literal: true

# Integration harness (same env contract as python-proxy-headers / javascript-proxy-headers):
#   PROXY_URL, HTTPS_PROXY
#   TEST_URL (default https://api.ipify.org?format=json)
#   PROXY_HEADER (default X-ProxyMesh-IP) — header to read from CONNECT response
#   SEND_PROXY_HEADER, SEND_PROXY_VALUE — optional extra headers on CONNECT
#
# Usage:
#   ruby test/test_proxy_headers.rb [-v] [net_http ...]

require 'uri'
require 'openssl'

ROOT = File.expand_path('..', __dir__)
$LOAD_PATH.unshift(File.join(ROOT, 'lib'))

require 'ruby_proxy_headers/net_http'

def env_proxy_url
  ENV['PROXY_URL'] || ENV['HTTPS_PROXY'] || ENV['https_proxy']
end

def test_net_http(verbose:)
  proxy_url = env_proxy_url
  raise 'Set PROXY_URL' unless proxy_url

  test_url = ENV.fetch('TEST_URL', 'https://api.ipify.org?format=json')
  proxy_header = ENV.fetch('PROXY_HEADER', 'X-ProxyMesh-IP')
  send_name = ENV['SEND_PROXY_HEADER']
  send_val = ENV['SEND_PROXY_VALUE']

  RubyProxyHeaders::NetHTTP.patch! unless RubyProxyHeaders::NetHTTP.patched?

  uri = URI.parse(test_url)
  proxy = URI.parse(proxy_url)

  http = Net::HTTP.new(uri.host, uri.port, proxy.host, proxy.port, proxy.user, proxy.password)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_PEER

  headers = {}
  headers[send_name] = send_val if send_name && send_val
  http.proxy_connect_request_headers = headers unless headers.empty?

  req = Net::HTTP::Get.new(uri)
  res = http.request(req)

  unless res.is_a?(Net::HTTPSuccess)
    return { ok: false, error: "HTTP #{res.code}" }
  end

  ph = http.last_proxy_connect_response_headers
  unless ph.is_a?(Hash)
    return { ok: false, error: 'No proxy CONNECT headers captured' }
  end

  # Case-insensitive lookup
  key = ph.keys.find { |k| k.casecmp(proxy_header).zero? }
  val = key ? ph[key] : nil

  if val.nil? || val.empty?
    return { ok: false, error: "Missing #{proxy_header} in CONNECT response (#{ph.keys.join(', ')})" }
  end

  puts "[PASS] net_http: #{val}" if verbose
  { ok: true, value: val }
rescue StandardError => e
  { ok: false, error: e.message }
end

MODULES = {
  'net_http' => method(:test_net_http)
}.freeze

def main
  verbose = ARGV.delete('-v') || ARGV.delete('--verbose')
  list = ARGV.delete('-l') || ARGV.delete('--list')

  if list
    puts MODULES.keys.sort.join("\n")
    exit 0
  end

  mods = ARGV.empty? ? MODULES.keys : ARGV
  failed = 0

  mods.each do |name|
    fn = MODULES[name]
    unless fn
      warn "Unknown module: #{name}"
      failed += 1
      next
    end
    print "Testing #{name}... "
    r = fn.call(verbose: verbose)
    if r[:ok]
      puts 'OK'
    else
      puts "FAIL (#{r[:error]})"
      failed += 1
    end
  end

  exit(failed.positive? ? 1 : 0)
end

main if __FILE__ == $PROGRAM_NAME
