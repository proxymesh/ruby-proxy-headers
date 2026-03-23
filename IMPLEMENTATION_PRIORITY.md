# ruby-proxy-headers — implementation plan

Prioritized roadmap for extension modules, aligned with [javascript-proxy-headers](https://github.com/proxymesh/javascript-proxy-headers) and [python-proxy-headers](https://github.com/proxymesh/python-proxy-headers).

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    ruby-proxy-headers                        │
├─────────────────────────────────────────────────────────────┤
│  Faraday / HTTParty / Excon helpers                        │
│       │                                                      │
│       ▼                                                      │
│  Net::HTTP patch — CONNECT send + capture + thread-local   │
└─────────────────────────────────────────────────────────────┘
```

## Phase 1 — Net::HTTP core (**done — v0.1+**)

- `RubyProxyHeaders::NetHTTP.patch!` extends `Net::HTTP#connect` for HTTPS + proxy.
- `last_proxy_connect_response_headers` on the `Net::HTTP` instance.
- `Thread.current[:ruby_proxy_headers_connect_headers]` + `RubyProxyHeaders.proxy_connect_response_headers` for cross-library reads.

**File:** `lib/ruby_proxy_headers/net_http.rb`

---

## Phase 2 — Faraday (**done — v0.2+**)

- Adapter `ruby_proxy_headers_net_http` (subclass of `Faraday::Adapter::NetHttp`) merges CONNECT response headers into Faraday response headers.
- Helper `RubyProxyHeaders::FaradayIntegration.connection(...)`.

**File:** `lib/ruby_proxy_headers/faraday.rb`

---

## Phase 3 — HTTParty (**done — v0.2+**)

- `RubyProxyHeaders::ProxyHeadersConnectionAdapter` — pass `proxy_connect_request_headers` in HTTParty options.

**File:** `lib/ruby_proxy_headers/httparty.rb`

---

## Phase 4 — Typhoeus / Ethon (**deferred**)

Ethon does not expose libcurl `CURLOPT_PROXYHEADER` in its option layer. See [DEFERRED.md](DEFERRED.md).

---

## Phase 5 — Excon (**partial — v0.2+**)

- **Sending** extra CONNECT headers: supported upstream via `:ssl_proxy_headers`; `RubyProxyHeaders::ExconIntegration.get` passes them through.
- **Reading** CONNECT response headers: not exposed on `Excon::Response` for the tunneled request. See [DEFERRED.md](DEFERRED.md).

**File:** `lib/ruby_proxy_headers/excon.rb`

---

## Phase 6 — Mechanize (**deferred**)

Uses `net-http-persistent`; needs dedicated integration. See [DEFERRED.md](DEFERRED.md).

---

## Testing

`bundle exec ruby test/test_proxy_headers.rb` with `PROXY_URL` set. Modules: `net_http`, `faraday`, `httparty`, `excon` (excon is a smoke test; CONNECT response headers are not asserted).

---

*Updated: March 2026*
