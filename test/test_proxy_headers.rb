#!/usr/bin/env ruby
# frozen_string_literal: true

# Integration harness (same env contract as python-proxy-headers / javascript-proxy-headers):
#   PROXY_URL, HTTPS_PROXY
#   TEST_URL (default https://api.ipify.org?format=json)
#   PROXY_HEADER (default X-ProxyMesh-IP) — header to read from CONNECT response
#   SEND_PROXY_HEADER, SEND_PROXY_VALUE — optional extra headers on CONNECT
#
# Usage:
#   bundle exec ruby test/test_proxy_headers.rb [-v] [net_http faraday httparty excon]

require 'json'
require 'uri'
require 'openssl'

ROOT = File.expand_path('..', __dir__)
$LOAD_PATH.unshift(File.join(ROOT, 'lib'))

require 'ruby_proxy_headers'

def env_proxy_url
  ENV['PROXY_URL'] || ENV['HTTPS_PROXY'] || ENV['https_proxy']
end

def find_header(hash, name)
  return nil unless hash.is_a?(Hash)

  key = hash.keys.find { |k| k.casecmp(name).zero? }
  key ? hash[key] : nil
end

def send_headers_from_env
  n = ENV['SEND_PROXY_HEADER']
  v = ENV['SEND_PROXY_VALUE']
  return {} unless n && v

  { n => v }
end

def assert_proxy_header(val, proxy_header, verbose:, label:)
  if val.nil? || val.to_s.empty?
    return { ok: false, error: "Missing #{proxy_header} (module #{label})" }
  end

  puts "[PASS] #{label}: #{val}" if verbose
  { ok: true, value: val }
end

def test_net_http(verbose:)
  proxy_url = env_proxy_url
  raise 'Set PROXY_URL' unless proxy_url

  test_url = ENV.fetch('TEST_URL', 'https://api.ipify.org?format=json')
  proxy_header = ENV.fetch('PROXY_HEADER', 'X-ProxyMesh-IP')

  RubyProxyHeaders::NetHTTP.patch! unless RubyProxyHeaders::NetHTTP.patched?

  uri = URI.parse(test_url)
  proxy = URI.parse(proxy_url)

  http = Net::HTTP.new(uri.host, uri.port, proxy.host, proxy.port, proxy.user, proxy.password)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_PEER

  h = send_headers_from_env
  http.proxy_connect_request_headers = h if h.any?

  res = http.request(Net::HTTP::Get.new(uri))
  return { ok: false, error: "HTTP #{res.code}" } unless res.is_a?(Net::HTTPSuccess)

  ph = http.last_proxy_connect_response_headers
  val = find_header(ph, proxy_header)
  assert_proxy_header(val, proxy_header, verbose: verbose, label: 'net_http')
rescue StandardError => e
  { ok: false, error: e.message }
end

def test_faraday(verbose:)
  require 'ruby_proxy_headers/faraday'

  proxy_url = env_proxy_url
  raise 'Set PROXY_URL' unless proxy_url

  test_url = ENV.fetch('TEST_URL', 'https://api.ipify.org?format=json')
  proxy_header = ENV.fetch('PROXY_HEADER', 'X-ProxyMesh-IP')
  h = send_headers_from_env

  conn = RubyProxyHeaders::FaradayIntegration.connection(
    proxy: proxy_url,
    proxy_connect_headers: (h if h.any?)
  )
  res = conn.get(test_url)
  return { ok: false, error: "HTTP #{res.status}" } unless res.success?

  val = res.headers[proxy_header] || res.headers[proxy_header.downcase]
  assert_proxy_header(val, proxy_header, verbose: verbose, label: 'faraday')
rescue StandardError => e
  { ok: false, error: e.message }
end

def test_httparty(verbose:)
  require 'httparty'
  require 'ruby_proxy_headers/httparty'

  proxy_url = env_proxy_url
  raise 'Set PROXY_URL' unless proxy_url

  test_url = ENV.fetch('TEST_URL', 'https://api.ipify.org?format=json')
  proxy_header = ENV.fetch('PROXY_HEADER', 'X-ProxyMesh-IP')
  proxy = URI.parse(proxy_url)

  RubyProxyHeaders::NetHTTP.patch! unless RubyProxyHeaders::NetHTTP.patched?

  h = send_headers_from_env
  opts = {
    http_proxyaddr: proxy.host,
    http_proxyport: proxy.port,
    http_proxyuser: proxy.user,
    http_proxypass: proxy.password,
    connection_adapter: RubyProxyHeaders::ProxyHeadersConnectionAdapter
  }
  opts[:proxy_connect_request_headers] = h if h.any?

  res = HTTParty.get(test_url, opts)
  return { ok: false, error: "HTTP #{res.code}" } unless res.success?

  ph = RubyProxyHeaders.proxy_connect_response_headers
  val = find_header(ph, proxy_header)
  assert_proxy_header(val, proxy_header, verbose: verbose, label: 'httparty')
rescue StandardError => e
  { ok: false, error: e.message }
end

def test_excon(verbose:)
  require 'ruby_proxy_headers/excon'

  proxy_url = env_proxy_url
  raise 'Set PROXY_URL' unless proxy_url

  test_url = ENV.fetch('TEST_URL', 'https://api.ipify.org?format=json')
  h = send_headers_from_env

  # Excon does not expose CONNECT response headers on the origin response (DEFERRED.md).
  # Smoke test: proxied GET succeeds; optional ssl_proxy_headers when SEND_* set.
  res = RubyProxyHeaders::ExconIntegration.get(
    test_url,
    proxy_url: proxy_url,
    proxy_connect_headers: (h if h.any?)
  )
  return { ok: false, error: "HTTP #{res.status}" } unless res.status == 200

  body = JSON.parse(res.body)
  return { ok: false, error: 'No ip in JSON body' } unless body['ip']

  msg = "#{body['ip']} (CONNECT response headers not exposed by Excon; see DEFERRED.md)"
  puts "[PASS] excon (smoke): #{msg}" if verbose
  { ok: true, value: body['ip'] }
rescue JSON::ParserError => e
  { ok: false, error: "Invalid JSON: #{e.message}" }
rescue StandardError => e
  { ok: false, error: e.message }
end

MODULES = {
  'net_http' => method(:test_net_http),
  'faraday' => method(:test_faraday),
  'httparty' => method(:test_httparty),
  'excon' => method(:test_excon)
}.freeze

def main
  verbose = !ARGV.delete('-v').nil? || !ARGV.delete('--verbose').nil?
  list = !ARGV.delete('-l').nil? || !ARGV.delete('--list').nil?

  if list
    puts MODULES.keys.sort.join("\n")
    exit 0
  end

  proxy_url = env_proxy_url
  unless proxy_url
    warn 'Error: Set PROXY_URL or HTTPS_PROXY'
    exit 1
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
