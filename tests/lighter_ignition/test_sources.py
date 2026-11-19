"""Offline source contract for lighter ignition (#6265).

Behaviour is covered natively by tests/lighter_ignition/probe.dm.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/game/objects/items/weapons/cigs_lighters.dm').read_text(encoding='utf-8-sig')
ATTACK = SOURCE.split('/obj/item/weapon/flame/lighter/attack(', 1)[1].split('\n/', 1)[0]


class LighterIgnition(unittest.TestCase):
    def test_only_a_lit_lighter_ignites(self):
        ignite = ATTACK.index('M.IgniteMob()')
        guard = ATTACK.rfind('\n', 0, ignite)
        guard_line = ATTACK[ATTACK.rfind('\n', 0, guard) + 1:guard]
        self.assertIn('if (lit)', guard_line)


if __name__ == '__main__':
    unittest.main()
