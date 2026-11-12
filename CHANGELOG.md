# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Changed

- Require Ruby >= 3.2. Dependabot resolves Bundler updates against the gemspec floor, and Ruby 3.1 cannot select nokogiri 1.19 (the release line that installs on the integration job's current Ruby).

## 0.1.0 - 2024-02-28

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

[Unreleased]: https://github.com/proxymeshai/ruby-proxy-headers/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/proxymeshai/ruby-proxy-headers/releases/tag/v0.1.0
