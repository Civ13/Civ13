"""Faction banner load: source contract checks.

    python3 tests/faction_banner_load/test_source.py
Native probe: python3 tests/ecology_spawning/run_linux.py . tests/faction_banner_load/probe.dm
"""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/mob/groups/factions.dm'


class FactionBannerLoadSource(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        text = SOURCE.read_text(encoding='utf-8')
        start = text.index('/obj/structure/banner/faction/New()')
        cls.new = text[start:text.index('/obj/structure/banner/faction/attackby(', start)]

    def test_banner_never_indexes_custom_civs_directly(self):
        # custom_civs is empty while a level loads; indexing a missing row was a
        # "cannot read from list" runtime for every restored faction banner.
        self.assertNotIn('map.custom_civs[faction][', self.new)
        self.assertIn('faction_banner_civ_data(faction)', self.new)

    def test_waits_for_the_whole_load(self):
        # Drawn symbols are restored after custom_civs, so wait for the load.
        self.assertRegex(self.new, r'while \(persistence_active_operation && world\.time < until\)\n\t\tsleep\(50\)')
        self.assertIn('islist(row) && row.len >= 6', self.new)

    def test_symbol_overlay_is_optional(self):
        self.assertIn('if (overs)\n\t\t\t\toverlays += overs', self.new)


if __name__ == '__main__':
    unittest.main()
