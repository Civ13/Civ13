"""Source/catalog contracts for the entire leather route; no native execution."""
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('tanning', ROOT/'scripts/atlas/tanning.py')
tanning = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tanning)


class TanningAtlasTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with tempfile.TemporaryDirectory() as folder:
            target = Path(folder)/'catalog.json'
            subprocess.run([sys.executable, str(ROOT/'scripts/build-crafting-atlas.py'),
                            '--catalog-only', '--game-catalog', str(target)], check=True, capture_output=True)
            cls.catalog = json.loads(target.read_text())
        cls.recipes = cls.catalog['recipes']

    def recipe(self, name):
        matches = [r for r in self.recipes if r['name'] == name]
        self.assertEqual(len(matches), 1, name)
        return matches[0]

    def test_paid_quantities_and_log_co_products(self):
        expected = {
            'Wash a prepared hide': ([('/material/hairlesshide', '1'), ('water', '5')], [('/material/wethide', '1')]),
            'Tan a dry hide into leather': ([('/material/dryhide', '1'), ('tannin', '5')], [('/material/leather', '1')]),
            'Extract bark tannin': ([('/obj/item/stack/bark', '1'), ('water', '10')], [('tannin', '10')]),
            'Cut logs with a hatchet for bark': ([('/material/wood', '2')], [('/material/wood/soft', '1'), ('/obj/item/stack/bark', '2')]),
            'Cut logs with a saw for bark': ([('/material/wood', '1')], [('/material/wood/soft', '4'), ('/obj/item/stack/bark', '1')]),
        }
        for name, pair in expected.items():
            recipe = self.recipe(name)
            actual = tuple([(x['id'], x['quantity']) for x in recipe[field]] for field in ('inputs', 'outputs'))
            self.assertEqual(actual, pair, name)

    def test_turkey_to_existing_leather_recipes_requires_every_stage(self):
        recipes = [r for r in self.recipes if r['kind'] == 'Leather tanning']
        target = '/material/leather'
        stages = ['Scrape rawhide into a prepared hide', 'Wash a prepared hide',
                  'Rack-dry washed hides', 'Tan a dry hide into leather', 'Extract bark tannin']

        def reachable(sex, excluded=''):
            known = {'/mob/living/simple_animal/turkey_'+sex, 'water', '/material/wood', tanning.STATION}
            for _ in recipes:
                old = set(known)
                for recipe in recipes:
                    if recipe['name'] != excluded and all(x['id'] in known for x in recipe['inputs']):
                        known.update(x['id'] for x in recipe['outputs'])
                if old == known:
                    break
            return known
        for sex in ('f', 'm'):
            self.assertIn(target, reachable(sex))
            for stage in stages:
                self.assertNotIn(target, reachable(sex, stage), stage)
        self.assertTrue(any(any(x['id'] == target for x in r['inputs']) and
                            r['kind'] != 'Leather tanning' for r in self.recipes), 'finished leather feeds existing crafting')
        for sex in ('hen', 'tom'):
            r = self.recipe('Harvest adult turkey '+sex+' skin')
            self.assertEqual(r['outputs'], [{'id': '/material/rawhide', 'name': 'raw hide', 'quantity': '1'}])
            self.assertIn('chicks give no hide', r['conditions'])
            self.assertIn('do not yield mammalian', r['conditions'])

    def test_rack_is_linked_to_construction_research_and_not_consumed(self):
        rack = self.recipe('Rack-dry washed hides')
        self.assertEqual(rack['processor'], 'tanning_rack')
        self.assertEqual(rack['station'], tanning.STATION)
        self.assertEqual(rack['unlock_eras'], [1])
        self.assertIn('Station construction research: resource_processing', rack['era_basis'])
        self.assertEqual([(x['id'], x['quantity']) for x in rack['inputs']],
                         [('/material/wethide', 'n pieces'), (tanning.STATION, 'station; not consumed')])
        self.assertEqual(rack['outputs'][0]['quantity'], 'n pieces')
        build = next(r for r in self.recipes if r['name'] == 'tanning rack' and r['file'].endswith('material_recipes_global.txt'))
        self.assertEqual([(x['id'], x['quantity']) for x in build['inputs']], [('/material/wood', '8')])
        self.assertEqual(build['unlock_eras'], [1])

    def test_acquisition_navigation_names_states_and_reviewed_sources(self):
        for resource in ['/material/rawhide', '/material/hairlesshide', '/material/wethide',
                         '/material/dryhide', '/material/leather', '/obj/item/stack/bark', 'tannin']:
            self.assertIn(resource, self.catalog['resources'])
            self.assertIn(resource, self.catalog['acquisition'])
            for route in self.catalog['acquisition'][resource]:
                self.assertTrue(route['steps'])
                self.assertTrue(route['audit_commit'])
                self.assertTrue((ROOT/route['file']).is_file())
                self.assertGreater(route['line'], 0)
                for linked in route['inputs']+route['outputs']:
                    self.assertIn(linked, self.catalog['resources'])
        self.assertEqual(self.catalog['resources']['/material/wethide']['type'], tanning.STACK+'wethide')
        self.assertEqual(self.catalog['resources'][tanning.BARK]['type'], tanning.BARK)
        self.assertIn('tannin', self.catalog['resources']['tannin']['name'])
        # Reagents are abstract resources, never a fabricated item sprite type.
        self.assertEqual(self.catalog['resources']['tannin']['type'], 'tannin')

    def test_no_animal_leather_shortcut_and_fur_remains_connected(self):
        leather_routes = self.catalog['acquisition']['/material/leather']
        self.assertEqual([r['name'] for r in leather_routes], ['Tan a dry hide into leather'])
        butcher = self.recipe('Butcher large mammals')
        self.assertNotIn('/material/leather', [x['id'] for x in butcher['outputs']])
        self.assertIn('/material/rawhide', [x['id'] for x in butcher['outputs']])
        scrape = self.recipe('Scrape sheeppelt into a prepared hide')
        pelt = scrape['inputs'][0]['id']
        self.assertTrue(any(r['name'] == 'Skin Sheep' and pelt in [x['id'] for x in r['outputs']] for r in self.recipes))
        self.assertTrue(any(pelt in [x['id'] for x in r['inputs']] and r['kind'].startswith('Material /') for r in self.recipes))

    def test_audited_source_drift_fails_closed(self):
        paths = json.loads((ROOT/'scripts/atlas/tanning-contracts.json').read_text())['sources']
        files = {p: (ROOT/p).read_text(encoding='utf-8') for p in paths}
        controls = [(tanning.LEATHER, '"water", 10', '"water", 100'),
                    (tanning.RACK, 'input1 = null', 'input1 = /obj/item/stack/material/lead'),
                    (tanning.LOGS, 'hatchet ? 2 : 1', 'hatchet ? 20 : 1'),
                    (tanning.HARVEST, 'return 1', 'return 3')]
        for path, old, new in controls:
            changed = files[path].replace(old, new)
            self.assertNotEqual(changed, files[path])
            with self.assertRaisesRegex(ValueError, 'Tanning source changed'):
                tanning.add_tanning(files | {path: changed}, lambda *a: None, [], {})

    def test_rack_entrypoint_and_processor_filter_are_present(self):
        source = (ROOT/'code/game/mob/crafting_atlas.dm').read_text()
        route = source.split('/obj/structure/converter/tanning/verb/processing_reference()')[1].split('/datum/')[0]
        self.assertIn('show(usr, processor = "tanning_rack")', route)
        self.assertIn("<option value='tanning_rack'", source)

    def test_committed_catalog_is_current(self):
        subprocess.run([sys.executable, str(ROOT/'scripts/build-crafting-atlas.py'), '--catalog-only',
                        '--check-game-catalog', str(ROOT/'UI/crafting-atlas.json')], check=True, capture_output=True)


if __name__ == '__main__':
    unittest.main()
