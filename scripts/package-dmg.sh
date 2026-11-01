#!/bin/zsh
# Builds a compressed disk image containing an .app and an /Applications shortcut.
# usage: package-dmg.sh <path/to/App.app> <out.dmg> [volume name]
# Does not sign or notarize the image; release.yml does that afterwards.
set -euo pipefail
app="${1:?usage: package-dmg.sh App.app out.dmg [volume name]}"; out="${2:?missing out.dmg}"
name="${3:-${${app:t}%.app}}"
[[ -d "$app" ]] || { echo "not an app bundle: $app" >&2; exit 1; }
stage="$(mktemp -d "${TMPDIR:-/tmp}/package-dmg.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
ditto "$app" "$stage/${app:t}"
ln -s /Applications "$stage/Applications"
rm -f "$out"
hdiutil create -quiet -volname "$name" -srcfolder "$stage" -fs HFS+ -format UDZO "$out"
echo "Created $out"
