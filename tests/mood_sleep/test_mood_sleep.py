"""Offline actual-source projections; no compiler, native world or network.

The complete mood helpers, maintenance prefix and migrated expressions execute
through the existing audited DM subset adapter with inert engine boundaries.
This establishes source control flow, not BYOND numeric/gameplay acceptance.
"""
from collections import Counter
import importlib.util
import json
import math
from pathlib import Path
import re
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('mood_source_adapter', ROOT/'tests/save_movement/source_adapter.py')
A = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(A)
A.FIELDS += ('mood', 'set_mood', 'adjust_mood', 'note_mood_cause', 'droid', 'resting', 'lying', 'mood_resting_level')
CORE = 'code/game/mob/living/carbon/human/human_needs.dm'
LIFE = 'code/game/mob/living/carbon/human/human_life.dm'
WRITES = json.loads((Path(__file__).parent/'original_writes.json').read_text())


def source(path):
    return (ROOT/path).read_text(encoding='utf-8-sig')


def uncomment(text):
    text = re.sub(r'/\*.*?\*/', '', text, flags=re.S)
    return '\n'.join(line.split('//', 1)[0] for line in text.splitlines())


def actor(mood=80, sleeping=0, resting=False, lying=False, stat=0, droid=False, core=None):
    core = source(CORE) if core is None else core
    env = {}
    setter = A.project(core, '/mob/living/human/proc/set_mood', 'src,amount,cause=None', env, method=True)
    adjuster = A.project(core, '/mob/living/human/proc/adjust_mood', 'src,amount,cause=None', env, method=True)
    mob = SimpleNamespace(mood=mood, sleeping=sleeping, resting=resting, lying=lying, stat=stat, droid=droid, causes=[])
    mob.set_mood = lambda value, cause=None: setter(mob, value, cause)
    mob.adjust_mood = lambda amount, cause=None: adjuster(mob, amount, cause)
    mob.note_mood_cause = lambda cause, delta: mob.causes.append((cause, delta))
    return mob


REST, FADE, RECOVER = 50, 0.07, 0.03


def maintenance(mob, rest=REST):
    # Life calls the one drift helper; its constants come from the defines.
    life = uncomment(source(LIFE))
    assert life.count('\tmood_drift()\n') == 1, 'life tick drifts mood once'
    defines = source('code/__defines/mobs.dm')
    for name, value in (('MOOD_REST', REST), ('MOOD_FADE', FADE), ('MOOD_RECOVER', RECOVER)):
        assert re.search(r'^#define %s %s\b' % (name, re.escape(str(value))), defines, re.M), name
    env = dict(MOOD_FADE=FADE, MOOD_RECOVER=RECOVER, max=max, min=min)
    mob.mood_resting_level = lambda: rest
    proc = A.project(source(CORE), '/mob/living/human/proc/mood_drift', 'src', env, method=True)
    proc(mob)


def execute_write(text, mob, values):
    env = dict(values, H=mob, M=mob, NB=mob, HM=mob, user=mob, current_user=mob,
               min=min, max=max, abs=abs, ceil=math.ceil, initial=lambda value: 100)
    proc = A.project('/write()\n\t'+text+'\n', '/write', 'src', env, method=True)
    proc(mob)
    return mob.mood


def assert_sleep_policy(core):
    for sleeping in (1, 2, 66):
        mob = actor(sleeping=sleeping, core=core)
        mob.adjust_mood(-5)
        assert mob.mood == 80, 'asleep loss'
        mob.adjust_mood(10)
        assert mob.mood == 90, 'asleep gain'
    for resting, lying in ((False, False), (True, False), (True, True), (False, True)):
        mob = actor(resting=resting, lying=lying, stat=1, core=core)
        mob.adjust_mood(-5)
        assert mob.mood == 75, 'awake loss'


class MoodSleep(unittest.TestCase):
    def test_actual_sleep_counter_and_awake_postures(self):
        assert_sleep_policy(source(CORE))
        life = source(LIFE)
        self.assertIn('else if (sleeping)', life)
        self.assertIn('AdjustSleeping(-1)', life)
        helpers = source('code/game/mob/living/carbon/human/human_helpers.dm')
        self.assertIn('sleeping = 66', helpers)
        self.assertIn('sleeping = 0', helpers)

    def test_absolute_targets_and_positive_changes(self):
        for sleeping in (0, 1, 66):
            for current in (-1, 0, 40, 80, 120, 150):
                for target in (-10, 0, 40, 100, 120, 160):
                    with self.subTest(sleeping=sleeping, current=current, target=target):
                        mob = actor(current, sleeping)
                        self.assertEqual(mob.set_mood(target), max(current, target) if sleeping else target)
                        self.assertEqual(mob.mood, max(current, target) if sleeping else target)

    def test_recipient_state_controls_external_event(self):
        values = dict(value=20)
        sleeper, awake = actor(sleeping=66), actor(resting=True, lying=True)
        execute_write('NB.adjust_mood(-(10))', sleeper, values)
        execute_write('NB.adjust_mood(-(10))', awake, values)
        self.assertEqual((sleeper.mood, awake.mood), (80, 70))

    def test_maintenance_drift_recovery_cap_and_droid(self):
        for droid in (False, True):
            for sleeping in (0, 1, 66):
                for current in (-5, 0, 20, 40, 50, 80, 120, 150):
                    with self.subTest(droid=droid, sleeping=sleeping, current=current):
                        mob = actor(current, sleeping, droid=droid)
                        maintenance(mob)
                        if sleeping:
                            expected = max(current, 100) if droid else (max(0, current)+RECOVER if current < REST else current)
                        else:
                            expected = min(120, max(0, current))
                            expected += -FADE if expected > REST else RECOVER if expected < REST else 0
                            if droid:
                                expected = 100
                        self.assertAlmostEqual(mob.mood, expected)

    def test_mood_settles_exactly_at_rest_from_both_sides(self):
        # It used to stall at 40, where the Bad effects began.
        for start in (49.99, 50.02, 20, 110):
            mob = actor(start)
            for _ in range(2000):
                maintenance(mob)
            self.assertEqual(mob.mood, REST)
        mob = actor(60)
        maintenance(mob, rest=64)
        self.assertAlmostEqual(mob.mood, 60 + RECOVER)

    def test_sleep_losses_are_discarded_without_waking_debt(self):
        mob = actor(sleeping=66)
        for _ in range(1000):
            mob.adjust_mood(-10)
            maintenance(mob)
        self.assertEqual(mob.mood, 80)
        mob.adjust_mood(5)
        mob.sleeping = 0
        maintenance(mob)
        self.assertAlmostEqual(mob.mood, 84.93)
        mob.adjust_mood(-3)
        self.assertAlmostEqual(mob.mood, 81.93)

    def test_all_migrated_expressions_preserve_awake_results_and_sleep_gains(self):
        defaults = dict(removed=2, satisfaction=10, biteamount=3, this_exp=5,
            change_mood_coefficient=1, I=20, work_time_amount=30, value=50,
            MOOD_LOSS_PER_DECISECOND_OF_PHYSICAL_WORK=0,
            MOOD_LOSS_PER_DECISECOND_OF_MENTAL_WORK=0, floor_mood=65)
        for site in WRITES:
            for current in (-5, 0, 5, 40, 80, 150):
                for sign in (-1, 1):
                    values = dict(defaults, satisfaction=sign*10, change_mood_coefficient=sign)
                    with self.subTest(path=site['path'], before=site['before'], mood=current, sign=sign):
                        expected = execute_write(site['before'], actor(current), values)
                        self.assertEqual(execute_write(site['after'], actor(current), values), expected)
                        self.assertEqual(execute_write(site['after'], actor(current, sleeping=66), values), max(current, expected))

    def test_every_migrated_site_is_present_with_its_original_count(self):
        counts = Counter((site['path'], site['after']) for site in WRITES)
        for (path, text), expected in counts.items():
            lines = [line.strip() for line in uncomment(source(path)).splitlines()]
            self.assertEqual(lines.count(text), expected, (path, text))

    def test_no_gameplay_writes_bypass_shared_setter(self):
        writes = []
        for path in sorted((ROOT/'code').rglob('*.dm')):
            for line in uncomment(path.read_text(encoding='utf-8-sig')).splitlines():
                if re.search(r'\bmood\s*(?:[-+*/&|^]?=(?!=)|\+\+|--)', line):
                    writes.append((path.relative_to(ROOT).as_posix(), line.strip()))
        self.assertEqual(writes, [('code/game/mob/living/carbon/carbon_defines.dm', 'var/mood = 100'),
            (CORE, 'mood = amount')])

    def test_causes_record_applied_changes_only(self):
        mob = actor(mood=80)
        mob.adjust_mood(-5, 'fleas')
        mob.adjust_mood(3)
        mob.set_mood(90, 'a good wash')
        self.assertEqual(mob.causes, [('fleas', -5), ('a good wash', 12)])
        sleeper = actor(mood=80, sleeping=66)
        sleeper.adjust_mood(-5, 'fleas')
        sleeper.adjust_mood(4, 'the food you ate')
        self.assertEqual((sleeper.mood, sleeper.causes), (84, [('the food you ate', 4)]))

    def test_omitted_broadened_and_frozen_guard_controls_fail(self):
        core = source(CORE)
        for before, after, failure in (
            ('sleeping > 0 && amount < mood', 'FALSE', 'asleep loss'),
            ('sleeping > 0 && amount < mood', '(sleeping > 0 || resting || lying || stat) && amount < mood', 'awake loss'),
            ('sleeping > 0 && amount < mood', 'sleeping > 0', 'asleep gain')):
            with self.subTest(control=after):
                self.assertEqual(core.count(before), 1)
                with self.assertRaisesRegex(AssertionError, failure):
                    assert_sleep_policy(core.replace(before, after))

    def test_helpers_only_write_mood_without_deferred_work(self):
        setter = A.extract(source(CORE), '/mob/living/human/proc/set_mood')
        adjuster = A.extract(source(CORE), '/mob/living/human/proc/adjust_mood')
        self.assertEqual(re.findall(r'^\s*(\w+)\s*=(?!=)', setter+adjuster, re.M), ['mood'])
        self.assertNotRegex(setter+adjuster, r'\b(?:spawn|sleep|addtimer|world|client)\b')


# One shared mood scale.
TIERS = dict(MOOD_TIER_HORRIBLE=1, MOOD_TIER_BAD=2, MOOD_TIER_NEUTRAL=3, MOOD_TIER_GOOD=4, MOOD_TIER_EXCELLENT=5)


def scale():
    env = dict(TIERS)
    for name in ('mood_tier', 'mood_tier_name', 'mood_stat_modifier', 'mood_movement_delay'):
        env[name] = A.project(source(CORE), '/proc/' + name, 'value', env)
    return env


class MoodScale(unittest.TestCase):
    def test_defines_match_the_projected_tiers(self):
        defines = source('code/__defines/mobs.dm')
        for name, value in TIERS.items():
            self.assertRegex(defines, r'(?m)^#define %s %d\b' % (name, value))

    def test_a_boundary_belongs_to_the_higher_tier(self):
        env = scale()
        for value, name in ((-5, 'horrible'), (0, 'horrible'), (19.99, 'horrible'), (20, 'bad'), (39.99, 'bad'),
                            (40, 'neutral'), (50, 'neutral'), (59.99, 'neutral'), (60, 'good'), (79.99, 'good'),
                            (80, 'excellent'), (120, 'excellent')):
            with self.subTest(value=value):
                self.assertEqual(env['mood_tier_name'](value), name)

    def test_neutral_has_no_stat_or_movement_effect(self):
        env = scale()
        # Mood 40 used to count as Bad: 0.95 stats and 0.8 movement delay.
        for value in (40, 40.01, 50, 59.99):
            with self.subTest(value=value):
                self.assertEqual(env['mood_stat_modifier'](value), 1)
                self.assertEqual(env['mood_movement_delay'](value), 0)
        self.assertEqual([env['mood_stat_modifier'](v) for v in (0, 9.99, 10, 20, 30, 39.99, 60, 80, 89.99, 90, 120)],
                         [0.8, 0.8, 0.85, 0.90, 0.95, 0.95, 1.05, 1.10, 1.10, 1.15, 1.15])
        self.assertEqual([env['mood_movement_delay'](v) for v in (0, 19.99, 20, 39.99, 60, 100)],
                         [0.90, 0.90, 0.8, 0.8, 0, 0])

    def test_sadness_flash_only_in_a_horrible_mood(self):
        handler = A.extract(source(CORE), '/mob/living/human/proc/handle_mood')
        self.assertIn('\tif (mood_tier(mood) == MOOD_TIER_HORRIBLE)\n\t\tflash_sadness((50-mood)/40)', handler)
        self.assertEqual(handler.count('flash_sadness('), 1)

    def test_every_reader_uses_the_shared_scale(self):
        readers = {
            'code/_onclick/hud/base_screen_objects.dm': 'icon_state = "mood[6 - mood_tier(L.mood)]"',
            'code/game/mob/living/carbon/human/examine.dm': 'switch(mood_tier(mood))',
            'code/game/mob/living/carbon/human/human_movement.dm': 'tally += mood_movement_delay(mood)',
            'code/modules/1713/movement_check.dm': 'movement_check_add(., "low mood", mood_movement_delay(mood))',
            'code/game/mob/player_help.dm': 'capitalize(mood_tier_name(value))',
            CORE: 'mood_modifier = mood_stat_modifier(mood)',
        }
        for path, text in readers.items():
            self.assertIn(text, source(path), path)
        # No reader keeps its own ranges.
        for path in sorted((ROOT / 'code').rglob('*.dm')):
            text = uncomment(path.read_text(encoding='utf-8-sig'))
            self.assertNotRegex(text, r'switch\s*\(\s*(?:\w+\.)?mood\s*\)', path.name)


if __name__ == '__main__':
    unittest.main()
