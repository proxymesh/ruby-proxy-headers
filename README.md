# Ruby Proxy Headers

Send and receive custom proxy headers during HTTPS `CONNECT` tunneling in modern Ruby HTTP workflows (for example [ProxyMesh](https://proxymesh.com) `X-ProxyMesh-IP` / `X-ProxyMesh-Country`).

## The problem

Most Ruby HTTP clients use `Net::HTTP`, Faraday, or libcurl without exposing:

1. Extra headers on the `CONNECT` request to the proxy.
2. Headers from the proxy’s `CONNECT` response (often discarded after the tunnel is established).

This library adds opt-in support for **Net::HTTP**, **Faraday** (2.x via `faraday-net_http`), **HTTParty**, and documents **Excon**’s built-in `:ssl_proxy_headers` for sends.

## Why teams use this

- **Geo-targeting at tunnel setup**: Send country/session directives on `CONNECT`.
- **Sticky-session observability**: Read proxy-assigned headers like `X-ProxyMesh-IP`.
- **Works with common Ruby stacks**: Useful for scraping and API clients using Net::HTTP-based flows.

## Installation

```bash
gem install ruby-proxy-headers
```

Or add to your `Gemfile`:

```ruby
gem 'ruby-proxy-headers'
```

The `Net::HTTP` patch is pure Ruby. Install **faraday**, **faraday-net_http**, **httparty**, and/or **excon** when you use those integrations.

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

Call `RubyProxyHeaders::NetHTTP.patch!` once before creating connections. You can also read the last CONNECT response headers on the current thread via `RubyProxyHeaders.proxy_connect_response_headers`.

## Faraday

```ruby
require 'ruby_proxy_headers/faraday'

conn = RubyProxyHeaders::FaradayIntegration.connection(
  proxy: ENV.fetch('PROXY_URL'),
  proxy_connect_headers: { 'X-ProxyMesh-Country' => 'US' } # optional
)
res = conn.get('https://api.ipify.org?format=json')
puts res.headers['X-ProxyMesh-IP']
```

Uses the registered adapter `:ruby_proxy_headers_net_http`, which merges proxy `CONNECT` response headers into Faraday’s response headers.

## HTTParty

```ruby
require 'httparty'
require 'ruby_proxy_headers/httparty'

RubyProxyHeaders::NetHTTP.patch!

proxy = URI(ENV.fetch('PROXY_URL'))
HTTParty.get(
  'https://api.ipify.org?format=json',
  http_proxyaddr: proxy.host,
  http_proxyport: proxy.port,
  http_proxyuser: proxy.user,
  http_proxypass: proxy.password,
  proxy_connect_request_headers: { 'X-ProxyMesh-IP' => '203.0.113.1' }, # optional
  connection_adapter: RubyProxyHeaders::ProxyHeadersConnectionAdapter
)

puts RubyProxyHeaders.proxy_connect_response_headers['X-ProxyMesh-IP']
```

## Excon (send-only; CONNECT response headers)

Excon supports **sending** extra headers on CONNECT with `:ssl_proxy_headers`. Reading `X-ProxyMesh-IP` from the CONNECT response is **not** exposed on the origin response object — see [DEFERRED.md](DEFERRED.md).

```ruby
require 'ruby_proxy_headers/excon'

RubyProxyHeaders::ExconIntegration.get(
  'https://api.ipify.org?format=json',
  proxy_url: ENV.fetch('PROXY_URL'),
  proxy_connect_headers: { 'X-ProxyMesh-Country' => 'US' } # optional
)
```

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
cd ruby-proxy-headers
bundle install
export PROXY_URL=http://user:pass@proxyhost:port
bundle exec ruby test/test_proxy_headers.rb -v
```

Use a placeholder proxy host in examples, e.g. `http://user:pass@proxyhost:port`.

## Documentation

- [Library research](LIBRARY_RESEARCH.md) — proxy header support by client
- [Implementation plan](IMPLEMENTATION_PRIORITY.md) — phased roadmap
- [Marketing plan](MARKETING_PLAN.md) — positioning, channels, and 90-day growth plan
- [Deferred items](DEFERRED.md) — Typhoeus, Mechanize, Excon CONNECT response caveats

## Related

- [python-proxy-headers](https://github.com/proxymesh/python-proxy-headers)
- [javascript-proxy-headers](https://github.com/proxymesh/javascript-proxy-headers)
- [proxy-examples (Ruby)](https://github.com/proxymesh/proxy-examples/tree/main/ruby)
