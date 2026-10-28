"""Lifecycle and source-only native packet checks; no compiler or game launches."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

from test_decay import ROOT, SOURCE, State, Construction, body
from construction_contract import CLOCK, HOOK, without_construction_hook

SPEC = importlib.util.spec_from_file_location("construction_prepare", Path(__file__).with_name("prepare.py"))
PREPARE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PREPARE)


class SourceTests(unittest.TestCase):
    def test_terminal_policy_dispatch_keeps_normal_destruction_and_debit_order(self):
        source = SOURCE.read_text()
        check = body(source, "/obj/proc/check_seasonal_construction()")
        self.assertNotIn("contents", check.split("var/damage =", 1)[1])
        self.assertLess(check.index("seasonal_construction_due = 0"), check.index("damage_seasonal_construction(damage)"))
        for prefix in ("/obj/covers", "/obj/roof"):
            damage = body(source, prefix + "/damage_seasonal_construction(damage)")
            self.assertIn("health -= damage", damage)
            self.assertIn("if (health <= 0)", damage)
            self.assertEqual(damage.count("qdel(src)"), 1)
            for bypass in ("Destroy(", "forceMove(", "contents", "loc ="):
                self.assertNotIn(bypass, damage)

    def test_legacy_parity_projection_rejects_missing_duplicate_moved_and_changed_hooks(self):
        source = (ROOT / "code/processes/abandoned_items.dm").read_text()
        legacy = without_construction_hook(source)
        for altered in (source.replace(HOOK, ''), source + HOOK,
                        source.replace(CLOCK + HOOK, HOOK + CLOCK),
                        source.replace('abandonment_season_changes++', 'abandonment_season_changes += 2')):
            with self.subTest(altered=altered[:40]), self.assertRaises(ValueError):
                without_construction_hook(altered)
        # Unrelated changes remain visible to the original full-file oracle.
        self.assertNotEqual(without_construction_hook(source + '// unrelated change\n'), legacy)

    def test_main_include_and_scheduler_registration(self):
        self.assertEqual((ROOT / "civ13.dme").read_text().count('code\\processes\\seasonal_construction.dm'), 1)
        self.assertIn("var/process/seasonal_construction/seasonal_construction = null",
                      (ROOT / "code/processes/__processes.dm").read_text())
        text = SOURCE.read_text()
        setup = body(text, "/process/seasonal_construction/setup()")
        self.assertIn("schedule_interval = 10 SECONDS", setup)
        self.assertIn("list(GAME_STATE_PLAYING)", setup)
        self.assertNotIn("spawn(", text)
        self.assertNotIn(" in world", text)
        self.assertNotIn(".Copy()", text)
        self.assertNotIn("Destroy()", body(text, "/obj/proc/check_seasonal_construction()"))

    def test_both_cover_definitions_and_roof_register_and_unregister(self):
        for filename, prefix in (("covers.dm", "/obj/covers"),
                                 ("covers_types/cover_walltypes.dm", "/obj/covers"),
                                 ("roof_stuff.dm", "/obj/roof")):
            source = (ROOT / "code/game/objects" / filename).read_text()
            self.assertIn("register_seasonal_construction()", body(source, prefix + "/New()"))
            # One historical definition has trailing whitespace on its declaration.
            source = source.replace("/Destroy()\t\t\t", "/Destroy()")
            self.assertIn("unregister_seasonal_construction()", body(source, prefix + "/Destroy()"))
        levels = (ROOT / "code/game/objects/building_levels.dm").read_text()
        for prefix in ("/obj/covers", "/obj/roof"):
            self.assertIn("unregister_seasonal_construction()", body(levels, prefix + "/Del()"))

    def test_saved_debt_and_runtime_exclusions_forward_to_parents(self):
        source = SOURCE.read_text()
        runtime = body(source, "/obj/persistence_runtime_var(key)")
        for key in ("seasonal_construction_last", "seasonal_construction_index"):
            self.assertIn('"' + key + '"', runtime)
        self.assertIn("return ..()", runtime)
        for prefix in ("/obj/covers", "/obj/roof"):
            before = body(source, prefix + "/before_save()")
            self.assertIn("accrue_seasonal_construction()", before)
            self.assertNotIn("damage_seasonal_construction", before)
            self.assertIn("return ..()", before)
            after = body(source, prefix + "/after_load()")
            self.assertIn("..()", after)
            self.assertLess(after.index("unregister_seasonal_construction()"), after.index("\tregister_seasonal_construction()"))
        roof = body((ROOT / "code/game/objects/building_levels.dm").read_text(), "/obj/roof/get_saved_vars()")
        self.assertIn('"seasonal_construction_due"', roof)
        self.assertIn(". = ..()", roof)
        metadata = body((ROOT / "code/game/objects/map_metadata/_map_metadata.dm").read_text(),
                        "/obj/map_metadata/persistence_runtime_var(var/key)")
        self.assertIn('"construction_last_season"', metadata)
        self.assertIn("return ..(key)", metadata)

    def test_existing_debris_increment_is_preserved_before_separate_hook(self):
        source = (ROOT / "code/processes/abandoned_items.dm").read_text()
        clock = body(source, "/obj/map_metadata/proc/record_abandonment_season_change(advance_decay = TRUE)")
        self.assertEqual(clock.strip(), "if (advance_decay && src == map)\n\t\tabandonment_season_changes++\n\trecord_construction_season_change(advance_decay)")
        request = body(source, "/proc/season_decay_requested(force, advance_decay)")
        self.assertIn("return isnull(advance_decay) ? !force : advance_decay", request)

    def test_pairing_after_construction_removes_candidate_without_damage(self):
        s = State()
        roof = Construction(s, "/obj/roof/wood", 100)
        roof.building_pair_id = "modern-floor"
        s.transition()
        s.sweep()
        self.assertEqual((roof.health, roof.seasonal_construction_due, s.registry), (100, 0, []))

    def test_positive_and_declared_controls_prepare_without_any_native_outputs(self):
        original = SOURCE.read_bytes()
        for control in (None, *PREPARE.CONTROLS):
            with self.subTest(control=control), tempfile.TemporaryDirectory(prefix="civ13-construction-packet-") as directory:
                packet = PREPARE.prepare(directory, control)
                output = Path(directory)
                self.assertTrue(packet["prepared_only"])
                self.assertEqual(packet["control"], control)
                self.assertEqual(packet["contents_policy"], "normal destruction; no occupancy deferral")
                self.assertEqual(packet["production_hashes"]["code/processes/seasonal_construction.dm"],
                                 hashlib.sha256(original).hexdigest())
                self.assertFalse(list(output.glob("*.dmb")))
                self.assertFalse(list(output.glob("*.rsc")))
                self.assertFalse(list(output.glob("*.sav")))
                self.assertFalse(list(output.glob("*.log")))
                probe = (output / "probe.dm").read_text()
                self.assertIn("occupied construction postponed terminal destruction", probe)
                self.assertNotIn("contained objects were retired or debt consumed", probe)
                self.assertIn("tests/seasonal_construction/collapse_policy_contents.dm", packet["production_hashes"])
                self.assertIn("map_storage.BuildVarDirectory(F, O, 1)", probe)
                self.assertIn("map_storage.Load_Entry(F, ref, null, locate(5,5,1))", probe)
                self.assertIn("visibility = 0", probe)
                self.assertIn('/world/OpenPort(port)\n\treturn ..("none")', probe)
                self.assertIn("/client/New()\n\tdel(src)\n\treturn", probe)
                dme = (output / "probe.dme").read_text()
                self.assertNotIn('.dmm"', dme)
                for filename, expected in packet["generated_hashes"].items():
                    self.assertEqual(hashlib.sha256((output / filename).read_bytes()).hexdigest(), expected)
                self.assertEqual(json.loads((output / "receipt.json").read_text())["head_sha"], packet["head_sha"])
                if control:
                    mutated = output / packet["adapted_sources"]["code/processes/seasonal_construction.dm"]
                    self.assertIn(PREPARE.CONTROLS[control][1], mutated.read_text())
        self.assertEqual(SOURCE.read_bytes(), original)

    def test_historical_native_probe_remains_immutable(self):
        historical = ROOT / "tests/seasonal_construction/probe.dm"
        self.assertEqual(hashlib.sha256(historical.read_bytes()).hexdigest(),
                         "548f261090e707670b2ae77a6d5a7d0dc46683099e97f6256c1f3a5436f3254d")


if __name__ == "__main__":
    unittest.main()
