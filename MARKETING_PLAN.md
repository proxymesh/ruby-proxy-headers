# Marketing Plan for ruby-proxy-headers (2026 Refresh)

This document restores and updates the project marketing plan with current Ruby ecosystem priorities, newer library positioning, and additional growth ideas.

## Positioning

`ruby-proxy-headers` helps Ruby teams send and read custom proxy headers during HTTPS `CONNECT` tunneling, with practical support for:

- `Net::HTTP` (core patch/integration)
- `Faraday` (via net-http adapter path)
- `HTTParty` (via Net::HTTP adapter)
- `Excon` (send-side CONNECT headers; response-header caveat documented)

Primary user segments:

1. Web scraping teams that need geotargeting and sticky sessions.
2. API integrators using managed proxies in Ruby apps.
3. Platform/tooling engineers building shared HTTP clients in Rails services.

## Ecosystem and "Newer Libraries" Angle

Use compatibility language that matches modern Ruby stacks:

- Ruby 3.x-first messaging (especially 3.1-3.3 usage in CI/docs when possible).
- Faraday 2.x usage examples (most teams are now on 2.x).
- HTTParty recent usage patterns with explicit proxy options.
- Net::HTTP as the baseline for any library that delegates to it.

Keep the messaging accurate: this project should market implemented integrations clearly and avoid claiming unsupported adapters until shipped.

## Core Messaging Pillars

1. **Control proxy routing at CONNECT time**  
   Set country/session/IP directives via proxy headers.
2. **Observe what proxy assigned**  
   Capture proxy CONNECT response headers for debugging and sticky-session workflows.
3. **Works with mainstream Ruby HTTP workflows**  
   Net::HTTP, Faraday, HTTParty, and Excon send-side support.
4. **Practical, production-oriented docs**  
   Copy/paste examples, troubleshooting steps, and live integration tests.

## Distribution Channels

## 1) Package and Registry Presence

- Publish and maintain on RubyGems (`ruby_proxy_headers`).
- Ensure gem metadata is complete: homepage, source code URI, changelog URI, bug tracker URI.
- Keep release cadence visible with changelog updates and GitHub releases.

## 2) GitHub Discoverability

- Repository topics:
  - `ruby`, `proxy`, `https`, `connect`, `faraday`, `httparty`, `net-http`, `web-scraping`
- Repository description should include: "custom proxy headers", "HTTPS CONNECT", and supported libraries.
- Add issue templates for:
  - New integration request
  - Proxy compatibility report
  - Bug report with minimal reproducible example

## 3) Documentation Footprint

- Keep README short and task-oriented; move detail to `docs/`.
- Add/refresh:
  - Compatibility matrix by Ruby version and library family.
  - "Choose your integration" page for Net::HTTP vs Faraday vs HTTParty vs Excon.
  - Troubleshooting page for CONNECT header visibility limitations.

## 4) Community Placement

- Submit to curated lists:
  - Awesome Ruby (HTTP/tooling sections)
  - Awesome Web Scraping (Ruby networking/proxy sections)
- Share launch/update posts in:
  - Ruby subreddit
  - Web scraping communities
  - Ruby Discord/Slack groups

## 5) Maintainer and Partner Outreach

- Open documentation PRs/issues on related libraries where appropriate.
- Reach out to proxy providers (including ProxyMesh ecosystem references) for potential "community integrations" listing.
- Cross-link with sibling repos:
  - `python-proxy-headers`
  - `javascript-proxy-headers`
  - `proxy-examples`

## New Growth Ideas (2026)

## 1) "Recipes" Content Series

Create short practical recipes and publish in repo docs + blog:

- "Rotate country per request in Faraday"
- "Sticky IP sessions with HTTParty"
- "Debug CONNECT handshake in Net::HTTP"
- "Excon send-only CONNECT headers: what to expect"

## 2) CI-Verified Example Matrix

Add tiny runnable examples per integration with CI smoke checks.  
Marketing value: "all examples are tested on every push."

## 3) Migration Guides

Publish "from ad-hoc proxy monkey patch to ruby-proxy-headers" guide:

- Before/after snippets
- risk reduction talking points
- observability improvements

## 4) Benchmark + Reliability Notes

Provide lightweight benchmark docs (not hype):

- baseline Net::HTTP vs patched path overhead
- expected overhead statements with reproducible script

## 5) AI/LLM Discovery Optimization

Many developers now ask coding assistants first.  
Improve machine-readable discoverability:

- FAQ section with direct Q/A phrasing.
- "How do I send CONNECT headers in Ruby?" exact-match wording in README/docs.
- Keep examples minimal and copy/paste ready.

## 6) Integration Request Funnel

Add a public roadmap issue for new adapters and let users vote with reactions.  
This converts interest into visible demand signals and prioritization data.

## 90-Day Execution Plan

### Days 1-15 (Foundation)

- Restore and update marketing plan (this document).
- Refresh README positioning for current supported integrations.
- Confirm gem metadata and repository topics.
- Prepare 2 recipe docs with runnable examples.

### Days 16-45 (Visibility)

- Publish gem update + GitHub release notes.
- Submit 2-3 awesome-list/documentation PRs.
- Publish one technical post (CONNECT headers in Ruby, practical guide).
- Share to Ruby/web-scraping communities.

### Days 46-90 (Compounding)

- Add CI-verified example matrix badge/workflow.
- Publish migration guide and troubleshooting deep dive.
- Launch integration-request roadmap issue.
- Track inbound issues/stars/download trend and adjust messaging.

## KPIs and Targets

Track monthly:

- RubyGems downloads (total + monthly delta)
- GitHub stars/forks/watchers
- Docs page views (README + docs pages)
- Referral sources (awesome lists, social, direct)
- Community conversion:
  - issue reports from new users
  - successful integration confirmations

Suggested 6-month directional goals:

- 5k+ cumulative downloads
- 100+ GitHub stars
- 3-5 meaningful external references (listings, docs links, articles)

## Immediate Action Checklist

Actions that can be done directly in repo/GitHub:

1. Keep `MARKETING_PLAN.md` current each release cycle.
2. Add or verify repository topics and concise description.
3. Create docs pages for compatibility matrix and recipes.
4. Add issue templates for integration requests and compatibility reports.
5. Publish release notes that mention supported libraries and caveats.

Human-led actions:

1. Community posting and engagement.
2. Maintainer outreach conversations.
3. Blog/newsletter placements.

## Suggested Outreach Blurb

Use this short form for PR descriptions, posts, or issues:

> ruby-proxy-headers adds practical support for sending and reading custom proxy headers during HTTPS CONNECT in Ruby workflows (Net::HTTP, Faraday, HTTParty, Excon send-side). Useful for geotargeting, sticky sessions, and proxy observability with providers like ProxyMesh.

