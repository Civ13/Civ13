#!/usr/bin/env python3
"""Offline source contracts for knowledge spreading with a lag."""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8', errors='replace').replace('\r\n', '\n')


class KnowledgeSpreadTests(unittest.TestCase):
    def test_the_module_is_compiled_in(self):
        self.assertIn('#include "code\\modules\\research_tree\\knowledge_spread.dm"', read('civ13.dme'))

    def test_the_lags_are_server_config_with_the_agreed_defaults(self):
        configuration = read('code/datums/configuration.dm')
        self.assertRegex(configuration, r'var/knowledge_spreading_eras = 2\b')
        self.assertRegex(configuration, r'var/knowledge_common_eras = 4\b')
        self.assertIn('if ("knowledge_spreading_eras", "knowledge_common_eras")', configuration)
        config = read('config/config.txt')
        self.assertRegex(config, r'(?m)^KNOWLEDGE_SPREADING_ERAS 2$')
        self.assertRegex(config, r'(?m)^KNOWLEDGE_COMMON_ERAS 4$')

    def test_only_book_research_worlds_spread_knowledge(self):
        module = read('code/modules/research_tree/knowledge_spread.dm')
        band = module[module.index('/proc/knowledge_band(node_id)'):module.index('/proc/knowledge_band_name')]
        self.assertIn('!map.book_research_enabled()', band)
        self.assertIn('N.mode == RESEARCH_MODE_BOOK', band)

    def test_the_research_windows_name_the_band(self):
        self.assertIn('"era_name" = research_era_label(N)', read('code/modules/research_tree/tech_tree_view.dm'))
        book = read('code/modules/research_tree/book_interface.dm')
        self.assertIn('out["era_name"] = research_era_label(N)', book)
        self.assertNotIn('ordinal_age_name(N.era_tier)', book)

    def test_the_band_is_not_saved(self):
        module = read('code/modules/research_tree/knowledge_spread.dm')
        self.assertIsNone(re.search(r'map_storage_saved_vars|round_state', module))


if __name__ == '__main__':
    unittest.main()
