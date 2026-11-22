"""Offline source contracts for faction substance rules. Gameplay is covered by
the native probe:
python3 tests/ecology_spawning/run_linux.py . tests/faction_substances/probe.dm 300
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/mob/groups/faction_substances.dm'


class FactionSubstanceSourceTests(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding='utf-8')

    def test_included(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertIn('#include "code\\game\\mob\\groups\\faction_substances.dm"', dme)

    def test_hooks(self):
        papers = (ROOT / 'code/game/mob/groups/faction_papers.dm').read_text(encoding='utf-8')
        self.assertIn('"substance" = "substance licence"', papers)
        self.assertIn('substance_rules_menu(faction)', papers)
        self.assertIn('substance_rules(faction) // faction_substances.dm', papers)
        justice = (ROOT / 'code/game/mob/groups/faction_justice.dm').read_text(encoding='utf-8')
        self.assertIn('map.substance_rule_lines(faction)', justice)
        items = (ROOT / 'code/game/objects/items.dm').read_text(encoding='utf-8')
        self.assertIn('substance_examine(user)', items)
        dog = (ROOT / 'code/modules/1713/complex_animal/dog.dm').read_text(encoding='utf-8')
        self.assertIn('item_sniffable(I, get_turf(src))', dog)

    def test_leader_only(self):
        menu = self.source.split('/mob/living/human/proc/substance_rules_menu(', 1)[1]
        self.assertEqual(menu.count('map.is_faction_leader(src, faction)'), 2)

    def test_no_spawn_or_sleep(self):
        self.assertNotRegex(self.source, r'\b(spawn|sleep)\(')


if __name__ == '__main__':
    unittest.main()
