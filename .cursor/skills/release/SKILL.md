---
name: release
description: >-
  Cuts a ruby-proxy-headers release from RELEASING.md. Prepare release opens a
  pull request from release/X.Y.Z; merging it publishes the gem and tags vX.Y.Z.
  Use when the user invokes /release, /release VERSION, or asks for a release PR.
---

# Release

Follow `RELEASING.md` at the repository root. Do not publish, tag, or merge the release pull request. Do not enable auto-merge.

## Version

Read `RubyProxyHeaders::VERSION` from `lib/ruby_proxy_headers/version.rb`.

| Input | Spec |
| --- | --- |
| `/release` | `patch` |
| `/release 1.4.0` | `1.4.0` |

The version must be `MAJOR.MINOR.PATCH`.

## Preferred path

From latest `origin/main`:

```bash
gh workflow run "Prepare release" --ref main -f version=SPEC
```

Wait until that run opens the pull request titled `Release X.Y.Z`.

## Manual path

Use this when the workflow cannot be started. Branch `release/X.Y.Z` from latest `origin/main` and make the same edits Prepare release makes:

- `lib/ruby_proxy_headers/version.rb`, `VERSION = 'X.Y.Z'`
- every `ruby-proxy-headers (X.Y.Z)` entry in `Gemfile.lock`
- move `## [Unreleased]` in `CHANGELOG.md` to `## [X.Y.Z] - YYYY-MM-DD`, and update the compare links

Commit, push `release/X.Y.Z`, and open a pull request into `main` titled `Release X.Y.Z` whose body is that changelog section.

Git identity for commits in this repo:

```bash
git config user.email "cursor@proxymesh.com"
git config user.name "Cursor"
```
