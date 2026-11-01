#!/bin/zsh
# Computes the Manager's version from the existing vX.Y.Z git tags. See docs/ci.md ("Versioning").
#
# usage: compute-version.sh release [major|minor|patch]   (default bump: patch)
#        compute-version.sh dev
#
# release  -> X.Y.Z, the latest vX.Y.Z tag bumped; 1.0.0 when there is no tag yet.
# dev      -> X.Y.Z-<UTC timestamp>.<short hash>, X.Y.Z being the latest tag with its patch bumped (1.0.0 when no tag).
#
# Prints key=value lines (usable with >> "$GITHUB_OUTPUT"):
#   version=<full version>   marketing_version=<X.Y.Z, always plain>
#   tag=v<X.Y.Z> for release, nightly-<full version> for dev
# CFBundleShortVersionString cannot carry a "-suffix", so builds use marketing_version and the full version names the artifact.
# Env: VERSION_TIMESTAMP overrides the timestamp (tests). Run from inside the git checkout; tags must be fetched.
set -euo pipefail

mode="${1:-}"; bump="${2:-patch}"
latest="$(git tag --list 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -n1 || true)"

if [[ -z "$latest" ]]; then
  base="1.0.0"
else
  IFS=. read -r major minor patch <<< "${latest#v}"
  case "$mode:$bump" in
    release:major) base="$((major + 1)).0.0" ;;
    release:minor) base="$major.$((minor + 1)).0" ;;
    release:patch|dev:*) base="$major.$minor.$((patch + 1))" ;;
    release:*) echo "unknown bump '$bump' (major|minor|patch)" >&2; exit 2 ;;
  esac
fi

case "$mode" in
  release)
    echo "version=$base"; echo "tag=v$base"; echo "marketing_version=$base" ;;
  dev)
    stamp="${VERSION_TIMESTAMP:-$(date -u +%Y%m%d%H%M%S)}"
    hash="$(git rev-parse --short=7 HEAD)"
    echo "version=$base-$stamp.$hash"; echo "tag=nightly-$base-$stamp.$hash"; echo "marketing_version=$base" ;;
  *) echo "usage: compute-version.sh release [major|minor|patch] | dev" >&2; exit 2 ;;
esac
