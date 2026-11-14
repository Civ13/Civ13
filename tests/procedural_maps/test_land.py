"""Expedition lands: a world-chart template becomes a playable, biome-skinned
region map, the same one every time."""
import json
import tempfile
import unittest
from pathlib import Path

from tools.procedural_maps import land
from tools.procedural_maps.configuration import validate_config
from tools.procedural_maps.source_audit import parse_classic
from tools.transfer_storage import world_chart as wc


def template(biome="TEMPERATE_FOREST", land_type="COASTAL_PLAIN", size=96, coast=("S",)):
    return {
        "biome": biome, "land_type": land_type, "size": "TINY", "width": size, "height": size,
        "coast": list(coast), "seed": "test:1:2:r0",
        "features": {"rivers": 1, "lakes": 0, "ridges": 1, "caves": False},
        "resources": {"ore": "rich", "ores": ["iron"], "rare": [], "fertility": "poor", "game": ["deer"]},
    }


class LandConfigTests(unittest.TestCase):
    def test_every_chart_biome_has_a_skin_and_every_land_type_is_known(self):
        self.assertEqual(set(wc.BIOMES), set(land.BIOME_SKINS))
        self.assertEqual(set(wc.LAND_TYPES), set(land.LAND_TYPES))
        self.assertEqual(set(wc.SIZES), set(land.SIZES))
        self.assertTrue(land.verify_skin_types())

    def test_every_biome_and_land_type_gives_a_valid_config(self):
        for biome in land.BIOME_SKINS:
            for land_type in land.LAND_TYPES:
                t = template(biome, land_type, 200)
                c = land.land_config(t, 0)
                self.assertEqual([], validate_config(c), (biome, land_type))
                self.assertNotEqual(json.dumps(c, sort_keys=True), json.dumps(land.land_config(t, 1), sort_keys=True),
                                    "a retry uses another seed")

    def test_rolled_chart_templates_are_accepted(self):
        for x in range(40):
            biome = sorted(wc.BIOMES)[x % len(wc.BIOMES)]
            t = wc.roll_template("s", x, 4, 0, biome, ["E"])
            self.assertEqual([], land.template_errors(t), t)

    def test_bad_templates_are_refused(self):
        self.assertTrue(land.template_errors([]))
        for key, value in (("biome", "MOON"), ("land_type", "CASTLE"), ("width", 20), ("coast", []),
                           ("seed", ""), ("resources", {})):
            t = template()
            t[key] = value
            self.assertTrue(land.template_errors(t), key)
        with tempfile.TemporaryDirectory() as tmp:
            bad = template()
            bad["coast"] = ["UP"]
            with self.assertRaises(ValueError):
                land.build_land(bad, Path(tmp) / "out")

    def test_smaller_lands_get_more_ore_and_larger_more_forage(self):
        rich, poor = template(), template()
        poor["resources"] = dict(poor["resources"], ore="poor", fertility="rich")
        a, b = land.land_config(rich), land.land_config(poor)
        self.assertGreater(a["resources"]["density_per_1000_land_tiles"][0], b["resources"]["density_per_1000_land_tiles"][1])
        self.assertLess(a["vegetation"]["suitable_site_density_pct"][1], b["vegetation"]["suitable_site_density_pct"][0])


class BuildLandTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.t = template("DESERT")
        cls.report = land.build_land(cls.t, Path(cls.tmp.name) / "one")
        cls.again = land.build_land(cls.t, Path(cls.tmp.name) / "two")

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_the_same_template_builds_the_same_land(self):
        self.assertEqual(self.report["dmm_sha256"], self.again["dmm_sha256"])
        self.assertEqual((96, 96), (self.report["width"], self.report["height"]))
        self.assertEqual(land.LAND_VERSION, self.report["schema"])

    def test_the_land_wears_its_biome(self):
        text = (Path(self.tmp.name) / "one" / "land.dmm").read_text(encoding="utf-8")
        skin = land.BIOME_SKINS["DESERT"]
        _, layout, _ = parse_classic(text)
        surface = [recipe.split(",") for (x, y, z), recipe in layout.items() if z == 2]
        self.assertTrue(surface)
        self.assertTrue(all(skin["area"] in atoms and land.SURFACE_AREA not in atoms for atoms in surface))
        self.assertGreater(self.report["skin"]["ground swapped"], 0)
        self.assertEqual({"ores": ["iron"], "rare": [], "game": ["deer"]}, self.report["slot_world"])
        saved = json.loads((Path(self.tmp.name) / "one" / "land.json").read_text(encoding="utf-8"))
        self.assertEqual(self.report["dmm_sha256"], saved["dmm_sha256"])
        self.assertTrue((Path(self.tmp.name) / "one" / "bundle").is_dir())


if __name__ == "__main__":
    unittest.main()
