#!/usr/bin/env bash
# Check that version.rb and Gemfile.lock carry the same gem version, and that
# a release/X.Y.Z branch carries version X.Y.Z. scripts/lint.sh runs this;
# on pull requests the branch comes from GITHUB_HEAD_REF.

set -euo pipefail

err() {
  echo "$*" >&2
}

main() {
  cd "$(git rev-parse --show-toplevel)"
  local version lock branch
  version="$(sed -nE "s/^ *VERSION = '([^']+)'$/\1/p" \
    lib/ruby_proxy_headers/version.rb)"
  lock="$(sed -nE 's/^    ruby-proxy-headers \(([^)]+)\)$/\1/p' Gemfile.lock)"
  branch="${GITHUB_HEAD_REF:-$(git rev-parse --abbrev-ref HEAD)}"
  if [[ -z "${version}" || "${lock}" != "${version}" ]]; then
    err "version.rb '${version}' != Gemfile.lock '${lock}'; run bundle install"
    exit 1
  fi
  if [[ "${branch}" == release/* && "${branch#release/}" != "${version}" ]]; then
    err "branch ${branch} != version.rb ${version}"
    exit 1
  fi
}

main "$@"
