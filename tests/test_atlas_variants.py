"""Offline semantic equivalence, source retention and generated-catalog checks."""
from copy import deepcopy
import importlib.util
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
family_spec = importlib.util.spec_from_file_location('families', ROOT/'scripts/atlas/families.py')
families = importlib.util.module_from_spec(family_spec)
family_spec.loader.exec_module(families)
spec = importlib.util.spec_from_file_location('variants', ROOT/'scripts/atlas/variants.py')
variants = importlib.util.module_from_spec(spec)
spec.loader.exec_module(variants)


def record(identifier='r1', catalog='global'):
    return dict(id=identifier, name='Arrow', kind='Material / '+catalog,
                file='config/crafting/material_recipes_'+catalog+'.txt', line=12,
                raw='RECIPE: /obj/wood,Arrow,/obj/arrow,1,40,0,1,weapons,0,14,0,8,null',
                inputs=[dict(id='/material/wood', name='wood', quantity='1')],
                outputs=[dict(id='/obj/arrow', name='arrow', quantity='1')],
                conditions='research 14; map gates apply', unlock_eras=[0],
                maximum_era=8, era_basis='archery', era_sort=0)


class AtlasVariantTests(unittest.TestCase):
    def test_equivalent_catalogs_keep_every_identity_and_source(self):
        source = [record(), record('r2', 'camp'), record('r3', 'camp')]
        original = deepcopy(source)
        source[2]['line'] = 20
        original[2]['line'] = 20
        groups = variants.consolidate_variants(source)
        self.assertEqual(source, original, 'grouping cannot mutate source records')
        self.assertEqual(len(groups), 1)
        self.assertEqual(groups[0]['variants'], [{k: r[k] for k in ('id', 'kind', 'file', 'line', 'raw')} for r in source])
        self.assertEqual(groups[0]['inputs'], source[0]['inputs'])
        game = variants.game_recipes(groups)[0]
        self.assertNotIn('raw', game)
        self.assertTrue(all('raw' not in v for v in game['variants']))
        self.assertEqual([v['id'] for v in game['variants']], ['r1', 'r2', 'r3'])

    def test_every_semantic_difference_remains_separate(self):
        base = record()
        changes = [dict(name='Other'), dict(inputs=[dict(id='/material/iron', name='iron', quantity='1')]),
                   dict(inputs=[dict(id='/material/wood', name='wood', quantity='2')]),
                   dict(outputs=[dict(id='/obj/arrow', name='arrow', quantity='3')]),
                   dict(outputs=[dict(id='/obj/bow', name='bow', quantity='1')]),
                   dict(conditions='research 15; different mode'), dict(unlock_eras=[1]),
                   dict(maximum_era=7), dict(era_basis='different node'),
                   dict(processor='station'), dict(future_requirement='new guard'),
                   dict(raw=base['raw'].replace(',40,', ',50,')),
                   # Even canonical aliases must not conceal distinct loader fields.
                   dict(raw=base['raw'].replace('/obj/wood', '/material/wood')),
                   dict(raw='custom callback'), dict(kind='Native stack')]
        for change in changes:
            with self.subTest(change=change):
                other = record('r2', 'camp') | change
                result = variants.consolidate_variants([base, other])
                self.assertEqual(len(result), 2)
                self.assertFalse(any('variants' in r for r in result))

    def test_real_arrow_group_and_all_retained_sources(self):
        catalog = json.loads((ROOT/'UI/crafting-atlas.json').read_text())
        arrows = [r for r in catalog['recipes'] if r['name'] == 'arrow shaft (x3)']
        self.assertEqual(len(arrows), 1)
        self.assertEqual(len(arrows[0]['variants']), 9)
        self.assertEqual(arrows[0]['inputs'][0]['quantity'], '1')
        identities = []
        catalog_rows = set()
        for recipe in catalog['recipes']:
            first_fields = None
            for variant in recipe.get('variants', [recipe]):
                identities.append(variant['id'])
                if variant['kind'].startswith('Material / '):
                    catalog_rows.add((variant['file'], variant['line']))
                if recipe.get('variants'):
                    row = (ROOT/variant['file']).read_text().splitlines()[variant['line']-1]
                    fields = row.split('RECIPE: ', 1)[1].strip().split(',')
                    if first_fields is None:
                        first_fields = fields
                    self.assertEqual(fields, first_fields, 'all original loader fields must agree')
                    self.assertEqual(fields[1], recipe['name'])
                    self.assertEqual(fields[3], recipe['inputs'][0]['quantity'])
        self.assertEqual(len(identities), len(set(identities)))
        # Production explicitly excludes these intermediate hides from generic
        # recipes. They remain resources for the separately extracted processing
        # routes. Catalog-row completeness must respect that admission boundary.
        processing_inputs = {prefix+stage for prefix in ('/material/', '/obj/item/stack/material/')
                             for stage in ('rawhide', 'hairlesshide', 'wethide', 'dryhide')}
        expected_rows = {(p.relative_to(ROOT).as_posix(), line)
                         for p in (ROOT/'config/crafting').rglob('*') if p.is_file()
                         for line, row in enumerate(p.read_text().splitlines(), 1)
                         if 'RECIPE: ' in row and '//' not in row and
                         len(row.split('RECIPE: ', 1)[1].strip().split(',')) == 13 and
                         row.split('RECIPE: ', 1)[1].strip().split(',')[0] not in processing_inputs}
        self.assertEqual(catalog_rows, expected_rows, 'every loader row survives grouping')


class PresentationFamilyTests(unittest.TestCase):
    def item(self, identity, output, name='fur gloves', **changes):
        return record(identity) | dict(name=name, outputs=[dict(id=output, name=output, quantity='1')]) | changes

    def test_exact_names_output_identity_and_declared_ancestry_preserve_all_recipe_fields(self):
        files = {'code/items.dm': '/obj/base\n/obj/base/brown\n/elsewhere/white\n\tparent_type = /obj/base\n/obj/base/trap\n\tparent_type = /obj/unrelated\n/obj/unrelated\n'}
        rows = [self.item('r1','/obj/base'), self.item('r2','/obj/base/brown'),
                self.item('r3','/elsewhere/white'), self.item('r4','/obj/base/trap'),
                self.item('r5','/obj/base',name='different exact name'),
                self.item('r6','/obj/base/brown', inputs=[dict(id='bisonpelt',name='bison pelt',quantity='3')])]
        original = deepcopy(rows)
        families.annotate_families(rows,files)
        self.assertEqual(len({rows[i]['family_id'] for i in (0,1,2,5)}),1)
        self.assertNotEqual(rows[0]['family_id'],rows[3]['family_id'])
        self.assertNotEqual(rows[0]['family_id'],rows[4]['family_id'])
        self.assertEqual([{k:v for k,v in row.items() if k!='family_id'} for row in rows],original)
        reversed_rows = deepcopy(original[::-1]);families.annotate_families(reversed_rows,files)
        self.assertEqual({r['id']:r['family_id'] for r in rows},{r['id']:r['family_id'] for r in reversed_rows})

    def test_unknown_conflicting_dynamic_and_cyclic_parents_do_not_prove_ancestry(self):
        for source in ('/obj/base\n/obj/base/red\n\tparent_type = dynamic_parent\n',
                       '/obj/base\n/obj/base/red\n\tparent_type = /obj/base\n/obj/base/red\n\tparent_type = /obj/other\n',
                       '/obj/base\n/obj/base/red\n\tparent_type = /obj/other\n/obj/other\n\tparent_type = /obj/base/red\n',
                       '/obj/base\n', '/obj/base/red\n'):
            with self.subTest(source=source):
                rows=[self.item('r1','/obj/base'),self.item('r2','/obj/base/red')]
                families.annotate_families(rows,{'code/items.dm':source})
                self.assertNotEqual(rows[0]['family_id'],rows[1]['family_id'])
        # Even unparsed reagents can share one exact canonical identity safely.
        rows=[self.item('r1','water'),self.item('r2','water')]
        families.annotate_families(rows,{})
        self.assertEqual(rows[0]['family_id'],rows[1]['family_id'])

    def test_candidate_ancestor_cycle_does_not_merge_families(self):
        rows=[self.item('r1','/obj/a'), self.item('r2','/obj/b')]
        files={'code/items.dm': '/obj/a\n\tparent_type = /obj/b\n/obj/b\n\tparent_type = /obj/a\n'}
        families.annotate_families(rows,files)
        self.assertNotEqual(rows[0]['family_id'],rows[1]['family_id'])

    def test_multiple_products_similar_names_and_other_output_types_remain_separate(self):
        rows=[self.item('r1','/obj/a'),self.item('r2','/obj/b'),
              self.item('r3','/obj/a',name='fur glove'),
              self.item('r4','/obj/a',outputs=[dict(id='/obj/a'),dict(id='/obj/b')]),
              self.item('r5','/obj/a',outputs=[dict(id='/obj/a'),dict(id='/obj/b')])]
        families.annotate_families(rows,{})
        self.assertEqual(len({r['family_id'] for r in rows}),len(rows))

    def test_real_screenshot_family_is_one_menu_family_with_distinct_inputs_and_ids(self):
        catalog=json.loads((ROOT/'UI/crafting-atlas.json').read_text())
        gloves=[r for r in catalog['recipes'] if r['name']=='fur gloves']
        self.assertGreater(len(gloves),1)
        self.assertEqual(len({r['family_id'] for r in gloves}),1)
        self.assertGreater(len({tuple(x['id'] for x in r['inputs']) for r in gloves}),1)
        self.assertEqual(len({r['id'] for r in gloves}),len(gloves))
        self.assertTrue(all('conditions' in r and 'unlock_eras' in r for r in gloves))


if __name__ == '__main__':
    unittest.main()
