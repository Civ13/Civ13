"""Offline production-source tests with synthetic clock, hull and compass."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STORM = (ROOT / 'code/modules/naval/hull_storm.dm').read_text()
LEDGER = (ROOT / 'code/modules/naval/hull_ledger.dm').read_text()
COMPASS = ('NORTH', 'NORTHEAST', 'EAST', 'SOUTHEAST',
           'SOUTH', 'SOUTHWEST', 'WEST', 'NORTHWEST')
DIRECTIONS = {key: i + 1 for i, key in enumerate(COMPASS)}


def body(signature, source=STORM):
    sections = source.splitlines()
    start = next(i for i, line in enumerate(sections) if line.startswith(signature))
    result = []
    for line in sections[start + 1:]:
        if line and not line.startswith('\t'):
            break
        if line:
            result.append(line)
    return '\n'.join(result)


def translated(signature, args, state=None):
    """Run just the numeric/control flow; no native weather or hull effects."""
    constants = {name: float(number) for name, number in re.findall(
        r'^#define (\w+) ([\d.]+)$', STORM, re.M)}
    env = {**DIRECTIONS, **constants, 'HULL_CLASS_SMALL': 1,
           'clamp': lambda x, lo, hi: max(lo, min(x, hi))}
    env['turn'] = lambda direction, arc: (direction - 1 - arc // 45) % 8 + 1
    lines = [f'def probe({args}):']
    for raw in body(signature).splitlines():
        prefix = raw[:len(raw) - len(raw.lstrip())].replace('\t', '    ')
        line = raw.strip()
        if line.startswith('//'):
            continue
        if line.startswith('craft.crew_message'):
            line = 'self.warnings.append(' + repr(line.split('SPAN_', 1)[1].split('(', 1)[0]) + ')'
        line = re.sub(r'^var/(\w+) =', r'\1 =', line)
        line = re.sub(r'\bTRUE\b', 'True', line)
        line = re.sub(r'\bFALSE\b', 'False', line)
        line = re.sub(r'!(?!=)', 'not ', line).replace('&&', ' and ').replace('||', ' or ')
        line = re.sub(r'^(if \(.*\))$', r'\1:', line)
        line = re.sub(r'^(\w+ = )(.+) \? (.+) : (.+)$', r'\1\3 if \2 else \4', line)
        if state:
            line = re.sub(
                r'\b(storm_beam_seconds|storm_warned|storm_beam|storm_unstable|hull_class|'
                r'capacity|add_water|storm_capsize)\b', r'self.\1', line)
        lines.append(prefix + line)
    exec(compile('\n'.join(lines), '<production hull storm projection>', 'exec'), env)
    return env['probe']


class Ledger:
    def __init__(self, *, beam=1, unstable=True, kind=3):
        self.beam = beam
        self.unstable = unstable
        self.kind = kind
        self.storm_beam_seconds = 0
        self.storm_warned = False
        self.warnings = []
        self.water = 0
        self.rolls = 0

    def storm_beam(self):
        return self.beam

    def storm_unstable(self):
        return self.unstable

    def hull_class(self):
        return self.kind

    def capacity(self):
        return 100

    def add_water(self, water):
        self.water += water

    def storm_capsize(self):
        self.rolls += 1
        return True


class Storm(unittest.TestCase):
    def setUp(self):
        self.step = translated('/datum/hull_ledger/proc/step_storm(', 'self, seconds', True)

    def test_relative_direction(self):
        beam = translated('/proc/hull_storm_beam(', 'heading, from_dir')
        for heading in COMPASS[::2]:
            for off, direction in enumerate(COMPASS):
                heading_index = COMPASS.index(heading)
                delta = (off - heading_index) % 8
                expected = (0, 0.5, 1, 0.5, 0, 0.5, 1, 0.5)[delta]
                self.assertEqual(beam(DIRECTIONS[heading], DIRECTIONS[direction]), expected)
        self.assertEqual(beam(99, DIRECTIONS['EAST']), 0)
        self.assertEqual(beam(DIRECTIONS['NORTH'], 0), 0)

    def test_lag_cannot_roll_before_warning_and_three_admitted_steps(self):
        hull = Ledger()
        self.assertFalse(self.step(hull, 3000))
        self.assertEqual(hull.storm_beam_seconds, 30)
        self.assertEqual(hull.warnings, ['WARNING', 'DANGER'])
        self.assertFalse(self.step(hull, 30))
        self.assertTrue(self.step(hull, 30))
        self.assertEqual(hull.rolls, 1)
        self.assertEqual(hull.warnings, ['WARNING', 'DANGER'])

    def test_turn_or_improve_stability_clears_roll_progress(self):
        for beam, stable in ((0, False), (0.5, False), (1, True)):
            hull = Ledger()
            for _ in range(2):
                self.assertFalse(self.step(hull, 30))
            hull.beam, hull.unstable = beam, not stable
            self.assertFalse(self.step(hull, 30))
            self.assertEqual(hull.storm_beam_seconds, 0)
            self.assertEqual(hull.rolls, 0)

    def test_waves_use_the_bilge_and_differ_by_aspect_and_hull(self):
        for kind, direction, expected in ((3, 1, 4), (3, .5, 2), (3, 0, 0), (1, 1, 8)):
            hull = Ledger(kind=kind, beam=direction, unstable=False)
            self.assertFalse(self.step(hull, 30))
            self.assertEqual(hull.water, expected)

    def test_admission_checks_deep_surface_heavy_band_and_crossings(self):
        s = body('/datum/hull_ledger/proc/storm_beam(')
        self.assertIn('is_open_sea(at)', s)
        self.assertIn('weather_storm_strength(at.x, at.y) < WEATHER_BAND_HEAVY', s)
        self.assertIn('hull_storm_beam(B.heading(), weather_wind_dir_at(at))', s)
        self.assertIn('T.voyage || T.crossing_hold', s)
        l = body('/datum/hull_ledger/proc/step_ledger(', LEDGER)
        self.assertLess(l.index('step_load(seconds)'), l.index('step_storm(seconds)'))
        self.assertLess(l.index('step_storm(seconds)'), l.index('pump_bilge(seconds)'))

    def test_only_accepted_recent_helm_commands_assign_a_pilot(self):
        tiller = (ROOT / 'code/modules/naval/built_hull.dm').read_text()
        helm = body('/obj/structure/hull_tiller/attack_hand(', tiller)
        self.assertEqual(helm.count('note_storm_pilot(H)'), 2)
        self.assertLess(helm.index('if (!craft.order_turn(heading))'), helm.index('note_storm_pilot(H)'))
        self.assertIn('if (choice in list("Full ahead", "Half ahead", "Slow ahead", "Weigh anchor"))'
                      '\n\t\tcraft.ledger?.note_storm_pilot(H)', helm)
        self.assertIn('else if (choice in list("All stop", "Drop anchor"))'
                      '\n\t\tcraft.ledger?.note_storm_pilot(null)', helm)
        note = body('/datum/hull_ledger/proc/note_storm_pilot(')
        self.assertIn('!H?.client || H.incapacitated() || !under_way()', note)
        self.assertIn('storm_pilot = WEAKREF(H)', note)
        self.assertIn('world.time + HULL_STORM_HELM_AGE', note)

    def test_save_risk_rechecks_active_helm_and_does_not_use_exposure_cache(self):
        s = body('/proc/any_crew_at_capsize_risk(')
        self.assertIn('watch_fit(H)', s)
        self.assertIn('H.incapacitated()', s)
        self.assertIn('world.time >= L.storm_pilot_until || L.storm_pilot?.resolve() != H', s)
        self.assertIn('range(1, at)', s)
        self.assertIn('L.under_way() || !L.deck_holds(at)', s)
        self.assertIn('L.storm_beam() == 1 && L.storm_unstable()', s)
        self.assertNotIn('storm_beam_seconds', s)
        self.assertNotIn('hull_ledgers', s)
        self.assertNotIn('add_water', s)
        self.assertNotIn('crew_message', s)


if __name__ == '__main__':
    unittest.main()
