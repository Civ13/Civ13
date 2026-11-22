"""Offline source contract for #6697 and #6705.

Behaviour is covered natively by tests/stale_safety_disarm/probe.dm.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
BOLT = (ROOT / 'code/modules/1713/weapons/guns/bolt-action.dm').read_text(encoding='utf-8-sig')
MINES = (ROOT / 'code/game/objects/items/weapons/mines.dm').read_text(encoding='utf-8-sig')


class StaleSafetyDisarm(unittest.TestCase):
    def test_single_shot_checks_safety_first(self):
        check = BOLT.split('/obj/item/weapon/gun/projectile/boltaction/singleshot/special_check(', 1)[1].split('\n/', 1)[0]
        self.assertLess(check.index('if (gun_safety && safetyon)'), check.index('if (bolt_open)'))

    def test_every_disarm_wait_tracks_the_mine_and_revalidates(self):
        waits = re.findall(r'do_after\(user,\d+(,src)?\)', MINES)
        self.assertEqual(len(waits), 6)
        self.assertTrue(all(w == ',src' for w in waits))
        self.assertEqual(MINES.count('if (!disarm_attempt_valid(generation, start))'), 6)
        self.assertIn('arm_generation++', MINES.split('/obj/item/mine/attack_self(', 1)[1].split('\n/', 1)[0])


if __name__ == '__main__':
    unittest.main()
