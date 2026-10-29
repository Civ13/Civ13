"""Prepare production native packets without compiling or launching an engine."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
RUNNER = ROOT / "tests/world_save/run-durable-world.py"


class NativePacketTests(unittest.TestCase):
    def test_positive_and_named_controls_prepare_without_native(self):
        production = ROOT / "code/modules/persistence/functions.dm"
        original = production.read_bytes()
        for control in (None, "year-helper", "year-load", "year-order"):
            with self.subTest(control=control):
                command = [sys.executable, str(RUNNER), "--prepare-only", "--persistence-year"]
                if control:
                    command += ["--negative-control", control]
                result = subprocess.run(command, cwd=ROOT, capture_output=True,
                                        text=True, timeout=30, check=True)
                output = Path(result.stdout.split("Retained evidence: ", 1)[1].splitlines()[0])
                receipt = json.loads((output / "receipt.json").read_text())
                self.assertTrue(receipt["prepared_only"])
                self.assertEqual(receipt["negative_control"], control)
                self.assertEqual(receipt["production_hashes"]["code/modules/persistence/functions.dm"],
                                 hashlib.sha256(original).hexdigest())
                probe = next(output.glob("*_probe.dm")).read_text()
                self.assertIn("/proc/persistence_year_startup()", probe)
                self.assertIn('config.allowedgamemodes == "PERSISTENCE"', probe)
                self.assertIn("operator.persistent()", probe)
                self.assertIn("ticker.loadmap()", probe)
                self.assertIn("persistence_year_disk(2)", probe)
                self.assertIn("persistence_year_disk(1)", probe)
                self.assertIn('global.game_id = "persistence-year-native-fixture"', probe)
                self.assertIn('map.ensure_node_entry("A", "fixture-node")', probe)
                self.assertIn('map.set_prototype_submitted("A", "fixture-node")', probe)
                self.assertNotIn("/world/proc/unused_durable_startup", probe)
                self.assertFalse(list(output.glob("*.dmb")))
                self.assertFalse((output / "daemon.log").exists())
                self.assertEqual(production.read_bytes(), original)
                copies = list(output.glob("*_2.dm"))
                self.assertEqual(len(copies), int(control is not None))
                if copies:
                    source = copies[0].read_text()
                    if control == "year-helper":
                        self.assertIn("if (TRUE)\n\t\treturn", source)
                    elif control == "year-load":
                        self.assertNotIn("map.apply_persistence_age_floor()", source)
                    else:
                        self.assertIn("map.apply_persistence_age_floor()\n\t\tmap_storage.restore_durable_world()", source)


if __name__ == "__main__":
    unittest.main()
