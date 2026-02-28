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
export PROXY_URL='http://user:pass@proxy.example.com:8080'

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

## Test Output

```
============================================================
ruby-proxy-headers Integration Tests
============================================================
Proxy URL:       http://****:****@proxy.example.com:8080
Test URL:        https://api.ipify.org?format=json
Proxy Header:    X-ProxyMesh-IP
Send Headers:    {"X-ProxyMesh-Country"=>"US"}
Tests:           7
============================================================

Testing Net::HTTP... OK (X-ProxyMesh-IP=1.2.3.4)
Testing Faraday... OK (X-ProxyMesh-IP=1.2.3.4)
Testing HTTParty... OK (X-ProxyMesh-IP=1.2.3.4)
Testing HTTP.rb... OK (X-ProxyMesh-IP=1.2.3.4)
Testing Typhoeus... OK (X-ProxyMesh-IP=1.2.3.4)
Testing Excon... OK (X-ProxyMesh-IP=1.2.3.4)
Testing RestClient... OK (X-ProxyMesh-IP=1.2.3.4)

============================================================
Results: 7 passed, 0 failed
============================================================
```

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
require_relative '../lib/ruby_proxy_headers'

proxy_url = ENV['PROXY_URL']
raise 'Set PROXY_URL' unless proxy_url

response = RubyProxyHeaders::NetHTTP.get(
  'https://api.ipify.org?format=json',
  proxy: proxy_url,
  proxy_headers: { 'X-Test' => 'value' }
)

puts "Status: #{response.code}"
puts "Proxy Headers: #{response.proxy_response_headers}"
```

## CI Configuration

### GitHub Actions

```yaml
# .github/workflows/test.yml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        ruby: ['2.7', '3.0', '3.1', '3.2', '3.3']
    
    steps:
    - uses: actions/checkout@v4
    - uses: ruby/setup-ruby@v1
      with:
        ruby-version: ${{ matrix.ruby }}
        bundler-cache: true
    - run: bundle exec rake spec
```

## Troubleshooting

### Connection Timeouts

```bash
# Increase timeout
export PROXY_TIMEOUT=60
```

### SSL Certificate Errors

```ruby
# Disable SSL verification (not recommended for production)
RubyProxyHeaders::Connection.new(
  proxy_url,
  verify_ssl: false
)
```

### Missing Dependencies

```bash
# Install all optional dependencies for testing
bundle install --with development
```
