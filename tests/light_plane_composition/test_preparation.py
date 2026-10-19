import hashlib
import json
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

    def test_render_evidence_binds_source(self):
        evidence = json.loads(Path(__file__).with_name("render-results.json").read_text())
        self.assertEqual(len(evidence["pairs"]), 15)
        for name, digest in evidence["canonical_lf_sources_sha256"].items():
            self.assertEqual(hashlib.sha256((Path(__file__).parent / "rejected" / (Path(name).name + ".txt")).read_text().encode()).hexdigest(), digest)

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
        self.assertIn("blend_mode\t   = BLEND_MULTIPLY", source)
        self.assertIn("blend_mode = LIGHTING_COMPOSITION_V2 ? BLEND_OVERLAY : BLEND_MULTIPLY", source)
        plane = runner.prepare()["production.dm"]
        self.assertNotIn("SEE_TURFS", plane)
        self.assertNotIn("SEE_OBJS", plane)
        self.assertNotIn("client.images", plane)
        self.assertIn("mouse_opacity = 0", plane)
        self.assertIn("#define LIGHTING_COMPOSITION_V2 0", (ROOT / "code/__defines/_planes+layers.dm").read_text())
        self.assertIn("#define LIGHTING_COMPOSITION_V2 0", runner.prepare(enabled=False)["probe.dme"])

    def test_coverage_mutation_changes_only_creation_guard(self):
        ordinary = runner.prepare()
        control = runner.prepare("coverage")
        self.assertEqual(control["coverage.dm"], ordinary["coverage.dm"].replace(
            "\tif(needed && !retained)\n\t\tnew", "\tif(FALSE && !retained)\n\t\tnew"))
        self.assertEqual(control["production.dm"], ordinary["production.dm"])

    def test_lifecycle_and_persistence_seams_are_present(self):
        for name in ("code/game/turfs/turf_changing.dm", "code/modules/lighting/lighting_turf.dm",
                     "code/modules/lighting/lighting_overlay.dm", "code/modules/persistence/loading.dm"):
            self.assertIn("sync_fullbright_coverage()", (ROOT / name).read_text())
        self.assertIn("sync_fullbright_coverage_world()", (ROOT / "code/modules/lighting/lighting_system.dm").read_text())
        self.assertIn("ispath(type, /atom/movable/lighting_fullbright)", (ROOT / "code/modules/persistence/loading.dm").read_text())
        self.assertIn("should_save = FALSE", (ROOT / "code/modules/lighting/lighting_composition.dm").read_text())


if __name__ == "__main__":
    unittest.main()
