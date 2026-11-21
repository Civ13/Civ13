"""Skull Island's grace-end ship transfer fires once (issue #6243).

The production tick body runs through the shared source adapter. The parent
tick, the world teleporter list and the round clock are inert test boundaries.
"""
from pathlib import Path
import re
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests/save_movement'))
from source_adapter import extract, project

SOURCE = (ROOT / 'code/game/objects/map_metadata/skullisland.dm').read_text(encoding='utf-8')
DECL = '/obj/map_metadata/skullisland/tick'


class Teleporter:
    type = '/obj/effect/area_teleporter'

    def __init__(self):
        self.activations = 0

    def Activated(self):
        self.activations += 1


class Ticker:
    playtime_elapsed = 0


class Processes:
    ticker = Ticker


class Map:
    do_once_activations = True


def load(teleporters, admin_ended=False):
    body = extract(SOURCE, DECL)
    body = body.replace('..()', 'parent_tick()')
    body = body.replace('for (var/obj/effect/area_teleporter/AT)',
                        'for (var/obj/effect/area_teleporter/AT in world)')
    body = re.sub(r'(?<![\w.])do_once_activations\b', 'src.do_once_activations', body)
    env = {'processes': Processes, 'admin_ended_all_grace_periods': admin_ended,
           'parent_tick': lambda: None, 'world': teleporters,
           'typed_iter': lambda where, kind: [t for t in where if t.type == kind]}
    return project('/tick()\n' + body, '/tick', 'src', env)


class GraceTransferTests(unittest.TestCase):
    def setUp(self):
        Ticker.playtime_elapsed = 0

    def run_ticks(self, count, admin_ended=False):
        teleporters = [Teleporter() for _ in range(3)]
        tick, ship = load(teleporters, admin_ended), Map()
        for _ in range(count):
            tick(ship)
        return teleporters, ship

    def test_nothing_moves_during_grace(self):
        teleporters, ship = self.run_ticks(5)
        self.assertEqual([t.activations for t in teleporters], [0, 0, 0])
        self.assertTrue(ship.do_once_activations)

    def test_grace_end_transfer_fires_once(self):
        Ticker.playtime_elapsed = 3000
        teleporters, ship = self.run_ticks(10)
        self.assertEqual([t.activations for t in teleporters], [1, 1, 1])
        self.assertFalse(ship.do_once_activations)

    def test_admin_grace_end_fires_once(self):
        teleporters, _ = self.run_ticks(4, admin_ended=True)
        self.assertEqual([t.activations for t in teleporters], [1, 1, 1])


if __name__ == '__main__':
    unittest.main()
