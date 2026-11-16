"""Census, citizenship papers, travel passes and border doors: source contract checks.

    python3 tests/faction_papers/test_source.py
Native probe: python3 tests/ecology_spawning/run_linux.py . tests/faction_papers/probe.dm
"""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/mob/groups/faction_papers.dm'


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


def body(text, head):
    return text.split(head, 1)[1].split('\n/', 1)[0]


class FactionPapersSource(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = SOURCE.read_text(encoding='utf-8')

    def test_included_after_bills(self):
        self.assertIn('#include "code\\game\\mob\\groups\\faction_bills.dm"\n#include "code\\game\\mob\\groups\\faction_papers.dm"', read('civ13.dme'))

    def test_rename_and_normalize_hooks(self):
        roster = read('code/game/mob/groups/faction_roster.dm')
        self.assertIn('papers_rename(old_name, new_name)', roster)
        self.assertIn('papers_normalize()', roster)

    def test_papers_power_is_an_office_power(self):
        self.assertIn('"papers" = "issue papers and keep the border"', read('code/game/mob/groups/faction_offices.dm'))

    def test_issuing_rechecks_power_distance_and_paper(self):
        issue = body(self.text, '/mob/living/human/proc/papers_issue_to(')
        tail = issue.split('// Everything is checked again after the prompts.', 1)[1]
        self.assertIn('map.faction_power(src, faction, "papers")', tail)
        self.assertIn('get_dist(src, M) > 1', tail)
        self.assertIn('bill_blank_supply(src)', tail)

    def test_papers_count_only_for_their_holder(self):
        admit = body(self.text, '/proc/papers_admit(')
        self.assertIn('P.holder_account != account', admit)
        self.assertIn('map.papers_row(faction, P.serial)', admit)

    def test_faction_doors_take_papers(self):
        door = read('code/game/objects/structures/key_doors/key_door.dm')
        self.assertIn('papers_admit(H, faction, admits)', door)
        self.assertEqual(4, door.count('faction_door_admits('))  # the proc, hand lock, bump and cross
        self.assertNotIn('H.civilization == faction)\n\t\t\tif(', door)

    def test_verb_given_with_the_other_faction_verbs(self):
        self.assertEqual(2, read('code/game/mob/groups/factions.dm').count('verbs += /mob/living/human/proc/faction_papers'))

    def test_papers_not_craftable(self):
        self.assertNotIn('/obj/item/faction_papers', read('config/crafting/material_recipes_global.txt'))


if __name__ == '__main__':
    unittest.main()
