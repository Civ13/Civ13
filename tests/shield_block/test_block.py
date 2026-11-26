"""Execute shield source control flow with fake engine and effect boundaries."""
import importlib.util
from pathlib import Path
import re
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('shield_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)
SOURCE = (ROOT / 'code/game/objects/items/weapons/shields.dm').read_text(encoding='utf-8')
HUMAN_DEFENSE = adapter.read('code/game/mob/living/carbon/human/human_defense.dm')
ARROW = adapter.read('code/modules/projectiles/projectile/arrows.dm')
ARROW_TYPES = adapter.read('code/modules/projectiles/__projectiles.dm')


def projection(source, path, args, env):
    # Replace DM type literals and implicit receiver references at the fixture boundary.
    for kind in ('melee', 'material/hatchet', 'material/tes13/mace'):
        source = source.replace('/obj/item/weapon/' + kind + ')', repr(kind) + ')')
    source = source.replace('/obj/item/projectile/arrow)', '"/obj/item/projectile/arrow")')
    source = re.sub(r'(?<![.\w])health\s*-=', 'src.health -=', source)
    for name in ('get_block_chance', 'block_wear', 'apply_wear'):
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

    def block_wear(self, source):
        return self.wear(self, source)

    # Mirrors /obj/item/proc/apply_wear() in code/_helpers/item_wear.dm.
    def apply_wear(self, amount, cause):
        if cause == 'blow':
            amount = self.plating_wear(amount)
        self.health -= amount
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


def projectile_shield_check(env):
    bullet_act = adapter.extract(HUMAN_DEFENSE, '/mob/living/human/bullet_act')
    shield_check = bullet_act[bullet_act.index('\tvar/shield_check = '):].split(
        '\telse\n\t\t/* bullet grazing', 1)[0]
    shield_check = shield_check.replace('var/obj/item/weapon/shield/SH\n', 'SH = None\n')
    shield_check = re.sub(r'new(/obj/item/ammo_casing/[\w/]+)\(', r'drop_casing("\1", ', shield_check)
    shield_check = re.sub(r'(?<=, )(/obj/item/[\w/]+)(?=\))', r'"\1"', shield_check)
    shield_check = shield_check.replace('l_hand', 'src.l_hand').replace('r_hand', 'src.r_hand')
    for method in ('check_shields', 'visible_message'):
        shield_check = re.sub(r'(?<!\.)\b' + method + r'\(', 'src.' + method + '(', shield_check)
    return adapter.project('/shield_check()\n' + shield_check + '\treturn 0\n',
                           '/shield_check', 'src, P, def_zone', env)


def recover_from_shield(env):
    body = ARROW.replace('if (!shield_recovery_casing)', 'if (!src.shield_recovery_casing)')
    body = body.replace('new shield_recovery_casing(', 'drop_casing(src.shield_recovery_casing, ')
    body = body.replace('/obj/item/projectile/arrow/bolt)', '"/obj/item/projectile/arrow/bolt")')
    return adapter.project(body, '/obj/item/projectile/arrow/proc/recover_from_shield',
                           'src, defender', env)


class ShieldBlockTest(unittest.TestCase):
    def setUp(self):
        self.arc = True
        self.roll = True
        env = {'istype': lambda source, kind: kind in getattr(source, 'kinds', source or ()),
               'reverse_direction': lambda direction: 2,
               'check_shield_arc': lambda *args: self.arc,
               'prob': lambda chance: self.roll, 'WEAR_BLOW': 'blow'}
        self.base = projection(SOURCE, '/obj/item/weapon/shield/proc/block_wear', 'src, damage_source', env)
        self.tes = projection(SOURCE, '/obj/item/weapon/shield/tes13/block_wear', 'src, damage_source', env)
        self.block = projection(SOURCE, '/obj/item/weapon/shield/handle_shield',
                                'src, user, damage, damage_source, attacker, def_zone, attack_text', env)

    def test_successful_blocks_preserve_wear_and_order(self):
        cases = [(self.base, {'melee'}, [10]), (self.base, {'material/hatchet'}, [10]),
                 (self.base, set(), [1]), (self.tes, {'melee'}, [2]),
                 (self.tes, {'material/hatchet'}, [2]), (self.tes, set(), [1]),
                 (self.tes, {'material/tes13/mace'}, [11])]
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

    def test_player_projectile_has_one_authoritative_shield_result(self):
        for family in ('arrow', 'bolt'):
            for case in ('rear', 'incapacitated', 'failed roll', 'recovered', 'shattered'):
                with self.subTest(family=family, case=case):
                    self.arc = case != 'rear'
                    self.roll = case != 'failed roll'
                    shield = Shield(self.base, factor=0.5)
                    shield.kinds = {'/obj/item/weapon/shield'}
                    defender = User(case == 'incapacitated')
                    defender.l_hand, defender.r_hand = shield, None
                    defender.check_shields = lambda damage, source, attacker, zone, text: self.block(
                        shield, defender, damage, source, attacker, zone, text)
                    on_hit, drops = [], []
                    path = '/obj/item/projectile/arrow'
                    projectile = SimpleNamespace(
                        kinds={path, f'{path}/{family}', f'{path}/{family}/iron'},
                        damage=40, name=family, blockedhit=False,
                        on_hit=lambda *args: on_hit.append(args))
                    # A successful legacy second roll, if reached, must never decide blocking.
                    env = {
                        'istype': lambda source, kind: kind in getattr(source, 'kinds', ()),
                        'prob': lambda chance: True, 'drop_casing': lambda path, turf: drops.append(path),
                        'get_turf': lambda mob: mob,
                    }
                    resolve = projectile_shield_check(env)
                    blocked = case in ('recovered', 'shattered')
                    expected_casing = f'/obj/item/ammo_casing/{family}/iron'
                    recovery_rolls = []

                    def recovery_roll(chance):
                        recovery_rolls.append(chance)
                        return case == 'recovered'

                    def recover(user):
                        projectile.shield_recovery_casing = re.search(
                            rf'(?m)^{path}/{family}/iron\n\tshield_recovery_casing = (\S+)$', ARROW_TYPES)[1]
                        projected = recover_from_shield(dict(env, prob=recovery_roll, SPAN_WARNING=str))
                        projected(projectile, user)

                    projectile.recover_from_shield = recover
                    self.assertEqual(resolve(defender, projectile, 'chest'), 2 if blocked else 0)
                    self.assertEqual(projectile.blockedhit, blocked)
                    self.assertEqual(shield.health, 99.5 if blocked else 100)
                    self.assertEqual(len(on_hit), int(blocked))
                    self.assertEqual(recovery_rolls, [50] if blocked else [])
                    self.assertEqual(drops, [expected_casing] if case == 'recovered' else [])
                    self.assertEqual(len(defender.messages), 2 if blocked else 0)

    def test_successfully_blocked_sling_stone_does_not_roll_for_casing(self):
        path = '/obj/item/projectile/arrow'
        self.assertIn('var/shield_recovery_casing = null', ARROW)
        stone = ARROW_TYPES.split(f'\n{path}/stone\n', 1)[1].split('\n/', 1)[0]
        self.assertNotIn('shield_recovery_casing', stone)
        projectile = SimpleNamespace(kinds={path, f'{path}/stone'}, shield_recovery_casing=None)
        # No probability or spawn stubs: attempting recovery would fail the fixture.
        recover = recover_from_shield({})
        projectile.recover_from_shield = lambda defender: recover(projectile, defender)
        shield, defender = Shield(self.base), User()
        self.assertTrue(self.block(shield, defender, 5, projectile, None, 'chest', 'the stone'))
        self.assertEqual(shield.health, 99)
        self.assertEqual(len(defender.messages), 1)


if __name__ == '__main__':
    unittest.main()
