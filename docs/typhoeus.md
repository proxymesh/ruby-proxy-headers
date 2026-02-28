# Typhoeus

[Typhoeus](https://typhoeus.github.io/) is a fast HTTP client that wraps libcurl. The `RubyProxyHeaders::Typhoeus` module provides proxy header support.

## Installation

```ruby
gem 'typhoeus'
gem 'ruby_proxy_headers'
```

**Note:** Typhoeus requires libcurl to be installed on your system.

## Basic Usage

```ruby
require 'ruby_proxy_headers'

response = RubyProxyHeaders::Typhoeus.get(
  'https://api.ipify.org?format=json',
  proxy: 'http://user:pass@proxy.example.com:8080',
  proxy_headers: { 'X-ProxyMesh-Country' => 'US' }
)

puts "Status: #{response.code}"
puts "Body: #{response.body}"
puts "Proxy IP: #{response.proxy_response_headers['x-proxymesh-ip']}"
```

## API Reference

### `RubyProxyHeaders::Typhoeus.get(url, options)`

Make a GET request.

**Parameters:**

- `url` (String) - Target URL
- `options` (Hash):
  - `:proxy` (String) - Proxy URL (required)
  - `:proxy_headers` (Hash) - Headers to send to proxy
  - `:headers` (Hash) - Request headers

**Returns:** `ProxyResponse`

### `RubyProxyHeaders::Typhoeus.post(url, options)`

Make a POST request.

**Parameters:**

- Same as `get`, plus:
  - `:body` (String) - Request body

### `RubyProxyHeaders::Typhoeus.request(method, url, options)`

Make a request with any HTTP method.

**Parameters:**

- `method` (Symbol) - HTTP method
- `url` (String) - Target URL
- `options` (Hash) - Same as above

## Response Object

```ruby
response.code                    # HTTP status code
response.body                    # Response body
response.headers                 # Response headers
response.proxy_response_headers  # Proxy CONNECT response headers
response.success?                # True if 2xx status
```

## Performance Note

Typhoeus is built on libcurl, which has native support for `CURLOPT_PROXYHEADER`. While the current implementation uses our core connection handler for HTTPS proxy headers, a future version may leverage libcurl's native support for improved performance.

## Example: Parallel Requests

```ruby
require 'ruby_proxy_headers'

hydra = Typhoeus::Hydra.new

countries = %w[US UK DE FR JP]
results = {}

countries.each do |country|
  # Note: For parallel requests, use standard Typhoeus
  # Our module is for sequential requests with proxy headers
  response = RubyProxyHeaders::Typhoeus.get(
    'https://api.ipify.org?format=json',
    proxy: ENV['PROXY_URL'],
    proxy_headers: { 'X-ProxyMesh-Country' => country }
  )
  
  results[country] = {
    ip: JSON.parse(response.body)['ip'],
    proxy_ip: response.proxy_response_headers['x-proxymesh-ip']
  }
end

puts results
```
