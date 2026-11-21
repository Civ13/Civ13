"""Era helpers keep the options the old per-era branches offered.

The statue clothing and object lists, the anvil category menus and the
Nomads mountain kit used to repeat their options in one branch per era. They
now declare when each option unlocks (era_options) or which value each era
gets (era_pick, code/_helpers/era.dm). FROZEN_* below is what the old
branches gave for every era 0-9; Python mirrors of the helpers evaluate the
current declarations against them.

EQUALS_CEILING: per-era `map.ordinal_age == N` checks outside map metadata
only go down; new code uses the helpers.
"""
from pathlib import Path
import ast
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
ERAS = range(10)
EQUALS_CEILING = 21


def era_options(options, age):
    found = []
    for option, when in options:
        if when is None or (isinstance(when, tuple) and when[0] <= age <= when[1]) or (isinstance(when, int) and age >= when):
            found.append(option)
    return found


def era_pick(by_era, age, fallback):
    if str(age) in by_era:
        return by_era[str(age)]
    best, best_from = None, -1
    for key, value in by_era.items():
        if key.endswith('+') and best_from < int(key[:-1]) <= age:
            best, best_from = value, int(key[:-1])
    return best if best_from >= 0 else fallback


def dm_value(text):
    text = text.strip()
    if text == 'null':
        return None
    if text.startswith('list('):
        return tuple(int(v) for v in text[5:-1].split(','))
    return ast.literal_eval(text)


def options_call(source, variable):
    body = re.search(r'var/list/' + variable + r' = era_options\(list\((.*?)\)\)\n', source, re.S)[1]
    return [(name, dm_value(when)) for name, when in re.findall(r'"([^"]+)" = (null|\d+|list\(\d+, \d+\))', body)]


def pick_calls(source):
    calls = []
    for body in re.findall(r'optlist = era_pick\(list\((.*?)\), optlist\)', source, re.S):
        calls.append({key: re.findall(r'"([^"]+)"', value)
                      for key, value in re.findall(r'"(\d+\+?)" = list\(([^)]*)\)', body)})
    return calls


def ladder(*steps, default=None):
    """steps: (first era, last era, value)."""
    return {age: next((v for lo, hi, v in steps if lo <= age <= hi), default) for age in ERAS}


BASE_CLOTHES = ['none', 'toga']
MEDIEVAL = ['tunic', 'medieval', 'king', 'templar', 'knight']
FROZEN_CLOTHES = ladder((0, 0, BASE_CLOTHES), (1, 1, BASE_CLOTHES + ['tunic']), (2, 2, BASE_CLOTHES + MEDIEVAL),
                        (3, 3, BASE_CLOTHES + MEDIEVAL + ['colonial']),
                        (4, 4, BASE_CLOTHES + MEDIEVAL + ['colonial', 'modern civilian']),
                        (5, 9, BASE_CLOTHES + MEDIEVAL + ['colonial', 'modern civilian', 'modern military']))
SPEARS = ['spear and roman shield', 'spear and oval shield']
ARMS = SPEARS + ['spear and semioval shield', 'sword and roman shield', 'sword and oval shield',
                 'sword and semioval shield', 'flag']
FROZEN_OBJECTS = ladder((0, 0, ['none', 'spear']), (1, 1, ['none', 'spear'] + SPEARS), (2, 2, ['none', 'spear'] + ARMS),
                        (3, 3, ['none', 'spear'] + ARMS + ['rifle']), (4, 6, ['none', 'spear'] + ARMS + ['rifle', 'pistol']),
                        (7, 9, ['none', 'spear'] + ARMS + ['rifle', 'assault rifle']))
JAPAN = ['japanese armor', 'japanese helmets', 'japanese headwear']
IRON_MID = ['helmets', 'other helmets', 'armor', 'other armor', 'other weapons', 'sallet helmets'] + JAPAN
# Armor never goes out of date (armor rework, 2026-11-21): iron keeps its
# armor and helmet categories from era 4 on.
IRON_LATE = ['helmets', 'other helmets', 'armor', 'other armor', 'sallet helmets'] + JAPAN
FROZEN_IRON = ladder((0, 1, ['cancel', 'shields', 'helmets', 'armor']), (2, 2, ['cancel', 'shields'] + IRON_MID),
                     (3, 3, ['cancel', 'guns'] + IRON_MID), (4, 9, ['cancel'] + IRON_LATE),
                     default=['cancel'])
# Emplaced machine guns joined the steel menu from the WW1 era on (2026-11-14).
# Steel forges armor (plated, samurai lord) in every era from 2 on.
STEEL_ARMOR = ['armor'] + JAPAN
FROZEN_STEEL = ladder((2, 3, ['cancel'] + STEEL_ARMOR + ['other weapons']), (4, 4, ['cancel', 'guns'] + STEEL_ARMOR),
                      (5, 5, ['cancel', 'helmets', 'mk1 brodie', 'm15 adrian', 'machine guns'] + STEEL_ARMOR),
                      (6, 6, ['cancel', 'helmets', 'machine guns'] + STEEL_ARMOR),
                      (7, 7, ['cancel', 'helmets', 'ussr heavy visored helmets', 'guns', 'machine guns'] + STEEL_ARMOR),
                      (8, 9, ['cancel', 'helmets', 'guns', 'machine guns'] + STEEL_ARMOR),
                      default=['cancel'])
FROZEN_BRONZE = ladder((0, 2, ['cancel', 'shields', 'helmets', 'armor']), (3, 9, ['cancel', 'helmets', 'armor']), default=['cancel'])


class EraHelperTest(unittest.TestCase):
    def test_statue_options_match_the_old_branches(self):
        stack = (ROOT / 'code/game/objects/items/stacks/stack.dm').read_text()
        for variable, frozen in (('possible_clothes', FROZEN_CLOTHES), ('possible_objects', FROZEN_OBJECTS)):
            options = options_call(stack, variable)
            for age in ERAS:
                with self.subTest(variable=variable, age=age):
                    self.assertEqual(era_options(options, age), frozen[age])

    def test_anvil_menus_match_the_old_branches(self):
        smith = (ROOT / 'code/game/objects/structures/blacksmithing/blacksmithing.dm').read_text()
        calls = pick_calls(smith)
        self.assertEqual(len(calls), 3)
        for call, frozen in zip(calls, (FROZEN_IRON, FROZEN_STEEL, FROZEN_BRONZE)):
            for age in ERAS:
                with self.subTest(age=age, first=frozen[0]):
                    self.assertEqual(era_pick(call, age, ['cancel']), frozen[age])

    def test_helper_contract(self):
        helper = (ROOT / 'code/_helpers/era.dm').read_text()
        self.assertIn('return map && map.ordinal_age >= age', helper)
        self.assertIn('if ("[age]" in by_era)\n\t\treturn by_era["[age]"]', helper)
        self.assertIn('return best_from >= 0 ? best : fallback', helper)

    def test_per_era_equality_checks_only_shrink(self):
        count = 0
        for path in (ROOT / 'code').rglob('*.dm'):
            if 'map_metadata' in path.parts:
                continue
            count += len(re.findall(r'ordinal_age *== *\d', path.read_text(encoding='utf-8', errors='replace')))
        self.assertLessEqual(count, EQUALS_CEILING, 'use era_pick/era_options/era_between from code/_helpers/era.dm')


if __name__ == '__main__':
    unittest.main()
