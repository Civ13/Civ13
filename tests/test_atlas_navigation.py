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
            cls.catalog_bytes = target.read_bytes()
            cls.catalog = json.loads(cls.catalog_bytes)

    def test_committed_catalog_matches_current_source(self):
        self.assertEqual(self.catalog_bytes, (ROOT/'UI/crafting-atlas.json').read_bytes())

    def test_chip_routes_preserve_batch_unit_and_expose_existing_oven_use(self):
        chips = '/obj/item/stack/wood_chips'
        routes = self.catalog['acquisition'][chips]
        self.assertEqual(len(routes), 2)
        producer, consumer = routes
        self.assertEqual(producer['outputs'], [chips])
        self.assertEqual(producer['inputs'], ['/material/wood'])
        self.assertIn('Five logs produce one abstract batch', producer['conditions'])
        self.assertIn('wizard_boy.dmm', producer['map_notes'])
        self.assertIn('Mapped base grinder:', producer['era'])
        self.assertIn('Constructed variant: Electricity', producer['era'])
        self.assertEqual(consumer['inputs'], [chips])
        self.assertEqual(consumer['outputs'], [])
        self.assertIn('five existing oven fuel units', consumer['steps'][1])
        self.assertIn('native', consumer['status'])
        # Acquisition notes and the unchanged fuel route have separate reviews.
        for route in (producer, consumer):
            self.assertRegex(route['audit_commit'], r'^[0-9a-f]{40}$')
        self.assertFalse(any('/material/wood' in r['outputs'] for r in routes))

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

    def test_radio_minimum_is_1903_without_retiring_in_later_eras(self):
        radio = {'/obj/structure/telecom', '/obj/structure/telecom/station', '/obj/structure/telecom/antenna'}
        rows = [r for r in self.catalog['recipes'] if any(o['id'] in radio for o in r['outputs'])]
        self.assertEqual(len(rows), 3)
        for row in rows:
            self.assertEqual(row['unlock_eras'], [5])
            self.assertEqual(row['maximum_era'], 8)
            self.assertIn('Construction minimum era', row['era_basis'])
        tv = [r for r in self.catalog['recipes'] if any(o['id'] in ('/obj/structure/telecom/tv', '/obj/structure/telecom/station/tv') for o in r['outputs'])]
        self.assertEqual(len(tv), 3)
        self.assertTrue(all(r['unlock_eras'] == [7] and r['maximum_era'] == 8 for r in tv))

    def test_constructed_grinder_has_exact_global_gate_and_prerequisite_notes(self):
        kind = '/obj/structure/grinder/constructed'
        recipes = [r for r in self.catalog['recipes'] if r['name'] == 'wood grinder']
        self.assertEqual(len(recipes), 1)
        recipe = recipes[0]
        self.assertEqual(recipe['kind'], 'Material / global')
        self.assertEqual([(i['id'], i['quantity']) for i in recipe['inputs']], [('/material/electronics', '20')])
        self.assertEqual([(i['id'], i['quantity']) for i in recipe['outputs']], [(kind, '1')])
        self.assertEqual(recipe['unlock_eras'], [5])
        self.assertEqual(recipe['maximum_era'], 8)
        self.assertEqual(self.catalog['resources'][kind]['name'], 'wood grinder')
        for note in ('Scaled base time', 'coefficient >= 2.2', 'nominal', 'full listed amount', 'No dismantling'):
            self.assertIn(note, recipe['conditions'])
        route, = self.catalog['acquisition'][kind]
        self.assertEqual(route['outputs'], [])  # Details for the real recipe, no duplicate build route.
        self.assertIn('global catalog', route['conditions'])
        self.assertIn('Wizard Boy', route['map_notes'])
        self.assertNotIn('/obj/structure/grinder', self.catalog['acquisition'])

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
        self.assertEqual({r['outputs'][0]['quantity'] for r in saw}, {'1', '10 nominal', '12 nominal'})
        self.assertTrue(all(r['inputs'][0]['quantity'] == '1' for r in saw))
        primitive = next(r for r in saw if r['station'] == '/obj/structure/sawmill')
        self.assertIn('sharpened flint', primitive['conditions'])
        self.assertIn('20 logs', primitive['conditions'])
        self.assertIn('One log yields one plank and one bark', primitive['conditions'])
        self.assertTrue(all('skill failure' in r['conditions'] for r in saw if r is not primitive))
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

    def test_sawmill_conditions_do_not_contaminate_other_machines(self):
        sources = json.loads((ROOT/'scripts/atlas/resource-sources.json').read_text())
        routes = [r for r in sources['mechanisms'] if r['name'] in ('Loom processing', 'Mill processing', 'Sawmill processing')]
        self.assertEqual({name: sum(r['name'] == name for r in routes) for name in ('Loom processing', 'Mill processing', 'Sawmill processing')},
                         {'Loom processing': 4, 'Mill processing': 4, 'Sawmill processing': 1})
        def unrelated_conditions_are_clean(route):
            text = route['conditions'].lower()
            return all(word not in text for word in ('sawmill', 'saw mill', 'flint', 'blade', 'plank', 'log'))
        for route in routes:
            if route['name'] != 'Sawmill processing':
                self.assertEqual(route['conditions'], 'Anchored machine; worker mood, stamina, skill and wait conditions apply.')
                self.assertTrue(unrelated_conditions_are_clean(route))
                self.assertEqual(route['source_commit'], 'd3b3ab657d6bd34e50ca61d1084b44ca077300e1')
                self.assertFalse(unrelated_conditions_are_clean(route | {'conditions': route['conditions'] + ' flint blade'}))
            else:
                self.assertIn('sharpened flint', route['conditions'])
                self.assertIn('one ordinary log into one plank and one bark', route['conditions'])
                self.assertEqual(route['source_commit'], 'd228a3ec507660d79d14019e800af5f5310ce685')
                self.assertEqual(route['line'], 2216)
        generated = [r for entries in self.catalog['acquisition'].values() for r in entries
                     if r['name'] in ('Loom processing', 'Mill processing', 'Sawmill processing')]
        self.assertEqual(len(generated), 9)
        self.assertTrue(all(unrelated_conditions_are_clean(r) for r in generated if r['name'] != 'Sawmill processing'))
        sand = next(r for r in self.catalog['acquisition']['/turf/floor/beach/sand'] if r['name'] == 'Shovel sand')
        self.assertIn('non-harm', sand['conditions'])

    def test_hand_interactions_are_generated_from_source(self):
        routes = self.catalog['acquisition']
        grown = '/obj/item/weapon/reagent_containers/food/snacks/grown/'
        expected = {
            'chamomile_tea': 'Steep chamomile flowers into chamomile tea',
            'elderflower_tea': 'Steep elderflowers into elderflower tea',
            'sunflower_oil': 'Grind shelled sunflower seeds in a mortar and pestle',
            grown + 'dried_mint': 'Dry mint on a dehydrator',
            grown + 'sunflower_seeds': 'Shell a sunflower head',
            grown + 'dandelion_root': 'Grow and harvest dandelion',
            '/obj/item/stack/medical/wild_herb/yarrow': 'Pick yarrow',
            '/obj/item/weapon/material/hide_scraper': 'Knap a hide scraper from flint',
            '/obj/item/weapon/reagent_containers/food/snacks/fishfillet': 'Fillet raw fish',
        }
        for resource, name in expected.items():
            self.assertIn(name, [route['name'] for route in routes.get(resource, [])], resource)
            self.assertIn(resource, self.catalog['resources'])
        tea = next(r for r in self.catalog['recipes'] if r['name'] == expected['chamomile_tea'])
        self.assertEqual([(x['id'], x['quantity']) for x in tea['inputs']], [(grown + 'chamomile', '1'), ('water', '5')])
        self.assertEqual(tea['research_status'], 'excluded')
        scraper = next(r for r in self.catalog['recipes'] if r['name'] == expected['/obj/item/weapon/material/hide_scraper'])
        self.assertEqual(scraper['research_nodes'], ['basic_tools'])
        # Curated routes win: wheat keeps its reviewed harvest text and gets no generated copy.
        wheat = [r['name'] for r in routes[grown + 'wheat']]
        self.assertNotIn('Grow and harvest wheat', wheat)

    def test_new_content_is_picked_up_and_changed_mechanisms_stop_generation(self):
        sys.path.insert(0, str(ROOT/'scripts'))
        from atlas.interactions import add_interactions
        paths = ('code/modules/1713/production.dm', 'code/modules/ecology/wild_herbs.dm', 'code/modules/1713/herbalism.dm',
                 'code/modules/1713/flint_mining.dm', 'code/modules/1713/stone_age_arms.dm', 'code/modules/1713/herb_garden.dm',
                 'code/game/objects/farming.dm', 'code/modules/reagents/reagent_containers/food/snacks/meat.dm',
                 'code/modules/projectiles/handloading.dm', 'code/modules/projectiles/_ammo_casing.dm',
                 'code/modules/research_tree/research_node.dm')
        files = {path: (ROOT/path).read_text(encoding='utf-8', errors='replace') for path in paths}
        files['code/new_herb.dm'] = ('/obj/item/new_herb\n\tname = "lovage"\n\tdry_size = 2\n\tdried_type = /obj/item/new_herb/dried\n'
                                     '\tsteep_reagent = "lovage_tea"\n\tsteep_amount = 7\n'
                                     '/obj/item/new_herb/dried\n\tname = "dried lovage"\n\tdried_type = null\n'
                                     '/datum/reagent/drink/lovage_tea\n\tid = "lovage_tea"\n')
        files['civ13.dme'] = ''.join(f'#include "{path}"\n' for path in files)
        records = []

        def add(name, kind, inputs, outputs, path, line, conditions=''):
            records.append(dict(name=name, kind=kind, inputs=[{'id': a.removeprefix('reagent:')} for a, _ in inputs],
                                outputs=[{'id': a.removeprefix('reagent:')} for a, _ in outputs]))
        names = {route['name'] for route in add_interactions(files, add, records, set())}
        self.assertIn('Dry lovage on a dehydrator', names)
        self.assertIn('Steep lovage into lovage tea', names)
        self.assertNotIn('Dry dried lovage on a dehydrator', names)
        self.assertIn('Handload 7.62x39mm', names)
        self.assertIn('Recover brass from a spent 7.62x39mm round', names)
        changed = dict(files)
        changed['code/modules/ecology/wild_herbs.dm'] = files['code/modules/ecology/wild_herbs.dm'].replace(
            'vessel.reagents.remove_reagent("water", amount)', 'vessel.reagents.remove_reagent("water", amount * 2)')
        with self.assertRaisesRegex(ValueError, 'wild_herbs.dm changed'):
            add_interactions(changed, add, records, set())

    def test_coverage_since_lists_new_types_without_routes(self):
        sys.path.insert(0, str(ROOT/'scripts'))
        from atlas.coverage import added_without_route
        catalog = {'recipes': [{'outputs': [{'id': '/obj/item/made'}]}], 'acquisition': {},
                   'resources': {'/obj/item/made': {'name': 'made'}, '/obj/item/orphan': {'name': 'orphan'}}}
        diff = ('+++ b/code/x.dm\n+/obj/item/made\n+/obj/item/orphan\n+/datum/reagent/drink/odd\n+\tid = "odd"\n'
                '+++ b/tests/probe.dm\n+/obj/item/ignored\n')
        found = added_without_route(catalog, diff)
        self.assertEqual(sorted(found), ['/obj/item/orphan', 'odd'])
        self.assertIn('no atlas page', found['odd']['problem'])


if __name__ == '__main__':
    unittest.main()
