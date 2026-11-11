"""Offline checks for the Status tab's "Playing, Observing, Lobby" line.

The old line used human_clients_mob_list and new_player_mob_list, which hold
mobs that may no longer have a client (lobby mobs left behind, humans whose
player disconnected), and derived Observing by subtraction, so it went
negative. Each bucket must now be counted from connected clients.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
MOB = (ROOT / 'code/game/mob/mob.dm').read_text(encoding='utf-8')


def body(source, header):
    start = source.index(header)
    first = source.index('\n', start) + 1
    match = re.search(r'^[/\w]', source[first:], re.M)
    return source[start:first + match.start()] if match else source[start:]


class PlayerCountStatus(unittest.TestCase):
    def test_line_uses_client_breakdown(self):
        stat = body(MOB, '/mob/Stat()')
        self.assertIn('var/list/population = client_population_breakdown()', stat)
        self.assertIn('"[population[1]], [population[2]], [population[3]]"', stat)
        self.assertNotIn('clients.len-human_clients_mob_list.len', stat)

    def test_every_bucket_counted_from_clients(self):
        proc = body(MOB, '/proc/client_population_breakdown()')
        self.assertIn('for (var/client/C in clients)', proc)
        for bucket in ('lobby++', 'playing++', 'observing++'):
            self.assertEqual(proc.count(bucket), 1, bucket)
        # One if/else-if/else chain: each client lands in exactly one bucket.
        self.assertIn('if (isnewplayer(M))', proc)
        self.assertIn('else if (isliving(M) && M.stat != DEAD)', proc)
        self.assertNotIn('.len-', proc)
        self.assertNotIn('mob_list', proc)


if __name__ == '__main__':
    unittest.main()
