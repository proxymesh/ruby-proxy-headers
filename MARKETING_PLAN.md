# Developer Marketing Plan for ruby-proxy-headers

This document outlines the marketing strategy for promoting ruby-proxy-headers to the Ruby developer community.

## 1. Package Registry Publishing

### RubyGems.org (Primary)

**Steps:**
1. Create account at https://rubygems.org/sign_up
2. Configure credentials: `gem push` will prompt for API key
3. Build gem: `gem build ruby_proxy_headers.gemspec`
4. Push: `gem push ruby_proxy_headers-0.1.0.gem`
5. Verify at https://rubygems.org/gems/ruby_proxy_headers

**Agent Can Do:** ❌ (Requires RubyGems account credentials)

### GitHub Packages

**Steps:**
1. Add to gemspec: `spec.metadata["github_repo"] = "ssh://github.com/proxymeshai/ruby-proxy-headers"`
2. Configure `~/.gem/credentials` with GitHub token
3. Push: `gem push --host https://rubygems.pkg.github.com/proxymeshai ruby_proxy_headers-0.1.0.gem`

**Agent Can Do:** ⚠️ (Can prepare files, but pushing requires auth)

---

## 2. Documentation Sites

### ReadTheDocs

**Setup Steps:**
1. Go to https://readthedocs.org/dashboard/import/
2. Connect GitHub account
3. Import `proxymeshai/ruby-proxy-headers` repository
4. Enable automatic builds

**Files Created:** ✅
- `.readthedocs.yaml`
- `mkdocs.yml`
- `docs/*.md`

**Agent Can Do:** ❌ (Requires ReadTheDocs account)

### README Badges

**Add to README:**
```markdown
[![Gem Version](https://badge.fury.io/rb/ruby_proxy_headers.svg)](https://badge.fury.io/rb/ruby_proxy_headers)
[![Documentation](https://img.shields.io/badge/docs-readthedocs-blue)](https://ruby-proxy-headers.readthedocs.io/)
```

**Agent Can Do:** ✅ (Already added)

---

## 3. Awesome Lists

### awesome-ruby (Markets)
**URL:** https://github.com/markets/awesome-ruby
**Section:** HTTP Clients and tools
**Stars:** 13k+

**PR Content:**
```markdown
## HTTP Clients
* [ruby-proxy-headers](https://github.com/proxymeshai/ruby-proxy-headers) - Extensions for HTTP libraries to support custom proxy headers during HTTPS CONNECT tunneling.
```

**Agent Can Do:** ✅ Fork repo and create PR

### awesome-ruby (Sdogruyol)
**URL:** https://github.com/Sdogruyol/awesome-ruby
**Section:** HTTP
**Stars:** 2k+

**Agent Can Do:** ✅ Fork repo and create PR

### awesome-web-scraping
**URL:** https://github.com/lorien/awesome-web-scraping
**File:** `ruby.md` (Network section)
**Stars:** 7k+

**PR Content:**
```markdown
* [ruby-proxy-headers](https://github.com/proxymeshai/ruby-proxy-headers) - Extensions for HTTP libraries to send/receive custom proxy headers during HTTPS CONNECT.
```

**Agent Can Do:** ✅ Fork repo and create PR

### Ruby Toolbox Categories
**URL:** https://www.ruby-toolbox.com/
**Categories:** HTTP Clients, Web Scraping, Proxy
**Note:** Automatic based on RubyGems metadata and GitHub

**Agent Can Do:** ❌ (Automatic based on gem publish)

---

## 4. Library Documentation PRs

### Faraday
**URL:** https://github.com/lostisland/faraday
**File:** `docs/middleware/index.md` or community middleware list
**Content:** Link to ruby-proxy-headers for proxy header support

**Agent Can Do:** ✅ Create documentation PR

### HTTParty
**URL:** https://github.com/jnunemaker/httparty
**File:** `README.md` - "Related Projects" or wiki
**Content:** Reference for proxy header extension

**Agent Can Do:** ✅ Create documentation PR

### HTTP.rb
**URL:** https://github.com/httprb/http
**File:** Wiki or README
**Content:** Reference for proxy header extension

**Agent Can Do:** ✅ Create wiki page or PR

### Typhoeus
**URL:** https://github.com/typhoeus/typhoeus
**File:** Wiki or README "Extensions" section

**Agent Can Do:** ✅ Create wiki page or PR

### Excon
**URL:** https://github.com/excon/excon
**File:** Documentation or README

**Agent Can Do:** ✅ Create PR

---

## 5. Direct Maintainer Outreach

### Template Email/Issue

```markdown
Subject: Ruby library for custom proxy headers during HTTPS CONNECT

Hi [Maintainer Name],

I've created ruby-proxy-headers, a gem that extends popular Ruby HTTP libraries 
(including [Library]) to support sending custom headers during HTTPS CONNECT 
tunneling and receiving proxy response headers.

This is useful for proxy services like ProxyMesh that use custom headers 
(e.g., X-ProxyMesh-Country, X-ProxyMesh-IP) for geolocation and session management.

Would you be open to:
- Mentioning this in your docs as a community extension?
- Reviewing the integration approach for potential inclusion?

GitHub: https://github.com/proxymeshai/ruby-proxy-headers
RubyGems: https://rubygems.org/gems/ruby_proxy_headers

Thank you!
```

### Maintainers to Contact

| Library | Maintainer | Contact Method |
|---------|-----------|----------------|
| Faraday | @iMacTia, @olleolleolle | GitHub Issue |
| HTTParty | @jnunemaker | GitHub Issue/Twitter |
| HTTP.rb | @tarcieri | GitHub Issue |
| Typhoeus | @typhoeus team | GitHub Issue |
| Excon | @geemus | GitHub Issue |

**Agent Can Do:** ✅ Create GitHub issues (but should be done thoughtfully)

---

## 6. Content Marketing

### Blog Posts

**Topics:**
1. "How to Send Custom Headers to Proxy Servers in Ruby"
2. "Solving HTTPS CONNECT Tunnel Header Limitations in Ruby"
3. "Building a Geo-Targeted Web Scraper with Ruby and ProxyMesh"

**Platforms:**
- Dev.to
- Medium
- Ruby Weekly newsletter submission
- Personal/company blog

**Agent Can Do:** ❌ (Requires human writing and accounts)

### Video Content

**Topics:**
1. "Quick Start: ruby-proxy-headers in 5 Minutes"
2. "Deep Dive: How HTTPS CONNECT Tunneling Works"

**Platforms:**
- YouTube
- Loom for quick tutorials

**Agent Can Do:** ❌ (Requires video creation)

---

## 7. Community Engagement

### Ruby Subreddits

**Target:**
- r/ruby
- r/rails (for Rails-specific use cases)
- r/webscraping

**Post Template:**
```markdown
Title: Open Source: Send Custom Proxy Headers in Ruby HTTP Clients

I built ruby-proxy-headers to solve a problem I had with proxy services that 
use custom headers during HTTPS CONNECT tunneling.

Supports: Faraday, HTTParty, HTTP.rb, Typhoeus, Excon, RestClient, Net::HTTP

GitHub: https://github.com/proxymeshai/ruby-proxy-headers

Would love feedback from the community!
```

**Agent Can Do:** ❌ (Requires Reddit account)

### Ruby Discord/Slack

**Communities:**
- Ruby Discord
- Ruby Together Slack
- Local Ruby meetup Slacks

**Agent Can Do:** ❌ (Requires account membership)

### Stack Overflow

**Strategy:**
- Answer questions about Ruby proxy issues
- Reference library when relevant
- Create self-answered Q&A for discoverability

**Example Tags:** `ruby`, `proxy`, `faraday`, `httparty`, `https`

**Agent Can Do:** ❌ (Requires SO account)

---

## 8. GitHub Presence Optimization

### Repository Topics

Add topics to improve discoverability:
- `ruby`
- `proxy`
- `http`
- `https`
- `faraday`
- `httparty`
- `web-scraping`
- `proxymesh`

**Agent Can Do:** ✅ Use `gh repo edit --add-topic`

### Repository Description

Ensure description is clear and keyword-rich:
"Send and receive custom proxy headers during HTTPS CONNECT tunneling. Extensions for Faraday, HTTParty, HTTP.rb, Typhoeus, Excon, RestClient."

**Agent Can Do:** ✅ Use `gh repo edit`

### GitHub Sponsors

Set up funding.yml:
```yaml
github: proxymeshai
custom: ["https://proxymesh.com"]
```

**Agent Can Do:** ✅ Create `.github/FUNDING.yml`

### Cross-Linking

Link between related repositories:
- Link to python-proxy-headers
- Link to javascript-proxy-headers
- Link from proxy-examples

**Agent Can Do:** ✅ Update READMEs

---

## 9. SEO & Discoverability

### RubyGems Keywords

Already in gemspec:
```ruby
spec.metadata['rubygems_mfa_required'] = 'true'
```

Add keywords through proper categorization.

### Google Search Optimization

**Target Keywords:**
- "ruby proxy custom headers"
- "faraday proxy headers"
- "httparty https proxy"
- "ruby http connect tunnel"
- "proxymesh ruby"

**Strategy:** Ensure README and docs contain these terms naturally.

---

## 10. Metrics & Tracking

### Key Metrics

| Metric | Tool | Goal (6 months) |
|--------|------|-----------------|
| RubyGems Downloads | rubygems.org | 5,000 |
| GitHub Stars | GitHub | 100 |
| GitHub Forks | GitHub | 20 |
| Documentation Views | ReadTheDocs | 2,000/month |
| Referral Traffic | GitHub Insights | Track sources |

### Tracking Links

Use UTM parameters for tracking:
```
https://github.com/proxymeshai/ruby-proxy-headers?utm_source=reddit&utm_medium=post
```

---

## Action Items Summary

### Agent Can Do Now (With GitHub Access)

1. ✅ Create GitHub repository
2. ✅ Push all code and documentation
3. ✅ Add repository topics via `gh repo edit --add-topic`
4. ✅ Create `.github/FUNDING.yml`
5. ✅ Fork awesome-ruby and create PR
6. ✅ Fork awesome-web-scraping and create PR
7. ✅ Create issues on library repos (Faraday, HTTParty, etc.)
8. ✅ Cross-link from proxy-examples README
9. ✅ Cross-link from javascript-proxy-headers

### Requires Human Action

1. ❌ Publish to RubyGems (requires account)
2. ❌ Import to ReadTheDocs (requires account)
3. ❌ Write blog posts
4. ❌ Post to Reddit/social media
5. ❌ Respond to community feedback
6. ❌ Answer Stack Overflow questions
7. ❌ Create video tutorials

---

## Timeline

### Week 1: Foundation
- [x] Create gem with all integrations
- [x] Complete documentation
- [x] Push to GitHub
- [ ] Publish to RubyGems
- [ ] Import to ReadTheDocs

### Week 2: Visibility
- [ ] Submit to awesome lists
- [ ] Create library documentation PRs
- [ ] Add GitHub topics and optimize repo

### Week 3: Outreach
- [ ] Contact library maintainers
- [ ] Post to Reddit/communities
- [ ] Write first blog post

### Month 2+: Ongoing
- [ ] Monitor and respond to issues
- [ ] Publish additional content
- [ ] Track metrics and adjust strategy
