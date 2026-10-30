"""Offline headroom fault-packet contracts, not native interleaving evidence."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]

def load(name):
    spec = importlib.util.spec_from_file_location('headroom_test_' + name, HERE / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

fixture = load('headroom_fixture')


class HeadroomSourceTests(unittest.TestCase):
    def test_exact_nine_cases_and_no_time_limit_expansion(self):
        self.assertEqual(len(fixture.SCENARIOS), 9)
        self.assertEqual(len(set(fixture.SCENARIOS)), 9)
        self.assertIn('headroom-parent-closed', fixture.SCENARIOS)
        runner = (HERE / 'correctness.py').read_text()
        self.assertIn('default=240', runner)
        self.assertIn('case_seconds=90', runner)
        self.assertIn('rss_mib=1024', runner)

    def test_packet_taps_preserve_real_sleep_and_production_source(self):
        path = ROOT / 'code/modules/persistence/saving.dm'
        original = path.read_text()
        packet = fixture.instrument_headroom(original)
        self.assertEqual(path.read_text(), original)
        self.assertEqual(packet.count('sleep(world.tick_lag)'), original.count('sleep(world.tick_lag)'))
        self.assertEqual(packet.count('fixture_headroom_before_wait(A, caller)'), 1)
        self.assertEqual(packet.count('fixture_force_headroom(A)'), 1)
        self.assertEqual(packet.count('fixture_headroom_nonprogress()'), 1)
        self.assertNotIn('world.tick_usage =', packet)
        capture = packet.split('/map_storage/proc/capture_moving_save_root(')[1]
        self.assertLess(capture.index('fixture_headroom_before_wait'), capture.index('sleep(world.tick_lag)'))
        self.assertLess(capture.index('sleep(world.tick_lag)'), capture.index('var/savefile/staged = new'))
        self.assertLess(capture.index('require_export_frame(caller)'), capture.index('var/savefile/staged = new'))
        with self.assertRaises(ValueError):
            fixture.instrument_headroom(original.replace('sleep(world.tick_lag)', 'sleep(0)'))
        with self.assertRaises(ValueError):
            fixture.instrument_headroom(packet)

    def test_probe_injection_is_armed_once_and_ownership_checked(self):
        probe = (HERE / 'probe.dm').read_text()
        self.assertIn('armed && fixture_is_headroom() && A == subject && !headroom_waits', probe)
        self.assertIn('if(!fixture_force_headroom(A)) return', probe)
        self.assertIn('map_storage.moving_save_chunk || map_storage.saving_references["\\ref[A]"]', probe)
        self.assertIn('caller.active = FALSE', probe)
        self.assertIn('new /turf(caller.source)', probe)
        self.assertIn('headroom_waits != 1', probe)
        self.assertIn('found_x != expected_x', probe)
        self.assertIn('!fixture_is_headroom() && !moving_save_chunk', probe)
        for forbidden in ('world.tick_usage =', 'world.tick_usage +='):
            self.assertNotIn(forbidden, probe)
        for scenario in fixture.SCENARIOS[1:]:
            self.assertIn(scenario, probe)

    def test_only_dedicated_packet_is_mutated_and_hash_receipt_identifies_it(self):
        correctness = load('correctness')
        with tempfile.TemporaryDirectory() as directory, patch('subprocess.Popen', side_effect=AssertionError('No native execution')):
            out = Path(directory) / 'packet'
            self.assertEqual(correctness.main(['--output', str(out)]), 0)
            name = 'code/modules/persistence/saving.dm'
            self.assertEqual((out / 'positive-source' / name).read_bytes(), (ROOT / name).read_bytes())
            self.assertIn('fixture_headroom_before_wait', (out / 'headroom-source' / name).read_text())
            receipt = json.loads((out / 'headroom-source/receipt.json').read_text())
            self.assertTrue(receipt['headroom_injection'])
            self.assertEqual(len(receipt['headroom_helper_sha256']), 64)
            self.assertNotEqual(receipt['sources'][name], json.loads((out / 'positive-source/receipt.json').read_text())['sources'][name])


if __name__ == '__main__': unittest.main()
