"""Execute the melee attack source with an injected parent, not a BYOND game."""
import importlib.util
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/objects/items/weapons/swords_axes_etc.dm'
DECL = '/obj/item/weapon/melee/attack'
spec = importlib.util.spec_from_file_location('dm_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)


class Actor:
    def __init__(self, intent):
        self.a_intent = intent


class Weapon:
    force_multiplier = 1.2
    force_divisor = 3
    weakens = 0
    weaken_chance = 40

    def __init__(self, force, initial_force):
        self.force = force
        self.initial_force = initial_force
        self.contacts = []

    def attack(self, intent):
        user = Actor(intent)
        body = adapter.extract(SOURCE.read_text(encoding='utf-8'), DECL)
        switch = ('switch (user.a_intent) // harm intent lets us murder people, others not so much - Kachnov\n'
                  '\t\tif (I_HARM)\n\t\t\tforce *= force_multiplier\n'
                  '\t\tif (I_HELP, I_GRAB, I_DISARM)\n\t\t\tforce /= force_divisor')
        replacement = ('if (user.a_intent == I_HARM)\n\t\tforce *= force_multiplier\n'
                       '\telse if (user.a_intent in (I_HELP, I_GRAB, I_DISARM))\n\t\tforce /= force_divisor')
        if switch not in body:
            raise AssertionError('Unexpected melee intent dispatch')
        body = body.replace(switch, replacement)
        body = body.replace('..(M, user, target_zone)', 'parent(M, user, target_zone)')
        for field in ('force', 'force_multiplier', 'force_divisor', 'weakens', 'weaken_chance'):
            body = re.sub(r'(?<![\w.])' + field + r'\b', 'src.' + field, body)
        source = DECL + '(mob/M, mob/user, target_zone)\n' + body + '\n'

        def parent(_target, _user, _zone):
            self.contacts.append(self.force)

        proc = adapter.project(source, DECL, 'src,M,user,target_zone', {
            'I_HARM': 'harm', 'I_HELP': 'help', 'I_GRAB': 'grab', 'I_DISARM': 'disarm',
            'parent': parent, 'prob': lambda _: False, 'initial': lambda _: self.initial_force,
        }, method=True)
        proc(self, object(), user, 'chest')
        self.assert_intent = user.a_intent


class MeleeForceTests(unittest.TestCase):
    def test_variable_baton_force_survives_consecutive_attacks(self):
        for force in (3, 15):
            for intent, expected in (('harm', force * 1.2), ('help', force / 3)):
                with self.subTest(force=force, intent=intent):
                    baton = Weapon(force, initial_force=0)
                    baton.attack(intent)
                    baton.attack(intent)
                    self.assertEqual(baton.contacts, [expected, expected])
                    self.assertEqual(baton.force, force)
                    self.assertEqual(baton.assert_intent, intent)

    def test_fixed_force_weapon_keeps_its_force(self):
        weapon = Weapon(9, initial_force=9)
        weapon.attack('harm')
        weapon.attack('help')
        self.assertAlmostEqual(weapon.contacts[0], 10.8)
        self.assertEqual(weapon.contacts[1], 3)
        self.assertEqual(weapon.force, 9)


if __name__ == '__main__':
    unittest.main()
