"""Tribal deeds: source contract checks.

    python3 tests/tribal_deeds/test_source.py
"""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/tribal_deeds.dm'


class TribalDeedsSource(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = SOURCE.read_text(encoding='utf-8')

    def test_included_after_the_hooked_files(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8').splitlines()
        index = {line: i for i, line in enumerate(dme)}
        mine = index['#include "code\\modules\\1713\\tribal_deeds.dm"']
        for name in ('dugout_canoe', 'domestication', 'rock_art'):
            self.assertLess(index['#include "code\\modules\\1713\\%s.dm"' % name], mine)

    def test_hooks_call_parent(self):
        for header in ('/mob/living/simple_animal/death(gibbed, deathmessage = "dies!")',
                '/obj/structure/dugout_log/finish(mob/user)',
                '/mob/living/simple_animal/tame_feeding(mob/user, now = trap_now_minutes())',
                '/obj/item/canvas/rock/accept_painting(mob/user, packed, palette_text, finish, new_title)'):
            start = self.text.index(header + '\n')
            body = self.text[start:start + 600]
            self.assertIn('..()', body, header)

    def test_rock_art_deed_only_on_first_finish(self):
        self.assertIn('if (finish && !was_finished && finished && ishuman(user))', self.text)

    def test_hidden_npcs_are_not_deeds(self):
        self.assertIn('istype(A, /mob/living/simple_animal/hostile/wizard)', self.text)
        self.assertNotIn('magic', self.text.lower())

    def test_carving_uses_a_knife(self):
        self.assertIn('is_tool(I, TOOL_KNIFE)', self.text)

    def test_no_forbidden_patterns(self):
        self.assertIsNone(re.search(r'(?<![a-z_])(spawn|input)\(', self.text))
        self.assertNotIn(' in world', self.text)


if __name__ == '__main__':
    unittest.main()
