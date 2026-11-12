# Releasing

## Cut a release

1. On GitHub, open **Actions** → **Prepare release** → **Run workflow** on `main`.
2. Set **version** to `X.Y.Z`, `patch`, `minor`, or `major`.
3. The workflow pushes `release/X.Y.Z` and opens a pull request titled `Release X.Y.Z`. The body is the changelog section. It does not auto-merge.
4. Wait until **Push Gem / release-check** is green, then merge the pull request.

Opening the pull request by hand still works. From an up-to-date `main`, bump every version manifest, move `## [Unreleased]` in `CHANGELOG.md` to `## [X.Y.Z] - YYYY-MM-DD`, push `release/X.Y.Z`, and open a pull request titled `Release X.Y.Z` whose body is that changelog section. Do not auto-merge.

Version manifests:

- `lib/ruby_proxy_headers/version.rb` (`RubyProxyHeaders::VERSION`)
- `Gemfile.lock` (every `ruby-proxy-headers` version entry)

`ruby-proxy-headers.gemspec` reads `RubyProxyHeaders::VERSION`.

## What runs

### Prepare

`.github/workflows/prepare-release.yml` runs on `workflow_dispatch`. It bumps the manifests, moves the changelog section, and opens the pull request.

### Validate

`.github/workflows/push_gem.yml` runs **release-check** on pull requests. It runs actionlint, checks that `version.rb` and `Gemfile.lock` agree, and runs `gem build`.

On a `release/X.Y.Z` pull request it also checks that `X.Y.Z` matches those manifests and that `CHANGELOG.md` has a `## [X.Y.Z] - YYYY-MM-DD` section.

### Publish

Pushing the merge to `main` runs **publish** in `.github/workflows/push_gem.yml` when that commit is the merge of a `release/X.Y.Z` pull request. The job uses the GitHub environment `release`. It builds the gem, pushes it to RubyGems with trusted publishing, then creates tag `vX.Y.Z` and a GitHub Release. The release notes are that changelog section. If the section is missing, the notes are `Release X.Y.Z.` so an older release pull request still publishes.

A re-run does not push a version that is already on RubyGems for this commit. If that version is already on RubyGems for a different commit, the job fails and names the version.

The workflow filename stays `push_gem.yml` so the existing trusted publisher keeps matching. Tags are `vX.Y.Z`. Existing tags already use that form; older tags are left as they are.

Publishing a GitHub Release by hand (`release: published`) still pushes the gem when the tag is `vX.Y.Z` and that version is not already on RubyGems. `workflow_dispatch` publish was removed.

## One-time setup

Do this once, before the next release. This change does not modify repository or RubyGems settings.

1. Create a GitHub environment named `release` (**Settings → Environments**). Add required reviewers so the publish job waits for approval. It does not need secrets.
2. On the `ruby-proxy-headers` trusted publisher, set the GitHub environment to `release`. Keep the repository `proxymesh/ruby-proxy-headers` and the workflow filename `push_gem.yml`. A publisher with a blank environment will reject the next push until the environment matches. If the environment cannot be edited, create a publisher with those values and remove the old one.
3. Publishing uses OpenID Connect. No RubyGems API token is read from the workflow. After a publish succeeds, delete any leftover RubyGems token from repository or environment secrets.
4. **Prepare release** opens the pull request as `github-actions[bot]`. Actions workflow permissions need read and write access, and **Allow GitHub Actions to create and approve pull requests** should stay enabled.
