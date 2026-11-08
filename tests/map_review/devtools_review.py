"""Map and sprite review through the real byond-devtools CLI, on test_map_review's tiny repository.

Not an offline suite: it needs node and BYOND_DEVTOOLS (a byond-devtools checkout); the map
pictures and lint also need BYOND_BIN. The map-review and sprite-review workflows run it:

    BYOND_DEVTOOLS=<checkout> BYOND_BIN=<BYOND bin> python3 -B -m unittest tests/map_review/devtools_review.py
"""
import os
import shutil
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import test_map_review as fixture  # noqa: E402
from test_map_review import map_review, sprite_review  # noqa: E402

DEVTOOLS = os.environ.get("BYOND_DEVTOOLS", "")
BYOND_BIN = os.environ.get("BYOND_BIN", "")


class DevtoolsReview(fixture.ReviewRepo):
    @classmethod
    def setUpClass(cls):
        if not DEVTOOLS or not shutil.which("node"):
            raise RuntimeError("set BYOND_DEVTOOLS to a byond-devtools checkout and put node on PATH")
        super().setUpClass()

    def test_sprite_review_with_devtools(self):
        out = Path(self.tmp) / "sprite-out"
        text, broken = sprite_review.review(self.base, "HEAD", DEVTOOLS, out)
        self.assertEqual(broken, 1, text)
        self.assertIn("- **icons/broken.dmi**: could not be read:", text)
        self.assertIn("Not a PNG file", text)
        self.assertIn("- **icons/gone.dmi** (deleted): 1 removed", text)
        self.assertIn("- **icons/crate.dmi** (modified): 1 added, 1 changed; picture `icons/crate.dmi.png`", text)
        self.assertIn("  - `open`: changed", text)
        self.assertIn("  - `broken`: added", text)
        self.assertTrue((out / "icons/crate.dmi.png").read_bytes().startswith(b"\x89PNG"))
        self.assertTrue((out / "summary.md").is_file())

    def test_map_review_with_devtools(self):
        out = Path(self.tmp) / "map-out"
        text, broken = map_review.review(self.base, "HEAD", DEVTOOLS, out)
        self.assertEqual(broken, 0, text)
        self.assertIn("**maps/town.dmm** (modified): 1 changed tiles; z1: 1 tiles (x 2-2, y 2-2)", text)
        self.assertIn("**maps/new.dmm** (new map, 1x1x1)", text)
        self.assertIn("**maps/old_name.dmm -> maps/new_name.dmm** (renamed): 0 changed tiles", text)
        self.assertIn("Run with --byond for pictures and lint.", text)
        self.assertFalse((self.repo / map_review.BASE_DIR).exists())

    @unittest.skipUnless(BYOND_BIN, "BYOND_BIN is needed for map pictures and lint")
    def test_map_review_pictures_and_lint(self):
        out = Path(self.tmp) / "map-pictures"
        text, broken = map_review.review(self.base, "HEAD", DEVTOOLS, out, byond=BYOND_BIN, dme="test.dme")
        self.assertEqual(broken, 0, text)
        self.assertIn("  - z1 picture `maps/town.dmm.z1.png`: x 1-3, y 1-3", text)
        self.assertIn("new lint problem: `/obj/crate` var `nonsense_var`", text)
        self.assertTrue((out / "maps/town.dmm.z1.png").read_bytes().startswith(b"\x89PNG"))


if __name__ == "__main__":
    unittest.main()
