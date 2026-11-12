"""Offline source checks for Life tick pacing; this is not a native BYOND test.

Measured natively on a headless Gaia world (2026-11-12): before these changes a
budgeted process that ran out of tick waited a full schedule_interval before it
continued, so 100 humans received 0.3 Life ticks per second each on an idle
server, and every organ recomputed the antibiotic dose (14 scans per Life tick).
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
PROCESS = (ROOT / 'code/processes/_process.dm').read_text(encoding='utf-8')
SCHEDULER = (ROOT / 'code/processes/__processScheduler.dm').read_text(encoding='utf-8')
ORGAN = (ROOT / 'code/modules/organs/organ.dm').read_text(encoding='utf-8')
HUMAN_ORGANS = (ROOT / 'code/game/mob/living/carbon/human/human_organs.dm').read_text(encoding='utf-8')
BLOOD = (ROOT / 'code/modules/organs/blood.dm').read_text(encoding='utf-8')
HUMAN = (ROOT / 'code/game/mob/living/carbon/human/human.dm').read_text(encoding='utf-8')


def body(source, signature):
    match = re.search(r'^' + re.escape(signature) + r'[^\n]*\n(.*?)(?=^\S|\Z)', source, re.M | re.S)
    if not match:
        raise AssertionError(signature)
    return match.group(1)


def simulate(entries, per_tick, interval_ticks, ticks, resume):
    """Model of queueProcesses/finished for one budgeted process."""
    pending = 0
    last_queued = -interval_ticks
    resume_pending = False
    done = 0
    pass_starts = []
    for tick in range(ticks):
        due = tick >= last_queued + interval_ticks
        if not ((resume and resume_pending) or due):
            continue
        if not pending:
            pending = entries
            pass_starts.append(tick)
        if not (resume and resume_pending):
            last_queued = tick
        work = min(pending, per_tick)
        pending -= work
        done += work
        resume_pending = pending > 0
    return done, pass_starts


class SchedulerResume(unittest.TestCase):
    def test_finished_records_an_unfinished_budgeted_run(self):
        finished = body(PROCESS, '/process/proc/finished(')
        early = finished.index('if (fire_result != PROCESS_TICK_CHECK_RETURNED_EARLY)')
        self.assertIn('\tresume_pending = TRUE\n\tif (fire_result != PROCESS_TICK_CHECK_RETURNED_EARLY)', finished)
        self.assertIn('\t\tresume_pending = FALSE\n\treturn fire_result', finished)
        # An exhausted snapshot is normalized to a completed run first.
        self.assertLess(finished.index('!length(current_list)'), early)
        self.assertIn('var/tmp/resume_pending = FALSE', PROCESS)

    def test_queue_continues_unfinished_runs_without_waiting_out_the_interval(self):
        queue = body(SCHEDULER, '/processScheduler/proc/queueProcesses()')
        self.assertIn('if (p.resume_pending || current_time >= (last_queued[p] + p.schedule_interval))', queue)
        # Disabled, running and already queued processes are still skipped first.
        self.assertLess(queue.index('p.disabled || p.running || p.queued || !p.idle'), queue.index('p.resume_pending'))

    def test_continued_run_keeps_its_pass_start_time(self):
        start = body(SCHEDULER, '/processScheduler/proc/recordStart(')
        self.assertRegex(start, r'if \(!process\.resume_pending\)\n\t\t\tlast_queued\[process\] = world\.time')

    def test_model_throughput(self):
        # 100 humans, 25 fit in one tick, one pass per second at 25 ticks per second.
        old_done, _ = simulate(100, 25, 25, 250, resume=False)
        new_done, new_starts = simulate(100, 25, 25, 250, resume=True)
        self.assertEqual(old_done, 250)  # a quarter of the humans each second
        self.assertEqual(new_done, 1000)  # every human once per second
        self.assertEqual(new_starts, list(range(0, 250, 25)))
        # A list that fits in one tick is unchanged.
        self.assertEqual(simulate(20, 25, 25, 250, False), simulate(20, 25, 25, 250, True))
        # Overload still makes progress every tick and never runs two passes at once.
        overload_done, overload_starts = simulate(1000, 25, 25, 250, resume=True)
        self.assertEqual(overload_done, 250 * 25)
        self.assertEqual(overload_starts, [0, 40, 80, 120, 160, 200, 240])


class AntibioticDose(unittest.TestCase):
    def test_dose_is_shared_for_the_organ_pass(self):
        dose = body(ORGAN, '/mob/living/human/proc/get_antibiotic_dose()')
        self.assertTrue(dose.startswith('\tif (antibiotic_dose_shared_at == world.time)\n\t\treturn antibiotic_dose_shared\n'))
        self.assertIn('for (var/id in antibiotic_strengths)', dose)
        organs = body(HUMAN_ORGANS, '/mob/living/human/proc/handle_organs()')
        refresh = ('\tantibiotic_dose_shared_at = -1\n'
                   '\tantibiotic_dose_shared = get_antibiotic_dose()\n'
                   '\tantibiotic_dose_shared_at = world.time\n')
        self.assertIn(refresh, organs)
        # Refreshed before any organ is processed, so this tick's metabolism counts.
        self.assertLess(organs.index(refresh), organs.index('I.process()'))
        self.assertIn('/mob/living/human/var/tmp/antibiotic_dose_shared_at = -1', ORGAN)

    def test_same_blood_fast_path_only_skips_identical_inputs(self):
        check = body(BLOOD, 'proc/blood_incompatible(')
        guard = 'if (donor == receiver && donor_species == receiver_species)\n\t\treturn FALSE'
        self.assertIn(guard, check)
        self.assertLess(check.index('if (!donor || !receiver) return FALSE'), check.index(guard))
        self.assertLess(check.index(guard), check.index('blood_species_name(donor_species)'))


class MannedGunRelease(unittest.TestCase):
    def test_life_and_movement_use_the_recorded_gun(self):
        for signature in ('/mob/living/human/proc/handle_look_stuff(', '/mob/living/human/proc/handle_looks_with_movement()'):
            with self.subTest(signature=signature):
                proc = body(HUMAN, signature)
                self.assertNotIn('in range(2, src)', proc)
                self.assertIn('var/obj/item/weapon/gun/projectile/automatic/stationary/HMG = using_object', proc)
                self.assertIn('istype(HMG) && HMG.used_by_mob == src', proc)
        stationary = (ROOT / 'code/modules/1713/weapons/guns/mg/_stationary.dm').read_text(encoding='utf-8')
        started = body(stationary, '/obj/item/weapon/gun/projectile/automatic/stationary/proc/started_using(')
        self.assertIn('used_by_mob = user\n\tuser.using_object = src', started)


if __name__ == '__main__':
    unittest.main()
