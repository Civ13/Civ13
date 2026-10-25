"""Synthetic exact-order controls; no compiler, daemon or socket execution."""
import copy
import json
from pathlib import Path
import unittest
from unittest.mock import patch

from oracle import expected, inventory, verify_result
from plan import PHASES, PROFILES, TOTAL_WALL_SECONDS, OUTPUT_LIMITS
from test_proposal import BINDING, evidence


class UprootingOracleTests(unittest.TestCase):
    def test_exact_two_stage_order_and_preserved_baseline(self):
        rows = inventory()['roundtrip']
        stage = ['nonshovel tool preserves seedling state'] * 10 + [
            'shovel uprooting retires tree processing',
            'uprooting returns no wood or seeds'] * 11
        self.assertEqual(rows[1:65], stage * 2)
        self.assertEqual(rows[0], 'fixture has no open port')
        self.assertEqual(rows[65], 'planting creates seedling and spends exactly one seed')
        self.assertIn('mature tree uses existing seven-log destruction', rows[65:])
        self.assertEqual(sum(len(expected('baseline', mode)) for mode in inventory()), 112)
        self.assertTrue(all(row['ok'] == 1 for row in expected('baseline', 'roundtrip')))

    def test_uprooting_rejects_first_hatchet_only(self):
        self.assertEqual(expected('uprooting', 'roundtrip'), [
            {'name': 'fixture has no open port', 'ok': 1},
            {'name': 'nonshovel tool preserves seedling state', 'ok': 0}])
        result, log = evidence('uprooting')
        self.assertEqual(verify_result(BINDING, 'uprooting', 'roundtrip', result, log)['assertions'], 2)
        for index in (2, 10, 33, 42):
            changed = copy.deepcopy(result)
            changed['assertions'] = expected('baseline', 'roundtrip')[:index + 1]
            changed['assertions'][-1]['ok'] = 0
            changed_log = '\n'.join('TREE1688_ASSERT ' + json.dumps(r) for r in changed['assertions'])
            changed_log += '\nTREE1688_RESULT uprooting:roundtrip\n'
            with self.subTest(index=index), self.assertRaises(ValueError):
                verify_result(BINDING, 'uprooting', 'roundtrip', changed, changed_log)

    def test_uprooting_prefix_drift_fails_closed(self):
        for index, replacement in ((0, 'other'), (1, 'other'), (2, 'other')):
            rows = copy.deepcopy(inventory())
            rows['roundtrip'][index] = replacement
            with self.subTest(index=index), patch('oracle.inventory', return_value=rows):
                with self.assertRaises(ValueError):
                    expected('uprooting', 'roundtrip')

    def test_old_controls_still_include_successful_uprooting_prefix(self):
        for variant in ('clock', 'duration', 'payment'):
            rows = expected(variant, 'roundtrip')
            self.assertGreater(len(rows), 65)
            self.assertTrue(all(r['ok'] == 1 for r in rows[:65]))
            self.assertEqual(sum(r['ok'] == 0 for r in rows), 1)
            self.assertEqual(rows[-1]['ok'], 0)

    def test_fixed_extra_phases_preserve_limits(self):
        self.assertEqual(len(PHASES), 12)
        self.assertEqual(PHASES[-2:], (
            ('uprooting-compile', 'compiler', 'uprooting', None),
            ('uprooting-roundtrip', 'daemon', 'uprooting', 'roundtrip')))
        self.assertEqual(TOTAL_WALL_SECONDS, 1200)
        self.assertEqual(OUTPUT_LIMITS['aggregate_evidence_bytes'], 2 * 1024**3)
        self.assertEqual(PROFILES['compiler']['wall_seconds'], 180)
        self.assertEqual(PROFILES['daemon']['wall_seconds'], 45)


if __name__ == '__main__':
    unittest.main()
