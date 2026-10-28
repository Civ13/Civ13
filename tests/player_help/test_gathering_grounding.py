"""Offline integration of the generated Atlas and injected player-help transport."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import test_bridge

ROOT = Path(__file__).resolve().parents[2]
bridge = test_bridge.bridge


class GatheringGroundingTests(unittest.TestCase):
    setUp = test_bridge.BridgeTests.setUp
    tearDown = test_bridge.BridgeTests.tearDown
    make = test_bridge.BridgeTests.make

    @classmethod
    def setUpClass(cls):
        cls.folder = tempfile.TemporaryDirectory()
        cls.catalog = Path(cls.folder.name) / 'atlas.json'
        subprocess.run([sys.executable, str(ROOT / 'scripts/build-crafting-atlas.py'),
                        '--catalog-only', '--game-catalog', str(cls.catalog)],
                       cwd=ROOT, check=True, capture_output=True, timeout=60)
        cls.atlas = json.loads(cls.catalog.read_text(encoding='utf-8'))

    @classmethod
    def tearDownClass(cls):
        cls.folder.cleanup()

    def answer_prompt(self, question, corpus):
        captured = []
        self.corpus = corpus
        instance = self.make(lambda _, payload, *args: captured.append(payload) or
                             {'message': {'content': 'Injected fixture answer'}})
        result = instance.answer({'id': '1-2-3', 'account': 'a' * 32,
                                  'question': question,
                                  'game_context': {'map': 'Nomads Gaia', 'civilizations': True}})
        self.assertEqual(result['status'], 'ok')
        return captured[0]['messages'][0]['content'].lower()

    def test_turf_and_item_have_same_route_but_distinct_identities(self):
        turf, item = '/turf/floor/beach/sand', '/obj/item/stack/ore/glass'
        self.assertEqual(self.atlas['resources'][turf]['type'], turf)
        self.assertEqual(self.atlas['resources'][item]['type'], item)
        self.assertEqual(self.atlas['resources'][item]['name'], 'sand')
        terrain = next(r for r in self.atlas['acquisition'][turf] if r['name'] == 'Shovel sand')
        output = next(r for r in self.atlas['acquisition'][item] if r['name'] == 'Shovel sand')
        self.assertEqual(terrain, output)
        self.assertEqual(terrain['outputs'], [item])
        self.assertIn('non-harm', terrain['conditions'].lower())
        self.assertIn('available', terrain['conditions'].lower())

    def test_sand_and_adjacent_forage_reach_help(self):
        projector = getattr(bridge, 'acquisition_context', None)
        self.assertIsNotNone(projector, 'Help must project reviewed acquisition routes')
        corpus = projector(self.catalog) + bridge.recipe_context(self.catalog) + bridge.gameplay_knowledge(ROOT)
        for question, expected in [('How do I get sand from desert sand?', 'shovel sand'),
                                   ('How can I gather and sharpen flint?', 'gather and sharpen flint'),
                                   ('How can I sift iron ore?', 'sift iron ore')]:
            with self.subTest(question=question):
                prompt = self.answer_prompt(question, corpus)
                self.assertIn(expected, prompt)
                self.assertNotIn('code/game/', prompt)
                self.instances[-1].close()
                self.instances.pop()

    def test_rain_collector_alias_selects_actual_dew_recipe_and_gates(self):
        recipes = bridge.recipe_context(self.catalog)
        dew = next(row for row in recipes if row['topic'].startswith('dew collector'))
        self.assertIn('rain collector', dew['topic'])
        distractors = [{'topic': 'rain', 'source': 'code', 'text': 'rain ' + 'x' * 9000},
                       {'topic': 'rain', 'source': 'code', 'text': 'rain ' + 'y' * 9000}]
        prompt = self.answer_prompt('How do I make a rain collector?', recipes + bridge.gameplay_knowledge(ROOT) + distractors)
        self.assertIn('recipe: dew collector', prompt)
        self.assertIn('8 x softwood', prompt)
        self.assertIn('basic_agriculture', prompt)
        self.assertIn('current gameplay code (dew collector rain collector', prompt)
        self.assertIn('findtext(a.icon_state, "rain")', prompt)
        self.assertIn('do not claim research is unlocked from era alone', prompt)

    def test_unknown_terms_and_private_fields_are_not_projected(self):
        projector = getattr(bridge, 'acquisition_context', None)
        self.assertIsNotNone(projector)
        data = {'resources': {'/obj/thing': {'name': 'quartz', 'type': '/obj/thing'}},
                'acquisition': {'/obj/thing': [{'name': 'Collect quartz', 'steps': ['Pick it up'],
                    'file': 'PRIVATE PATH', 'raw': 'PRIVATE SECRET', 'conditions': 'Nearby only'}]}}
        fixture = Path(self.folder.name) / 'privacy.json'
        fixture.write_text(json.dumps(data), encoding='utf-8')
        rows = projector(fixture)
        self.assertNotIn('PRIVATE', str(rows))
        self.assertNotIn('PRIVATE', self.answer_prompt('Where is quartz?', rows))

    def test_rain_alias_is_bound_to_collector_output_only(self):
        recipes = [
            {'name': 'dew collector', 'kind': 'Material / global', 'inputs': [],
             'outputs': [{'id': '/obj/structure/reagent_dispensers/dew_collector', 'name': 'dew collector'}]},
            {'name': 'dew cloth', 'kind': 'Material / global', 'inputs': [],
             'outputs': [{'id': '/obj/item/dew_cloth', 'name': 'dew cloth'}]},
        ]
        fixture = Path(self.folder.name) / 'aliases.json'
        fixture.write_text(json.dumps({'recipes': recipes}), encoding='utf-8')
        rows = bridge.recipe_context(fixture)
        self.assertIn('rainwater collector', rows[0]['topic'])
        self.assertNotIn('rain', rows[1]['topic'])


if __name__ == '__main__':
    unittest.main()
