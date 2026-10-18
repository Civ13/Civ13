import copy
import importlib.util
import json
from pathlib import Path
import unittest

HERE = Path(__file__).parent
SPEC = importlib.util.spec_from_file_location('map_abi', HERE / 'map_adapter.py')
adapter = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(adapter)


class MapABIContract(unittest.TestCase):
    def setUp(self):
        fixture = json.loads((HERE / 'dagger_map_abi.json').read_text(encoding='utf-8'))
        self.assertEqual(fixture['source_commit'], 'd1cdc2c426799687b98ccd2a846bcc045c1cb8fa')
        self.layout, self.template = fixture['layout_contract'], fixture['template']

    def test_exact_map_descriptor_projects_both_berths_all_four_decks(self):
        result = adapter.validate(self.layout, self.template)
        projections = result['destination_projections']
        self.assertEqual([p['end'] for p in projections], [[101, 173, 8], [159, 173, 8]])
        self.assertEqual([p['deck_z'] for p in projections], [[5, 6, 7, 8]] * 2)
        self.assertEqual([p['cells'] for p in projections], [12240, 12240])
        result['template']['revision'] = 9
        self.assertEqual(self.template['revision'], 1)

    def test_revision_never_defaults_to_manifest_schema(self):
        for revision in (None, True, 0, '1', 1.5, 16777216, 2):
            layout = copy.deepcopy(self.layout)
            if revision is None:
                layout.pop('template_revision')
            else:
                layout['template_revision'] = revision
            with self.subTest(revision=revision), self.assertRaisesRegex(ValueError, 'Explicit template revision'):
                adapter.validate(layout, self.template)

    def test_template_shape_decks_and_geometry_fail_before_projection(self):
        mutations = [lambda t: t.update(origin=[1, 1, 1]), lambda t: t.pop('revision'),
                     lambda t: t.update(width=True), lambda t: t.update(height=513),
                     lambda t: t['decks'].pop(), lambda t: t['decks'].reverse(),
                     lambda t: t['decks'][0].update(layer=True),
                     lambda t: t['berths'].pop(), lambda t: t.update(schema=2)]
        for mutate in mutations:
            template = copy.deepcopy(self.template)
            mutate(template)
            before = copy.deepcopy(self.layout)
            with self.assertRaises(ValueError):
                adapter.validate(self.layout, template)
            self.assertEqual(self.layout, before)

    def test_origins_are_exact_xyz_and_berths_do_not_overlap(self):
        for origin in ([72, 72], [72, 72, 5, 9], [72, 72, True], [250, 72, 5], [72, 72, 7],
                       self.layout['raid_berths'][1]['origin']):
            layout = copy.deepcopy(self.layout)
            layout['raid_berths'][0]['origin'] = origin
            with self.subTest(origin=origin), self.assertRaises(ValueError):
                adapter.validate(layout, self.template)

    def test_invalid_layout_and_out_of_world_clearance_fail_closed(self):
        for layout in (None, [], 'layout'):
            with self.assertRaisesRegex(ValueError, 'Layout object'):
                adapter.validate(layout, self.template)
        layout = copy.deepcopy(self.layout)
        layout['raid_berths'][0]['reserved_bounds'][2] = layout['world']['width'] + 1
        with self.assertRaisesRegex(ValueError, 'within world'):
            adapter.validate(layout, self.template)


if __name__ == '__main__':
    unittest.main()
