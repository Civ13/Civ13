"""Treaties between factions: source contract checks.

    python3 tests/faction_treaties/test_source.py
Native probe: python3 tests/ecology_spawning/run_linux.py . tests/faction_treaties/probe.dm
"""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/mob/groups/faction_treaties.dm'


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


class FactionTreatiesSource(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = SOURCE.read_text(encoding='utf-8')

    def test_included_after_papers(self):
        self.assertIn('#include "code\\game\\mob\\groups\\faction_papers.dm"\n#include "code\\game\\mob\\groups\\faction_treaties.dm"', read('civ13.dme'))

    def test_rename_and_normalize_hooks(self):
        roster = read('code/game/mob/groups/faction_roster.dm')
        self.assertIn('treaty_rename(old_name, new_name)', roster)
        self.assertIn('treaty_normalize()', roster)

    def test_diplomacy_is_an_office_power(self):
        self.assertIn('"diplomacy" = "make and sign treaties"', read('code/game/mob/groups/faction_offices.dm'))

    def test_every_change_rechecks_the_power_after_prompts(self):
        verb = self.text.split('/mob/living/human/proc/faction_treaties()', 1)[1].split('\n// "Treaty 3', 1)[0]
        self.assertGreaterEqual(verb.count('map.faction_power(src, faction, "diplomacy")'), 5)
        draft = self.text.split('/mob/living/human/proc/treaty_draft_menu(', 1)[1]
        self.assertIn('map.faction_power(src, faction, "diplomacy")', draft)

    def test_drafts_and_treaties_in_force_are_never_pruned(self):
        draft = self.text.split('/obj/map_metadata/proc/treaty_draft(', 1)[1].split('\n/', 1)[0]
        self.assertIn('(old["status"] in list("refused", "renounced"))', draft)

    def test_verb_given_with_the_other_faction_verbs(self):
        self.assertEqual(2, read('code/game/mob/groups/factions.dm').count('verbs += /mob/living/human/proc/faction_treaties'))


if __name__ == '__main__':
    unittest.main()
