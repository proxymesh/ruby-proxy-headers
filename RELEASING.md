# Releasing

## Cut a release

1. On GitHub, open **Actions** → **Prepare release** → **Run workflow** on `main`.
2. Set **version** to `X.Y.Z`, `patch`, `minor`, or `major`.
3. The workflow bumps the version, moves the changelog section, runs the release checks, and opens a pull request titled `Release X.Y.Z`. It does not auto-merge.
4. Merge that pull request when you are ready.

Opening the pull request by hand still works. From an up-to-date `main`, bump every version manifest, move `## [Unreleased]` in `CHANGELOG.md` to `## [X.Y.Z] - YYYY-MM-DD`, and open a pull request titled `Release X.Y.Z` whose body is that changelog section. Do not auto-merge.

Version manifests:

- `lib/ruby_proxy_headers/version.rb` (`RubyProxyHeaders::VERSION`)
- `Gemfile.lock` (every `ruby-proxy-headers` version entry)

`ruby-proxy-headers.gemspec` reads `RubyProxyHeaders::VERSION`.

## What runs

### Prepare release

`.github/workflows/prepare-release.yml` runs on `workflow_dispatch` from `main`. It bumps the manifests, moves the changelog section, checks that the version matches and the changelog has a dated section, builds the gem, and opens the pull request.

A pull request opened with `GITHUB_TOKEN` does not run `pull_request` workflows, so those checks run in this job before the branch is pushed.

### Release check

`.github/workflows/push_gem.yml` runs **Release check** on pull requests into `main`. It checks that `version.rb` and `Gemfile.lock` agree and runs `gem build`. On a `release/X.Y.Z` pull request it also checks that `X.Y.Z` matches those files and that `CHANGELOG.md` has a `## [X.Y.Z] - YYYY-MM-DD` section.

### Publish

A push to `main` runs **publish** and **github-release** in `.github/workflows/push_gem.yml`. Each job looks up the pull request for that commit and does nothing when it is not a merged `release/X.Y.Z` pull request.

**publish** uses the GitHub environment `release`. It builds the gem and pushes it with `gem push` after `rubygems/configure-rubygems-credentials`. A version already on RubyGems fails the push. **github-release** then runs `gh release view` or `gh release create` with the changelog section as the notes.

The workflow filename stays `push_gem.yml` so the existing trusted publisher keeps matching.

## One-time owner setup

Do this once, before the next release. This change does not modify repository or RubyGems settings.

1. Create a GitHub environment named `release` (**Settings → Environments**). Add required reviewers so the publish job waits for approval. It does not need secrets.
2. On the `ruby-proxy-headers` trusted publisher, set the GitHub environment to `release`. Keep the repository `proxymesh/ruby-proxy-headers` and the workflow filename `push_gem.yml`. A publisher with a blank environment will reject the next push until it matches. If the environment cannot be edited, create a publisher with those values and remove the old one.
3. Publishing uses OpenID Connect. No RubyGems API token is read from the workflow. After a publish succeeds, delete any leftover RubyGems token from repository or environment secrets.
4. **Prepare release** opens the pull request as `github-actions[bot]`. Actions workflow permissions need read and write access, and **Allow GitHub Actions to create and approve pull requests** should stay enabled.

## Tags

Tags are `vX.Y.Z`. Existing tags already use that form. Older tags are left as they are.
