# Excon

[Excon](https://github.com/excon/excon) is a fast, simple HTTP(S) client. The `RubyProxyHeaders::Excon` module adds proxy header support.

## Installation

```ruby
gem 'excon'
gem 'ruby_proxy_headers'
```

## Basic Usage

```ruby
require 'ruby_proxy_headers'

response = RubyProxyHeaders::Excon.get(
  'https://api.ipify.org?format=json',
  proxy: 'http://user:pass@proxy.example.com:8080',
  proxy_headers: { 'X-ProxyMesh-Country' => 'US' }
)

puts "Status: #{response.code}"
puts "Body: #{response.body}"
puts "Proxy IP: #{response.proxy_response_headers['x-proxymesh-ip']}"
```

## API Reference

### `RubyProxyHeaders::Excon.get(url, options)`

Make a GET request.

**Parameters:**

- `url` (String) - Target URL
- `options` (Hash):
  - `:proxy` (String) - Proxy URL (required)
  - `:proxy_headers` (Hash) - Headers to send to proxy
  - `:headers` (Hash) - Request headers

**Returns:** `ProxyResponse`

### `RubyProxyHeaders::Excon.post(url, options)`

Make a POST request.

**Parameters:**

- Same as `get`, plus:
  - `:body` (String) - Request body

### `RubyProxyHeaders::Excon.request(method, url, options)`

Make a request with any HTTP method.

## Response Object

```ruby
response.status                  # HTTP status code (alias: code)
response.body                    # Response body
response.headers                 # Response headers
response.proxy_response_headers  # Proxy CONNECT response headers
```

## Example: AWS SDK Compatible

Excon is commonly used with AWS SDKs. Here's how to use proxy headers with AWS:

```ruby
require 'ruby_proxy_headers'

response = RubyProxyHeaders::Excon.get(
  'https://sts.amazonaws.com/?Action=GetCallerIdentity&Version=2011-06-15',
  proxy: ENV['PROXY_URL'],
  proxy_headers: { 'X-ProxyMesh-Country' => 'US' },
  headers: {
    'Authorization' => aws_signature,
    'X-Amz-Date' => Time.now.utc.strftime('%Y%m%dT%H%M%SZ')
  }
)

puts response.body
```
