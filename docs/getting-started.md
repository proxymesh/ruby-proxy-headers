# Getting Started

This guide will help you get started with ruby-proxy-headers.

## Installation

### Bundler (Recommended)

Add to your `Gemfile`:

```ruby
gem 'ruby-proxy-headers'
```

Then run:

```bash
bundle install
```

### Direct Installation

```bash
gem install ruby-proxy-headers
```

## Basic Usage

### 1. Import the Library

```ruby
require 'ruby_proxy_headers'
```

### 2. Make a Request with Proxy Headers

Choose the module that matches your HTTP library:

=== "Net::HTTP"

    ```ruby
    response = RubyProxyHeaders::NetHTTP.get(
      'https://example.com',
      proxy: 'http://user:pass@proxy:8080',
      proxy_headers: { 'X-Custom-Header' => 'value' }
    )
    ```

=== "Faraday"

    ```ruby
    require 'ruby_proxy_headers/faraday'

    conn = RubyProxyHeaders::FaradayIntegration.connection(
      proxy: 'http://user:pass@proxy:8080',
      proxy_connect_headers: { 'X-Custom-Header' => 'value' }
    )
    response = conn.get('https://example.com')
    puts response.headers['X-ProxyMesh-IP']
    ```

=== "HTTParty"

    ```ruby
    require 'httparty'
    require 'ruby_proxy_headers/httparty'

    RubyProxyHeaders::NetHTTP.patch!
    proxy = URI('http://user:pass@proxy:8080')
    response = HTTParty.get(
      'https://example.com',
      http_proxyaddr: proxy.host,
      http_proxyport: proxy.port,
      http_proxyuser: proxy.user,
      http_proxypass: proxy.password,
      proxy_connect_request_headers: { 'X-Custom-Header' => 'value' },
      connection_adapter: RubyProxyHeaders::ProxyHeadersConnectionAdapter
    )
    puts RubyProxyHeaders.proxy_connect_response_headers['X-ProxyMesh-IP']
    ```

### 3. Access Proxy Response Headers

`NetHTTP.get` returns `response.proxy_response_headers`. Faraday merges the same headers into `response.headers`. HTTParty leaves them on `RubyProxyHeaders.proxy_connect_response_headers`. Lookup is case-insensitive.

## Configuration Options

### Proxy URL Format

```ruby
# Full format
proxy: 'http://username:password@proxy.example.com:8080'

# Without authentication
proxy: 'http://proxy.example.com:8080'
```

### Proxy Headers

```ruby
proxy_headers: {
  'X-ProxyMesh-Country' => 'US',
  'X-ProxyMesh-Session' => 'session123',
  'X-Custom-Header' => 'custom-value'
}
```

## Environment Variables

The live proxy harness in `test/test_proxy_headers.rb` reads `PROXY_URL`. The library methods take the proxy URL as an argument; they do not fall back to `HTTPS_PROXY`.

```bash
export PROXY_URL='http://user:pass@proxy.example.com:8080'
```

## Next Steps

- Explore library-specific guides in the sidebar
- Check the [Core API](core-api.md) for advanced usage
- See [Testing](testing.md) for running integration tests
