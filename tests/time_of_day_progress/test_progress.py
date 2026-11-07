"""Offline complete-source projection; no compiler, native world or network.

Every executable helper line must have an audited translation. DM lists, numeric
rounding and process state are explicit inert boundaries, not native evidence.
"""
from copy import deepcopy
import importlib.util
import math
from pathlib import Path
import re
from types import SimpleNamespace as NS
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
PATH = 'code/processes/time_of_day_progress.dm'
SOURCE = (ROOT / PATH).read_text()
DEFINES = (ROOT / 'code/__defines/time_of_day.dm').read_text()
CYCLE = re.findall(r'"([^"]+)"', re.search(r'var/list/times_of_day = list\(([^\n]+)\)', DEFINES)[1])
DURATIONS = {name: int(minutes) * int(seconds) for name, minutes, seconds in
             re.findall(r'"([^"]+)" = (\d+)\*(\d+)', DEFINES)}


class DMList(list):
    @property
    def len(self):
        return len(self)

    def __getitem__(self, position):
        return super().__getitem__(position - 1)


def body(source, signature):
    match = re.search(r'^' + re.escape(signature) + r'\n(.*?)(?=^/|\Z)', source, re.M | re.S)
    if not match:
        raise AssertionError('Missing helper: ' + signature)
    return match[1]


# Translate the complete production procedures, never a separately maintained
# implementation of their logic. A new/unknown executable line fails closed.
OPERATIONS = {
    'if (!config || !config.daynight_on || !roundstart_time || !TOD_loop_started || persistence_save_in_progress)':
        'if not config or not config.daynight_on or not roundstart_time or not TOD_loop_started or persistence_save_in_progress:',
    'if (disabled || paused || killed || !main || !main.isRunning || !may_fire())':
        'if disabled or paused or killed or not main or not main.isRunning or not may_fire():',
    'if (!isnum(schedule_interval) || schedule_interval <= 0)':
        'if not isnum(schedule_interval) or schedule_interval <= 0:',
    'if (!map || !islist(map.times_of_day) || map.times_of_day.len < 2 || !islist(times_of_day) || times_of_day.len < 2)':
        'if not map or not islist(map.times_of_day) or map.times_of_day.len < 2 or not islist(times_of_day) or times_of_day.len < 2:',
    'return null': 'return None',
    'var/position = 0': 'position = 0',
    'for (var/i = 1 to times_of_day.len)': 'for i in range(1, times_of_day.len + 1):',
    'if (times_of_day[i] == time_of_day)': 'if times_of_day[i] == time_of_day:',
    'position = i': 'position = i',
    'if (!position)': 'if not position:',
    'var/next_phase = times_of_day[(position % times_of_day.len) + 1]':
        'next_phase = times_of_day[(position % times_of_day.len) + 1]',
    'if (!istext(next_phase) || !length(next_phase) || next_phase == time_of_day)':
        'if not isinstance(next_phase, str) or not len(next_phase) or next_phase == time_of_day:',
    'if (!islist(time_of_day2ticks))': 'if not isinstance(time_of_day2ticks, dict):',
    'var/duration = time_of_day2ticks[time_of_day]': 'duration = time_of_day2ticks.get(time_of_day)',
    'if (!isnum(duration) || duration <= 0 || !isnum(TOD_ticks) || TOD_ticks < 0)':
        'if not isnum(duration) or duration <= 0 or not isnum(TOD_ticks) or TOD_ticks < 0:',
    'if (TOD_may_automatically_change || TOD_ticks >= duration)':
        'if TOD_may_automatically_change or TOD_ticks >= duration:',
    'return "changing to [next_phase]"': 'return f"changing to {next_phase}"',
    'var/quarter = clamp(round(TOD_ticks / duration * 4) + 1, 1, 4)':
        'quarter = min(max(math.floor(TOD_ticks / duration * 4) + 1, 1), 4)',
    'var/remaining = duration - TOD_ticks': 'remaining = duration - TOD_ticks',
    'var/time_left = remaining < 60 ? "under a minute" : "~[ceil(remaining / 60)] min"':
        'time_left = "under a minute" if remaining < 60 else f"~{math.ceil(remaining / 60)} min"',
    'return "quarter [quarter]/4, [time_left] until [next_phase]"':
        'return f"quarter {quarter}/4, {time_left} until {next_phase}"',
    'var/text = time_of_day': 'text = time_of_day',
    'if (processes && processes.time_of_day)': 'if processes and processes.time_of_day:',
    'var/progress = processes.time_of_day.progress_text()': 'progress = processes.time_of_day.progress_text()',
    'if (progress)': 'if progress:',
    'text += " ([progress])"': 'text += f" ({progress})"',
    'return text': 'return text',
}


def project(source, signature, env):
    lines = ['def projected():']
    for raw in body(source, signature).splitlines():
        statement = raw.split('//', 1)[0].strip()
        if not statement:
            continue
        depth = len(raw) - len(raw.lstrip('\t'))
        lines.append('    ' * depth + OPERATIONS[statement])
    scope = dict(env, math=math, isnum=lambda value: type(value) in (int, float),
                 islist=lambda value: isinstance(value, DMList))
    exec('\n'.join(lines), scope)
    return scope['projected']


def state(**changes):
    env = dict(config=NS(daynight_on=True), roundstart_time=1, TOD_loop_started=True,
               persistence_save_in_progress=False, disabled=False, paused=False, killed=False,
               main=NS(isRunning=True), may_fire=lambda: True, schedule_interval=100,
               map=NS(times_of_day=DMList(CYCLE)), times_of_day=DMList(CYCLE),
               time_of_day='Morning', time_of_day2ticks=dict(DURATIONS), TOD_ticks=0,
               TOD_may_automatically_change=False)
    env.update(changes)
    return env


def progress(env, source=SOURCE):
    return project(source, '/process/time_of_day/proc/progress_text()', env)()


def display(env, source=SOURCE):
    return project(source, '/proc/get_time_of_day_with_progress()',
                   dict(env, processes=NS(time_of_day=NS(progress_text=lambda: progress(env, source)))))()


class ProgressTests(unittest.TestCase):
    def test_all_default_phases_and_night_wrap(self):
        self.assertEqual(len(CYCLE), 6)
        for index, phase in enumerate(CYCLE):
            with self.subTest(phase=phase):
                self.assertEqual(DURATIONS[phase], 1200)
                self.assertEqual(display(state(time_of_day=phase)),
                    f'{phase} (quarter 1/4, ~20 min until {CYCLE[(index + 1) % len(CYCLE)]})')

    def test_quarter_boundaries_and_minute_rounding(self):
        for elapsed, quarter, left in ((0, 1, '~20 min'), (299, 1, '~16 min'),
                (300, 2, '~15 min'), (599, 2, '~11 min'), (600, 3, '~10 min'),
                (899, 3, '~6 min'), (900, 4, '~5 min'), (1139, 4, '~2 min'),
                (1140, 4, '~1 min'), (1141, 4, 'under a minute'), (1199, 4, 'under a minute')):
            with self.subTest(elapsed=elapsed):
                self.assertEqual(progress(state(TOD_ticks=elapsed)),
                                 f'quarter {quarter}/4, {left} until Midday')

    def test_configured_duration_uses_seconds_not_deciseconds(self):
        for duration, elapsed, expected in ((1800, 450, 'quarter 2/4, ~23 min until Midday'),
                (60, 0, 'quarter 1/4, ~1 min until Midday'),
                (30, 0, 'quarter 1/4, under a minute until Midday'),
                (90, 45, 'quarter 3/4, under a minute until Midday')):
            env = state(TOD_ticks=elapsed)
            env['time_of_day2ticks']['Morning'] = duration
            self.assertEqual(progress(env), expected)

    def test_custom_global_cycle_beats_different_map_order(self):
        env = state(times_of_day=DMList(['Night', 'Morning', 'Evening']))
        self.assertEqual(progress(env), 'quarter 1/4, ~20 min until Evening')
        env['time_of_day'] = 'Evening'
        self.assertEqual(progress(env), 'quarter 1/4, ~20 min until Night')

    def test_duplicate_phase_matches_transition_last_position(self):
        env = state(times_of_day=DMList(['Morning', 'Evening', 'Morning', 'Night']))
        self.assertEqual(progress(env), 'quarter 1/4, ~20 min until Night')

    def test_pending_gate_never_claims_a_fresh_phase(self):
        for elapsed in (0, 10, 1190):
            self.assertEqual(display(state(TOD_may_automatically_change=True, TOD_ticks=elapsed)),
                             'Morning (changing to Midday)')
        self.assertEqual(display(state(time_of_day='Midday', TOD_ticks=0)),
                         'Midday (quarter 1/4, ~20 min until Afternoon)')

    def test_disable_resume_and_restore_preserve_counter_and_gate(self):
        env = state(TOD_ticks=900)
        self.assertEqual(display(env), 'Morning (quarter 4/4, ~5 min until Midday)')
        env['config'].daynight_on = False
        self.assertEqual(display(env), 'Morning')
        env['config'].daynight_on = True
        self.assertEqual(display(env), 'Morning (quarter 4/4, ~5 min until Midday)')
        env.update(TOD_ticks=0, TOD_may_automatically_change=True)
        env['config'].daynight_on = False
        self.assertEqual(display(env), 'Morning')
        env['config'].daynight_on = True
        self.assertEqual(display(env), 'Morning (changing to Midday)')
        restored = deepcopy(env)
        self.assertEqual(display(restored), 'Morning (changing to Midday)')
        restored.update(time_of_day='Midday', TOD_may_automatically_change=False)
        self.assertEqual(display(restored), 'Midday (quarter 1/4, ~20 min until Afternoon)')

    def test_at_and_after_duration_never_shows_negative_time(self):
        for elapsed in (1200, 1210, 9999):
            self.assertEqual(progress(state(TOD_ticks=elapsed)), 'changing to Midday')

    def test_inactive_and_paused_states_keep_only_original_label(self):
        cases = [dict(config=None), dict(config=NS(daynight_on=False)), dict(roundstart_time=0),
                 dict(TOD_loop_started=False), dict(persistence_save_in_progress=True),
                 dict(disabled=True), dict(paused=True), dict(killed=True), dict(main=None),
                 dict(main=NS(isRunning=False)), dict(may_fire=lambda: False), dict(map=None)]
        for changes in cases:
            with self.subTest(changes=changes):
                self.assertEqual(display(state(**changes)), 'Morning')
                self.assertEqual(display(state(TOD_may_automatically_change=True, **changes)), 'Morning')

    def test_fixed_missing_and_invalid_cycles_keep_only_original_label(self):
        for cycle in (None, 'Morning', DMList(), DMList(['Morning'])):
            self.assertEqual(display(state(times_of_day=cycle)), 'Morning')
            self.assertEqual(display(state(map=NS(times_of_day=cycle))), 'Morning')
        self.assertEqual(display(state(time_of_day='Dark Night', map=NS(times_of_day=DMList(['Dark Night'])))),
                         'Dark Night')

    def test_unknown_current_or_invalid_next_phase_has_no_countdown(self):
        self.assertEqual(display(state(time_of_day='Unknown')), 'Unknown')
        for next_phase in (None, '', 42, 'Morning'):
            self.assertEqual(display(state(times_of_day=DMList(['Morning', next_phase]))), 'Morning')

    def test_invalid_durations_counters_and_intervals_do_not_guess(self):
        for value in (None, '1200', 0, -1):
            env = state()
            env['time_of_day2ticks']['Morning'] = value
            self.assertEqual(display(env), 'Morning')
            self.assertEqual(display(state(schedule_interval=value)), 'Morning')
        for value in (None, '300', -1):
            self.assertEqual(display(state(TOD_ticks=value)), 'Morning')
        self.assertEqual(display(state(time_of_day2ticks={})), 'Morning')
        for table in (None, 0, 'invalid'):
            self.assertEqual(display(state(time_of_day2ticks=table)), 'Morning')

    def test_no_process_keeps_original_label(self):
        for processes in (None, NS(time_of_day=None)):
            env = dict(state(), processes=processes)
            self.assertEqual(project(SOURCE, '/proc/get_time_of_day_with_progress()', env)(), 'Morning')

    def test_repeated_reads_do_not_mutate_or_advance_any_state(self):
        env = state(TOD_ticks=600)
        before = deepcopy(env)
        for _ in range(3):
            self.assertEqual(display(env), 'Morning (quarter 3/4, ~10 min until Midday)')
        self.assertEqual(env, before)
        for forbidden in ('spawn(', 'sleep(', 'progress_time_of_day(', 'update_lighting(', 'durable_schedule'):
            self.assertNotIn(forbidden, SOURCE)
        self.assertNotRegex(SOURCE, r'^\s*(?:TOD_ticks|TOD_may_automatically_change|time_of_day)\s*=(?!=)')

    def test_status_wiring_and_existing_timer_units(self):
        self.assertIn('client.add_stat("<b>Time of Day:</b>", get_time_of_day_with_progress())',
                      (ROOT / 'code/game/mob/mob.dm').read_text())
        self.assertIn('#include "code\\processes\\time_of_day_progress.dm"', (ROOT / 'civ13.dme').read_text())
        timer = (ROOT / 'code/processes/time_of_day.dm').read_text()
        self.assertIn('TOD_ticks += schedule_interval/10', timer)
        self.assertRegex(timer, r'TOD_ticks = 0\n\s*game_hour = 0\n\s*TOD_may_automatically_change = TRUE')
        self.assertIn('if (times_of_day[v] == time_of_day)\n\t\t\t\tTOD_position_in_list = v', DEFINES)

    def test_unknown_executable_statement_is_rejected(self):
        broken = SOURCE.replace('var/position = 0', 'do_unreviewed_work()')
        with self.assertRaises(KeyError):
            progress(state(), broken)

    def test_negative_control_missing_gate_is_detected(self):
        broken = SOURCE.replace('if (TOD_may_automatically_change || TOD_ticks >= duration)',
                                'if (!position)')
        self.assertNotEqual(progress(state(TOD_may_automatically_change=True), broken), 'changing to Midday')

    def test_ci_registration_is_explicit_and_additive(self):
        spec = importlib.util.spec_from_file_location('tod_ci_baseline', ROOT / 'scripts/ci_baseline.py')
        ci = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(ci)
        name = 'time_of_day_progress'
        suite = ci.SUITES[name]
        self.assertEqual(suite['files'], ('tests/time_of_day_progress/test_progress.py',))
        prior = {key: value for key, value in ci.SUITES.items() if key != name}
        for path in suite['shared_paths']:
            with patch.object(ci, 'SUITES', prior):
                old = ci.impact([path])
            current = ci.impact([path])
            old_selected = {key for key, value in old['suites'].items() if value['selected']}
            current_selected = {key for key, value in current['suites'].items() if value['selected']}
            self.assertEqual(current_selected, old_selected | {name})
            self.assertEqual(current['fallback_reasons'], old['fallback_reasons'])
        self.assertFalse(ci.impact(['README.md'])['suites'][name]['selected'])


if __name__ == '__main__':
    unittest.main()
