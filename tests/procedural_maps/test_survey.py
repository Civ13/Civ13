import contextlib
import io
import json
import tempfile
import unittest
from pathlib import Path

from tools.procedural_maps import survey
from tools.procedural_maps.configuration import barren_surface_preset, preset
from tools.procedural_maps.generator import generate
from tools.procedural_maps.bundle import write_bundle

ROOT = Path(__file__).resolve().parents[2]
SHIPPED = ROOT / "config" / "space" / "survey" / "barren.json"


def bundle(config, folder):
    r = generate(config)
    if r["document"] is None:
        raise AssertionError(r["reasons"])
    write_bundle(folder, r["document"], r["manifest"], preview=False, fresh=True)
    return r["document"]


def cell(terrain="PLAIN", water="NONE"):
    return {"terrain": terrain, "water": water}


class SurveyMapTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.folder = Path(cls.tmp.name) / "barren"
        cls.folder.mkdir()
        cls.doc = bundle(barren_surface_preset("barren-t", 64, 80), cls.folder)

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_classes(self):
        self.assertEqual(survey.ICE, survey.classify(cell(water="LAKE")))
        self.assertEqual(survey.ICE, survey.classify(cell("MOUNTAIN", "SEA")))
        self.assertEqual(survey.CHANNEL, survey.classify(cell(water="RIVER")))
        self.assertEqual(survey.RIDGE, survey.classify(cell("ROCK")))
        self.assertEqual(survey.PLAIN, survey.classify(cell()))

    def test_majority_wins_and_ties_favour_the_hazard(self):
        plain, ridge = cell(), cell("MOUNTAIN")
        row_a = [plain, plain, ridge, ridge] * 4
        row_b = [plain] * 16
        doc = {"profile": "SURFACE", "width": 16, "height": 16,
               "layers": {"SURFACE": {"cells": [row_a, row_b] * 8}}}
        rows = survey.survey_rows(doc, 2)
        # Each 2x2 cell holds 3 plains + 1 ridge or 2 + 2: the tie goes to the ridge.
        self.assertEqual([".^" * 4] * 8, rows)

    def test_build_is_deterministic_and_rows_run_south_to_north(self):
        data = survey.build(self.folder)
        self.assertEqual(data, survey.build(self.folder))
        self.assertEqual(survey.SCHEMA, data["schema"])
        self.assertEqual((12, 16), (data["width"], data["height"]))
        cells = self.doc["layers"]["SURFACE"]["cells"]
        expected = survey.survey_rows(self.doc)
        self.assertEqual(expected, data["rows"])
        self.assertTrue(all(set(r) <= set(survey.TIE_ORDER) for r in data["rows"]))
        self.assertEqual(len(cells) // survey.CELL_TILES, len(data["rows"]))

    def test_refusals(self):
        with self.assertRaisesRegex(ValueError, "SURVEY_CELL_TILES"):
            survey.survey_rows(self.doc, 0)
        with self.assertRaisesRegex(ValueError, "SURVEY_SIZE"):
            survey.survey_rows(self.doc, 16)
        with self.assertRaisesRegex(ValueError, "SURVEY_PROFILE"):
            survey.survey_rows(dict(self.doc, profile="OCEANIC"))
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaisesRegex(ValueError, "json"):
                survey.write(self.folder, Path(tmp) / "map.txt")
            existing = Path(tmp) / "map.json"
            existing.write_text("{}", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "exists"):
                survey.write(self.folder, existing)
            self.assertEqual("{}", existing.read_text(encoding="utf-8"))

    def test_cli_writes_the_survey(self):
        from tools.procedural_maps.__main__ import main
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "survey.json"
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(0, main(["survey", str(self.folder), "--out", str(out)]))
                self.assertEqual(2, main(["survey", str(self.folder), "--out", str(out)]))
            self.assertEqual(survey.build(self.folder), json.loads(out.read_text(encoding="utf-8")))

    def test_check_matches_only_its_own_bundle(self):
        from tools.procedural_maps.__main__ import main
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "barren.json"
            survey.write(self.folder, out)
            self.assertTrue(survey.check(self.folder, out)["matches"])
            data = json.loads(out.read_text(encoding="utf-8"))
            data["ir_sha256"] = "0" * 64
            other = Path(tmp) / "other.json"
            other.write_text(json.dumps(data), encoding="utf-8")
            self.assertFalse(survey.check(self.folder, other)["matches"])
            junk = Path(tmp) / "junk.json"
            junk.write_text("{}", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "SURVEY_SCHEMA"):
                survey.check(self.folder, junk)
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(0, main(["survey-check", str(self.folder), "--survey", str(out)]))
                self.assertEqual(1, main(["survey-check", str(self.folder), "--survey", str(other)]))
                self.assertEqual(2, main(["survey-check", str(self.folder), "--survey", str(junk)]))

    def test_cavern_bundles_are_refused(self):
        c = preset("UNDERGROUND_CAVERN", "cave-s")
        c["dimensions"].update(width=64, height=80)
        c["starts"]["count"] = 4
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp) / "cave"
            folder.mkdir()
            bundle(c, folder)
            with self.assertRaisesRegex(ValueError, "SURVEY_PROFILE"):
                survey.build(folder)


class ShippedSurveyMapTests(unittest.TestCase):
    """config/space/survey/barren.json is what the mission console reads."""

    def test_shipped_map_is_well_formed(self):
        data = json.loads(SHIPPED.read_text(encoding="utf-8"))
        self.assertEqual(survey.SCHEMA, data["schema"])
        self.assertEqual((40, 40), (data["width"], data["height"]))
        self.assertEqual(40, len(data["rows"]))
        self.assertTrue(all(len(r) == 40 and set(r) <= set(survey.TIE_ORDER) for r in data["rows"]))
        plains = sum(r.count(survey.PLAIN) for r in data["rows"])
        self.assertGreater(plains, 100)
        for mark in (survey.CHANNEL, survey.ICE, survey.RIDGE):
            self.assertTrue(any(mark in r for r in data["rows"]), mark)

    def test_shipped_map_matches_the_barren_preset(self):
        data = json.loads(SHIPPED.read_text(encoding="utf-8"))
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp) / "barren"
            folder.mkdir()
            bundle(barren_surface_preset(data["seed"]), folder)
            self.assertEqual(data, survey.build(folder))
            self.assertTrue(survey.check(folder, SHIPPED)["matches"])


if __name__ == "__main__":
    unittest.main()
