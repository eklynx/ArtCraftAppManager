#!/bin/zsh
# Tests scripts/compute-version.sh against a throwaway git repo with fake tags. Exits non-zero on the first failure.
set -euo pipefail
script="${0:A:h:h}/compute-version.sh"
work="$(mktemp -d "${TMPDIR:-/tmp}/compute-version-test.XXXXXX")"
trap 'rm -rf "$work"' EXIT
cd "$work"
git init -q . && git -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
hash="$(git rev-parse --short=7 HEAD)"

check() { # description expected actual
  if [[ "$2" != "$3" ]]; then echo "FAIL: $1 — expected '$2', got '$3'" >&2; exit 1; fi
  echo "ok: $1"
}
field() { "$script" "${@:2}" | sed -n "s/^$1=//p"; }

check "release without tags is 1.0.0 (bump ignored)" "1.0.0" "$(field version release major)"
check "dev without tags" "1.0.0-20260101000000.$hash" "$(VERSION_TIMESTAMP=20260101000000 field version dev)"

git tag v1.2.3; git tag v1.10.0; git tag v1.9.9; git tag not-a-version; git tag v2.0.0-rc1
check "latest tag sorts numerically, ignoring non-release tags" "1.10.1" "$(field version release)"
check "release minor" "1.11.0" "$(field version release minor)"
check "release major" "2.0.0" "$(field version release major)"
check "release tag name" "v1.10.1" "$(field tag release patch)"
check "dev builds are the next patch plus suffix" "1.10.1-20260101000000.$hash" "$(VERSION_TIMESTAMP=20260101000000 field version dev)"
check "dev tag is nightly-<version>" "nightly-1.10.1-20260101000000.$hash" "$(VERSION_TIMESTAMP=20260101000000 field tag dev)"
check "dev marketing version is plain X.Y.Z" "1.10.1" "$(field marketing_version dev)"
if "$script" release huge >/dev/null 2>&1; then echo "FAIL: bad bump accepted" >&2; exit 1; fi
echo "ok: bad bump rejected"
