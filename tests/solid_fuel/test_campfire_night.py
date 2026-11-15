"""A properly fuelled campfire lasts through a full night (Evening + Night)."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OVEN = (ROOT / 'code/game/objects/structures/kitchen/oven.dm').read_text(encoding='utf-8')
TOD = (ROOT / 'code/__defines/time_of_day.dm').read_text(encoding='utf-8')

NIGHT_LOGS = 5  # what the player guide calls a night's worth of logs


def phase_seconds(name):
    match = re.search(r'"%s"\s*=\s*(\d+)\s*\*\s*(\d+)' % name, TOD.split('time_of_day2ticks', 1)[1])
    return int(match.group(1)) * int(match.group(2))


def fireplace_block():
    return OVEN.split('\n/obj/structure/oven/fireplace\n', 1)[1].split('\n/obj/', 1)[0]


class CampfireNight(unittest.TestCase):
    def test_night_worth_of_logs_outlasts_the_dark(self):
        rate = float(re.search(r'fuel_per_cycle = ([0-9.]+)', fireplace_block()).group(1))
        fire = OVEN.split('/obj/structure/oven/fireplace/proc/keep_fire_on(', 1)[1].split('\n/obj/', 1)[0]
        self.assertIn('spawn(600)', fire)  # one burn per minute
        dark_minutes = (phase_seconds('Evening') + phase_seconds('Night')) / 60
        self.assertGreaterEqual(NIGHT_LOGS / rate, dark_minutes)
        self.assertEqual(1 / rate, 8.0)  # one log burns for 8 minutes

    def test_fire_loop_burns_the_device_rate(self):
        loop = OVEN.split('/obj/structure/oven/proc/fire_loop()', 1)[1].split('\n/obj/', 1)[0]
        self.assertIn('burn_structure_fuel(fuel_per_cycle)', loop)
        self.assertIn('var/fuel_per_cycle = 1', OVEN)  # ovens and stoves keep their old rate


if __name__ == '__main__':
    unittest.main()
