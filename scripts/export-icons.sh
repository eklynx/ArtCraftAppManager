#!/bin/zsh
# Renders docs/prototypes/AppIcon.svg into the asset catalog PNGs (app icon pack + menu bar icon).
# Needs only macOS tools (swift, sips); qlmanage is not used because it paints an opaque background. Re-run after editing the SVG, then commit the PNGs.
set -euo pipefail
root="${0:A:h:h}"
svg="$root/docs/prototypes/AppIcon.svg"
assets="$root/ArtCraftAppManager/Assets.xcassets"
work="${CLAUDE_WORK:-${TMPDIR:-/tmp}}/tmp/ArtCraftAppManager/icon-export"
rm -rf "$work"; mkdir -p "$work/app" "$work/bar"

# Menu bar variant: crop to the squircle body (no margin, no drop shadow); corners stay transparent.
sed -e 's/viewBox="0 0 1024 1024"/viewBox="100 100 824 824"/' -e 's/ filter="url(#shadow)"//' "$svg" > "$work/bar/MenuBarIcon.svg"

render() { # svg size out [shadow]
  swift "$root/scripts/render-svg.swift" "$@"
}
render "$svg" 1024 "$work/app/1024.png" shadow
for s in 16 32 64 128 256 512; do sips -z $s $s "$work/app/1024.png" --out "$work/app/$s.png" >/dev/null; done
render "$work/bar/MenuBarIcon.svg" 144 "$work/bar/144.png"
sips -z 18 18 "$work/bar/144.png" --out "$work/bar/menubar.png" >/dev/null
sips -z 36 36 "$work/bar/144.png" --out "$work/bar/menubar@2x.png" >/dev/null

icon="$assets/AppIcon.appiconset"; bar="$assets/MenuBarIcon.imageset"; mkdir -p "$bar"
for s in 16 32 64 128 256 512 1024; do cp "$work/app/$s.png" "$icon/icon_$s.png"; done
cp "$work/bar/menubar.png" "$bar/menubar.png"; cp "$work/bar/menubar@2x.png" "$bar/menubar@2x.png"
echo "Exported icons to $icon and $bar"
