"""Offline source contracts for long sleeping sweeps and wake bursts; no BYOND runtime.

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
FLOORING = (ROOT / 'code/game/turfs/flooring/flooring_premade.dm').read_text(encoding='utf-8')


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


class SoilRecoveryWake(unittest.TestCase):
    # Gaia has ~134k dirt turfs. One sleeping spawn chain per turf cost about
    # 50 MB of closures and tokens for the whole round, and with a shared
    # 12000-12010 ds first wait they all woke in the same second (a 2.2 s stall
    # every 20 minutes). Depleted turfs now register with the shared
    # soil_recovery process; full turfs hold no recovery state at all.
    def setUp(self):
        self.recover = proc_body(FLOORING, '/turf/floor/dirt/proc/soil_nutrition_recover()')
        self.schedule = proc_body(FLOORING, '/turf/floor/dirt/proc/soil_recovery_schedule(delay)')
        self.process = (ROOT / 'code/processes/soil_recovery.dm').read_text(encoding='utf-8')

    def test_dirt_turfs_hold_no_sleeping_chain_or_token(self):
        self.assertNotIn('spawn(', self.recover)
        self.assertNotIn('spawn(', self.schedule)
        self.assertNotIn('/datum/soil_recovery_token', FLOORING)
        self.assertNotIn('soil_nutrition_recover()', proc_body(FLOORING, '/turf/floor/dirt/New()'))
        self.assertIn('soil_recovery_schedule()', proc_body(FLOORING, '/turf/floor/dirt/New()'))

    def test_only_depleted_soil_is_registered(self):
        self.assertIn('if (soil_nutrition >= max_soil_nutrition)\n\t\treturn', self.schedule)
        self.assertIn('soil_recovery_pending += src', self.schedule)
        self.assertIn('if (soil_nutrition >= max_soil_nutrition)\n\t\tsoil_recovery_unregister()', self.recover)

    def test_first_wait_is_spread_and_later_waits_keep_the_period(self):
        self.assertIn('delay = rand(1, rand(12000,12010))', self.schedule)
        self.assertIn('soil_recovery_schedule(rand(12000,12010))', self.recover)

    def test_process_drives_recovery_from_the_registry(self):
        self.assertIn('/process/soil_recovery/fire()', self.process)
        self.assertIn('world.time >= D.soil_recovery_deadline', self.process)
        self.assertIn('D.soil_nutrition_recover()', self.process)
        self.assertIn('var/process/soil_recovery/soil_recovery = null', (ROOT / 'code/processes/__processes.dm').read_text(encoding='utf-8'))
        self.assertIn('code\\processes\\soil_recovery.dm', (ROOT / 'civ13.dme').read_text(encoding='utf-8-sig'))

    def test_load_and_consumption_register_depleted_turfs(self):
        self.assertIn('soil_recovery_schedule()', proc_body(FLOORING, '/turf/floor/dirt/after_load()'))
        farming = (ROOT / 'code/game/objects/farming.dm').read_text(encoding='utf-8')
        self.assertIn('D.soil_recovery_schedule()', proc_body(farming, '/obj/structure/farming/plant/proc/soil_nutrition_proc()'))


if __name__ == '__main__':
    unittest.main()
