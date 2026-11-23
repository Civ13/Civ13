"""Source checks for issue 6984: bows, slings and atlatls only load ammunition still in hand.
Native probe: python3 tests/ecology_spawning/run_linux.py . tests/bow_load_source/probe.dm
"""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BOW = ROOT / 'code/modules/1713/weapons/guns/bow.dm'


class BowLoadSourceTest(unittest.TestCase):
    def test_load_rechecks_source_after_wait(self):
        text = BOW.read_text(encoding='utf-8')
        start = text.index('/obj/item/weapon/gun/projectile/bow/load_ammo(')
        body = text[start:text.index('\n/obj/', start + 1)]
        snap = body.index('var/atom/source = A?.loc')
        wait = body.index('do_after(user, load_delay')
        check = body.index('if (!bow_load_source_ok(A, source, user))')
        self.assertLess(snap, wait)
        self.assertLess(wait, check)
        self.assertLess(check, body.index('user.next_load = world.time + 1'))

    def test_helper_requires_hand_or_held_handful(self):
        text = BOW.read_text(encoding='utf-8')
        start = text.index('/proc/bow_load_source_ok(')
        body = text[start:text.index('\n/obj/', start)]
        self.assertIn('A.loc != source', body)
        self.assertIn('istype(source, /obj/item/ammo_handful)', body)
        self.assertIn('source.loc == user', body)


if __name__ == '__main__':
    unittest.main()
