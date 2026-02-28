# Net::HTTP

Net::HTTP is Ruby's built-in HTTP client. The `RubyProxyHeaders::NetHTTP` module provides a wrapper that adds proxy header support.

## Installation

Net::HTTP is part of Ruby's standard library, so no additional gems are required.

```ruby
require 'ruby_proxy_headers'
```

## Basic Usage

### GET Request

```ruby
response = RubyProxyHeaders::NetHTTP.get(
  'https://api.ipify.org?format=json',
  proxy: 'http://user:pass@proxy.example.com:8080',
  proxy_headers: { 'X-ProxyMesh-Country' => 'US' }
)

puts "Status: #{response.code}"
puts "Body: #{response.body}"
puts "Proxy IP: #{response.proxy_response_headers['x-proxymesh-ip']}"
```

### POST Request

```ruby
response = RubyProxyHeaders::NetHTTP.post(
  'https://httpbin.org/post',
  '{"key": "value"}',
  proxy: 'http://proxy:8080',
  proxy_headers: { 'X-Session' => 'abc123' },
  headers: { 'Content-Type' => 'application/json' }
)

puts response.body
```

### Generic Request

```ruby
response = RubyProxyHeaders::NetHTTP.request(
  :put,
  'https://httpbin.org/put',
  proxy: 'http://proxy:8080',
  proxy_headers: { 'X-Custom' => 'value' },
  body: 'request body',
  headers: { 'Content-Type' => 'text/plain' }
)
```

## API Reference

### `RubyProxyHeaders::NetHTTP.get(url, options)`

Make a GET request.

**Parameters:**

- `url` (String) - Target URL
- `options` (Hash):
  - `:proxy` (String) - Proxy URL (required)
  - `:proxy_headers` (Hash) - Headers to send to proxy
  - `:headers` (Hash) - Request headers

**Returns:** `ProxyResponse`

### `RubyProxyHeaders::NetHTTP.post(url, body, options)`

Make a POST request.

**Parameters:**

- `url` (String) - Target URL
- `body` (String) - Request body
- `options` (Hash) - Same as `get`

**Returns:** `ProxyResponse`

### `RubyProxyHeaders::NetHTTP.request(method, url, options)`

Make a request with any HTTP method.

**Parameters:**

- `method` (Symbol) - HTTP method (`:get`, `:post`, `:put`, `:delete`, etc.)
- `url` (String) - Target URL
- `options` (Hash):
  - `:proxy` (String) - Proxy URL (required)
  - `:proxy_headers` (Hash) - Headers to send to proxy
  - `:headers` (Hash) - Request headers
  - `:body` (String) - Request body

**Returns:** `ProxyResponse`

## Response Object

The `ProxyResponse` wraps the standard response and adds:

```ruby
response.code                    # HTTP status code
response.body                    # Response body
response.headers                 # Response headers
response.proxy_response_headers  # Headers from proxy CONNECT response
```

## Example: ProxyMesh Integration

```ruby
require 'ruby_proxy_headers'
require 'json'

proxy_url = 'http://user:pass@us.proxymesh.com:31280'

response = RubyProxyHeaders::NetHTTP.get(
  'https://api.ipify.org?format=json',
  proxy: proxy_url,
  proxy_headers: {
    'X-ProxyMesh-Country' => 'US',
    'X-ProxyMesh-Session' => 'my-session'
  }
)

ip_info = JSON.parse(response.body)
puts "Request IP: #{ip_info['ip']}"
puts "Proxy IP: #{response.proxy_response_headers['x-proxymesh-ip']}"
```
