"""Offline source contracts and mutation controls; no native execution claims."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
ANIMALS = ROOT / 'code/game/mob/living/simple_animal'


def block(source, header):
    start = source.index(header + '\n') + len(header) + 1
    end = source.find('\n/', start)
    return source[start:end if end >= 0 else None]


def safety_contract(source):
    body = block(source, '/mob/living/simple_animal/proc/try_defensive_retaliation(mob/living/attacker)')
    required = (
        '!uses_defensive_retaliation()', 'QDELETED(src)', 'stat != CONSCIOUS',
        'health <= 0', 'incapacitated()', 'resting', 'buckled', '!canmove',
        '!isturf(loc)', '!istype(attacker)', 'attacker == src',
        'QDELETED(attacker)', 'attacker.stat != CONSCIOUS', 'attacker.health <= 0',
        '!isturf(attacker.loc)', '!Adjacent(attacker)',
        'behaviour == "wander" && mob_size < attacker.mob_size',
        'attacker.status_flags & CANWEAKEN', 'attacker.incapacitated()',
        'attacker.lying', 'attacker.prone', 'attacker.buckled',
        'world.time < next_animal_retaliation',
        'world.time < attacker.next_animal_retaliation',
        'next_animal_retaliation = world.time + 10 SECONDS',
        'attacker.next_animal_retaliation = world.time + 10 SECONDS',
        'attacker.Weaken(2)',
        'attacker.drop_from_inventory(attacker.get_active_hand())',
    )
    for text in required:
        if text not in body:
            raise AssertionError('Missing safety contract: ' + text)
    if re.search(r'apply_damage|adjust\w*Loss|\.attack\(|target_mob\s*=|stance\s*=|sleep\(|spawn\(', body):
        raise AssertionError('Retaliation acquired damage, pursuit, or asynchronous work')
    if body.index('attacker.next_animal_retaliation =') > body.index('attacker.Weaken(2)'):
        raise AssertionError('Cooldown must be reserved before effects')
    return body


class RetaliationSources(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = (ANIMALS / 'simple_animal.dm').read_text(encoding='utf-8')
        cls.farm = (ANIMALS / 'friendly/farm_animals.dm').read_text(encoding='utf-8')

    def test_bounded_zero_damage_and_target_validity(self):
        safety_contract(self.source)
        enable = block(self.source, '/mob/living/simple_animal/proc/uses_defensive_retaliation()')
        self.assertIn('defensive_retaliation && (behaviour == "wander" || behaviour == "defends")', enable)

    def test_safety_mutations_are_rejected(self):
        for text in ('!Adjacent(attacker)', 'attacker.stat != CONSCIOUS',
                     'world.time < next_animal_retaliation',
                     'world.time < attacker.next_animal_retaliation',
                     'attacker.incapacitated()', 'attacker.Weaken(2)'):
            with self.subTest(removed=text), self.assertRaises(AssertionError):
                safety_contract(self.source.replace(text, 'FALSE', 1))
        with self.assertRaises(AssertionError):
            safety_contract(self.source.replace('attacker.Weaken(2)', 'attacker.adjustBruteLoss(1)\n\tattacker.Weaken(2)', 1))

    def test_only_reviewed_domestic_species_opt_in(self):
        paths = []
        for file in (ROOT / 'code').rglob('*.dm'):
            content = file.read_text(encoding='utf-8-sig')
            for match in re.finditer(r'^(/[^\n]+)\n((?:[\t ][^\n]*\n|\n)*)', content, re.M):
                if re.search(r'^\tdefensive_retaliation = TRUE$', match[2], re.M):
                    paths.append(match[1])
        self.assertEqual(set(paths), {'/mob/living/simple_animal/' + path for path in
                         ('cattle', 'pig_boar', 'pig_gilt', 'goat', 'sheep', 'horse', 'camel')})
        self.assertIn('var/defensive_retaliation = FALSE', self.source)

    def test_juveniles_retain_existing_behavior(self):
        for species, flag in (('cattle', 'calf'), ('pig_boar', 'piglet'),
                              ('pig_gilt', 'piglet'), ('goat', 'lamb'), ('sheep', 'lamb')):
            with self.subTest(species=species):
                body = block(self.farm, f'/mob/living/simple_animal/{species}/uses_defensive_retaliation()')
                self.assertEqual(body.strip(), f'return !{flag} && ..()')

    def test_provocation_and_no_chase_dispatch(self):
        hand = block(self.source, '/mob/living/simple_animal/attack_hand(mob/living/human/M as mob)')
        self.assertIn('if (M.a_intent == I_HARM || M.a_intent == I_DISARM || M.a_intent == I_GRAB)\n\t\ttry_defensive_retaliation(M)', hand)
        self.assertEqual(hand.count('behaviour == "defends" && !uses_defensive_retaliation()'), 3)
        item = block(self.source, '/mob/living/simple_animal/attackby(var/obj/item/O, var/mob/user)')
        gate = item.index('if (uses_defensive_retaliation() && (behaviour == "defends" || mob_size >= user.mob_size))')
        legacy = item.index('if (behaviour == "defends" || behaviour == "hunt" || behaviour == "hostile")')
        self.assertLess(gate, legacy)
        self.assertIn('if (health < health_before_attack)\n\t\t\ttry_defensive_retaliation(user)\n\t\treturn attack_result', item[gate:legacy])
        self.assertIn('do_behaviour("scared")', item[legacy:])
        self.assertEqual(item.count('O.attack(src, user, tgt)'), 2)

    def test_cooldown_is_runtime_only(self):
        source = (ROOT / 'code/modules/persistence/functions.dm').read_text(encoding='utf-8')
        body = block(source, '/mob/persistence_runtime_var(key)')
        self.assertIn('key == "next_animal_retaliation"', body)
        self.assertIn('return ..()', body)
        self.assertIn('/mob/living/var/tmp/next_animal_retaliation = 0', self.source)


if __name__ == '__main__':
    unittest.main()
