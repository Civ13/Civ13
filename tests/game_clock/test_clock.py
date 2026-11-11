"""Execute the production clock formatter through a small offline DM projection.

This checks source behavior, not BYOND runtime or in-game presentation.
"""
import importlib.util
import math
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location(
    'source_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)
SOURCE = ROOT / 'code/__defines/time_of_day.dm'


def clock(source):
    # Translate DM's switch labels to equivalent if/else-if tests. Everything
    # else is projected by the shared adapter, which fails on unknown syntax.
    body = source.split('/proc/clock_time()\n', 1)[1].split('\n#undef', 1)[0]
    lines = []
    in_switch = False
    labels = 0
    for line in body.splitlines():
        if line == '\tswitch(time_of_day)':
            if in_switch or labels:
                raise AssertionError('Unexpected clock switch')
            in_switch = True
            continue
        if in_switch and line.startswith('\t') and not line.startswith('\t\t'):
            in_switch = False
        if in_switch:
            line = line[1:]
            match = re.fullmatch(r'\tif \("([^"]+)"\)(.*)', line)
            if match:
                keyword = 'if' if labels == 0 else 'else if'
                line = f'\t{keyword} (time_of_day == "{match[1]}"){match[2]}'
                labels += 1
        line = re.sub(r'"([^"\n]*\[[A-Za-z_]\w*\][^"\n]*)"',
                      lambda m: 'f"' + re.sub(r'\[([A-Za-z_]\w*)\]', r'{\1}', m[1]) + '"', line)
        lines.append(line)
    if labels != 6 or in_switch:
        raise AssertionError('Unexpected clock switch structure')
    fixture = '/fixture/clock()\n' + '\n'.join(lines) + '\n'
    return adapter.project(fixture, '/fixture/clock', 'game_hour, time_of_day', {'Floor': math.floor})


class ClockTests(unittest.TestCase):
    def test_minute_boundaries(self):
        format_clock = clock(SOURCE.read_text(encoding='utf-8-sig'))
        for minutes, expected in ((0, '07:00 AM'), (2, '07:02 AM'),
                                  (58, '07:58 AM'), (60, '08:00 AM'),
                                  (62, '08:02 AM'), (118, '08:58 AM'),
                                  (120, '09:00 AM'), (180, '10:00 AM'),
                                  (238, '10:58 AM')):
            with self.subTest(minutes=minutes):
                self.assertEqual(format_clock(minutes, 'Morning'), expected)

    def test_noon_and_midnight(self):
        format_clock = clock(SOURCE.read_text(encoding='utf-8-sig'))
        for phase, minutes, expected in (
            ('Midday', 58, '11:58 AM'), ('Midday', 60, '12:00 PM'),
            ('Midday', 118, '12:58 PM'), ('Midday', 120, '01:00 PM'),
            ('Night', 58, '11:58 PM'), ('Night', 60, '12:00 AM'),
            ('Night', 118, '12:58 AM'), ('Night', 120, '01:00 AM'),
        ):
            with self.subTest(phase=phase, minutes=minutes):
                self.assertEqual(format_clock(minutes, phase), expected)

    def test_other_phases(self):
        format_clock = clock(SOURCE.read_text(encoding='utf-8-sig'))
        for phase, expected in (('Early Morning', '03:02 AM'),
                                ('Afternoon', '03:02 PM'), ('Evening', '07:02 PM')):
            with self.subTest(phase=phase):
                self.assertEqual(format_clock(2, phase), expected)


if __name__ == '__main__':
    unittest.main()
