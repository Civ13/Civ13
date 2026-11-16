"""Faction laws, courts and warrants: source contract checks.

    python3 tests/faction_justice/test_source.py
Native probe: python3 tests/ecology_spawning/run_linux.py . tests/faction_justice/probe.dm
"""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/mob/groups/faction_justice.dm'


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


class FactionJusticeSource(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = SOURCE.read_text(encoding='utf-8')

    def test_included_after_offices(self):
        self.assertIn('#include "code\\game\\mob\\groups\\faction_offices.dm"\n#include "code\\game\\mob\\groups\\faction_justice.dm"', read('civ13.dme'))

    def test_verb_hooks_and_recipes(self):
        self.assertEqual(read('code/game/mob/groups/factions.dm').count('verbs += /mob/living/human/proc/faction_justice'), 2)
        roster = read('code/game/mob/groups/faction_roster.dm')
        self.assertIn('justice_rename(old_name, new_name)', roster)
        self.assertIn('justice_normalize()', roster)
        recipes = read('config/crafting/material_recipes_global.txt')
        self.assertIn('RECIPE: /material/wood/,gavel block,/obj/item/weapon/gavelblock,', recipes)
        self.assertIn('RECIPE: /material/wood/,gavel hammer,/obj/item/weapon/gavelhammer,', recipes)

    def test_judges_set_cell_timers(self):
        ops = read('code/modules/1713/cmss13_ops.dm')
        self.assertIn('justice_can_jail(H)', ops.split('/proc/can_set_cell_timer(', 1)[1].split('\n/', 1)[0])

    def test_trial_needs_a_gavel_and_rechecks(self):
        trial = self.text.split('/mob/living/human/proc/justice_hold_trial(', 1)[1].split('\n/', 1)[0]
        tail = trial.split('// Everything is checked again after the prompts.', 1)[1]
        self.assertIn('justice_court_near(src)', tail)
        self.assertIn('map.faction_power(src, faction, "justice")', tail)

    def test_papers_escape_player_text(self):
        for proc in ('/proc/justice_warrant_text(', '/proc/justice_judgment_text('):
            body = self.text.split(proc, 1)[1].split('\n/', 1)[0]
            self.assertIn('html_encode(name)', body)

    def test_fines_paid_at_the_strongbox(self):
        self.assertIn('pay_fine(user)', read('code/game/mob/groups/faction_treasury.dm'))


if __name__ == '__main__':
    unittest.main()
