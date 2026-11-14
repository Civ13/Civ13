"""Rusty bolt effect: offline seam checks.

The native probe (probe.dm, run.py) checks the behaviour in a real build. These
checks keep the transmitter hooks in place: powered radio sets, radio (not TV)
station desks for live speech and lessons, and relay masts for arrivals.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


def proc(text, header):
    start = text.index(header)
    end = re.search(r'\n(?=/|#define|\Z)', text[start + 1:])
    return text[start:start + 1 + end.start()] if end else text[start:]


RUSTY = read('code/modules/1713/rusty_bolt.dm')
RADIO = read('code/modules/1713/radio.dm')
TELECOM = read('code/modules/1713/modern_telecom.dm')
RELAY = read('code/modules/1713/radio_relay.dm')
DME = read('civ13.dme')


class RustyBoltSources(unittest.TestCase):
    def test_included_after_its_callers(self):
        self.assertIn('#include "code\\modules\\1713\\rusty_bolt.dm"', DME)

    def test_radio_broadcast_hook(self):
        self.assertIn('rusty_bolt_from_radio(R, msg, speaker)', proc(RADIO, '/proc/radio_broadcast('))
        helper = proc(RUSTY, '/proc/rusty_bolt_from_radio(')
        self.assertIn('istype(R, /obj/structure/radio)', helper)
        self.assertIn('check_power()', helper)

    def test_station_hooks_are_radio_only(self):
        live = proc(TELECOM, '/obj/structure/telecom/station/proc/transmit_live(')
        self.assertIn('\n\tif (!television) rusty_bolt_reradiate(src, message, speaking)\n', live)
        lesson = proc(TELECOM, '/obj/structure/telecom/station/proc/transmit_lesson(')
        self.assertRegex(lesson, r'if \(!television\)\n\t\trusty_bolt_reradiate\(src, telecom_lesson_text\(program, line\), null\)')
        self.assertLess(lesson.index('if (!prepared || !line'), lesson.index('rusty_bolt_reradiate'))

    def test_relay_arrival_hook(self):
        body = proc(RELAY, '/proc/civ_relay_rebroadcast(')
        self.assertIn('rusty_bolt_reradiate(origin, message, speaker.language)', body)

    def test_bounded(self):
        for name, value in (('RUSTY_BOLT_RANGE', 6), ('RUSTY_BOLT_HEAR_RANGE', 2),
                            ('RUSTY_BOLT_MAX_SOURCES', 3), ('RUSTY_BOLT_MAX_LISTENERS', 12)):
            self.assertIn(f'#define {name} {value}\n', RUSTY)


if __name__ == '__main__':
    unittest.main()
