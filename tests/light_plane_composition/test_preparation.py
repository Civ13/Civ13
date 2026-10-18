import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("plane_runner", Path(__file__).with_name("run.py"))
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class Preparation(unittest.TestCase):
    def test_exact_source_and_controls(self):
        expected = (ROOT / runner.PLANE).read_text()
        self.assertEqual(runner.prepare()["production.dm"], expected)
        for control, replacement in (("bypass", "FALSE"), ("ordinary", "TRUE")):
            self.assertEqual(runner.prepare(control)["production.dm"], expected.replace(
                "mymob && mymob.see_invisible >= INVISIBILITY_LEVEL_TWO", replacement))

    def test_mode_refresh_order(self):
        life = (ROOT / "code/game/mob/living/life.dm").read_text()
        self.assertIn("handle_hud_icons()\n\thandle_vision()\n\tupdate_lighting_plane()", life)
        ghost = (ROOT / "code/game/mob/observer/ghost/ghost.dm").read_text()
        self.assertIn("\tupdate_lighting_plane()\n\tupdateghostimages()", ghost)
        human = (ROOT / "code/game/mob/living/carbon/human/human_life.dm").read_text()
        self.assertIn("species.handle_vision(src)", human)
        self.assertIn("\tif (!..())\n\t\treturn", human)

    def test_mask_and_authority_boundary(self):
        source = (ROOT / "code/modules/lighting/lighting_overlay.dm").read_text()
        self.assertIn("blend_mode\t   = BLEND_OVERLAY", source)
        self.assertIn("\tblend_mode = BLEND_OVERLAY\n\t#endif", source)
        plane = runner.prepare()["production.dm"]
        self.assertNotIn("SEE_TURFS", plane)
        self.assertNotIn("SEE_OBJS", plane)
        self.assertNotIn("client.images", plane)
        self.assertIn("mouse_opacity = 0", plane)


if __name__ == "__main__":
    unittest.main()
