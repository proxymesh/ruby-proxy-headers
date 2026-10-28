# Typhoeus

[Typhoeus](https://typhoeus.github.io/) is an HTTP client that wraps libcurl through [Ethon](https://github.com/typhoeus/ethon). `RubyProxyHeaders::Typhoeus` sends custom proxy headers on HTTPS `CONNECT` and reads the proxy's CONNECT response.

## Requirements

- Typhoeus 1.7 or newer (`gem 'typhoeus', '~> 1.7'`), which depends on Ethon `>= 0.19`, `< 0.20`
- Ethon 0.19 or newer, for `:proxyheader` (`CURLOPT_PROXYHEADER`) and `:headeropt` (`:unified` / `:separate`)
- libcurl 7.37 or newer (libcurl 8.x is what the mock-proxy spec runs against)

`ruby-proxy-headers` does not declare a runtime dependency on Typhoeus or Ethon. Add Typhoeus to the application Gemfile when you use this adapter. Typhoeus 1.7 has its own breaking changes; see Typhoeus's `UPGRADE.md` before upgrading an existing app.

```ruby
gem 'typhoeus', '~> 1.7'
gem 'ruby-proxy-headers'
```

**Note:** Typhoeus requires libcurl to be installed on the system.

## Basic Usage

```ruby
require 'ruby_proxy_headers/typhoeus'

response = RubyProxyHeaders::Typhoeus.get(
  'https://api.ipify.org?format=json',
  proxy: 'http://user:pass@proxy.example.com:8080',
  proxy_headers: { 'X-ProxyMesh-Country' => 'US' },
  headers: { 'Accept' => 'application/json' }
)

puts "Status: #{response.code}"
puts "Body: #{response.body}"
puts "Proxy IP: #{response.proxy_response_headers['x-proxymesh-ip']}"
```

`proxy_headers` are copied into a libcurl proxy-header list and `:headeropt` is set to `:separate`. On HTTPS, libcurl sends that list only on `CONNECT`. Headers passed in `:headers` go to the origin and are not copied onto the CONNECT request.

## API Reference

### `RubyProxyHeaders::Typhoeus.get(url, options)`

Make a GET request.

**Parameters:**

- `url` (String) - Target URL
- `options` (Hash):
  - `:proxy` (String) - Proxy URL (required)
  - `:proxy_headers` (Hash) - Headers to send to the proxy
  - `:headers` (Hash) - Headers to send to the origin
  - Other Typhoeus / Ethon options (`:timeout`, `:body`, and so on) are passed through

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
response.code                    # HTTP status code of the origin response
response.body                    # Response body
response.headers                 # Origin response headers (last header block)
response.proxy_response_headers  # Proxy CONNECT response headers (lowercase names)
response.success?                # True if 2xx status
```

libcurl appends every header block to `response_headers`. The proxy's CONNECT response is the first block, for example:

```http
HTTP/1.1 200 Connection established
X-ProxyMesh-IP: 203.0.113.10
```

Typhoeus's `response.headers` is only the last block, the origin response, so `X-ProxyMesh-IP` is not in `response.headers`. This adapter parses that first block when its status line says `Connection established`.

## Example: Several countries

Each helper call performs one request. Repeat it to send a different proxy header:

```ruby
require 'json'
require 'ruby_proxy_headers/typhoeus'

countries = %w[US UK DE FR JP]
results = {}

countries.each do |country|
  response = RubyProxyHeaders::Typhoeus.get(
    'https://api.ipify.org?format=json',
    proxy: ENV.fetch('PROXY_URL'),
    proxy_headers: { 'X-ProxyMesh-Country' => country }
  )

  results[country] = {
    ip: JSON.parse(response.body)['ip'],
    proxy_ip: response.proxy_response_headers['x-proxymesh-ip']
  }
end

puts results
```
