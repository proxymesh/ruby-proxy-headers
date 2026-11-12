# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `RubyProxyHeaders::Typhoeus` sends proxy headers with libcurl `CURLOPT_PROXYHEADER` (`:proxyheader` and `headeropt: :separate` on Typhoeus 1.7 / Ethon 0.19) and exposes the CONNECT response, including `X-ProxyMesh-IP`, as `proxy_response_headers`.

### Changed

- Require Ruby >= 3.2. Dependabot resolves Bundler updates against the gemspec floor, and Ruby 3.1 cannot select nokogiri 1.19 (the release line that installs on the integration job's current Ruby).
- Development dependencies for the Typhoeus adapter are `typhoeus` `~> 1.7` and `ethon` `>= 0.19.1`, `< 0.20`. The gem still has no runtime dependency on Typhoeus.

### Fixed

- HTTPS requests through `RubyProxyHeaders::Typhoeus` no longer call `RubyProxyHeaders::NetHTTP.request`, which is not defined.
- HTTP.rb and RestClient no longer call that missing method. HTTP.rb uses its own `proxy_headers` on CONNECT. RestClient keeps using Net::HTTP, with CONNECT headers attached by the Net::HTTP patch.
- The Net::HTTP patch no longer replaces `Net::HTTP#connect` with a copy of the Ruby 3.2 method. Socket setup, `timeouted_connect`, and HTTPS proxies stay in the installed net-http.
- The Faraday adapter no longer overrides faraday-net_http's private `request_with_wrapped_block`. CONNECT response headers are merged from `build_connection` and `call`.
- `NetHTTP.patch!` still applies after WebMock swaps `Net::HTTP` out and restores it.

## [0.1.0] - 2024-02-28

### Added

- Initial release
- Core `Connection` class for proxy CONNECT handling with custom headers
- `NetHTTP` module for Net::HTTP integration
- `Faraday` middleware for Faraday integration
- `HTTParty` module for HTTParty integration
- `HTTPGem` module for HTTP.rb integration
- `Typhoeus` module for Typhoeus integration
- `Excon` module for Excon integration
- `RestClient` module for RestClient integration
- Comprehensive documentation
- Test suite with RSpec

[Unreleased]: https://github.com/proxymesh/ruby-proxy-headers/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/proxymesh/ruby-proxy-headers/releases/tag/v0.1.0
