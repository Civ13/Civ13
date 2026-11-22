"""Mounted bayonets aimed at the mouth (issue #6742).

Only hard masks turn the blade; any other mask takes the same 95% miss / 5%
hit roll as an uncovered mouth. Behaviour of bayonet_mouth_guard() is covered
natively by tests/bayonet_mouth/probe.dm:

    python3 tests/ecology_spawning/run_linux.py . tests/bayonet_mouth/probe.dm
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
GUN = (ROOT / 'code/modules/projectiles/gun.dm').read_text(encoding='utf-8')


def mouth_branch():
    start = GUN.index('if (user.targeted_organ == "mouth")')
    end = GUN.index('//your limbs are still only a 25% chance to hit', start)
    return GUN[start:end]


class BayonetMouth(unittest.TestCase):
    def test_roll_is_not_nested_under_any_mask(self):
        branch = mouth_branch()
        self.assertNotIn('if (H.wear_mask)', branch)
        guard = branch.index('if (hard_mask)')
        roll = branch.index('if (prob(95))')
        self.assertLess(guard, roll)
        # The roll sits at the guard's own depth, not inside it or an else.
        depth = lambda i: len(branch[:i].rsplit('\n', 1)[1]) - len(branch[:i].rsplit('\n', 1)[1].lstrip('\t'))
        self.assertEqual(depth(guard), depth(roll))

    def test_bounce_names_the_mask(self):
        branch = mouth_branch()
        self.assertIn("bounces off [H]'s [hard_mask]", branch)
        self.assertNotIn('wear_suit', branch)

    def test_guard_lists_only_hard_masks(self):
        proc = GUN.split('/obj/item/weapon/gun/proc/bayonet_mouth_guard(', 1)[1].split('\n/', 1)[0]
        for path in ('/obj/item/clothing/mask/samurai', '/obj/item/clothing/mask/stone', '/obj/item/clothing/mask/wooden'):
            self.assertIn(path, proc)
        self.assertNotIn('/obj/item/clothing/mask/gas', proc)


if __name__ == '__main__':
    unittest.main()
