"""Replay the boiling-oil pot's pour and refill events from source, not BYOND."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/siege/boiling_oil.dm'

# The pre-fix delayed reset, frozen as a negative control.
OLD_SPLASH = '''obj/structure/boiling_oil/proc/splash()
	timer = 0
	icon_state = "oil_pot3"
	spawn(18)
		icon_state = "oil_pot0"
	spawn(8)
'''


def delayed_reset(source):
    """Return (guard, state) for the spawn(18) block in splash(): the timer it requires, if any."""
    splash = source[source.index('obj/structure/boiling_oil/proc/splash()'):]
    block = re.search(r'\tspawn\(18\)\n((?:\t\t.*\n)+)', splash).group(1)
    guard = re.search(r'if \(timer == (\d+)\)', block)
    state = re.search(r'icon_state = "(\w+)"', block).group(1)
    return (int(guard.group(1)) if guard else None), state


def replay(source, refill_before_reset):
    """Pour a ready pot, optionally refill it before the 18-decisecond callback, then run the callback."""
    guard, state = delayed_reset(source)
    timer, icon = 0, 'oil_pot3'  # splash() has just run
    if refill_before_reset:
        timer, icon = 1, 'oil_pot1'  # attackby() refill
    if guard is None or timer == guard:
        icon = state
    return icon


class BoilingOilSplashIconTest(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding='utf-8')

    def test_refill_during_pour_keeps_heating_icon(self):
        self.assertEqual(replay(self.source, True), 'oil_pot1')

    def test_ordinary_pour_shows_empty_pot(self):
        self.assertEqual(replay(self.source, False), 'oil_pot0')

    def test_refill_sets_heating_state(self):
        self.assertIn('timer = 1', self.source)
        self.assertIn('icon_state = "oil_pot1"', self.source)

    def test_negative_control_old_reset_overwrites_refill(self):
        self.assertEqual(replay(OLD_SPLASH, True), 'oil_pot0')


if __name__ == '__main__':
    unittest.main()
