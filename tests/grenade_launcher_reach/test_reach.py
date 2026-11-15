"""Grenade launchers: loading must not finish out of reach (#5526).

Offline source check; no compiler, game or network. The completion guard is
modelled from its DM conditions and the attackby order is checked.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/weapons/guns/grenade_launcher.dm'
LEGACY_ATTACKBY = '''/obj/item/weapon/gun/launcher/grenade/attackby(obj/item/I, mob/user)
	if ((istype(I, /obj/item/weapon/grenade)))
		if (do_after(user, 10, src, can_move = TRUE))
			load(I, user)
'''


def block(text, header):
    match = re.search(r'^' + re.escape(header) + r'.*?(?=^\S)', text, re.M | re.S)
    if not match:
        raise AssertionError('missing ' + header)
    return match.group(0)


def finishes(attackby, guard_body, *, held, adjacent, waited=True):
    """Model whether a grenade is loaded, from the source text."""
    if not waited:
        return False
    if '&& can_finish_loading(I, user)' not in attackby:
        return True
    if 'user.get_active_hand() != G' in guard_body and not held:
        return False
    if '!Adjacent(user)' in guard_body and not adjacent:
        return False
    return True


class GrenadeLauncherReachTests(unittest.TestCase):
    def setUp(self):
        self.text = SOURCE.read_text(encoding='utf-8-sig')
        self.attackby = block(self.text, '/obj/item/weapon/gun/launcher/grenade/attackby(')
        self.guard = block(self.text, '/obj/item/weapon/gun/launcher/grenade/proc/can_finish_loading(')

    def test_out_of_reach_does_not_load(self):
        self.assertFalse(finishes(self.attackby, self.guard, held=True, adjacent=False))

    def test_grenade_no_longer_held_does_not_load(self):
        self.assertFalse(finishes(self.attackby, self.guard, held=False, adjacent=True))

    def test_in_reach_and_held_loads(self):
        self.assertTrue(finishes(self.attackby, self.guard, held=True, adjacent=True))

    def test_negative_control_legacy_loads_out_of_reach(self):
        self.assertTrue(finishes(LEGACY_ATTACKBY, self.guard, held=True, adjacent=False))

    def test_guard_runs_after_wait_and_before_load(self):
        self.assertIn('if (do_after(user, 10, src, can_move = TRUE) && can_finish_loading(I, user))\n\t\t\tload(I, user)',
                      self.attackby)
        self.assertIn('QDELETED(G)', self.guard)


if __name__ == '__main__':
    unittest.main()
