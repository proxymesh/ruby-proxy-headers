# ruby-proxy-headers — implementation plan

Prioritized roadmap for extension modules, aligned with [javascript-proxy-headers](https://github.com/proxymesh/javascript-proxy-headers) and [python-proxy-headers](https://github.com/proxymesh/python-proxy-headers).

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    ruby-proxy-headers                        │
├─────────────────────────────────────────────────────────────┤
│  Library wrappers (Faraday, HTTParty, Mechanize, …)        │
│       │                                                      │
│       ▼                                                      │
│  Net::HTTP patch (Phase 1) — CONNECT send + capture        │
│       │                                                      │
│       ├──► Typhoeus / Ethon — libcurl options (Phase 4)     │
│       └──► Excon — custom tunnel (Phase 5)                  │
└─────────────────────────────────────────────────────────────┘
```

## Phase 1 — Net::HTTP core (**done in v0.1**)

**Goal:** `RubyProxyHeaders::NetHTTP.patch!` extends `Net::HTTP#connect` for `use_ssl? && proxy?` to:

- Send optional `proxy_connect_request_headers` on `CONNECT`
- Store `last_proxy_connect_response_headers` from the `CONNECT` response

**Files:**

- `lib/ruby_proxy_headers/net_http.rb`

**Tests:**

- `test/test_proxy_headers.rb` module `net_http`

**Success criteria:**

- Live test against `PROXY_URL` with `X-ProxyMesh-IP` visible in `last_proxy_connect_response_headers`

---

## Phase 2 — Faraday

**Goal:** Ergonomic API: `proxy_headers: { ... }` on the connection or per-request, backed by patched `Net::HTTP`.

**Approach:**

- `Faraday.new(...) { |f| f.adapter :net_http }` and ensure the adapter’s `Net::HTTP` instance receives `proxy_connect_request_headers`
- Or `Faraday::Connection` subclass / middleware that sets headers on the underlying `Net::HTTP` before `connect`

**Files (planned):**

- `lib/ruby_proxy_headers/faraday.rb`

---

## Phase 3 — HTTParty

**Goal:** Document + optional helper to set `proxy_connect_request_headers` on the internal `Net::HTTP` (or class-level hooks).

**Files (planned):**

- `lib/ruby_proxy_headers/httparty.rb` (thin wrapper or documentation module)

---

## Phase 4 — Typhoeus / Ethon

**Goal:** Map Ruby header hash to libcurl proxy header options; capture CONNECT-related output if feasible.

**Files (planned):**

- `lib/ruby_proxy_headers/typhoeus.rb` or `ethon.rb`

**Risk:** libcurl version differences; may need feature detection.

---

## Phase 5 — Excon

**Goal:** Custom CONNECT path or middleware mirroring the Node `ProxyHeadersAgent` behavior.

**Files (planned):**

- `lib/ruby_proxy_headers/excon.rb`

---

## Phase 6 — Mechanize

**Goal:** Ensure Mechanize sessions use patched `Net::HTTP` behavior and document how to read `last_proxy_connect_response_headers` from the right object.

**Files (planned):**

- `lib/ruby_proxy_headers/mechanize.rb` (wrapper or patches)

---

## Testing

All phases should plug into `test/test_proxy_headers.rb` with the same env vars as Python/JS:

- `PROXY_URL`, `PROXY_HEADER`, `SEND_PROXY_HEADER`, `SEND_PROXY_VALUE`, `TEST_URL`

---

## Success criteria (project-wide)

1. At least one production-quality path for **Net::HTTP** (done).
2. Faraday + HTTParty documented with working examples.
3. Optional: Typhoeus, Excon, Mechanize where demand and maintenance cost align.

---

*Plan created: March 2026*
