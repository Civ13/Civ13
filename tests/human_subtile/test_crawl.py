"""Bounded offline contracts and schedule oracle, not native acceptance."""
import math
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
MODULE = ROOT / 'code/game/mob/living/carbon/human/subtile_movement.dm'


class CrawlContracts(unittest.TestCase):
    def test_paid_schedule_has_progress_and_no_early_arrival(self):
        for distance in (2, 7, 16, 30, 32):
            count = math.ceil(distance / 2)
            for duration in (9, 13.5, 13.3, 35):
                due = [(i + 1) * duration / count for i in range(count)]
                actual = [math.ceil((t - 1e-9) / .5) * .5 for t in due]
                self.assertGreaterEqual(actual[-1], duration)
                self.assertLessEqual(actual[-1], duration + .5)
                self.assertEqual(sum(min(2, distance - i * 2) for i in range(count)), distance)
                if count > 1:
                    self.assertLess(actual[0], duration)
        source = MODULE.read_text()
        self.assertIn('due = start_time + i * duration / pulse_count', source)
        self.assertIn('while (due > world.time && valid(direction))', source)
        self.assertIn('while (world.time < end_time)', source)

    def test_admission_default_and_optout_use_existing_setter(self):
        source = MODULE.read_text()
        crawl = source[source.index('/mob/living/human/proc/human_subtile_crawl_move'):source.index('/mob/living/human/proc/set_human_subtile')]
        for guard in ('human_subtile_transaction || human_subtile_pulse', '!scrambling', '!human_subtile_crawl_ready(direct)',
                      '!human_subtile_crawl_authority(client)', 'n != get_step(src, direct)', 'if (!human_subtile_enabled)'):
            self.assertIn(guard, crawl)
        self.assertIn('set_human_subtile(TRUE)', crawl)
        self.assertIn('client.move_delay = max(client.move_delay, deadline)', crawl)
        self.assertNotIn('human_subtile_deadline(', crawl)
        self.assertNotIn('ROOT2', crawl)
        self.assertNotIn('human_subtile_enabled =', crawl)

    def test_each_pulse_checks_original_posture_and_physical_snapshot(self):
        source = MODULE.read_text()
        valid = source[source.index('/datum/human_subtile_transaction/proc/valid'):source.index('/datum/human_subtile_transaction/proc/perform')]
        for guard in ('persistence_save_in_progress', '!actor.scrambling', '!actor.human_subtile_enabled',
                      '!actor.human_subtile_crawl_ready(direction)', '!actor.human_subtile_crawl_authority(owner)',
                      'actor.prone != initial_prone', 'actor.lying != initial_lying', 'human_subtile_same(expected, actor.human_subtile_snapshot())'):
            self.assertIn(guard, valid)
        self.assertIn('(paid_posture && attempted)', source)
        movement = (ROOT / 'code/game/mob/mob_movement.dm').read_text()
        self.assertIn('subtile_input_actor.human_subtile_transaction.paid_posture', movement)

    def test_actual_entries_retain_delay_sources_and_legacy_fallback(self):
        source = (ROOT / 'code/_onclick/click.dm').read_text()
        self.assertIn('human_subtile_crawl_move(F, 9*slowness, "scramble")', source)
        self.assertIn('var/prone_delay = get_prone_delay()', source)
        self.assertIn('human_subtile_crawl_move(F, prone_delay, "prone")', source)
        self.assertIn('sleep(9*slowness)', source)
        self.assertIn('sleep(prone_delay)', source)
        self.assertEqual(source.count('catch (var/exception/crawl_error)'), 2)

    def test_native_fixture_covers_mid_interval_reach_and_cancellation(self):
        source = (ROOT / 'tests/human_subtile/crawl.dm').read_text()
        for label in ('crawl_intermediate_physical_reach_changes', 'crawl_never_continues_from_external_teleport',
                      'crawl_blocked_attempt_retains_lock_entire_interval', 'crawl_explicit_optout_legacy_path',
                      'crawl_owned_short_recovery_spans_paid_interval', 'crawl_does_not_import_walking_costs'):
            self.assertIn(label, source)
        self.assertIn('bounds_dist(src, fixture_reach_target)', source)
        self.assertIn('if (client)\n\t\treturn ..()', source)
        runner = (ROOT / 'tests/human_subtile/run-crawl.py').read_text()
        self.assertIn('legacy.prepare(diagonal.ROOT, out, \'human\')', runner)
        self.assertIn("'late-start'", runner)
        self.assertIn("'lost-lock'", runner)

    def test_dynamic_blocker_retains_stop_oracle_and_existing_overlap_regression(self):
        source = (ROOT / 'tests/human_subtile/crawl.dm').read_text()
        self.assertIn('C.fixture_pulses == (change == "blocker" ? 5 : 4)', source)
        self.assertIn('C.x == 8 && C.step_x == 8', source)
        self.assertIn('C.fixture_inserted["bounds_distance"] == 0', source)
        self.assertIn('I.fixture_inserted["bounds_distance"] == -8', source)
        self.assertIn('"crawl_existing_overlap_preserves_native_motion_and_paid_interval"', source)
        boundary = source[source.index('/obj/subtile_crawl_boundary/Cross'):source.index('/mob/living/human/subtile_fixture/crawl\n')]
        self.assertIn('. = ..()', boundary)
        self.assertNotIn('return FALSE', boundary)
        self.assertLess(source.index('human_subtile_crawl_changes += list(change_row)'), source.index('human_subtile_crawl_assert(C.fixture_pulses'))


if __name__ == '__main__':
    unittest.main(verbosity=2)
