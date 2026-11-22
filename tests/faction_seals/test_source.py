"""Faction seals: source contract checks.

    python3 tests/faction_seals/test_source.py
Native probe: python3 tests/ecology_spawning/run_linux.py . tests/faction_seals/probe.dm
"""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/paperwork/faction_seals.dm'


class FactionSealSource(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = SOURCE.read_text(encoding='utf-8')

    def test_included_after_stamps(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertIn('#include "code\\modules\\paperwork\\stamps.dm"\n#include "code\\modules\\paperwork\\faction_seals.dm"', dme)

    def test_stamps_use_the_impression_look_and_record_seals(self):
        stamps = (ROOT / 'code/modules/paperwork/stamps.dm').read_text(encoding='utf-8')
        self.assertIn('S.impression_state()', stamps)
        self.assertIn('faction_seal_note_impression(P, S)', stamps)
        self.assertNotIn('S.icon_state', stamps)

    def test_register_follows_faction_renames(self):
        roster = (ROOT / 'code/game/mob/groups/faction_roster.dm').read_text(encoding='utf-8')
        self.assertIn('faction_seal_rename(old_name, new_name)', roster)
        self.assertIn('faction_seal_normalize()', roster)

    def test_revocation_uses_an_exact_clock(self):
        # world.realtime is a 32-bit float (about a minute of precision), so
        # ordering must come from the integer seal clock.
        self.assertIn('row[3] = faction_seal_tick()', self.text)
        self.assertIn('tick > row[3]', self.text)

    def test_signature_inspection_stays_on_the_read_boundary(self):
        signature_lines = self.text.split('/proc/faction_seal_signature_lines(', 1)[1].split('/proc/', 1)[0]
        self.assertIn('new(P, reader, "paper", null)', signature_lines)
        self.assertIn('request.project(reader)', signature_lines)
        self.assertIn('projection["error"]', signature_lines)
        self.assertIn('html_encode(section["text"])', signature_lines)
        self.assertNotIn('document_record', signature_lines)
        self.assertIn('identity not verified', signature_lines)
        guard = self.text.split('/proc/faction_seal_can_inspect(', 1)[1].split('/proc/', 1)[0]
        self.assertIn('reader.client.mob == reader', guard)
        self.assertIn('P.loc == reader || (isturf(P.loc) && P.Adjacent(reader))', guard)
        self.assertLess(signature_lines.index('faction_seal_can_inspect'), signature_lines.index('request.project'))
        verb = self.text.split('/obj/item/weapon/paper/verb/check_seals()', 1)[1]
        self.assertLess(verb.index('faction_seal_can_inspect'), verb.index('faction_seal_check_text'))

    def test_seal_verdict_does_not_authenticate_contents(self):
        self.assertIn('impression matches the current register', self.text)
        self.assertIn('does not authenticate the current contents', self.text)

    def test_recipe_and_research(self):
        recipes = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
        self.assertIn('RECIPE: /material/wood/soft/,seal matrix,/obj/item/weapon/stamp/faction_seal,', recipes)
        research = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
        self.assertIn('"/obj/item/weapon/stamp/faction_seal" = "papermaking",', research)

    def test_actions_are_logged(self):
        self.assertIn('log_game("[key_name(user)] cut seal no.', self.text)
        self.assertIn('log_game("[key_name(user)] revoked seal no.', self.text)

    def test_no_forbidden_patterns(self):
        self.assertIsNone(re.search(r'(?<![A-Za-z_])(spawn|input)\(', self.text))
        self.assertNotIn(' in world', self.text)


if __name__ == '__main__':
    unittest.main()
