#!/usr/bin/env python3
"""Builds the Sparkle Feed (appcast.xml) from the Manager's GitHub releases. See docs/specs/10-manager-update.md and docs/ci.md.

usage: build-appcast.py <output-dir>
Env:   GH_TOKEN (gh), SPARKLE_BIN (folder with generate_appcast), SPARKLE_ED_PRIVATE_KEY (EdDSA key, passed on stdin).

Each Manager DMG is placed in a folder per channel, signed by `generate_appcast --channel`, and the per-channel feeds are
merged into <output-dir>/appcast.xml with enclosure URLs pointing at the GitHub release assets.
"""
from __future__ import annotations

import json, os, re, shutil, subprocess, sys
import xml.etree.ElementTree as ET
from pathlib import Path

SPARKLE_NS = "http://www.andymatuschak.org/xml-namespaces/sparkle"
ET.register_namespace("sparkle", SPARKLE_NS)
ET.register_namespace("dc", "http://purl.org/dc/elements/1.1/")
NIGHTLY_PREFIX = "nightly-"


def channel_for(tag: str, is_prerelease: bool) -> str | None:
    """Release -> None (the default channel); pre-release not starting with `nightly-` -> prerelease; else nightly."""
    if not is_prerelease:
        return None
    return "nightly" if tag.startswith(NIGHTLY_PREFIX) else "prerelease"


def dmg_asset(release: dict) -> str | None:
    return next((a["name"] for a in release.get("assets", []) if re.fullmatch(r"ArtCraftAppManager-.+\.dmg", a["name"])), None)


def merge_feeds(feeds: list[Path], urls: dict[str, str], out: Path) -> None:
    """Concatenates the <item>s of several feeds, rewriting each enclosure URL via `urls` (DMG file name -> download URL)."""
    root = ET.Element("rss", {"version": "2.0"})
    channel = ET.SubElement(root, "channel")
    ET.SubElement(channel, "title").text = "ArtCraft Application Manager"
    items = []
    for feed in feeds:
        for item in ET.parse(feed).getroot().iter("item"):
            enclosure = item.find("enclosure")
            if enclosure.get(f"{{{SPARKLE_NS}}}edSignature") is None:
                continue  # builds from before Sparkle carry no signature; Sparkle would reject them
            name = enclosure.get("url").rsplit("/", 1)[-1]
            if name in urls:
                enclosure.set("url", urls[name])
            items.append(item)
    items.sort(key=lambda i: int(i.findtext(f"{{{SPARKLE_NS}}}version") or 0), reverse=True)
    channel.extend(items)
    ET.indent(root)
    ET.ElementTree(root).write(out, encoding="utf-8", xml_declaration=True)


def main(out_dir: Path) -> None:
    repo = os.environ.get("GITHUB_REPOSITORY", "eklynx/ArtCraftAppManager")
    releases = json.loads(subprocess.check_output(
        ["gh", "release", "list", "--repo", repo, "--limit", "200", "--exclude-drafts", "--json", "tagName,isPrerelease"]))
    work = out_dir / "work"
    shutil.rmtree(work, ignore_errors=True)
    urls: dict[str, str] = {}
    feeds: list[Path] = []
    for release in releases:
        tag = release["tagName"]
        detail = json.loads(subprocess.check_output(["gh", "release", "view", tag, "--repo", repo, "--json", "assets"]))
        name = dmg_asset(detail)
        if not name:
            continue
        folder = work / (channel_for(tag, release["isPrerelease"]) or "release")
        folder.mkdir(parents=True, exist_ok=True)
        subprocess.check_call(["gh", "release", "download", tag, "--repo", repo, "--pattern", name, "--dir", str(folder), "--clobber"])
        urls[name] = f"https://github.com/{repo}/releases/download/{tag}/{name}"
    key = os.environ["SPARKLE_ED_PRIVATE_KEY"]
    tool = Path(os.environ["SPARKLE_BIN"]) / "generate_appcast"
    for folder in sorted(p for p in work.iterdir() if p.is_dir()):
        args = [str(tool), "--ed-key-file", "-", "--maximum-versions", "0", "-o", str(folder / "appcast.xml")]
        if folder.name != "release":
            args += ["--channel", folder.name]
        subprocess.run(args + [str(folder)], input=(key.strip() + "\n").encode(), check=True)
        feeds.append(folder / "appcast.xml")
    out_dir.mkdir(parents=True, exist_ok=True)
    merge_feeds(feeds, urls, out_dir / "appcast.xml")
    shutil.rmtree(work)


if __name__ == "__main__":
    main(Path(sys.argv[1]))
