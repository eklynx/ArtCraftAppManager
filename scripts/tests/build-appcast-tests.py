#!/usr/bin/env python3
"""Tests for scripts/build-appcast.py (REQ-UPD-7). Run: python3 scripts/tests/build-appcast-tests.py"""
import importlib.util, tempfile, unittest
from pathlib import Path
import xml.etree.ElementTree as ET

spec = importlib.util.spec_from_file_location("build_appcast", Path(__file__).parent.parent / "build-appcast.py")
ba = importlib.util.module_from_spec(spec); spec.loader.exec_module(ba)
NS = ba.SPARKLE_NS


def feed(items):
    body = "".join(
        f'<item><sparkle:version>{v}</sparkle:version><enclosure url="https://x/{n}"'
        + (f' sparkle:edSignature="sig"' if signed else "") + "/></item>" for v, n, signed in items)
    return f'<rss xmlns:sparkle="{NS}" version="2.0"><channel>{body}</channel></rss>'


class ChannelTests(unittest.TestCase):
    def test_release_is_default_channel(self):
        self.assertIsNone(ba.channel_for("v1.2.3", False))

    def test_nightly_prefix_is_nightly(self):
        self.assertEqual(ba.channel_for("nightly-1.0.1-20261102.abc1234", True), "nightly")

    def test_other_prerelease_is_prerelease(self):
        self.assertEqual(ba.channel_for("v1.3.0-beta.1", True), "prerelease")
        self.assertEqual(ba.channel_for("rc-2", True), "prerelease")


class MergeTests(unittest.TestCase):
    def test_merge_orders_by_build_rewrites_urls_and_drops_unsigned(self):
        with tempfile.TemporaryDirectory() as d:
            a, b, out = Path(d, "a.xml"), Path(d, "b.xml"), Path(d, "out.xml")
            a.write_text(feed([(5, "M-1.dmg", True), (3, "M-old.dmg", False)]))
            b.write_text(feed([(9, "M-2.dmg", True)]))
            ba.merge_feeds([a, b], {"M-1.dmg": "https://gh/v1/M-1.dmg", "M-2.dmg": "https://gh/n/M-2.dmg"}, out)
            items = list(ET.parse(out).getroot().iter("item"))
            self.assertEqual([i.findtext(f"{{{NS}}}version") for i in items], ["9", "5"])
            self.assertEqual([i.find("enclosure").get("url") for i in items], ["https://gh/n/M-2.dmg", "https://gh/v1/M-1.dmg"])


if __name__ == "__main__":
    unittest.main()
