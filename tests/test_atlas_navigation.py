"""Source-backed unlock/processing contracts and default entrypoint acceptance."""
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('metadata', ROOT/'scripts/atlas/catalog_metadata.py')
metadata = importlib.util.module_from_spec(spec)
spec.loader.exec_module(metadata)


class AtlasNavigationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with tempfile.TemporaryDirectory() as folder:
            target = Path(folder)/'catalog.json'
            subprocess.run([sys.executable, str(ROOT/'scripts/build-crafting-atlas.py'), '--catalog-only', '--game-catalog', str(target)], check=True, capture_output=True)
            cls.catalog = json.loads(target.read_text())

    def test_era_order_and_unknown_are_explicit(self):
        recipes = self.catalog['recipes']
        self.assertEqual([r['era_sort'] for r in recipes], sorted(r['era_sort'] for r in recipes))
        self.assertTrue(any(r['era_status'] == 'unknown' for r in recipes))
        mapped = [r for r in recipes if 'Research node:' in r['era_basis']]
        self.assertGreater(len(mapped), 100)
        self.assertTrue(any(r.get('maximum_era') != r['era_sort'] for r in mapped))
        modern = [r for r in recipes if 'Minimum era Modern' in r['conditions']]
        self.assertTrue(modern)
        self.assertTrue(all(r['unlock_eras'] == [8] for r in modern))

    def test_multiple_research_eras_and_expiry_negative_control(self):
        nodes = 'new /datum/research_node("a", "A", "I", 10, 0, MODE, null, 1)\nnew /datum/research_node("b", "B", "I", 10, 0, MODE, null, 4)\n"/obj/a" = "a"\n"/obj/b" = "b"'
        def record(outputs):
            return dict(id='test', name='Test', kind='Material / fixture', outputs=[{'id': x} for x in outputs], conditions='maximum era ordinal 8')
        multi, unknown = record(['/obj/a', '/obj/b']), record(['/obj/unmapped'])
        metadata.annotate_eras([multi, unknown], nodes, lambda s: [x.strip() for x in s.split(',')])
        self.assertEqual(multi['unlock_eras'], [1, 4])
        self.assertEqual(multi['era_status'], 'multiple')
        self.assertEqual(unknown['unlock_eras'], [])
        self.assertEqual(unknown['maximum_era'], 8)
        partial = record(['/obj/a', '/obj/unmapped'])
        metadata.annotate_eras([partial], nodes, lambda s: [x.strip() for x in s.split(',')])
        self.assertEqual(partial['unlock_eras'], [])
        self.assertIn('Combined unlock unknown', partial['era_basis'])
        # The deliberately wrong expiry-as-unlock candidate fails this contract.
        def accepts(candidate):
            return candidate['unlock_eras'] == [] and candidate['era_sort'] == 99
        self.assertTrue(accepts(unknown))
        self.assertFalse(accepts(unknown | {'unlock_eras': [8], 'era_sort': 8}))

    def test_processor_conversions_and_source_drift_control(self):
        recipes = self.catalog['recipes']
        saw = [r for r in recipes if r.get('processor') == 'sawmill']
        self.assertEqual(len(saw), 3)
        self.assertEqual({r['station']: r['unlock_eras'] for r in saw}, {'/obj/structure/sawmill': [1], '/obj/structure/sawmill/large': [3], '/obj/structure/sawmill/powered': [3]})
        self.assertEqual({r['outputs'][0]['quantity'] for r in saw}, {'4 nominal', '10 nominal', '12 nominal'})
        self.assertTrue(all(r['inputs'][0]['quantity'] == '1' and 'skill failure' in r['conditions'] for r in saw))
        self.assertIn('cable power', next(r['conditions'] for r in saw if r['station'].endswith('/powered')))
        grain = [r for r in recipes if r.get('processor') == 'grain_mill']
        self.assertEqual(len(grain), 8)
        self.assertTrue(all(r['inputs'][0]['quantity'] == r['outputs'][0]['quantity'] == '1' for r in grain))
        self.assertTrue(any(r['inputs'][0]['id'].endswith('/wheat') and r['outputs'][0]['id'].endswith('/flour') for r in grain))
        source = (ROOT/'code/modules/1713/production.dm').read_text()
        changed = source.replace('W.amount * 12, FALSE', 'W.amount * 120, FALSE')
        self.assertNotEqual(changed, source)
        with self.assertRaisesRegex(ValueError, 'Sawmill source contract changed'):
            metadata.add_processors({'code/modules/1713/production.dm': changed}, lambda *a: None, [])

    def test_existing_entrypoints_use_default_and_legacy_is_deliberate(self):
        source = (ROOT/'code/game/mob/crafting_atlas.dm').read_text()
        verb = source.split('/mob/verb/crafting_atlas()')[1].split('/obj/')[0]
        self.assertIn('crafting_atlas_reference.show(src)', verb)
        self.assertIn('legacy = FALSE', source)
        self.assertIn('legacy ? page_html(viewer, query, page, recipe_id) : graph_html', source)
        self.assertIn('legacy = TRUE', source.split('else if (href_list["atlas_page"])')[1])
        self.assertIn('atlas_open=1', (ROOT/'code/game/objects/items/stacks/stack.dm').read_text())
        for processor in ('sawmill', 'grain_mill'):
            self.assertIn('show(usr, processor = "'+processor+'")', source)


if __name__ == '__main__':
    unittest.main()
