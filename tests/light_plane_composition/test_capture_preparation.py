"""Source export and synthetic comparison controls; no capture or native launch."""
import ast
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
def load(name):
    spec = importlib.util.spec_from_file_location(name, HERE / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

prep = load('prepare_capture')
pixels = load('pixel_comparison')


class CapturePreparation(unittest.TestCase):
    def test_fresh_export_stays_held_binds_raw_current_source_and_preserves_inputs(self):
        before = (HERE / 'capture_scene.dm').read_bytes()
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'proposal'
            plan = prep.prepare(output)
            self.assertFalse(plan['native_execution_ready'])
            self.assertFalse(plan['complete_project_materialized'])
            self.assertEqual(plan['source_revision'], 'ff67d89241336d55f456967ec596d5cd10358df6')
            self.assertEqual(plan['source_tree'], '8614d882918542be45a8ce822d731f88c84e79f2')
            self.assertEqual(plan, json.loads((output / 'plan.json').read_text()))
            self.assertEqual(plan['first_pair']['modes'], [0, 1])
            self.assertEqual(plan['first_pair']['jobs'], 2)
            self.assertEqual(plan['first_pair']['captures_per_job'], ['opaque-root', 'clear-root'])
            self.assertEqual(plan['runtime']['version'], '516.1688')
            self.assertEqual(plan['inventory_sha256'], hashlib.sha256((output / 'source-inventory.git-tree').read_bytes()).hexdigest())
            for name, expected in plan['generated_sha256'].items():
                self.assertEqual(hashlib.sha256((output / name).read_bytes()).hexdigest(), expected)
            self.assertEqual((output / 'mode-0.dme-prefix').read_text(), '#define LIGHTING_COMPOSITION_V2 0\n')
            self.assertEqual((output / 'mode-1.dme-prefix').read_text(), '#define LIGHTING_COMPOSITION_V2 1\n')
            self.assertNotIn('FILMING_NATIVE_RELEASED TRUE', (output / 'scene.dm').read_text())
        self.assertEqual((HERE / 'capture_scene.dm').read_bytes(), before)

    def test_existing_proposal_cannot_be_overwritten(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory); old = path / 'spent.txt'; old.write_text('retain')
            with self.assertRaises(ValueError): prep.prepare(path)
            self.assertEqual(old.read_text(), 'retain')

    def test_release_or_hidden_entry_point_changes_fail_before_output(self):
        original = (HERE / 'capture_scene.dm').read_text()
        for changed in (original.replace('RELEASED FALSE', 'RELEASED TRUE'),
                        original + '\n#define LIGHTING_CAPTURE_SCENE_RELEASED TRUE\n',
                        original + '\n/world/New()\n\treturn\n'):
            with tempfile.TemporaryDirectory() as directory:
                root = Path(directory); (root / 'capture_scene.dm').write_text(changed)
                with patch.object(prep, 'HERE', root), self.assertRaises(ValueError):
                    prep.prepare(root / 'output')
                self.assertFalse((root / 'output').exists())

    def test_authored_map_has_exact_bounds_and_witness_coordinates(self):
        text = prep.authored_map()
        rows = text.split('(1,1,1) = {"\n')[1].split('\n"}')[0].splitlines()
        self.assertEqual(len(rows), 13)
        self.assertEqual({len(row) for row in rows}, {15})
        for x, y, expected in ((8, 6, 'p'), (8, 7, 'h'), (7, 5, 'v')):
            self.assertEqual(rows[13-y][x-1], expected)
        self.assertEqual(sum(row.count('p') for row in rows), 1)
        self.assertEqual(sum(row.count('h') + row.count('v') for row in rows), 2)

    def test_all_historical_pixel_gates_plus_ordinary_clear_and_hud_remain_required(self):
        required = {'weather', 'intentional_fullbright', 'dynamic_to_fullbright', 'fullbright_to_dynamic',
                    'turf_replacement', 'save_import', 'sight_bypass', 'sight_restore', 'occluded_oversize',
                    'ordinary_lit', 'clear_root', 'hud_lifecycle', 'fully_covered_warm',
                    'view_edge', 'other_oversized_assets'}
        self.assertEqual(set(prep.REQUIRED), required)
        self.assertEqual(len(prep.REQUIRED), len(required))

    def test_exporter_has_no_native_network_or_controller_publication_path(self):
        tree = ast.parse((HERE / 'prepare_capture.py').read_text())
        calls = [node for node in ast.walk(tree) if isinstance(node, ast.Call)
                 and isinstance(node.func, ast.Attribute) and isinstance(node.func.value, ast.Name)
                 and node.func.value.id == 'subprocess']
        self.assertEqual([node.func.attr for node in calls], ['check_output'])
        self.assertEqual(calls[0].args[0].elts[0].value, 'git')

    def test_native_adapter_has_no_world_client_admission_and_uses_actual_hud_and_view(self):
        source = (HERE / 'capture_scene.dm').read_text()
        self.assertIn('#define LIGHTING_CAPTURE_SCENE_RELEASED FALSE', source)
        self.assertNotIn('/world/New', source)
        self.assertNotIn('/client/New', source)
        self.assertIn('new /datum/hud(H)', source)
        self.assertIn('H.update_lighting_plane()', source)
        self.assertIn('view(H.client.view, H)', source)
        self.assertIn('T.get_lumcount()', source)
        self.assertIn('rows.len != 49', source)
        self.assertNotIn('H.client.screen =', source)
        self.assertIn('H.client.images.len', source)
        self.assertNotRegex(source, r'H\.client\.images\s*(?:=|\+=|\|=)')


class PixelComparison(unittest.TestCase):
    def frame(self, changes=None):
        value = bytearray(b'\x19\x27\x35' * pixels.PIXELS)
        for pixel, color in (changes or {}).items(): value[pixel*3:pixel*3+3] = bytes(color)
        return bytes(value)

    def test_expected_blackening_is_only_comparison_never_native_acceptance(self):
        before = self.frame(); after = self.frame({10:(0,0,0),11:(0,0,0)})
        result = pixels.compare_occluded(before, after, (10,11))
        self.assertEqual(result['changed_pixels'], 2)
        self.assertFalse(result['native_acceptance'])
        self.assertFalse(pixels.compare_clear(before, before)['native_acceptance'])

    def test_visible_hud_or_viewport_changes_cannot_hide_in_the_occlusion_result(self):
        with self.assertRaisesRegex(ValueError, 'outside'):
            pixels.compare_occluded(self.frame(), self.frame({10:(0,0,0),100:(0,0,0)}), (10,))

    def test_remaining_bright_overhang_or_missing_reproducer_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'nonblack'):
            pixels.compare_occluded(self.frame(), self.frame(), (10,))
        with self.assertRaisesRegex(ValueError, 'did not reproduce'):
            pixels.compare_occluded(self.frame({10:(0,0,0)}), self.frame({10:(0,0,0)}), (10,))

    def test_empty_duplicate_bad_or_whole_screen_oracle_is_rejected(self):
        before = self.frame()
        for indices in ((), (10,10), (-1,), (pixels.PIXELS,), (True,), ([],), list(range(5)), tuple(range(pixels.PIXELS))):
            with self.subTest(indices_type=type(indices)), self.assertRaises(ValueError):
                pixels.compare_occluded(before, before, indices)

    def test_dimensions_and_rgb_bytes_are_exact_and_clear_controls_compare_every_pixel(self):
        for bad in (b'', bytes(480*480*4), bytearray(480*480*3)):
            with self.assertRaises(ValueError): pixels.compare_clear(bad, self.frame())
        with self.assertRaisesRegex(ValueError, 'changed: 1'):
            pixels.compare_clear(self.frame(), self.frame({pixels.PIXELS-1:(1,2,3)}))


if __name__ == '__main__':
    unittest.main()
