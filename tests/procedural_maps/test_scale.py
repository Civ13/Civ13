"""Generation at every size: the shortcuts that make a large map affordable
give exactly the results of the slow way, and a land may not outgrow what a
world has been measured to hold."""
import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from tools.procedural_maps import land
from tools.procedural_maps.bundle import verify_bundle, write_bundle
from tools.procedural_maps.configuration import port_surface_preset
from tools.procedural_maps.dmm_export import project
from tools.procedural_maps.generator import generate
from tools.procedural_maps.io import new_output
from tools.procedural_maps.validator import (MAX_SIDE, canonical_hash, remembered, stable_u64, unchanged,
                                            validate)


def slow_draw(*parts):
    payload = json.dumps(list(parts), ensure_ascii=True, separators=(",", ":")).encode("ascii")
    return int.from_bytes(hashlib.sha256(payload).digest()[:8], "big")


def slow_hash(document):
    return hashlib.sha256(json.dumps(document, sort_keys=True, separators=(",", ":"), allow_nan=False).encode()).hexdigest()


def land_template(width, height, **changes):
    t = {"biome": "GRASSLAND", "land_type": "COASTAL_PLAIN", "size": "TINY", "width": width, "height": height,
         "coast": ["S"], "seed": "scale:1", "features": {"ridges": 0},
         "resources": {"ore": "fair", "ores": [], "rare": [], "fertility": "fair", "game": []}}
    t.update(changes)
    return t


class DrawTests(unittest.TestCase):
    def test_the_fast_draw_is_the_json_framed_draw(self):
        for seed in ("ports-0", 'quote"and\\slash', "x" * 128):
            for stage in ("coast", "start-rank", 'odd "stage"'):
                for x, y, slot in ((0, 0, 0), (1279, 1279, 31), (-3, 7, 2 ** 40), (12, 0, 5)):
                    args = (seed, "surface-offline/0.2.0", "abstract-survival-catalog/1", "SURFACE-offline/2:ab", stage,
                            "SURFACE", x, y, slot)
                    self.assertEqual(slow_draw(*args), stable_u64(*args), args)

    def test_values_that_are_not_plain_integers_keep_the_json_framing(self):
        args = ("s", "a", "c", "p", "stage", "SURFACE")
        self.assertEqual(slow_draw(*args, True, 2, 0), stable_u64(*args, True, 2, 0))
        self.assertNotEqual(stable_u64(*args, 1, 2, 0), stable_u64(*args, True, 2, 0))


class UnchangedTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.result = generate(port_surface_preset("ports-0", 64, 80))
        cls.doc = cls.result["document"]

    def test_results_inside_the_block_equal_the_full_checks(self):
        errors, digest, layout = validate(self.doc), slow_hash(self.doc), project(self.doc)
        self.assertIsNone(remembered(self.doc))
        with unchanged(self.doc):
            self.assertEqual(errors, validate(self.doc))
            self.assertEqual(digest, canonical_hash(self.doc))
            first = project(self.doc)
            self.assertEqual(layout, first)
            first[(1, 1, 1)] = "changed by a caller"
            self.assertEqual(layout, project(self.doc), "each caller gets its own layout")
            validate(self.doc).append("changed by a caller")
            self.assertEqual(errors, validate(self.doc))
        self.assertIsNone(remembered(self.doc))

    def test_only_the_exact_object_is_remembered(self):
        twin = json.loads(json.dumps(self.doc))
        twin["width"] = 3
        with unchanged(self.doc, [], canonical_hash(self.doc)):
            self.assertTrue(validate(twin))
            self.assertNotEqual(canonical_hash(self.doc), canonical_hash(twin))

    def test_a_broken_document_is_still_refused_inside_the_block(self):
        broken = json.loads(json.dumps(self.doc))
        broken["layers"]["SURFACE"]["cells"][3][3]["terrain"] = "LAVA"
        with unchanged(broken):
            self.assertTrue(validate(broken))
            with self.assertRaises(ValueError):
                project(broken)

    def test_the_reserve_plane_reads_the_same_shared_or_copied(self):
        copied = json.loads(json.dumps(self.doc))
        self.assertEqual(self.doc, copied)
        self.assertEqual(slow_hash(self.doc), slow_hash(copied))
        self.assertEqual(project(self.doc), project(copied))


class LightBundleTests(unittest.TestCase):
    def test_a_light_bundle_keeps_the_manifest_and_preview_only(self):
        result = generate(port_surface_preset("ports-0", 64, 80))
        with tempfile.TemporaryDirectory() as tmp:
            full = write_bundle(new_output(Path(tmp) / "full", True), result["document"], result["manifest"], fresh=True)
            light = write_bundle(new_output(Path(tmp) / "light", True), result["document"], result["manifest"], fresh=True,
                                 light=True)
            self.assertEqual({"preview.png", "seed.manifest.json"}, {p.name for p in (Path(tmp) / "light").iterdir()})
            self.assertEqual(full["ir_sha256"], light["ir_sha256"])
            self.assertEqual(full["files"]["map.dmm"], light["dmm_sha256"])
            self.assertEqual((Path(tmp) / "full" / "seed.manifest.json").read_bytes(),
                             (Path(tmp) / "light" / "seed.manifest.json").read_bytes())
            self.assertEqual("VERIFIED_OFFLINE_ONLY", verify_bundle(Path(tmp) / "full")["status"])
            with self.assertRaises(OSError):
                verify_bundle(Path(tmp) / "light")

    def test_a_land_is_the_same_map_with_either_bundle(self):
        with tempfile.TemporaryDirectory() as tmp:
            light = land.build_land(land_template(96, 96), Path(tmp) / "light")
            full = land.build_land(land_template(96, 96), Path(tmp) / "full", full_bundle=True)
            self.assertEqual(light["dmm_sha256"], full["dmm_sha256"])
            self.assertFalse((Path(tmp) / "light" / "bundle" / "map.ir.json").exists())
            self.assertTrue((Path(tmp) / "light" / "bundle" / "preview.png").is_file())
            self.assertEqual("VERIFIED_OFFLINE_ONLY", verify_bundle(Path(tmp) / "full" / "bundle")["status"])


class LandBudgetTests(unittest.TestCase):
    def test_a_land_fits_the_measured_world(self):
        self.assertEqual([], land.template_errors(land_template(724, 724)))
        self.assertEqual([], land.template_errors(land_template(MAX_SIDE, 400)))
        for width, height in ((725, 725), (MAX_SIDE, 420), (1132, 920)):
            problems = land.template_errors(land_template(width, height))
            self.assertTrue(any("measured" in p for p in problems), (width, height, problems))
        self.assertTrue(land.template_errors(land_template(MAX_SIDE + 1, 64)))
        self.assertTrue(land.template_errors(land_template("724", 724)))

    def test_every_chart_size_class_fits_at_its_largest(self):
        from tools.transfer_storage import world_chart as wc
        for size, (width, height) in wc.SIZE_TILES.items():
            t = land_template(int(width * 1.15), int(height * 1.15), size=size)
            self.assertEqual([], land.template_errors(t), size)

    def test_a_wide_land_builds(self):
        # Far from square and past the old 512 limit on one side.
        with tempfile.TemporaryDirectory() as tmp:
            report = land.build_land(land_template(600, 64), Path(tmp) / "wide")
            self.assertEqual((600, 64), (report["width"], report["height"]))


if __name__ == "__main__":
    unittest.main()
