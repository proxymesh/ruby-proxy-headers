# Ruby Proxy Headers

Extensions for Ruby HTTP libraries to support **sending and receiving custom proxy headers** during HTTPS `CONNECT` tunneling (for example [ProxyMesh](https://proxymesh.com) `X-ProxyMesh-IP` / `X-ProxyMesh-Country`).

## The problem

Most Ruby HTTP clients use `Net::HTTP`, Faraday, or libcurl without exposing:

1. Extra headers on the `CONNECT` request to the proxy.
2. Headers from the proxy’s `CONNECT` response (often discarded after the tunnel is established).

This library adds opt-in support, starting with **`Net::HTTP`**.

## Installation

```bash
gem install ruby-proxy-headers
```

Or add to your `Gemfile`:

```ruby
gem 'ruby-proxy-headers'
```

Native extensions are not required for the `Net::HTTP` adapter (pure Ruby patch).

## Net::HTTP

```ruby
require 'uri'
require 'openssl'
require 'ruby_proxy_headers/net_http'

RubyProxyHeaders::NetHTTP.patch!

uri = URI('https://api.ipify.org?format=json')
proxy = URI(ENV.fetch('PROXY_URL'))

http = Net::HTTP.new(uri.host, uri.port, proxy.host, proxy.port, proxy.user, proxy.password)
http.use_ssl = true

# Optional: headers to send on CONNECT (e.g. sticky IP)
http.proxy_connect_request_headers = { 'X-ProxyMesh-IP' => '203.0.113.1' }

res = http.request(Net::HTTP::Get.new(uri))
puts res.body
puts http.last_proxy_connect_response_headers['X-ProxyMesh-IP']
```

Call `RubyProxyHeaders::NetHTTP.patch!` once before creating connections. After a request, `last_proxy_connect_response_headers` is a `Hash` of headers from the proxy’s response to `CONNECT`.

## Testing (live proxy)

Same environment variables as [python-proxy-headers](https://github.com/proxymesh/python-proxy-headers):

| Variable | Role |
|----------|------|
| `PROXY_URL` | Proxy URL (required for tests) |
| `TEST_URL` | Target HTTPS URL (default `https://api.ipify.org?format=json`) |
| `PROXY_HEADER` | Header to read from CONNECT response (default `X-ProxyMesh-IP`) |
| `SEND_PROXY_HEADER` | Optional header name to send on `CONNECT` |
| `SEND_PROXY_VALUE` | Optional value for that header |

```bash
export PROXY_URL=http://us-ca.proxymesh.com:31280
ruby test/test_proxy_headers.rb -v net_http
```

## Documentation

- [Library research](LIBRARY_RESEARCH.md) — proxy header support by client
- [Implementation plan](IMPLEMENTATION_PRIORITY.md) — phased roadmap

## Related

- [python-proxy-headers](https://github.com/proxymesh/python-proxy-headers)
- [javascript-proxy-headers](https://github.com/proxymesh/javascript-proxy-headers)
- [proxy-examples (Ruby)](https://github.com/proxymesh/proxy-examples/tree/main/ruby)
