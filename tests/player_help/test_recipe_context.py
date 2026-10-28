"""Recipe wording and actual prompt projection, with injected transport only."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('recipe_bridge', ROOT / 'scripts/player_help_bridge.py')
bridge = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(bridge)


class RecipeContextTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        atlas = bridge.bounded_json(ROOT / 'UI/crafting-atlas.json', 16 * 1024 * 1024)
        cls.sawmill = next(recipe for recipe in atlas['recipes']
                           if recipe['name'] == 'primitive saw mill' and recipe['kind'] == 'Material / global')
        cls.material_recipes = [recipe for recipe in atlas['recipes'] if recipe['kind'].startswith('Material / ')]

    def project(self, recipes):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / 'atlas.json'
            path.write_text(json.dumps({'recipes': recipes}), encoding='utf-8')
            return bridge.recipe_context(path)

    def test_actual_primitive_sawmill_legacy_catalog_matches_recipe_and_formats_meaning(self):
        rows = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8').splitlines()
        row = next(row for row in rows if ',primitive saw mill,/obj/structure/sawmill,' in row)
        columns = row.split('RECIPE: ', 1)[1].split(',')
        self.assertEqual(columns[3:7], ['28', '60', '1', '1'])
        text = self.project([self.sawmill])[0]['text']
        self.assertIn('inputs: 28 x wood', text)
        self.assertIn('base construction time 6 simulation seconds', text)
        self.assertIn('strength/crafting modifiers (crafting squared)', text)
        self.assertIn('rounded and interruptible', text)
        self.assertIn('requires a floor-tile surface', text)
        self.assertIn('at most one resulting object per tile', text)
        self.assertIn('category economy & production', text)
        self.assertIn('maximum era ordinal 8', text)
        self.assertIn('Research-node and map gates also apply.', text)
        self.assertIn('Explicit research node: resource_processing.', text)
        self.assertNotIn('floor 1', text)
        self.assertNotIn('time 60 deciseconds', text)

    def test_false_flags_and_zero_or_fractional_base_time(self):
        for one in ('0', '1'):
            for floor in ('0', '1'):
                with self.subTest(one=one, floor=floor):
                    mixed = copy.deepcopy(self.sawmill)
                    mixed['conditions'] = mixed['conditions'].replace('one per turf 1; floor 1',
                                                                      f'one per turf {one}; floor {floor}')
                    text = bridge.recipe_conditions(mixed)
                    self.assertEqual('requires a floor-tile surface' in text, floor == '1')
                    self.assertEqual('at most one resulting object per tile' in text, one == '1')
        recipe = copy.deepcopy(self.sawmill)
        recipe['conditions'] = recipe['conditions'].replace('one per turf 1; floor 1', 'one per turf 0; floor 0')
        recipe['conditions'] = recipe['conditions'].replace('time 60 deciseconds', 'time 0 deciseconds')
        text = bridge.recipe_conditions(recipe)
        self.assertIn('no recipe-specific floor-tile surface requirement', text)
        self.assertIn('no recipe-specific one-per-tile restriction', text)
        self.assertIn('0 simulation seconds (no timed wait)', text)
        self.assertNotIn('modifiers can change', text)
        recipe['conditions'] = recipe['conditions'].replace('time 0 deciseconds', 'time 15.5 deciseconds')
        self.assertIn('base construction time 1.55 simulation seconds', bridge.recipe_conditions(recipe))

    def test_malformed_unknown_and_unrelated_conditions_are_not_rewritten(self):
        for conditions in (None, {'private': 'SECRET DATA'}, ['floor 1', 'SECRET DATA']):
            with self.subTest(conditions=conditions):
                projected = self.project([None, 7, {'name': 'malformed', 'kind': 'Material / global', 'conditions': conditions}])
                self.assertEqual(len(projected), 1)
                self.assertIn('Unknown catalog conditions.', projected[0]['text'])
                self.assertNotIn('SECRET', projected[0]['text'])
        for fragment in ('floor 2', 'floor 3', 'floor true', 'one per turf 2', 'time NaN deciseconds'):
            with self.subTest(fragment=fragment):
                recipe = copy.deepcopy(self.sawmill)
                old = 'one per turf 1' if fragment.startswith('one') else 'time 60 deciseconds' if fragment.startswith('time') else 'floor 1'
                recipe['conditions'] = recipe['conditions'].replace(old, fragment)
                text = bridge.recipe_conditions(recipe)
                self.assertTrue(text.startswith('Catalog conditions (uninterpreted): '))
                self.assertIn(fragment, text)
                self.assertNotIn('requires a floor-tile surface', text)
        raw = 'Unknown gate; floor 1; time 60 deciseconds; one per turf 1'
        self.assertEqual(bridge.recipe_conditions({'kind': 'Processor', 'conditions': raw}), raw)
        self.assertEqual(bridge.recipe_conditions(dict(self.sawmill, kind='Processor')), self.sawmill['conditions'])
        text = bridge.recipe_conditions({'kind': 'Material / global', 'conditions': raw})
        self.assertIn(raw, text)
        self.assertNotIn('base construction time', text)

    def test_unknown_extra_conditions_bounds_and_source_privacy(self):
        recipe = copy.deepcopy(self.sawmill)
        recipe['conditions'] += ' Unknown weather gate remains unverified.'
        recipe.update(file='SECRET PATH', raw='SECRET CODE', source='SECRET SOURCE', sprite='SECRET IMAGE')
        text = self.project([recipe])[0]['text']
        self.assertIn('Unknown weather gate remains unverified.', text)
        self.assertNotIn('SECRET', text)
        recipe['conditions'] += 'x' * 10000
        self.assertLessEqual(len(bridge.recipe_conditions(recipe)), 500)
        self.assertIn('requirements are unknown here. Consult the Crafting Atlas.', bridge.recipe_conditions(recipe))
        recipe['name'] = 'n' * 10000
        self.assertLessEqual(len(self.project([recipe])[0]['text']), 2000)

    def test_installed_recognized_material_conditions_keep_all_gate_clauses(self):
        for recipe in self.material_recipes:
            match = bridge.MATERIAL_CONDITIONS.fullmatch(recipe['conditions'])
            if match:
                with self.subTest(recipe=recipe['name']):
                    formatted = bridge.recipe_conditions(recipe)
                    self.assertIn(match['gates'], formatted)
                    self.assertIn(match['extra'], formatted)
                    self.assertLessEqual(len(formatted), 500)

    def test_injected_transport_captures_grounded_sawmill_prompt_without_inference(self):
        calls = []
        corpus = self.project([self.sawmill])
        corpus.append({'topic': 'primitive saw mill', 'source': 'recipe', 'catalog': 'Material / camp',
                       'text': 'WRONG MAP COST AND CONDITIONS'})
        with tempfile.TemporaryDirectory() as temporary, \
                mock.patch.object(bridge, 'network', side_effect=AssertionError('network forbidden')), \
                mock.patch.object(bridge, 'network_child', side_effect=AssertionError('network forbidden')):
            instance = bridge.Bridge(Path(temporary) / 'spool',
                                     {'enabled': True, 'model': 'injected-test', 'endpoint': 'unused',
                                      'workers': 1, 'timeout_seconds': 1}, corpus,
                                     lambda *args: calls.append(args) or {'message': {'content': 'Injected fixture reply'}})
            try:
                result = instance.answer({'id': '1-2-3', 'account': 'a' * 32,
                                          'question': 'How do I make a primitive saw mill in Nomads Gaia?',
                                          'game_context': {'map': 'Nomads (Gaia)', 'civilizations': True,
                                                           'era_ordinal': 8, 'research_unlocked': 'PRIVATE',
                                                           'player': {'ckey': 'PRIVATE'}}})
            finally:
                instance.close()
        self.assertEqual(result['status'], 'ok')
        self.assertEqual(len(calls), 1)
        prompt = calls[0][1]['messages'][0]['content']
        self.assertIn('inputs: 28 x wood', prompt)
        self.assertIn('requires a floor-tile surface', prompt)
        self.assertIn('base construction time 6 simulation seconds', prompt)
        self.assertIn('strength/crafting modifiers (crafting squared)', prompt)
        self.assertIn('Explicit research node: resource_processing.', prompt)
        self.assertIn('Do not claim research is unlocked from era alone.', prompt)
        for forbidden in ('floor 1', 'time 60 deciseconds', 'level 1', 'WRONG MAP', 'PRIVATE', 'a' * 32):
            self.assertNotIn(forbidden, prompt)

    def test_sawmill_processing_prompt_uses_one_plank_yield(self):
        catalog = ROOT / 'UI/crafting-atlas.json'
        corpus = (bridge.bounded_json(ROOT / 'UI/player-help.json', 32768)
                  + bridge.recipe_context(catalog) + bridge.acquisition_context(catalog)
                  + bridge.gameplay_knowledge(ROOT))
        calls = []
        with tempfile.TemporaryDirectory() as temporary, \
                mock.patch.object(bridge, 'network', side_effect=AssertionError('network forbidden')), \
                mock.patch.object(bridge, 'network_child', side_effect=AssertionError('network forbidden')):
            instance = bridge.Bridge(Path(temporary),
                                     {'enabled': True, 'model': 'injected-test', 'endpoint': 'unused',
                                      'workers': 1, 'timeout_seconds': 1}, corpus,
                                     lambda *args: calls.append(args) or {'message': {'content': 'fixture'}})
            try:
                result = instance.answer({'id': '1-2-3', 'account': 'a' * 32,
                                          'question': 'How do I use a primitive sawmill to cut logs and replace its flint blade?',
                                          'game_context': {'map': 'Nomads Gaia', 'civilizations': True}})
            finally:
                instance.close()
        self.assertEqual(result['status'], 'ok')
        prompt = calls[0][1]['messages'][0]['content'].lower()
        self.assertIn('one log yields one plank and one bark', prompt)
        self.assertIn('sharpened flint', prompt)
        self.assertNotIn('one log yields four planks', prompt)


if __name__ == '__main__':
    unittest.main()
