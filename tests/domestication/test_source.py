"""Domestication: source contract checks.

    python3 tests/domestication/test_source.py
"""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/domestication.dm'
SUBTYPE_HOOKS = ('cattle', 'cattle/cow', 'pig_gilt', 'goat/female', 'sheep', 'sheep/female')


def proc_body(text, header):
    start = text.index(header + '\n')
    rest = text[start + len(header) + 1:]
    end = re.search(r'^\S', rest, re.M)
    return rest[:end.start()] if end else rest


class DomesticationSource(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = SOURCE.read_text(encoding='utf-8')

    def test_included_after_traps(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8').splitlines()
        index = {line: i for i, line in enumerate(dme)}
        mine = index['#include "code\\modules\\1713\\domestication.dm"']
        self.assertLess(index['#include "code\\modules\\1713\\stone_age_traps.dm"'], mine)
        self.assertLess(index['#include "code\\game\\mob\\living\\simple_animal\\friendly\\farm_animals.dm"'], mine)

    def test_every_attackby_is_intercepted(self):
        for sub in SUBTYPE_HOOKS:
            body = proc_body(self.text, '/mob/living/simple_animal/%s/attackby(obj/item/O, mob/user)' % sub)
            self.assertIn('domestication_intercept(O, user)', body)
            self.assertIn('return ..()', body)
        farm = (ROOT / 'code/game/mob/living/simple_animal/friendly/farm_animals.dm').read_text(encoding='utf-8')
        defined = set(re.findall(r'^/mob/living/simple_animal/([a-z_/]+)/attackby\(', farm, re.M))
        domestic = {d for d in defined if d.split('/')[0] in ('cattle', 'goat', 'sheep', 'pig_gilt', 'pig_boar')}
        self.assertEqual(domestic, set(SUBTYPE_HOOKS))

    def test_spawners_make_wild(self):
        eco = (ROOT / 'code/modules/ecology/ecology_spawning.dm').read_text(encoding='utf-8')
        self.assertIn('A.make_wild()', eco)
        spawner = (ROOT / 'code/game/objects/effects/spawner.dm').read_text(encoding='utf-8')
        self.assertIn('spawnedMob.make_wild()', spawner)

    def test_leash_is_stone_age(self):
        research = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
        self.assertIn('"/obj/item/weapon/leash" = "basic_tools",', research)
        self.assertNotIn('"/obj/item/weapon/leash" = "basic_agriculture",', research)

    def test_restore_is_left_alone(self):
        self.assertIn('/mob/living/simple_animal/on_runtime_spawn()', self.text)
        self.assertNotIn('/mob/living/simple_animal/New(', self.text)

    def test_no_forbidden_patterns(self):
        self.assertIsNone(re.search(r'(?<![a-z_])(spawn|input)\(', self.text))
        self.assertNotIn(' in world', self.text)


if __name__ == '__main__':
    unittest.main()
