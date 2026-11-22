"""Offline source contract for motorcycle refuelling (#6733).

Behaviour is covered natively by tests/motorcycle_refuel/probe.dm.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/game/objects/structures/transports.dm').read_text(encoding='utf-8-sig')
REFUEL = SOURCE.split('/obj/structure/vehicle/motorcycle/proc/motorcycle_refuel(', 1)[1].split('\n/', 1)[0]
ATTACK = SOURCE.split('/obj/structure/vehicle/motorcycle/attackby(', 1)[1].split('\n/', 1)[0]


class MotorcycleRefuel(unittest.TestCase):
    def test_attackby_uses_engine_fuels(self):
        self.assertIn('motorcycle_refuel(W, user)', ATTACK)
        self.assertNotIn('"gasoline"', ATTACK)

    def test_refuel_loops_engine_fuels_within_room(self):
        self.assertIn('engine.fuels', REFUEL)
        self.assertIn('min(room, GC.reagents.get_reagent_amount(fuel))', REFUEL)
        self.assertIn('room -= amount', REFUEL)


if __name__ == '__main__':
    unittest.main()
