"""An incapacitated holder cannot discharge a lit flamethrower (issue #6257).

The production fire() body runs through the shared source adapter. Messages,
the fuel tank and process_fire are inert test boundaries.
"""
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests/save_movement'))
from source_adapter import extract, project

SOURCE = (ROOT / 'code/modules/1713/weapons/flamethrower.dm').read_text(encoding='utf-8')
DECL = '/obj/item/weapon/flamethrower/proc/fire'
TANK = '/obj/item/weapon/reagent_containers/glass/flamethrower'


class World:
    time = 100


class Reagents:
    def __init__(self, fuel):
        self.fuel = fuel

    def get_reagent_amount(self, name):
        return self.fuel if name == 'gasoline' else 0


class Tank:
    type = TANK

    def __init__(self, fuel=50):
        self.reagents = Reagents(fuel)


class Holder:
    def __init__(self, **state):
        self.stat = self.paralysis = self.stunned = self.weakened = 0
        self.dir, self.back = 1, Tank()
        for key, value in state.items():
            setattr(self, key, value)

    def has_empty_hand(self, both=True):
        return True


class Flamethrower:
    def __init__(self):
        self.active, self.lastfire, self.fired = True, 0, []

    def process_fire(self, H, FM, cdir, target):
        self.fired.append(H)


def load():
    body = extract(SOURCE, DECL)
    for name in ('active', 'lastfire', 'process_fire'):
        body = body.replace(name, 'src.' + name) if name != 'active' else body.replace('!active', '!src.active')
    env = {'world': World, 'to_chat': lambda *a: None, 'SPAN_WARNING': str,
           'istype': lambda obj, kind: getattr(obj, 'type', None) == kind}
    return project('/fire()\n' + body.replace('istype(H.back,/obj/item/weapon/reagent_containers/glass/flamethrower)',
                                              'istype(H.back, "' + TANK + '")'),
                   '/fire', 'src,H,cdir=None,target=None', env)


class IncapacitatedFireTests(unittest.TestCase):
    def setUp(self):
        self.fire = load()

    def test_able_holder_fires(self):
        gun = Flamethrower()
        self.fire(gun, Holder())
        self.assertEqual(len(gun.fired), 1)

    def test_incapacitated_holder_cannot_fire(self):
        for state in ({'stunned': 3}, {'paralysis': 3}, {'weakened': 3}, {'stat': 1}):
            gun = Flamethrower()
            self.fire(gun, Holder(**state))
            self.assertEqual(gun.fired, [], state)


if __name__ == '__main__':
    unittest.main()
