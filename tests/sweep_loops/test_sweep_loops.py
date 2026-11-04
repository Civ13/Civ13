"""Offline source contracts for long sleeping sweeps; no BYOND runtime.

A DM for-in loop over a large list that sleeps between batches pays a cost
proportional to the whole list each time it resumes, and world.tick_usage
does not see it. Measured on 516.1688 (300k entries, 20% tick gate): for-in
held the server ~44% behind real time; an index loop over the same list had
no drift. The day/night sweep must therefore index its snapshots.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/processes/time_of_day_change.dm').read_text(encoding='utf-8')


def proc_body(text, header):
    start = text.index(header)
    following = re.search(r'^/', text[start + len(header):], re.M)
    end = start + len(header) + following.start() if following else len(text)
    return text[start:end]


class DaylightSweep(unittest.TestCase):
    def setUp(self):
        self.body = proc_body(SOURCE, '/process/time_of_day_change/proc/apply_daylight(')

    def test_large_sweeps_do_not_use_sleeping_for_in_loops(self):
        for name in ('lighting_overlay_list', 'turfs'):
            with self.subTest(name=name):
                self.assertIsNone(re.search(r'for\s*\([^)]*\bin\s+' + name + r'\s*\)', self.body))

    def test_index_loops_walk_one_time_snapshots(self):
        self.assertIn('var/list/sweep_overlays = lighting_overlay_list.Copy()', self.body)
        self.assertIn('var/list/sweep_turfs = turfs.Copy()', self.body)
        self.assertIn('overlay_index <= sweep_overlays.len', self.body)
        self.assertIn('turf_index <= sweep_turfs.len', self.body)
        # The snapshot lists are not re-read from the live globals per step.
        loops = self.body.split('setup_lighting = TRUE', 1)
        self.assertNotIn('lighting_overlay_list[', self.body)
        self.assertNotIn('turfs[', loops[1].replace('sweep_turfs[', ''))

    def test_both_sweeps_keep_their_budget_and_revision_checks(self):
        self.assertEqual(self.body.count('if (environment_sweep_pause(++work))'), 2)
        self.assertEqual(self.body.count('if (revision != lighting_revision)'), 2)
        # Entries that are not turfs (or deleted overlays) are skipped, as the
        # typed for-in did, instead of raising mid-sweep.
        self.assertIn('if (!istype(T))', self.body)
        self.assertIn('if (LO)', self.body)


if __name__ == '__main__':
    unittest.main()
