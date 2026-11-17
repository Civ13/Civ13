"""Faction offices and elections: source contract checks.

    python3 tests/faction_offices/test_source.py
Native probe: python3 tests/ecology_spawning/run_linux.py . tests/faction_offices/probe.dm
"""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/mob/groups/faction_offices.dm'


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


class FactionOfficesSource(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = SOURCE.read_text(encoding='utf-8')

    def test_included_after_land_registry(self):
        self.assertIn('#include "code\\game\\mob\\groups\\land_registry.dm"\n#include "code\\game\\mob\\groups\\faction_offices.dm"', read('civ13.dme'))

    def test_verb_granted_with_the_faction_verbs(self):
        factions = read('code/game/mob/groups/factions.dm')
        self.assertEqual(factions.count('verbs += /mob/living/human/proc/faction_offices'), 2)

    def test_rename_and_normalize_hooks(self):
        roster = read('code/game/mob/groups/faction_roster.dm')
        self.assertIn('office_rename(old_name, new_name)', roster)
        self.assertIn('office_normalize()', roster)

    def test_every_power_goes_through_faction_power(self):
        self.assertIn('map.faction_power(H, faction, "treasury")', read('code/game/mob/groups/faction_treasury.dm'))
        self.assertIn('map.faction_power(user, faction, "registry")', read('code/game/mob/groups/land_registry.dm'))
        self.assertIn('faction_power(H, faction, "seals")', read('code/modules/paperwork/faction_seals.dm'))
        self.assertEqual(read('code/modules/1713/coin_mint.dm').count('map.faction_power(user, faction, "mint")'), 2)
        self.assertNotIn('faction_office_holder', read('code/modules/paperwork/faction_seals.dm'))

    def test_leadership_changes_only_through_change_faction_leader(self):
        self.assertIn('change_faction_leader(faction, previous, W)', self.text)
        self.assertNotIn('[4] = W', self.text)

    def test_leader_powers_rechecked_after_prompts(self):
        verb = self.text.split('/mob/living/human/proc/faction_offices()', 1)[1].split('\n/', 1)[0]
        after = verb.split('var/choice = WWinput(', 1)[1]
        self.assertGreaterEqual(after.count('map.is_faction_leader(src, faction)'), 8)


    def test_absent_leader_opens_the_leadership(self):
        open_body = self.text.split('/obj/map_metadata/proc/office_leader_open(faction)', 1)[1].split('\n/', 1)[0]
        self.assertIn('if (office_leader_away(faction))\n\t\treturn TRUE', open_body)
        away = self.text.split('/obj/map_metadata/proc/office_leader_away(faction)', 1)[1].split('\n/', 1)[0]
        self.assertIn('if (!L || L.client)\n\t\treturn FALSE', away)
        self.assertIn('OFFICE_LEADER_AWAY_DAYS * OFFICE_DAY', away)
        self.assertIn('#define OFFICE_LEADER_AWAY_DAYS 3', self.text)

if __name__ == '__main__':
    unittest.main()
