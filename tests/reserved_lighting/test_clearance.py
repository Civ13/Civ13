"""Real DMI rectangle boundary controls; no renderer or gameplay evidence."""
import copy
import hashlib
from pathlib import Path
import unittest

from clearance import resource, validate

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ('icons/obj/flora/pinetrees.dmi', 'icons/obj/flora/pinetrees_snow.dmi')


def declaration(asset, state, y):
    return {'schema_version': 1, 'bindings': {asset: hashlib.sha256((ROOT/asset).read_bytes()).hexdigest()},
            'world': [16, 16, 1], 'region': [5, 5, 1, 12, 12, 1],
            'omitted_cells': [[8, 8, 1]], 'unknowns': [],
            'appearances': [{'resource': asset, 'states': [state], 'anchor': [8, y, 1],
                             'pixel_x': [-24, -8], 'pixel_y': [0, 16], 'transform': 'identity',
                             'lifecycle': 'frozen-static', 'overlays': [], 'underlays': []}]}


class Clearance(unittest.TestCase):
    def test_real_six_states_preserve_two_and_three_tile_north_overlap(self):
        count = 0
        for asset in ASSETS:
            self.assertEqual(resource(ROOT/asset)[:2], (64, 96))
            for state in ('new_pine_1', 'new_pine_2', 'new_pine_3'):
                for distance in (2, 3):
                    with self.subTest(asset=asset, state=state, distance=distance), self.assertRaisesRegex(ValueError, 'intersects'):
                        validate(declaration(asset, state, 8-distance), ROOT)
                    count += 1
                self.assertTrue(validate(declaration(asset, state, 4), ROOT)['declared_clearance_valid'])
        self.assertEqual(count, 12)

    def test_every_audited_offset_uses_full_rectangle(self):
        rejected, clear = 0, 0
        for asset in ASSETS:
            for state in ('new_pine_1', 'new_pine_2', 'new_pine_3'):
                for px in range(-24, -7):
                    for py in range(17):
                        doc = declaration(asset, state, 5)
                        doc['appearances'][0]['pixel_x'] = [px, px]
                        doc['appearances'][0]['pixel_y'] = [py, py]
                        if py:
                            with self.assertRaisesRegex(ValueError, 'intersects'):
                                validate(doc, ROOT)
                            rejected += 1
                        else:
                            self.assertTrue(validate(doc, ROOT)['declared_clearance_valid'])
                            clear += 1
        self.assertEqual((rejected, clear), (1632, 102))

    def test_unknown_dynamic_death_transform_source_and_cell_controls(self):
        original = declaration(ASSETS[0], 'new_pine_1', 4)
        for mutation in ('unknown', 'dynamic', 'transform', 'overlay', 'death', 'source', 'outside', 'halo'):
            doc = copy.deepcopy(original)
            if mutation == 'unknown':
                doc['unknowns'] = ['unaudited death appearance']
            elif mutation == 'dynamic':
                doc['appearances'][0]['lifecycle'] = 'ordinary-pine-can-change'
            elif mutation == 'transform':
                doc['appearances'][0]['transform'] = 'unknown'
            elif mutation == 'overlay':
                doc['appearances'][0]['overlays'] = ['unaudited']
            elif mutation == 'death':
                doc['appearances'][0]['states'] = ['unknown_death_state']
            elif mutation == 'source':
                doc['bindings'][ASSETS[0]] = '0'*64
            elif mutation == 'outside':
                doc['omitted_cells'] = [[17, 8, 1]]
            else:
                doc['omitted_cells'] = [[5, 8, 1]]
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                validate(doc, ROOT)
