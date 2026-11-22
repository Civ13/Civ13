"""Suit patching waits on the wearer, not the worn suit (issue #6746).

Behaviour is covered natively (still wearer patched; a wearer who walks away
keeps the kit and the suit unchanged):

    python3 tests/ecology_spawning/run_linux.py . tests/suit_patch_wait/probe.dm
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/space/pressure_suits.dm').read_text(encoding='utf-8')


class SuitPatchWait(unittest.TestCase):
    def body(self):
        return SOURCE.split('/obj/item/pressure_suit_patch/proc/patch(', 1)[1].split('\n/', 1)[0]

    def test_waits_on_the_wearer(self):
        body = self.body()
        self.assertIn('wait_target = wearer', body)
        self.assertIn('do_after(user, 30, wait_target)', body)
        self.assertNotIn('do_after(user, 30, S)', body)

    def test_rechecks_wearer_before_patching(self):
        body = self.body()
        recheck = body.index('S.loc != wearer || wearer.wear_suit != S || !user.Adjacent(wearer)')
        self.assertLess(body.index('do_after('), recheck)
        self.assertLess(recheck, body.index('S.integrity = min('))
        self.assertLess(recheck, body.index('qdel(src)'))


if __name__ == '__main__':
    unittest.main()
