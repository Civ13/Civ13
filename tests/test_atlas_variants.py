"""Offline semantic equivalence, source retention and generated-catalog checks."""
from copy import deepcopy
import importlib.util
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
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
        expected_rows = {(p.relative_to(ROOT).as_posix(), line)
                         for p in (ROOT/'config/crafting').rglob('*') if p.is_file()
                         for line, row in enumerate(p.read_text().splitlines(), 1)
                         if 'RECIPE: ' in row and '//' not in row and
                         len(row.split('RECIPE: ', 1)[1].strip().split(',')) == 13}
        self.assertEqual(catalog_rows, expected_rows, 'every loader row survives grouping')


if __name__ == '__main__':
    unittest.main()
