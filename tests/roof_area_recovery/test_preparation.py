"""Offline preparation/admission checks. These do not establish native recovery."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
RUNNER = ROOT / 'tests/world_save/run-durable-world.py'


class RoofAreaPreparation(unittest.TestCase):
    def test_native_execution_is_refused_before_preparation(self):
        result = subprocess.run([sys.executable, str(RUNNER), '--roof-areas'],
                                cwd=ROOT, capture_output=True, text=True, timeout=20)
        self.assertEqual(result.returncode, 2)
        self.assertIn('separately reviewed bounded runner/admission', result.stderr)
        self.assertNotIn('Retained evidence:', result.stdout)

    def test_other_modes_cannot_enable_execution(self):
        for mode in ('--lighting', '--wounds', '--persistence-year', '--dimension-bootstrap',
                     '--recovery-reconnect', '--lifecycle-shutdown', '--startup-only'):
            with self.subTest(mode=mode):
                result = subprocess.run([sys.executable, str(RUNNER), '--roof-areas', '--prepare-only', mode],
                                        cwd=ROOT, capture_output=True, text=True, timeout=20)
                self.assertEqual(result.returncode, 2)
                self.assertIn('cannot combine', result.stderr)

    def test_actual_preparer_retains_full_sources_without_engine_or_private_data(self):
        inputs = [ROOT / p for p in ('code/modules/persistence/loading.dm',
                  'code/modules/persistence/durable_world.dm', 'code/game/objects/roof_stuff.dm')]
        before = {p: p.read_bytes() for p in inputs}
        result = subprocess.run([sys.executable, str(RUNNER), '--roof-areas', '--prepare-only'],
                                cwd=ROOT, capture_output=True, text=True, timeout=40, check=True)
        output = Path(result.stdout.split('Retained evidence: ', 1)[1].splitlines()[0])
        receipt = json.loads((output / 'receipt.json').read_text())
        self.assertTrue(receipt['roof_areas'] and receipt['prepared_only'])
        fixture = ROOT / 'tests/roof_area_recovery/probe.dm'
        self.assertEqual(receipt['roof_probe_hash'], hashlib.sha256(fixture.read_bytes()).hexdigest())
        probe = next(output.glob('*_probe.dm')).read_text()
        self.assertIn('/world/OpenPort(port)\n\treturn ..("none")', probe)
        self.assertIn('/client/New()\n\tdel(src)', probe)
        self.assertNotIn('OpenPort(0)', probe)
        self.assertIn('var/obj/roof/wood/roof = new(locate(3,3,1))', probe)
        self.assertIn('map_storage.run_world_operation("save", op)', probe)
        self.assertIn('map_storage.run_world_operation("load", op)', probe)
        self.assertIn('map_storage.restore_durable_world()', probe)
        dme = (output / 'probe.dme').read_text()
        self.assertIn('code\\game\\objects\\roof_stuff.dm', dme)
        self.assertNotIn('.dmm"', dme)
        self.assertFalse(list(output.glob('*.dmb')))
        self.assertFalse(list(output.glob('*.rsc')))
        self.assertFalse((output / 'config').exists())
        self.assertFalse((output / 'map_saves').exists())
        for path, data in before.items():
            self.assertEqual(path.read_bytes(), data)

    def test_projection_precedes_both_validators_and_never_mutates_world(self):
        source = (ROOT / 'code/modules/persistence/loading.dm').read_text()
        plan = source.split('/map_storage/proc/prepare_saved_roof_areas(', 1)[1].split('/map_storage/proc/materialize_saved_roof_areas()', 1)[0]
        self.assertNotIn('new type', plan)
        self.assertNotIn('contents +=', plan)
        for guard in ('Ambiguous or multiply placed saved roof', 'Saved roof lacks scalar area metadata',
                      'Saved roof base area differs', 'Disabled saved roof changes area',
                      'Unsupported saved roof climate', 'Ambiguous current roof area identity'):
            self.assertIn(guard, plan)
        validate = source.split('/map_storage/proc/validate_world_save()', 1)[1]
        self.assertLess(validate.index('prepare_saved_roof_areas('), validate.index('validate_saved_value('))
        self.assertLess(validate.index('prepare_saved_roof_areas('), validate.index('validate_durable_world('))
        self.assertIn('if(!ispath(area_type, value["type"]))', validate)

    def test_materialization_precedes_recursive_import_and_keeps_strict_decode(self):
        source = (ROOT / 'code/modules/persistence/loading.dm').read_text()
        load = source.split('/map_storage/proc/load_world_contents(', 1)[1].split('// A failed preflight', 1)[0]
        self.assertLess(load.index('T.ChangeTurf('), load.index('materialize_saved_roof_areas()'))
        self.assertLess(load.index('materialize_saved_roof_areas()'), load.index('Load_Entry('))
        self.assertIn('!istype(T.loc, value["type"])', source)
        self.assertIn('existing_references[roof["entry"]] == ob', source)
        self.assertIn('Saved roof location changed during import', source)

    def test_native_fixture_has_real_alias_and_fail_closed_controls(self):
        probe = (ROOT / 'tests/roof_area_recovery/probe.dm').read_text()
        for mode in ('missing-roof', 'wrong-base', 'missing-scalar', 'disabled-roof',
                     'unrelated-area', 'duplicate-area'):
            self.assertIn(mode, probe)
        for check in ('Saved area references diverged', 'Nested area or roof alias lost',
                      'Saved list area key/alias diverged', 'Rejected preflight mutated',
                      'Actual roofs do not share the canonical climate area'):
            self.assertIn(check, probe)


if __name__ == '__main__':
    unittest.main()
