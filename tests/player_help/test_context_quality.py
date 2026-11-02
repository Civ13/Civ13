"""Offline answer-context quality checks: tips, role, retrieval and context budget.

Uses injected transports only; no model, network or deployed worker.
"""
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('context_bridge', ROOT / 'scripts/player_help_bridge.py')
bridge = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(bridge)


class ContextQualityTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.instances = []
        self.calls = []

    def tearDown(self):
        for instance in self.instances:
            instance.close()
        self.temp.cleanup()

    def ask(self, corpus, question, num_ctx=None, game_context=None):
        config = {'enabled': True, 'model': 'test', 'endpoint': 'http://localhost/api/chat',
                  'workers': 1, 'timeout_seconds': 1}
        if num_ctx is not None:
            config['num_ctx'] = num_ctx
        instance = bridge.Bridge(self.root / ('spool' + str(len(self.instances))), config, corpus,
                                 lambda *args: self.calls.append(args) or {'message': {'content': 'Answer'}})
        self.instances.append(instance)
        request = {'id': str(len(self.calls) + 1), 'account': 'a' * 32, 'question': question}
        if game_context is not None:
            request['game_context'] = game_context
        self.assertEqual(instance.answer(request)['status'], 'ok')
        return self.calls[-1][1]

    def test_round_start_tips_are_retrievable(self):
        tips = bridge.tips_knowledge(ROOT)
        lines = [line for line in (ROOT / 'config/tips.txt').read_text(encoding='utf-8').splitlines() if line.strip()]
        self.assertEqual(len(tips), len(lines))
        self.assertTrue(all(entry['source'] == 'tip' for entry in tips))
        prompt = self.ask(tips, 'How do I tan a hide into leather?')['messages'][0]['content']
        self.assertIn('IN-GAME TIP', prompt)
        self.assertIn('soak in tannin to get leather', prompt)
        self.assertEqual(bridge.tips_knowledge(self.root), [])

    def test_role_is_bounded_and_reaches_prompt(self):
        context = bridge.public_game_context({'game_context': {'player': {'role': '  Colony\nMedic ' + 'x' * 200}}})
        self.assertEqual(len(context['player']['role']), 80)
        self.assertTrue(context['player']['role'].startswith('Colony Medic x'))
        self.assertNotIn('role', bridge.public_game_context({'game_context': {'player': {'role': 7}}})['player'])
        corpus = [{'topic': 'medic doctor role clinic colony', 'source': 'wiki', 'text': 'PLAYER WIKI Colony Medic: run the clinic.'},
                  {'topic': 'blacksmith role anvil forge colony', 'source': 'wiki', 'text': 'PLAYER WIKI Blacksmith: forge tools.'}]
        prompt = self.ask(corpus, 'What should I be doing right now?',
                          game_context={'gamemode': 'Colony Building RP', 'player': {'role': 'Colony Medic'}})['messages'][0]['content']
        self.assertIn('"role": "Colony Medic"', prompt)
        self.assertIn('run the clinic', prompt)
        # Both pages share the game-mode hint; the role-matching page ranks first.
        self.assertLess(prompt.index('run the clinic'), prompt.index('forge tools'))

    def test_role_hint_never_outranks_question_matches(self):
        corpus = [{'topic': 'medic doctor role clinic', 'source': 'wiki', 'text': 'PLAYER WIKI medic page'}]
        corpus += [{'topic': 'fishing fish rod bait ' + str(i), 'source': 'wiki', 'text': 'PLAYER WIKI fishing ' + str(i)} for i in range(6)]
        prompt = self.ask(corpus, 'How do I fish with bait?', game_context={'player': {'role': 'Medic'}})['messages'][0]['content']
        self.assertNotIn('medic page', prompt)

    def test_plural_folding_and_stopwords(self):
        self.assertEqual(bridge.retrieval_terms('This: ingots, wounds, berries and glass', bridge.RETRIEVAL_STOPWORDS),
                         {'ingot', 'wound', 'berry', 'glass'})
        corpus = [{'topic': 'bronze ingot', 'source': 'recipe', 'text': 'Recipe: bronze ingot from copper and tin.'},
                  {'topic': 'what where does', 'source': 'recipe', 'text': 'Unrelated generic page.'}]
        prompt = self.ask(corpus, 'Where does one get bronze ingots?')['messages'][0]['content']
        self.assertIn('copper and tin', prompt)
        self.assertNotIn('Unrelated generic page', prompt)

    def test_duplicate_rows_do_not_crowd_out_guides(self):
        corpus = [{'topic': 'crop seed forage ' + str(i), 'source': 'acquisition', 'text': 'Forage crop seed ' + str(i)} for i in range(8)]
        corpus.append({'topic': 'farming farm crops', 'source': 'wiki', 'text': 'PLAYER WIKI plant crops in tilled soil'})
        prompt = self.ask(corpus, 'How do I grow crops?')['messages'][0]['content']
        self.assertIn('plant crops in tilled soil', prompt)

    def test_prompt_fits_configured_context_window(self):
        corpus = [{'topic': 'iron ore ' + str(i), 'source': 'wiki', 'text': 'PLAYER WIKI iron ore ' + str(i) + ' ' + 'detail ' * 600} for i in range(12)]
        small = self.ask(corpus, 'Where is iron ore?', num_ctx=4096)
        prompt_chars = sum(len(message['content']) for message in small['messages'])
        self.assertLessEqual(prompt_chars, (4096 - bridge.NUM_PREDICT - 256) * 3)
        self.assertEqual(small['options']['num_ctx'], 4096)
        default = self.ask(corpus, 'Where is iron ore?')
        self.assertEqual(default['options']['num_ctx'], bridge.DEFAULT_NUM_CTX)
        large = self.ask(corpus, 'Where is iron ore?', num_ctx=32768)
        count = lambda payload: payload['messages'][0]['content'].count('PLAYER WIKI iron ore')
        self.assertLess(count(small), count(default))
        self.assertLess(count(default), count(large))
        self.assertLessEqual(len(json.dumps(['http://localhost/api/chat', large, {}, 1])), 64000)

    def test_reviewed_guides_cover_new_wiki_pages(self):
        for relative in ('guides/Guide_to_Combat.md', 'guides/Guide_to_Animals.md', 'guides/Guide_to_Trenches.md',
                         'guides/Guide_to_Survival.md', 'New_Player_Guide.md', 'Hotkeys.md', 'Colony_Medic.md',
                         'gamemodes/Team_Combat.md'):
            self.assertIn(relative, bridge.WIKI_REVIEWED_GUIDES)
        for digest, aliases in bridge.WIKI_REVIEWED_GUIDES.values():
            self.assertRegex(digest, r'^[0-9a-f]{64}$')
            self.assertTrue(aliases.strip())

    @unittest.skipUnless(os.environ.get('CIV13_WIKI_ROOT'), 'set CIV13_WIKI_ROOT to a civ13-wiki checkout')
    def test_reviewed_hashes_match_wiki_checkout(self):
        status = {}
        bridge.gameplay_knowledge(ROOT, os.environ['CIV13_WIKI_ROOT'], wiki_status=status)
        self.assertEqual(status['verified_guides'], len(bridge.WIKI_REVIEWED_GUIDES), status)


if __name__ == '__main__':
    unittest.main()
