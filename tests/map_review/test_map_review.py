"""Map and sprite review (scripts/map_review.py, scripts/sprite_review.py) on a tiny git repository.

This offline suite checks the git and summary logic. devtools_review.py runs the same repository
through the real byond-devtools CLI (and BYOND for map pictures and lint); the map-review and
sprite-review workflows run it, so a broken review fails there before a real map or icon PR.
"""
import shutil
import struct
import subprocess
import sys
import tempfile
import unittest
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
import map_review  # noqa: E402
import sprite_review  # noqa: E402

DME = """#include "test.dm"
"""
CODE = """/area/test
/turf/floor
\ticon = 'icons/crate.dmi'
\ticon_state = "closed"
/obj/crate
\ticon = 'icons/crate.dmi'
\ticon_state = "open"
"""


def png_chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)


def dmi(states, size=4):
    """A DMI with one 1-dir, 1-frame state per (name, rgba) pair, size x size pixels each."""
    width = size * len(states)
    rows = b""
    for _ in range(size):
        rows += b"\x00" + b"".join(bytes(rgba) * size for _, rgba in states)
    description = "# BEGIN DMI\nversion = 4.0\n\twidth = %d\n\theight = %d\n" % (size, size)
    for name, _ in states:
        description += 'state = "%s"\n\tdirs = 1\n\tframes = 1\n' % name
    description += "# END DMI\n"
    return (b"\x89PNG\r\n\x1a\n"
            + png_chunk(b"IHDR", struct.pack(">IIBBBBB", width, size, 8, 6, 0, 0, 0))
            + png_chunk(b"zTXt", b"Description\x00\x00" + zlib.compress(description.encode()))
            + png_chunk(b"IDAT", zlib.compress(rows))
            + png_chunk(b"IEND", b""))


def dmm(rows):
    keys = '"a" = (/turf/floor,/area/test)\n"b" = (/obj/crate,/turf/floor,/area/test)\n'
    return keys + '\n(1,1,1) = {"\n' + "\n".join(rows) + '\n"}\n'


class ReviewRepo(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.mkdtemp(prefix="map-review-test-")
        cls.repo = Path(cls.tmp) / "repo"
        cls.repo.mkdir()
        cls.git("init", "-q", "-b", "master")
        cls.git("config", "user.email", "test@example.invalid")
        cls.git("config", "user.name", "test")
        cls.write("maps/town.dmm", dmm(["aaa", "aaa", "aaa"]))
        cls.write("maps/old_name.dmm", dmm(["aa", "aa"]))
        cls.write("icons/crate.dmi", dmi([("closed", (200, 100, 0, 255)), ("open", (100, 50, 0, 255))]))
        cls.write("icons/gone.dmi", dmi([("x", (1, 2, 3, 255))]))
        cls.write("test.dme", DME)
        cls.write("test.dm", CODE)
        cls.write(".gitignore", "*.dmb\n*.rsc\n*.int\n*.lk\n")
        cls.git("add", "-A")
        cls.git("commit", "-q", "-m", "base")
        cls.base = cls.git("rev-parse", "HEAD").strip()
        cls.write("maps/town.dmm", dmm(["aaa", "aba", "aaa"]))
        cls.write("maps/new.dmm", dmm(["b"]).replace("/obj/crate", "/obj/crate{nonsense_var = 1}"))
        cls.git("mv", "maps/old_name.dmm", "maps/new_name.dmm")  # unchanged content, so git pairs it as a rename
        cls.write("icons/crate.dmi", dmi([("closed", (200, 100, 0, 255)), ("open", (0, 50, 200, 255)), ("broken", (9, 9, 9, 255))]))
        cls.write("icons/broken.dmi", b"not a png")
        (cls.repo / "icons/gone.dmi").unlink()
        cls.git("add", "-A")
        cls.git("commit", "-q", "-m", "head")
        cls.saved_roots = map_review.ROOT, sprite_review.ROOT
        map_review.ROOT = sprite_review.ROOT = cls.repo

    @classmethod
    def tearDownClass(cls):
        map_review.ROOT, sprite_review.ROOT = cls.saved_roots
        shutil.rmtree(cls.tmp, ignore_errors=True)

    @classmethod
    def git(cls, *args):
        return subprocess.run(["git", *args], cwd=cls.repo, check=True, capture_output=True, text=True).stdout

    @classmethod
    def write(cls, rel, data):
        path = cls.repo / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data if isinstance(data, bytes) else data.encode())

    def test_changed_files_follow_renames_and_deletes(self):
        maps = sorted(map_review.changed_maps(self.base, "HEAD"))
        self.assertEqual(maps, [("A", "maps/new.dmm", "maps/new.dmm"), ("M", "maps/town.dmm", "maps/town.dmm"),
                                ("R", "maps/old_name.dmm", "maps/new_name.dmm")])
        icons = sorted(sprite_review.changed_icons(self.base, "HEAD"))
        self.assertEqual(icons, [("A", "icons/broken.dmi", "icons/broken.dmi"), ("D", "icons/gone.dmi", "icons/gone.dmi"),
                                 ("M", "icons/crate.dmi", "icons/crate.dmi")])

    def test_no_changes_says_so(self):
        fake = Path(self.tmp) / "fake-devtools"
        (fake / "src").mkdir(parents=True, exist_ok=True)
        (fake / "src" / "cli.js").write_text("", encoding="utf-8")
        text, broken = map_review.review("HEAD", "HEAD", str(fake), Path(self.tmp) / "none-maps")
        self.assertIn("No .dmi files changed.", sprite_review.review("HEAD", "HEAD", str(fake), Path(self.tmp) / "none-icons")[0])
        self.assertIn("No .dmm files changed.", text)
        self.assertEqual(broken, 0)
        with self.assertRaises(SystemExit):  # the CLI path is checked before anything runs
            sprite_review.review("HEAD", "HEAD", Path(self.tmp) / "missing", Path(self.tmp) / "none")
        with self.assertRaises(SystemExit):
            map_review.review("HEAD", "HEAD", Path(self.tmp) / "missing", Path(self.tmp) / "none")


if __name__ == "__main__":
    unittest.main()
