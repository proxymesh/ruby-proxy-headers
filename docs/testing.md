# Testing

This guide covers running tests for ruby-proxy-headers.

## Running Unit Tests

```bash
# Install dependencies
bundle install

# Run all tests
rake spec

# Run with verbose output
rake test

# Run specific test file
bundle exec rspec spec/connection_spec.rb
```

## Running Integration Tests

Integration tests require an actual proxy server.

### Environment Variables

```bash
# Required
export PROXY_URL='http://user:pass@proxy.example.com:31280'

# Optional
export TEST_URL='https://api.ipify.org?format=json'
export PROXY_HEADER='X-ProxyMesh-IP'
export SEND_PROXY_HEADER='X-ProxyMesh-Country'
export SEND_PROXY_VALUE='US'
```

### Running Tests

```bash
# Run all integration tests
ruby test/test_proxy_headers.rb

# Run specific tests
ruby test/test_proxy_headers.rb net_http faraday

# List available tests
ruby test/test_proxy_headers.rb -l

# Verbose output
ruby test/test_proxy_headers.rb -v
```

The harness prints `Testing <module>... OK` or `FAIL`. Module names are `net_http`, `faraday`, `httparty`, `excon`, `typhoeus`, `http_gem`, and `rest_client`. Excon checks that the proxied request succeeds. It does not read CONNECT response headers.

## Writing Tests

### Unit Test Example

```ruby
# spec/my_module_spec.rb
require 'spec_helper'

RSpec.describe MyModule do
  describe '#my_method' do
    it 'does something' do
      result = MyModule.my_method
      expect(result).to eq(expected_value)
    end
  end
end
```

### Integration Test Example

```ruby
# test/my_integration_test.rb
require 'uri'
require_relative '../lib/ruby_proxy_headers'

proxy_url = ENV['PROXY_URL']
raise 'Set PROXY_URL' unless proxy_url

RubyProxyHeaders::NetHTTP.patch!
uri = URI('https://api.ipify.org?format=json')
proxy = URI(proxy_url)
http = Net::HTTP.new(uri.host, uri.port, proxy.host, proxy.port, proxy.user, proxy.password)
http.use_ssl = true
http.proxy_connect_request_headers = { 'X-Test' => 'value' }
response = http.request(Net::HTTP::Get.new(uri))
puts response.code
puts http.last_proxy_connect_response_headers['X-ProxyMesh-IP']
```

## CI

`.github/workflows/unit_tests.yml` runs `bundle exec rspec` on Ruby 3.2 and 3.3. `.github/workflows/proxy_integration_tests.yml` runs `test/test_proxy_headers.rb` when the `PROXY_URL` Actions secret is set.

## Troubleshooting

Set `open_timeout` and `read_timeout` on the client you are using. For a mock origin with a self-signed certificate, disable verification on that client (`verify_mode`, Faraday `ssl.verify`, HTTP.rb `verify_ssl: false`, or RestClient `verify_ssl: false`). Do not do that against a public site.

```bash
bundle install
```
