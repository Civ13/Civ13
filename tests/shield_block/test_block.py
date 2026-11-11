"""Execute shield source control flow with fake engine and effect boundaries."""
import importlib.util
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('shield_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)
SOURCE = (ROOT / 'code/game/objects/items/weapons/shields.dm').read_text(encoding='utf-8')


def projection(source, path, args, env):
    # Replace DM type literals and implicit receiver references at the fixture boundary.
    for kind in ('melee', 'material/hatchet', 'material/tes13/mace'):
        source = source.replace('/obj/item/weapon/' + kind + ')', repr(kind) + ')')
    source = re.sub(r'(?<![.\w])health\s*-=', 'src.health -=', source)
    for name in ('plating_wear', 'get_block_chance', 'apply_block_wear', 'check_health'):
        source = re.sub(r'(?<![.\w/])' + name + r'\(', 'src.' + name + '(', source)
    # Restore the selected declaration after receiver qualification.
    source = source.replace('/proc/src.', '/proc/').replace('/tes13/src.', '/tes13/')
    source = source.replace('/shield/src.', '/shield/')
    return adapter.project(source, path, args, env)


class Shield:
    def __init__(self, wear, factor=1):
        self.health = 100
        self.factor = factor
        self.wear = wear
        self.events = []

    def plating_wear(self, amount):
        self.events.append(('wear', amount))
        return amount * self.factor

    def get_block_chance(self, *args):
        self.events.append(('chance',))
        return 50

    def apply_block_wear(self, source):
        self.wear(self, source)

    def check_health(self):
        self.events.append(('health', self.health))


class User:
    dir = 1

    def __init__(self, incapacitated=False):
        self.disabled = incapacitated
        self.messages = []

    def incapacitated(self):
        return self.disabled

    def visible_message(self, message):
        self.messages.append(message)


class ShieldBlockTest(unittest.TestCase):
    def setUp(self):
        self.arc = True
        self.roll = True
        env = {'istype': lambda source, kind: kind in source,
               'reverse_direction': lambda direction: 2,
               'check_shield_arc': lambda *args: self.arc,
               'prob': lambda chance: self.roll}
        self.base = projection(SOURCE, '/obj/item/weapon/shield/proc/apply_block_wear', 'src, damage_source', env)
        self.tes = projection(SOURCE, '/obj/item/weapon/shield/tes13/apply_block_wear', 'src, damage_source', env)
        self.block = projection(SOURCE, '/obj/item/weapon/shield/handle_shield',
                                'src, user, damage, damage_source, attacker, def_zone, attack_text', env)

    def test_successful_blocks_preserve_wear_and_order(self):
        cases = [(self.base, {'melee'}, [10]), (self.base, {'material/hatchet'}, [10]),
                 (self.base, set(), [1]), (self.tes, {'melee'}, [2]),
                 (self.tes, {'material/hatchet'}, [2]), (self.tes, set(), [1]),
                 (self.tes, {'material/tes13/mace'}, [1, 10])]
        for wear, source, amounts in cases:
            for factor in (1, 0.5):
                with self.subTest(source=source, wear=wear, factor=factor):
                    shield, user = Shield(wear, factor), User()
                    self.assertTrue(self.block(shield, user, 5, source, None, None, 'the attack'))
                    expected_health = 100 - sum(amounts) * factor
                    self.assertEqual(shield.health, expected_health)
                    self.assertEqual(shield.events, [('chance',)] + [('wear', n) for n in amounts] + [('health', expected_health)])
                    self.assertEqual(len(user.messages), 1)

    def test_failed_blocks_have_no_wear_or_message(self):
        for gate in ('incapacitated', 'arc', 'roll'):
            with self.subTest(gate=gate):
                self.arc, self.roll = gate != 'arc', gate != 'roll'
                shield, user = Shield(self.tes), User(gate == 'incapacitated')
                self.assertFalse(self.block(shield, user, 5, {'material/tes13/mace'}, None, None, 'the attack'))
                self.assertEqual(shield.health, 100)
                self.assertFalse(user.messages)
                self.assertFalse(any(event[0] in ('wear', 'health') for event in shield.events))

    def test_tes_inherits_the_shared_handler(self):
        self.assertNotIn('/obj/item/weapon/shield/tes13/handle_shield(', SOURCE)


if __name__ == '__main__':
    unittest.main()
