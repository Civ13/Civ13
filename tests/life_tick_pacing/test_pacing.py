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
ICONS = (ROOT / 'code/game/mob/living/carbon/human/update_icons.dm').read_text(encoding='utf-8')
HELPERS = (ROOT / 'code/game/mob/living/carbon/human/human_helpers.dm').read_text(encoding='utf-8')
NEEDS = (ROOT / 'code/game/mob/living/carbon/human/human_needs.dm').read_text(encoding='utf-8')
DAMAGE = (ROOT / 'code/game/mob/living/carbon/human/human_damage.dm').read_text(encoding='utf-8')
BEARCAVE = (ROOT / 'code/game/objects/structures/animalspawner/bearcave.dm').read_text(encoding='utf-8')
GLOBALS = (ROOT / 'code/global.dm').read_text(encoding='utf-8')
ECOLOGY = (ROOT / 'code/modules/ecology/ecology_spawning.dm').read_text(encoding='utf-8')
MOB_PROCESS = (ROOT / 'code/processes/mob.dm').read_text(encoding='utf-8')
ANIMAL = (ROOT / 'code/game/mob/living/simple_animal/simple_animal.dm').read_text(encoding='utf-8')


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


class NearbyHeat(unittest.TestCase):
    WEATHER = (ROOT / 'code/modules/1713/weather.dm').read_text(encoding='utf-8')
    RAIN = (ROOT / 'code/modules/1713/rain_gear.dm').read_text(encoding='utf-8')

    def test_get_temp_keeps_every_heat_source_and_radius(self):
        scan = body(self.WEATHER, '/proc/nearby_heat_source(')
        for kind, radius in (('brazier', 3), ('heatsource', 3), ('oven/fireplace', 1), ('engine', 1)):
            self.assertRegex(scan, r'for \(var/obj/structure/%s/\w+ in range\(%d, A\)\)\n\t\tif \(\w+\.on\)\n\t\t\treturn TRUE' % (kind, radius))
        temp = body(self.WEATHER, '/proc/get_temp(')
        self.assertIn('if (loc_temp < 22)', temp)
        self.assertIn('if (istype(H) ? H.life_nearby_heat() : nearby_heat_source(A))\n\t\t\tloc_temp = 22', temp)

    def test_cache_is_dropped_on_a_new_tile_or_after_three_seconds(self):
        self.assertIn('#define LIFE_HEAT_SCAN_INTERVAL 30', self.WEATHER)
        current = body(self.WEATHER, '/mob/living/human/proc/life_heat_scan_current()')
        self.assertIn('if (T != life_heat_scan_turf || world.time >= life_heat_scan_until)', current)
        self.assertIn('life_heat_scan_warm = null', current)
        self.assertIn('life_heat_scan_drying = null', current)
        # Inside a container there is no tile to remember: scan as before.
        self.assertIn('if (!isturf(T))\n\t\treturn FALSE', current)
        warm = body(self.WEATHER, '/mob/living/human/proc/life_nearby_heat()')
        self.assertIn('if (!life_heat_scan_current())\n\t\treturn nearby_heat_source(src)', warm)
        drying = body(self.WEATHER, '/mob/living/human/proc/life_near_drying_fire()')
        self.assertIn('if (!life_heat_scan_current())\n\t\treturn near_drying_fire(get_turf(src))', drying)
        self.assertIn('if (life_near_drying_fire())\n\t\treturn FIRE_DRYING_RATE', body(self.RAIN, '/mob/living/human/proc/drying_rate('))

    def test_cache_model(self):
        calls = []
        state = {'turf': None, 'until': 0, 'warm': None}

        def warm(turf, now, lit):
            if turf != state['turf'] or now >= state['until']:
                state.update(turf=turf, until=now + 30, warm=None)
            if state['warm'] is None:
                calls.append(now)
                state['warm'] = lit
            return state['warm']

        self.assertFalse(warm('a', 0, False))
        self.assertFalse(warm('a', 10, True))   # a fire lit beside a standing human
        self.assertFalse(warm('a', 20, True))
        self.assertTrue(warm('a', 30, True))    # is felt within three seconds
        self.assertTrue(warm('b', 40, True))    # and at once after a step
        self.assertEqual(calls, [0, 30, 40])


class StanceDislocation(unittest.TestCase):
    def test_one_dislocation_walk_per_limb(self):
        stance = body(HUMAN_ORGANS, '/mob/living/human/proc/handle_stance()')
        self.assertEqual(stance.count('E.is_dislocated()'), 1)
        self.assertNotIn('(!E.is_usable() &&', stance)
        self.assertIn('(E.status & (ORGAN_MUTATED|ORGAN_DEAD)) || E.is_stump())', stance)
        self.assertIn('if (E.is_broken() || (dislocated && !(E.status & ORGAN_SPLINTED)))', stance)
        self.assertIn('else if (dislocated)\n\t\t\t\tstance_damage += 0.5', stance)
        # The shortcut holds only while is_usable() is "not dislocated and not mutated or dead".
        external = (ROOT / 'code/modules/organs/organ_external.dm').read_text(encoding='utf-8')
        self.assertIn('/obj/item/organ/external/is_usable()\n\treturn !is_dislocated() && !(status & (ORGAN_MUTATED|ORGAN_DEAD))', external)


class OverlayRedraw(unittest.TestCase):
    """Life() used to redraw every human once a second, which hid layer changes
    that were never drawn. Measured 2026-11-13: 1.0 update_icons per human per
    second before, one per 30 s after, with skipped redraws drawn on the next tick."""

    LAYER_PROCS = re.findall(
        r'^(/mob/living/human/(?:proc/)?(?:update_\w+|UpdateDamageIcon))\(var/update_icons=1',
        ICONS, re.M)

    def test_every_layer_proc_queues_a_skipped_redraw(self):
        self.assertGreaterEqual(len(self.LAYER_PROCS), 24)
        for signature in self.LAYER_PROCS:
            with self.subTest(signature):
                first = body(ICONS, signature + '(').lstrip('\n').split('\n')[:2]
                self.assertEqual(first, ['\tif (!update_icons)', '\t\tqueue_overlay_redraw()'])

    def test_queued_redraw_is_one_flush_per_tick(self):
        queue = body(ICONS, '/mob/living/human/proc/queue_overlay_redraw(')
        self.assertLess(queue.index('overlays_dirty = TRUE'), queue.index('if (overlays_flush_queued)'))
        self.assertIn('\toverlays_flush_queued = TRUE\n'
                      '\taddtimer(CALLBACK(src, PROC_REF(flush_overlay_redraw)), 0)', queue)
        self.assertNotIn('spawn', queue)
        flush = body(ICONS, '/mob/living/human/proc/flush_overlay_redraw(')
        self.assertIn('\toverlays_flush_queued = FALSE\n'
                      '\tif (overlays_dirty && !QDELETED(src))\n\t\tupdate_icons()', flush)
        redraw = body(ICONS, '/mob/living/human/update_icons(')
        self.assertIn('overlays_dirty = FALSE', redraw)
        self.assertLess(redraw.index('overlays_dirty = FALSE'), redraw.index('overlays.Cut()'))

    def test_redraw_masks_replaced_images_in_water(self):
        redraw = body(ICONS, '/mob/living/human/update_icons(')
        mask = redraw.index('if (drowning || water_overlay)\n\t\t\tapply_water_mask()')
        self.assertLess(mask, redraw.index('for (var/image/I in overlays_standing)'))
        fire = body(ICONS, '/mob/living/human/update_fire(')
        self.assertLess(fire.index('apply_water_mask()'), fire.index('update_icons()'))

    def test_life_only_redraws_on_a_change_or_the_backstop(self):
        refresh = body(ICONS, '/mob/living/human/proc/life_water_refresh(')
        self.assertIn('if (state != life_water_state || overlays_dirty || !(life_tick % LIFE_OVERLAY_BACKSTOP))', refresh)
        self.assertIn('\telse\n\t\tupdate_posture_transform()', refresh)
        self.assertIn('\t\tif (riding && riding_mob)\n\t\t\triding_mob.update_icons()', refresh)
        self.assertIn('on_fire', refresh)
        self.assertIn('water_mask_state()', refresh)
        self.assertIn('#define LIFE_OVERLAY_BACKSTOP 30', ICONS)

    def test_drowning_never_redraws_unconditionally(self):
        drowning = body(HELPERS, '/mob/living/human/proc/handle_drowning(')
        self.assertNotIn('update_fire(', drowning)
        # Every exit refreshes, including under cover and on a boat, where the
        # water mask used to stay on.
        returns = [m.start() for m in re.finditer(r'^\t+return$', drowning, re.M)]
        self.assertGreaterEqual(len(returns), 9)
        for at in returns:
            before = drowning[:at].rstrip('\n').split('\n')
            tail = [line.strip() for line in before[-2:]]
            self.assertIn('life_water_refresh()', tail, before[-3:])

    def test_hygiene_overlay_is_replaced_only_on_a_change(self):
        # The proc holds commented-out lines at column 0, so slice to the next proc.
        start = NEEDS.index('/mob/living/human/proc/handle_hygiene(')
        hygiene = NEEDS[start:NEEDS.index('/mob/living/human/proc/adjust_hygiene(')]
        self.assertEqual(hygiene.count('overlays_standing[27] = img_nasties'), 1)
        self.assertIn('if (nasties_state != hygiene_overlay_state || !overlays_standing[27])\n'
                      '\t\thygiene_overlay_state = nasties_state\n'
                      '\t\toverlays_standing[27] = img_nasties\n'
                      '\t\tqueue_overlay_redraw()', hygiene)


class LoopAudit(unittest.TestCase):
    """Second loop audit (2026-11-13): work every tick that changed nothing."""

    def test_pain_healing_skips_unhurt_bodies(self):
        hal = body(DAMAGE, '/mob/living/human/adjustHalLoss(')
        guard = hal.index('if (heal)\n\t\tvar/hurt = FALSE')
        self.assertIn('if (E.brute_dam || E.burn_dam || E.pain || E.damage)', hal)
        self.assertIn('\t\tif (!hurt)\n\t\t\treturn', hal)
        self.assertLess(guard, hal.index('organs.Copy()'))

    def test_each_bear_cave_ticks_itself_without_a_world_scan(self):
        tick = body(BEARCAVE, '/obj/structure/animalspawner/bearcave/proc/Tick(')
        self.assertNotIn(' in world', tick)
        self.assertIn('\tif(ticking || gcDestroyed || gc_destroyed)\n\t\treturn\n\tticking = TRUE\n', tick)
        self.assertIn('\tspawn while(src && ticking && !gcDestroyed && !gc_destroyed)\n', tick)
        self.assertIn('\t\ttotal_population = males + females + cubs\n\t\tTicker()\n\t\tsleep(50)', tick)
        self.assertIn('\tticking = FALSE\n\treturn ..()', body(BEARCAVE, '/obj/structure/animalspawner/bearcave/Destroy('))
        self.assertIn('return key == "ticking" || ..()', body(BEARCAVE, '/obj/structure/animalspawner/bearcave/persistence_runtime_var('))
        self.assertEqual(body(BEARCAVE, '/obj/structure/animalspawner/bearcave/New(').count('\tTick()\n'), 1)
        self.assertNotIn('Tick()', body(BEARCAVE, '/obj/structure/animalspawner/bearcave/full/New('))
        self.assertNotIn('bearcave_ticking', BEARCAVE + GLOBALS)


def cell_near(observers, x, y, z, max_x, max_y, max_z, reach=32):
    """Python model of ecology_refresh_observers' buckets and ecology_observer_near()."""
    rows = (max_y - 1) // reach + 1
    columns = (max_x - 1) // reach + 1
    cells = {}
    for ox, oy, oz in observers:
        cells.setdefault(oz, {}).setdefault(((ox - 1) // reach) * rows + (oy - 1) // reach + 1, []).append((ox, oy))
    cx, cy = (x - 1) // reach, (y - 1) // reach
    for cz in range(max(1, z - 1), min(max_z, z + 1) + 1):
        for gx in range(max(0, cx - 1), min(columns - 1, cx + 1) + 1):
            for gy in range(max(0, cy - 1), min(rows - 1, cy + 1) + 1):
                for ox, oy in cells.get(cz, {}).get(gx * rows + gy + 1, ()):
                    if max(abs(ox - x), abs(oy - y)) <= reach:
                        return True
    return False


class ObserverBuckets(unittest.TestCase):
    """Animals far from players rest; the range check used to walk every observer
    for every animal each second, and the observer list was rebuilt on every
    resumed slice of the mob process (21,000 times in 164 s with 413 mobs)."""

    def test_refresh_runs_once_per_pass(self):
        fire = body(MOB_PROCESS, '/process/mob/fire(')
        self.assertNotIn('ecology_refresh_observers()', fire)
        reset = body(MOB_PROCESS, '/process/mob/reset_current_list(')
        self.assertLess(reset.index('PROCESS_USE_FASTEST_LIST(living_mob_list)'), reset.index('ecology_refresh_observers()'))

    def test_resting_uses_the_buckets(self):
        resting = body(ECOLOGY, '/proc/ecology_animal_resting(')
        self.assertIn('if (ecology_observer_near(T))\n\t\treturn FALSE', resting)
        self.assertNotIn('ecology_observer_turfs', resting)
        near = body(ECOLOGY, '/proc/ecology_observer_near(')
        self.assertIn('max(abs(O.x - T.x), abs(O.y - T.y)) <= ECOLOGY_AWAKE_RANGE', near)
        self.assertIn('for (var/z = max(1, T.z - 1), z <= min(ecology_observer_cells.len, T.z + 1), z++)', near)
        self.assertIn('var/rows = ecology_observer_rows', near)
        self.assertIn('ecology_observer_rows = rows', refresh_src := body(ECOLOGY, '/proc/ecology_refresh_observers('))
        refresh = body(ECOLOGY, '/proc/ecology_refresh_observers(')
        self.assertIn('ecology_observer_turfs = turfs', refresh)
        self.assertIn('var/index = ecology_cell_index(T.x, T.y, rows)', refresh)
        self.assertIn('return round((x - 1) / ECOLOGY_AWAKE_RANGE) * rows + round((y - 1) / ECOLOGY_AWAKE_RANGE) + 1',
                      body(ECOLOGY, '/proc/ecology_cell_index('))

    def test_bucket_model_matches_the_old_scan(self):
        import random
        rng = random.Random(4)
        for trial in range(60):
            max_x, max_y, max_z = rng.choice([(500, 500, 6), (255, 300, 3), (33, 64, 2), (32, 32, 1)])
            observers = [(rng.randint(1, max_x), rng.randint(1, max_y), rng.randint(1, max_z)) for _ in range(rng.randint(0, 12))]
            for _ in range(300):
                x, y, z = rng.randint(1, max_x), rng.randint(1, max_y), rng.randint(1, max_z)
                old = any(abs(oz - z) <= 1 and max(abs(ox - x), abs(oy - y)) <= 32 for ox, oy, oz in observers)
                self.assertEqual(old, cell_near(observers, x, y, z, max_x, max_y, max_z))

    def test_animals_skip_the_surface_lookup_without_radiation(self):
        rad = body(ANIMAL, '/mob/living/simple_animal/handle_mutations_and_radiation(')
        self.assertIn('if (global_radiation > 0 && z == multiz_top_z())', rad)


if __name__ == '__main__':
    unittest.main()
