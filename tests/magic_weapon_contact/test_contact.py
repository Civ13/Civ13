"""Source-flow regression checks for enchanted weapon contact.

These check production DM call-site placement and guard structure; they do not
execute DreamMaker code, simulate probabilities, or establish gameplay behavior.
"""

from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
ITEM = 'code/_onclick/item_attack.dm'
MAGIC = 'code/modules/magic/magic_weapons.dm'
HUMAN = 'code/game/mob/living/carbon/human/human_defense.dm'
CARBON = 'code/game/mob/living/carbon/carbon_defense.dm'
LIVING = 'code/game/mob/living/living_defense.dm'
ANIMAL = 'code/game/mob/living/simple_animal/simple_animal.dm'
ZOMBIE = 'code/game/mob/living/simple_animal/hostile/zombie.dm'


def proc(path, declaration):
    text = (ROOT / path).read_text(encoding='utf-8-sig')
    match = re.search(r'^' + re.escape(declaration) + r'\([^\n]*\)[^\n]*\n', text, re.M)
    if not match:
        raise AssertionError(f'{path}: missing {declaration}')
    lines = []
    for line in text[match.end():].splitlines():
        if line and not line.startswith(('\t', ' ')):
            break
        lines.append(line)
    return '\n'.join(lines)


def contact(body, weapon, indent=1):
    pattern = rf'^\t{{{indent}}}{weapon}\.on_weapon_contact\(src,\s*user\)\s*(?://[^\n]*)?$'
    matches = list(re.finditer(pattern, body, re.M))
    if len(matches) != 1:
        raise AssertionError(f'Expected one unconditional contact callback for {weapon}')
    return matches[0].start()


def resistance_contact(body, weapon, branch_indent):
    pattern = rf'^\t{{{branch_indent}}}{weapon}\.on_weapon_contact\(src,\s*user\)\s*(?://[^\n]*)?$'
    matches = list(re.finditer(pattern, body, re.M))
    if len(matches) != 1:
        raise AssertionError(f'Expected one resistant-target contact callback for {weapon}')
    return matches[0].start()


class MagicWeaponContact(unittest.TestCase):
    def test_magic_effects_are_only_in_contact_hook(self):
        source = (ROOT / MAGIC).read_text(encoding='utf-8-sig')
        self.assertNotRegex(source, re.compile(r'^/obj/item/weapon/material/sword/magic/attack\(', re.M))
        hook = proc(MAGIC, '/obj/item/weapon/material/sword/magic/on_weapon_contact')
        for chance in ('weakens', 'flames', 'ices', 'toxics', 'leechs', 'shocks'):
            self.assertRegex(hook, rf'prob\(\s*{chance}\s*\)')
        proc(ITEM, '/obj/item/proc/on_weapon_contact')

    def test_rejected_attacks_never_reach_hit_dispatch(self):
        body = proc(ITEM, '/obj/item/proc/attack')
        dispatch = body.index('M.resolve_item_attack(')
        for pattern in (r'if \(!force\s*\|\|[^\n]*\)\s*\n\s*return',
                        r'if \(M == user && user\.a_intent != I_HARM\)\s*\n\s*return',
                        r'if \(user\.pacifist\)[\s\S]*?\n\t\treturn',
                        r'else\s*\n\s*to_chat\(H,[^\n]*catch your breath[^\n]*\)\s*\n\s*return'):
            match = re.search(pattern, body)
            self.assertIsNotNone(match, pattern)
            self.assertLess(match.end(), dispatch)
        self.assertRegex(body, r'if \(hit_zone\)\s*\n\t\tapply_hit_effect\(')
        self.assertNotIn('on_weapon_contact(', body)

    def test_human_miss_shield_dodge_and_missing_limb_skip_contact(self):
        resolve = proc(HUMAN, '/mob/living/human/resolve_item_attack')
        for condition in (r'!hit_zone', r'check_shields\(', r'attempt_dodge\(', r'!affecting\s*\|\|\s*affecting\.is_stump\('):
            self.assertRegex(resolve, rf'if\s*\({condition}[^\n]*\)[\s\S]*?\n\t+return null')
        body = proc(HUMAN, '/mob/living/human/hit_with_weapon')
        call = contact(body, 'I')
        # Hands/feet, arms/legs, and head each have a later miss after resolution.
        self.assertGreaterEqual(len(re.findall(r'(?i)missed!.*\n\t+return', body[:call])), 3)
        self.assertLess(body.index('standard_weapon_hit_effects('), call)
        self.assertGreater(body.index('return blocked'), call)

    def test_simple_animal_shield_skips_contact_and_resistance_does_not(self):
        body = proc(ANIMAL, '/mob/living/simple_animal/hit_with_weapon')
        call = contact(body, 'O')
        resistant_call = resistance_contact(body, 'O', 2)
        for text in ('check_shields(', 'O.force <= resistance', 'adjustBruteLoss('):
            self.assertLess(body.index(text), call)
        self.assertRegex(body[:call], r'if \(check_shields\([^\n]*\)\)\s*\n\s*return')
        self.assertLess(body.index('O.force <= resistance'), resistant_call)
        self.assertRegex(body[resistant_call:call], r'^\t\tO\.on_weapon_contact\(src,\s*user\)\s*\n\t\treturn')

    def test_zombie_late_misses_skip_contact_and_resistance_does_not(self):
        body = proc(ZOMBIE, '/mob/living/simple_animal/hostile/human/zombie/hit_with_weapon')
        call = contact(body, 'O', indent=2)
        resistant_call = resistance_contact(body, 'O', 3)
        self.assertEqual(len(re.findall(r'missed![^\n]*\n\t\treturn', body[:resistant_call])), 3)
        self.assertLess(body.index('O.force <= resistance'), resistant_call)
        self.assertRegex(body[resistant_call:call], r'^\t\t\tO\.on_weapon_contact\(src,\s*user\)\s*\n\t\t\treturn')
        self.assertLess(body.index('limb_hit(hit_zone)'), call)

    def test_generic_living_contact_follows_normal_weapon_effects(self):
        body = proc(LIVING, '/mob/living/proc/hit_with_weapon')
        call = contact(body, 'I')
        self.assertLess(body.index('standard_weapon_hit_effects('), call)
        self.assertGreater(body.index('return blocked'), call)

    def test_throat_contact_requires_completed_action_and_valid_grab(self):
        body = proc(CARBON, '/mob/living/human/proc/attack_throat')
        call = contact(body, 'W')
        for pattern in (r'if \(!do_after\([^\n]*\)\)\s*\n\s*return FALSE',
                        r'if \(!\(G && G\.assailant == user && G\.affecting == src\)\)[^\n]*\n\s*return FALSE'):
            match = re.search(pattern, body)
            self.assertIsNotNone(match, pattern)
            self.assertLess(match.end(), call)
        self.assertLess(body.index('apply_damage('), call)
        self.assertGreater(body.index('return TRUE', call), call)


if __name__ == '__main__':
    unittest.main()
