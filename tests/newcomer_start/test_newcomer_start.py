#!/usr/bin/env python3
"""Offline source contracts for new players starting near people."""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8', errors='replace').replace('\r\n', '\n')


SOURCE = read('code/game/objects/map_metadata/nomads/newcomer_start.dm')
START = read('code/game/objects/map_metadata/nomads/nomads_start.dm')


class NewcomerStart(unittest.TestCase):
    def test_compiled_once(self):
        self.assertEqual(read('civ13.dme').count('nomads\\newcomer_start.dm"'), 1)

    def test_only_new_accounts_and_only_safe_tiles(self):
        pick = SOURCE[SOURCE.index('/obj/map_metadata/nomads/proc/pick_newcomer_ground('):]
        self.assertIn('!new_player_marks.is_new(C)', pick)
        near = SOURCE[SOURCE.index('/obj/map_metadata/nomads/proc/newcomer_ground_near('):SOURCE.index('/obj/map_metadata/nomads/proc/pick_newcomer_ground(')]
        self.assertIn('new_player_has_exit(T)', near)

    def test_the_band_keeps_newcomers_out_of_the_camp_itself(self):
        low = int(re.search(r'#define NEWCOMER_MIN_DISTANCE (\d+)', SOURCE)[1])
        high = int(re.search(r'#define NEWCOMER_MAX_DISTANCE (\d+)', SOURCE)[1])
        self.assertGreaterEqual(low, 30)
        self.assertGreater(high, low)

    def test_hosts_are_awake_connected_and_outdoors(self):
        hosts = SOURCE[SOURCE.index('/obj/map_metadata/nomads/proc/newcomer_hosts()'):SOURCE.index('/obj/map_metadata/nomads/proc/newcomer_gathering(')]
        for guard in ('for (var/client/C in clients)', 'H.stat != CONSCIOUS', 'T.z != new_player_start_z', 'A.location != AREA_OUTSIDE', '/mob/living/human/practice'):
            self.assertIn(guard, hosts)

    def test_nobody_is_put_into_a_faction(self):
        self.assertNotIn('civilization =', SOURCE)
        self.assertNotIn('faction =', SOURCE)

    def test_random_start_remains_the_fallback(self):
        self.assertIn('if (near_people)\n\t\treturn near_people\n\treturn pick_new_player_ground()', START)


if __name__ == '__main__':
    unittest.main()
