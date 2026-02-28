# Getting Started

This guide will help you get started with ruby-proxy-headers.

## Installation

### Bundler (Recommended)

Add to your `Gemfile`:

```ruby
gem 'ruby_proxy_headers'
```

Then run:

```bash
bundle install
```

### Direct Installation

```bash
gem install ruby_proxy_headers
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
    require 'faraday'
    
    conn = Faraday.new do |f|
      f.use RubyProxyHeaders::Faraday::Middleware,
            proxy: 'http://user:pass@proxy:8080',
            proxy_headers: { 'X-Custom-Header' => 'value' }
      f.adapter Faraday.default_adapter
    end
    
    response = conn.get('https://example.com')
    ```

=== "HTTParty"

    ```ruby
    response = RubyProxyHeaders::HTTParty.get(
      'https://example.com',
      proxy: 'http://user:pass@proxy:8080',
      proxy_headers: { 'X-Custom-Header' => 'value' }
    )
    ```

### 3. Access Proxy Response Headers

```ruby
# All modules provide proxy_response_headers
puts response.proxy_response_headers['x-proxymesh-ip']
```

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

You can configure the proxy via environment variables:

```bash
export PROXY_URL='http://user:pass@proxy.example.com:8080'
export HTTPS_PROXY='http://proxy.example.com:8080'
```

The libraries will use `HTTPS_PROXY` or `HTTP_PROXY` as fallback if no proxy is specified.

## Error Handling

```ruby
begin
  response = RubyProxyHeaders::NetHTTP.get(
    'https://example.com',
    proxy: 'http://proxy:8080',
    proxy_headers: { 'X-Custom' => 'value' }
  )
rescue RubyProxyHeaders::ProxyAuthenticationError => e
  puts "Proxy auth failed: #{e.message}"
rescue RubyProxyHeaders::ConnectError => e
  puts "Proxy connection failed: #{e.message}"
rescue StandardError => e
  puts "Error: #{e.message}"
end
```

## Next Steps

- Explore library-specific guides in the sidebar
- Check the [Core API](core-api.md) for advanced usage
- See [Testing](testing.md) for running integration tests
