"""Offline source-projection checks, not native BYOND gameplay evidence."""
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
GUNS = ROOT / 'code/modules/1713/weapons/guns'
spec = importlib.util.spec_from_file_location('chamber_source_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)
adapter.FIELDS += ('chambered', 'loaded')
BASE = '/obj/item/weapon/gun/projectile'


class Loaded(list):
    @property
    def len(self):
        return len(self)

    def __getitem__(self, index):
        return super().__getitem__(index - 1)

    def __isub__(self, casing):
        self.remove(casing)
        return self


class Casing:
    def __init__(self, bb):
        self.BB = bb
        self.loc = 'gun'
        self.rotations = 0

    def randomrotation(self):
        self.rotations += 1


class ChamberTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        source = (GUNS / '_gun.dm').read_text(encoding='utf-8')
        env = {'get_turf': lambda gun: gun.turf}
        cls.eject = staticmethod(adapter.project(source, BASE + '/proc/eject_chambered_casing', 'src', env, method=True))
        cls.feed = staticmethod(adapter.project(source, BASE + '/proc/feed_first_loaded_casing', 'src', env, method=True))

    def gun(self, chamber, *stock):
        return SimpleNamespace(chambered=chamber, loaded=Loaded(stock), turf='floor')

    def test_cycle_ejects_live_and_spent_before_feeding_fifo(self):
        for bb in (object(), None):
            old, first, second = Casing(bb), Casing(object()), Casing(object())
            gun = self.gun(old, first, second)
            self.eject(gun)
            self.feed(gun)
            self.assertEqual((old.loc, old.rotations), ('floor', 1))
            self.assertIs(gun.chambered, first)
            self.assertEqual(list(gun.loaded), [second])
            self.assertEqual(first.loc, 'gun')

    def test_empty_and_existing_chamber_feed_behavior(self):
        old, first = Casing(object()), Casing(object())
        empty = self.gun(None)
        self.eject(empty)
        self.feed(empty)
        self.assertIsNone(empty.chambered)
        gun = self.gun(old)
        self.feed(gun)
        self.assertIs(gun.chambered, old)
        gun.loaded.append(first)
        self.feed(gun)
        self.assertIs(gun.chambered, first)
        self.assertEqual((old.loc, old.rotations), ('gun', 0))

    def test_caller_order_and_action_specific_messages(self):
        shotgun = (GUNS / 'shotguns.dm').read_text(encoding='utf-8')
        lever = (GUNS / 'lever_action.dm').read_text(encoding='utf-8')
        revolver = (GUNS / 'revolvers.dm').read_text(encoding='utf-8')
        for source, declaration in ((shotgun, BASE + '/shotgun/pump/proc/pump'),
                                    (lever, BASE + '/leveraction/proc/pump')):
            body = adapter.extract(source, declaration)
            self.assertLess(body.index('playsound('), body.index('eject_chambered_casing()'))
            self.assertLess(body.index('eject_chambered_casing()'), body.index('feed_first_loaded_casing()'))
            self.assertLess(body.index('feed_first_loaded_casing()'), body.index('update_icon()'))
        body = adapter.extract(lever, BASE + '/leveraction/proc/pump')
        for message in ('cycles the [src]!', 'ejecting a spent casing!', 'ejecting an unused casing!'):
            self.assertLess(body.index(message), body.index('eject_chambered_casing()'))
        for source, subtype in ((shotgun, 'shotgun/coachgun'), (shotgun, 'shotgun/mts225'),
                                (revolver, 'revolver/derringer')):
            close = adapter.extract(source, BASE + '/' + subtype + '/attack_self')
            post = adapter.extract(source, BASE + '/' + subtype + '/handle_post_fire')
            self.assertLess(close.index('open = FALSE'), close.index('feed_first_loaded_casing()'))
            self.assertLess(close.index('feed_first_loaded_casing()'), close.index('else'))
            self.assertLess(close.index('feed_first_loaded_casing()'), close.index('recentpump = world.time'))
            self.assertLess(post.index('..()'), post.index('feed_first_loaded_casing()'))
            self.assertEqual(close.count('feed_first_loaded_casing()'), 1)
            self.assertEqual(post.count('feed_first_loaded_casing()'), 1)


if __name__ == '__main__':
    unittest.main()
