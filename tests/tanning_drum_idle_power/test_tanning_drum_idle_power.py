"""A waiting tanning drum gives its grid reservation back (#6856)."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/factory_tanning.dm'


def block(text, header):
    start = text.index('\n' + header) + 1
    end = re.search(r'\n(?=\S)', text[start:])
    return text[start:start + end.start() if end else len(text)]


class TanningDrumIdlePowerTests(unittest.TestCase):
    def setUp(self):
        self.text = SOURCE.read_text(encoding='utf-8-sig').replace('\r\n', '\n')

    def test_wait_releases_a_held_reservation(self):
        wait = block(self.text, '/obj/structure/tanning_drum/proc/drum_wait(')
        self.assertIn('if (powersource && (src in powersource.power_consumers))', wait)
        self.assertIn('drum_release_power()', wait)

    def test_supplies_and_output_are_checked_before_power(self):
        step = block(self.text, '/obj/structure/tanning_drum/proc/drum_step(')
        draw = step.index('if (!draw_cable_power())')
        self.assertLess(step.index('return drum_wait("its tile is full")'), draw)
        self.assertLess(step.index('drum_supply_wait(wash)'), draw)
        # Bark that can still be soaked needs the drum turning, so power first.
        self.assertLess(step.index('if (!can_brew)'), draw)
        self.assertLess(draw, step.index('drum_brew()'))


if __name__ == '__main__':
    unittest.main()
