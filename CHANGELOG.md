# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- HTTP.rb, RestClient, and Typhoeus no longer raise `NoMethodError` on HTTPS requests. They send custom CONNECT headers through `RubyProxyHeaders::NetHTTP.request` and expose the proxy's CONNECT response headers.
- The Net::HTTP patch no longer replaces `Net::HTTP#connect` with a stale copy. Socket setup, `timeouted_connect`, and HTTPS proxies (`proxy_use_ssl`) stay in the installed net-http.
- The Faraday adapter no longer overrides faraday-net_http's private `request_with_wrapped_block`. CONNECT response headers are merged from the public adapter hooks.

### Changed

- Gem metadata now includes `homepage_uri`, `changelog_uri`, and `bug_tracker_uri`.
- The published gem no longer ships `IMPLEMENTATION_PRIORITY.md`, `LIBRARY_RESEARCH.md`, or `DEFERRED.md`. Per-library guides under `docs/` are included instead.
- Faraday, HTTParty, and Excon guides describe `FaradayIntegration`, `ProxyHeadersConnectionAdapter`, and `ExconIntegration` instead of middleware and helpers that were never implemented.

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
