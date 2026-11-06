"""Offline tests for the 64-bit stream save helper (tools/savestream).

They compile the helper with the host compiler and drive it over the same
pipe protocol the call_ext shim uses. No BYOND install is needed.

    python3 -m unittest tests/savestream/test_helper.py
"""
from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from helper_client import Helper, Path_, Raw, build_helper, parse_token, record, subtree, tok_str  # noqa: E402

ICON_TEXT = (
    'filedata("name=t.dmi;length=4;crc32=0x0;encoding=base64",{"\n'
    'AAECAw==\n"})'
)


class HelperTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = Path(tempfile.mkdtemp(prefix="savestream-test-"))
        cls.exe = build_helper(cls.tmp)

    def write(self, name: str, batches: list[str], force: bool = False) -> tuple[Path, dict]:
        out = self.tmp / name
        h = Helper(self.exe, "write", out)
        for batch in batches:
            self.assertEqual(h.request("W", batch), b"OK")
        summary = json.loads(h.request("F", "force" if force else ""))
        h.close()
        return out, summary

    def test_round_trip_values(self):
        values = {
            "/format_version": 3,
            "/generation": "round-v2:abc",
            "/entries/0/1/type": Path_("/turf/floor/grass"),
            "/entries/0/1/name": {"kind": "value", "value": 'he said "hi"\nnew ü'},
            "/entries/0/1/n": {"kind": "value", "value": 1.12345684},
            "/entries/0/1/neg": -0.5,
            "/entries/0/1/content": ["1;2;3", "4"],
            "/entries/0/1/nested": [None, Path_("/datum"), {"x": []}],
            "/map/1/1/1": 1,
        }
        records = [record(p, v) for p, v in values.items()]
        # Records may arrive across several batches.
        out, summary = self.write("values.stream", ["".join(records[:4]), "".join(records[4:])])
        self.assertTrue(summary["valid"], summary)
        self.assertTrue(summary["published"])
        self.assertEqual(summary["nodes"], len(values))
        r = Helper(self.exe, "read", out)
        try:
            v, _ = parse_token(r.request("G", "/entries/0/1/name"))
            self.assertEqual(v, [("kind", "value"), ("value", 'he said "hi"\nnew ü')])
            v, _ = parse_token(r.request("G", "/entries/0/1/n"))
            self.assertAlmostEqual(v[1][1], 1.12345684, places=7)
            v, _ = parse_token(r.request("G", "/entries/0/1/type"))
            self.assertEqual(v.path, "/turf/floor/grass")
            self.assertEqual(r.request("G", "/missing"), b"?")
            names, _ = parse_token(r.request("D", "/entries/0/1"))
            self.assertEqual(sorted(n[0] for n in names), ["content", "n", "name", "neg", "nested", "type"])
            names, _ = parse_token(r.request("D", "/"))
            self.assertEqual(sorted(n[0] for n in names), ["entries", "format_version", "generation", "map"])
            v, _ = parse_token(r.request("G", "/entries/0/1/nested"))
            self.assertIsNone(v[0][0])
            self.assertEqual(v[1][0].path, "/datum")
        finally:
            r.close()

    def test_text_request_renders_savefile_text(self):
        batch = record("/entries/0/1/type", Path_("/obj/item"))
        batch += record("/entries/0/1/name", 'q"uo\\te [b] {"x"}\nnl\ttab é')
        batch += record("/entries/0/1/items", {"a": [1.5, -2, None], "b": Path_("/datum")})
        batch += record("/entries/0/1/icon", {"kind": "value", "value": Raw(ICON_TEXT)})
        batch += record("/entries/0/1/far", float("inf"))
        batch += record("/entries/0/1/odd-name", 7)
        batch += record("/entries/0/1/sub/deep", 8)
        batch += record("/entries/0/2/type", Path_("/obj"))
        batch += record("/entries/1/513/type", Path_("/obj"))
        for i in (1, 2, 10, 513):
            batch += record(f"/lists/{i}", {"kind": "scalars", "length": i})
        batch += record("/lists/2/1/key", "k")
        raw = batch.encode() + tok_str("W", "/entries/0/2/name").encode() + b"S3:\xff\x01x"
        out = self.tmp / "text.stream"
        h = Helper(self.exe, "write", out)
        self.assertEqual(h.request("W", raw), b"OK")
        self.assertTrue(json.loads(h.request("F", "force"))["published"])
        h.close()
        r = Helper(self.exe, "read", out)
        try:
            reply = r.request("T", "/entries/0")
            count, rest = reply.split(b";", 1)
            # inf, a text macro and a name with no savefile text form come back by path.
            self.assertEqual(int(count), 3)
            missing = []
            for _ in range(int(count)):
                head, rest = rest[1:].split(b":", 1)
                missing.append(rest[:int(head)].decode())
                rest = rest[int(head):]
            self.assertEqual(sorted(missing), ["/entries/0/1/far", "/entries/0/1/odd-name", "/entries/0/2/name"])
            text = rest.decode()
            self.assertEqual(text.splitlines()[0], "1")
            self.assertIn('\tname = "q\\"uo\\\\te \\[b\\] {\\"x\\"}\\nnl\ttab é"\n', text)
            self.assertIn('\titems = list("a" = list(1.5,-2,null),"b" = /datum)\n', text)
            self.assertIn('\ticon = list("kind" = "value","value" = filedata("name=t.dmi;length=4;crc32=0x0;encoding=base64",{"\nAAECAw==\n"}))\n', text)
            self.assertIn("\tsub\n\t\tdeep = 8\n", text)
            # A handed-back node keeps its name line; the game writes its value.
            self.assertIn("\tfar\n", text)
            self.assertIn("2\n\tname\n\ttype = /obj\n", text)
            self.assertNotIn("513", text)
            reply = r.request("T", "/lists\n1\n512")
            self.assertTrue(reply.startswith(b"0;"))
            lists = reply[2:].decode()
            self.assertEqual(lists, '1 = list("kind" = "scalars","length" = 1)\n'
                                    '2 = list("kind" = "scalars","length" = 2)\n\t1\n\t\tkey = "k"\n'
                                    '10 = list("kind" = "scalars","length" = 10)\n')
            self.assertTrue(r.request("T", "/lists\n5\n1").startswith(b"ERR:"))
            self.assertEqual(r.request("T", "/nothing"), b"0;")
        finally:
            r.close()

    def test_last_write_wins_and_dir_grouping(self):
        batch = record("/a/1", 1) + record("/a/1-x/b", 2) + record("/a/1/c", 3) + record("/a/1", 4)
        out, summary = self.write("dup.stream", [batch])
        self.assertEqual(summary["nodes"], 3)
        r = Helper(self.exe, "read", out)
        try:
            v, _ = parse_token(r.request("G", "/a/1"))
            self.assertEqual(v, 4.0)
            names, _ = parse_token(r.request("D", "/a"))
            self.assertEqual(sorted(n[0] for n in names), ["1", "1-x"])
        finally:
            r.close()

    def test_blobs_are_deduplicated(self):
        batch = "".join(record(f"/entries/0/{i}/icon", {"kind": "value", "value": Raw(ICON_TEXT)}) for i in range(1, 6))
        batch += "".join(record(f"/entries/0/{i}/type", Path_("/obj")) for i in range(1, 6))
        out, summary = self.write("blobs.stream", [batch])
        self.assertEqual(summary["blobs"], 1)
        self.assertEqual(summary["blob_refs"], 5)
        r = Helper(self.exe, "read", out)
        try:
            v, _ = parse_token(r.request("G", "/entries/0/3/icon"))
            text = v[1][1].text
            self.assertTrue(text.startswith('filedata("name=t.dmi;length=4;crc32=0x0;encoding=base64",{"'), text)
            self.assertIn("AAECAw==", text)
        finally:
            r.close()

    def test_validation_reports_missing_references(self):
        batch = record("/entries/0/1/type", Path_("/obj"))
        batch += record("/entries/0/1/owner", {"kind": "entry", "ref": 7})
        batch += record("/entries/0/1/items", {"kind": "list", "ref": 3})
        batch += record("/map/1/1/1", 2)
        out, summary = self.write("broken.stream", [batch])
        self.assertFalse(summary["valid"])
        self.assertFalse(summary["published"])
        self.assertFalse(out.exists())
        self.assertEqual(summary["missing_entry_refs"], 2)
        self.assertEqual(summary["missing_lists"], 1)
        _, forced = self.write("broken.stream", [batch], force=True)
        self.assertTrue(forced["published"])

    def test_savefile_subtree_text(self):
        text = (
            "\ntype = /obj/item\nname = list(\"kind\" = \"value\",\"value\" = \"knife\")\n"
            "icon = list(\"kind\" = \"value\",\"value\" = " + ICON_TEXT + ")\n"
            "app = list(\"kind\" = \"value\",\"value\" = appearance(,,3,,,,\"o\"))\n"
            "thing = object(\".0\")\n\t.0\n\t\ttype = /datum/thing\n\t\ta = 5\n"
            "sub\n\tdeep = -9.9999997473787516355514526367188e-06\n"
        )
        out, summary = self.write("subtree.stream", [subtree("/entries/0/9", text)])
        self.assertTrue(summary["published"], summary)
        self.assertEqual(summary["blobs"], 1)
        r = Helper(self.exe, "read", out)
        try:
            v, _ = parse_token(r.request("G", "/entries/0/9/type"))
            self.assertEqual(v.path, "/obj/item")
            v, _ = parse_token(r.request("G", "/entries/0/9/app"))
            self.assertEqual(v[1][1].text, 'appearance(,,3,,,,"o")')
            v, _ = parse_token(r.request("G", "/entries/0/9/thing"))
            self.assertEqual(v.text, 'object(".0")\n.0\n\ttype = /datum/thing\n\ta = 5\n')
            v, _ = parse_token(r.request("G", "/entries/0/9/sub/deep"))
            self.assertAlmostEqual(v, -1e-5, places=9)
            self.assertEqual(r.request("G", "/entries/0/9/thing/.0/type"), b"?")
        finally:
            r.close()

    def test_scalar_list_node_defines_the_list(self):
        # Value format 2 writes an all-scalar list as the one node /lists/<id>.
        batch = record("/entries/0/1/type", Path_("/obj"))
        batch += record("/entries/0/1/tags", {"kind": "list", "ref": 4})
        batch += record("/lists/4", {"kind": "scalars", "length": 1, "keys": ["a"], "values": [None]})
        _, summary = self.write("scalars.stream", [batch])
        self.assertTrue(summary["valid"], summary)
        self.assertEqual(summary["missing_lists"], 0)

    def test_write_mode_reads_back_the_last_value(self):
        out = self.tmp / "late.stream"
        h = Helper(self.exe, "write", out)
        try:
            self.assertEqual(h.request("W", record("/entries/0/1/type", Path_("/turf")) + record("/entries/0/1/content", ["1"])), b"OK")
            v, _ = parse_token(h.request("G", "/entries/0/1/content"))
            self.assertEqual(v, [("1",)])
            self.assertEqual(h.request("W", record("/entries/0/1/content", ["1", "2"])), b"OK")
            v, _ = parse_token(h.request("G", "/entries/0/1/content"))
            self.assertEqual(v, [("1",), ("2",)])
            self.assertEqual(h.request("G", "/entries/0/2/content"), b"?")
            summary = json.loads(h.request("F", ""))
        finally:
            h.close()
        self.assertTrue(summary["published"], summary)
        r = Helper(self.exe, "read", out)
        try:
            v, _ = parse_token(r.request("G", "/entries/0/1/content"))
            self.assertEqual(v, [("1",), ("2",)])
        finally:
            r.close()

    def test_seek_finds_a_subtree_start(self):
        batch = "".join(record(p, 1) for p in ("/lists/12", "/lists/12/1/key", "/lists/120", "/lists/2/length", "/entries/1/600/type"))
        out, _ = self.write("seek.stream", [batch], force=True)
        r = Helper(self.exe, "read", out)
        try:
            order = ["/entries/1/600/type", "/lists/12", "/lists/12/1/key", "/lists/120", "/lists/2/length"]
            self.assertEqual(int(r.request("K", "/lists/12")), order.index("/lists/12"))
            self.assertEqual(int(r.request("K", "/lists/12/")), order.index("/lists/12/1/key"))
            self.assertEqual(int(r.request("K", "/lists/3")), len(order))
            self.assertEqual(int(r.request("K", "/entries/1/")), 0)
        finally:
            r.close()

    def test_incomplete_file_is_rejected(self):
        out = self.tmp / "partial.stream"
        h = Helper(self.exe, "write", out)
        self.assertEqual(h.request("W", record("/a", 1)), b"OK")
        h.proc.kill()
        h.proc.wait()
        h.proc.stdin.close()
        h.proc.stdout.close()
        self.assertFalse(out.exists())
        r = Helper(self.exe, "read", Path(str(out) + ".tmp"))
        reply = r.request("S")
        self.assertTrue(reply.startswith(b"ERR:"), reply)

    def test_bad_record_reports_error(self):
        out = self.tmp / "bad.stream"
        h = Helper(self.exe, "write", out)
        reply = h.request("W", "W2:/aZ")
        self.assertTrue(reply.startswith(b"ERR:"), reply)
        h.request("A")
        h.close()
        self.assertFalse(out.exists())


class ShippedBinariesTest(unittest.TestCase):
    """The Windows shim and helper ship at the repository root for Gaia."""

    ROOT = Path(__file__).resolve().parents[2]

    def manifest(self) -> dict:
        return json.loads((self.ROOT / "tools/savestream/shipped.json").read_text())

    def test_root_binaries_match_the_manifest(self):
        import hashlib
        for name, digest in self.manifest()["files"].items():
            data = (self.ROOT / name).read_bytes()
            self.assertEqual(hashlib.sha256(data).hexdigest(), digest, name)

    def test_sources_match_the_shipped_build(self):
        import hashlib
        for name, digest in self.manifest()["sources"].items():
            data = (self.ROOT / "tools/savestream/src" / name).read_bytes()
            self.assertEqual(hashlib.sha256(data).hexdigest(), digest,
                             f"{name} changed: rebuild with build.sh windows, re-ship the root binaries and update shipped.json")

    def test_rebuild_reproduces_the_shipped_binaries(self):
        # Without mingw-w64 this only checks the manifest above; with it, a
        # source change that was not rebuilt and re-shipped fails here.
        import hashlib
        import shutil
        import subprocess
        if not (shutil.which("i686-w64-mingw32-gcc") and shutil.which("x86_64-w64-mingw32-gcc")):
            # The offline baseline counts skips as failures. The source hash
            # test above already forces a re-ship; the rebuild needs mingw.
            return
        subprocess.run(["bash", str(self.ROOT / "tools/savestream/build.sh"), "windows"], check=True, stdout=subprocess.DEVNULL)
        built = self.ROOT / "tools/savestream/bin/windows"
        for name, digest in self.manifest()["files"].items():
            self.assertEqual(hashlib.sha256((built / name).read_bytes()).hexdigest(), digest,
                             f"{name}: rebuild differs; copy bin/windows/{name} to the root and update shipped.json")


if __name__ == "__main__":
    unittest.main()
