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

    def test_common_knowledge_reaches_new_and_living_characters(self):
        module = read('code/modules/research_tree/knowledge_spread.dm')
        login = module[module.index('/mob/living/human/Login()'):]
        self.assertLess(login.index('..()'), login.index('grant_common_knowledge()'))
        grant = module[module.index('/mob/living/human/proc/grant_common_knowledge'):module.index('/mob/living/human/Login()')]
        self.assertIn('stat == DEAD', grant)
        self.assertIn('recipe_knowledge_exempt()', grant)
        book = read('code/modules/research_tree/book_research.dm')
        finished = book[book.index('/obj/map_metadata/proc/book_research_node_finished'):]
        self.assertLess(finished.index('ordinal_age = N.era_tier'), finished.index('knowledge_era_advanced()'))

    def test_losing_an_era_takes_nothing_back(self):
        self.assertNotIn('knowledge', read('code/modules/research_tree/era_loss.dm'))

    def test_spreading_subjects_are_quicker_to_learn(self):
        self.assertRegex(read('code/modules/research_tree/_research_tree_defines.dm'), r'#define KNOWLEDGE_SPREADING_STUDY 0\.5\b')
        self.assertIn('* knowledge_study_mult(node_id)', read('code/modules/research_tree/scholar_tools.dm'))
        self.assertIn('knowledge_band(N.id) == KNOWLEDGE_SPREADING) ? 1 : TRADE_LATE_CAP', read('code/modules/research_tree/trade_learning.dm'))
        book = read('code/modules/research_tree/book_interface.dm')
        self.assertEqual(book.count('BOOK_STUDY_TIME(N.era_tier) * knowledge_study_mult(node_id) / desk'), 3)

    def test_rediscovery_costs_a_third_at_the_bench_only(self):
        self.assertRegex(read('code/modules/research_tree/_research_tree_defines.dm'), r'#define KNOWLEDGE_REDISCOVERY_RATE 3\b')
        research = read('code/modules/research_tree/book_research.dm')
        self.assertEqual(research.count('knowledge_rediscovery_rate('), 1)
        tick = research[research.index('if (B.add_research_work(assigned_node, round(base_tick_rate'):]
        self.assertIn('* knowledge_rediscovery_rate(assigned_node) *', tick[:tick.index('\n')])
        book = read('code/modules/research_tree/book_interface.dm')
        self.assertIn('* late_bench_rate(N) * knowledge_rediscovery_rate(node_id) *', book)
        self.assertIn('"Spreading knowledge, already known in the world"', book)
        # Samples, field work, prototypes and compared notes keep their usual shares.
        for path in ('field_work.dm', 'subject_prototypes.dm', 'compare_notes.dm', 'naturalist_finds.dm'):
            self.assertNotIn('knowledge_rediscovery_rate', read('code/modules/research_tree/' + path))

    def test_the_band_is_not_saved(self):
        module = read('code/modules/research_tree/knowledge_spread.dm')
        self.assertIsNone(re.search(r'map_storage_saved_vars|round_state', module))


if __name__ == '__main__':
    unittest.main()
