"""Ask for Help finds the wiki passage that answers a player's question.

Offline: the real corpus and the guide copies shipped with the game, an
injected transport, no model. tests/player_help/wiki_eval/run.py scores the
same questions against a live model when an operator wants answer scores.
"""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('wiki_eval_run', ROOT / 'tests/player_help/wiki_eval/run.py')
wiki_eval = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(wiki_eval)
bridge = wiki_eval.load_bridge(ROOT / 'scripts/player_help_bridge.py')
QUESTIONS = json.loads(wiki_eval.QUESTIONS.read_text(encoding='utf-8'))


def options(marker):
    return [marker] if isinstance(marker, str) else marker


class WikiAnswerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.corpus, cls.status = wiki_eval.build_corpus(bridge, ROOT)
        cls.temp = tempfile.TemporaryDirectory()
        cls.prompts = []
        # The live worker's budget: a 16384-token window and 16000 evidence characters.
        config = {'enabled': True, 'model': 'test', 'endpoint': 'http://localhost/api/chat', 'workers': 1,
                  'timeout_seconds': 1, 'num_ctx': 16384, 'evidence_chars': 16000,
                  'limits': {'global_requests': 4096, 'global_seconds': 1}}
        cls.replies = []
        cls.worker = bridge.Bridge(Path(cls.temp.name) / 'spool', config, cls.corpus,
                                   lambda endpoint, payload, *rest: cls.prompts.append(payload['messages'][0]['content'])
                                   or {'message': {'content': cls.replies.pop() if cls.replies else 'Answer'}})

    @classmethod
    def tearDownClass(cls):
        cls.worker.close()
        cls.temp.cleanup()

    def evidence(self, question, account):
        reply = self.worker.answer({'id': '1', 'account': '%032x' % account, 'question': question,
                                    'game_context': wiki_eval.GAME_CONTEXT})
        self.assertEqual(reply['status'], 'ok')
        return wiki_eval.plain(self.prompts[-1]), reply

    def test_every_pinned_guide_ships_with_the_game(self):
        self.assertEqual(self.status['verified_guides'], len(bridge.WIKI_REVIEWED_GUIDES))
        self.assertEqual((self.status['missing_guides'], self.status['changed_guides']), (0, 0))
        shipped = {str(path.relative_to(ROOT / bridge.WIKI_BUNDLE)).replace('\\', '/')
                   for path in (ROOT / bridge.WIKI_BUNDLE).rglob('*.md')}
        self.assertEqual(shipped, set(bridge.WIKI_REVIEWED_GUIDES))

    def test_question_set_quotes_the_shipped_guides(self):
        self.assertGreaterEqual(len(QUESTIONS), 30)
        for entry in QUESTIONS:
            if entry['page'] is None:
                continue
            page = (ROOT / bridge.WIKI_BUNDLE / entry['page']).read_text(encoding='utf-8')
            for marker in entry['evidence']:
                with self.subTest(question=entry['id'], marker=options(marker)[0]):
                    # The first option is always the named guide's own wording.
                    self.assertIn(options(marker)[0], page)

    def test_each_question_reaches_the_model_with_its_answer(self):
        for index, entry in enumerate(QUESTIONS):
            if not entry['evidence']:
                continue
            with self.subTest(question=entry['id']):
                evidence, _ = self.evidence(entry['question'], index + 1)
                for marker in entry['evidence']:
                    self.assertTrue(any(option in evidence for option in options(marker)), options(marker)[0])
                self.assertIn('https://civ13.github.io/civ13-wiki/' + entry['page'].removesuffix('.md') + '.html', evidence)

    def test_excerpts_keep_their_headings_and_section_links(self):
        source = ('# Fishing\nIntro line.\n\n## Bait\nUse raw meat.\n\n### Ice fishing\n' + 'Cut a hole in the ice. ' * 150 +
                  '\n\n## Nets\n[Nets](Other.md#nets) take no bait.\n<img src="x.png">\n```admonish info\nA note.\n```\n| a | b |\n| --- | --- |\n| 1 | 2 |\n')
        chunks = bridge.wiki_chunks(source)
        self.assertTrue(all(len(text) <= bridge.WIKI_CHUNK_CHARS + 200 for _, _, text in chunks))
        ice = [chunk for chunk in chunks if 'Ice fishing' in chunk[0]]
        self.assertGreater(len(ice), 1)
        # Every piece of a long section still says where it comes from.
        self.assertTrue(all(text.startswith('Fishing > Bait > Ice fishing\n') and anchor == 'ice-fishing' for _, anchor, text in ice[1:]))
        self.assertTrue(all(text.rstrip().endswith('.') for _, _, text in ice[1:-1]))
        nets = chunks[-1][2]
        self.assertIn('Nets take no bait.', nets)
        self.assertIn('| 1 | 2 |', nets)
        for removed in ('Other.md', '<img', '```', '---'):
            self.assertNotIn(removed, nets)
        self.assertEqual(bridge.wiki_anchor('Walking to a neighbouring land'), 'walking-to-a-neighbouring-land')

    def test_hidden_topics_and_internal_names_are_withheld(self):
        text = bridge.wiki_plain('| 5 | Quick-cast spell 5 |\nA clear spell of weather.\n- [Nations RP (Persistence Beta)](Persistence_Beta.md)\nThe wizard casts a spell with a wand.\n')
        self.assertEqual(text, 'A clear spell of weather.\n- the persistent world')
        for entry in self.corpus:
            if entry.get('source') == 'wiki':
                self.assertNotRegex(entry['text'], r'Persistence|[Mm]agic|\bmana\b|Quick-cast')
        self.assertNotIn('persistence', ' '.join(aliases for _, aliases in bridge.WIKI_REVIEWED_GUIDES.values()).lower())
        self.assertFalse(any('wizard' in relative.lower() for relative in bridge.WIKI_REVIEWED_GUIDES))
        # Whatever the model writes, the internal server name never reaches a player.
        self.replies.append('Persistence is the long world; on Nations RP (Persistence Beta) you keep your home.')
        _, reply = self.evidence('What is the long-running world called?', 900)
        self.assertEqual(reply['answer'], 'the persistent world is the long world; on the persistent world you keep your home.')
        self.assertIn('Magic and other hidden discoveries', self.prompts[-1])

    def test_rare_words_and_named_entries_rank_first(self):
        corpus = ([{'topic': 'wooden thing %d' % index, 'source': 'recipe', 'text': 'Recipe: a wooden thing made of wood.'} for index in range(30)] +
                  [{'topic': 'guides/Guide_to_Flint.md Getting flint', 'aliases': 'flint knapping', 'headings': 'Getting flint', 'source': 'wiki',
                    'text': 'PLAYER WIKI url:\n"Click a large rock for flint."'},
                   {'topic': 'guides/Guide_to_Homes.md Furniture', 'aliases': 'home house', 'headings': 'Furniture', 'source': 'wiki',
                    'text': 'PLAYER WIKI url:\n"A wooden table. Flint is not furniture."'}])
        with tempfile.TemporaryDirectory() as spool:
            prompts = []
            worker = bridge.Bridge(Path(spool) / 'spool', {'enabled': True, 'model': 'test', 'endpoint': 'http://localhost/api/chat',
                                                           'workers': 1, 'timeout_seconds': 1}, corpus,
                                   lambda endpoint, payload, *rest: prompts.append(payload['messages'][0]['content']) or {'message': {'content': 'Answer'}})
            try:
                worker.answer({'id': '1', 'account': 'a' * 32, 'question': 'Where do I find wooden flint?'})
            finally:
                worker.close()
        self.assertLess(worker.term_weights()['wooden'], worker.term_weights()['flint'])
        self.assertLess(prompts[0].index('Click a large rock'), prompts[0].index('Flint is not furniture'))
        self.assertLess(prompts[0].index('Flint is not furniture'), prompts[0].index('a wooden thing made of wood'))
        self.assertEqual(bridge.question_synonyms('My leg is broken', {'leg', 'broken'}), {'fractur', 'splint'})


if __name__ == '__main__':
    unittest.main()
