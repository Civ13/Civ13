"""Source/staging controls for the disabled scene; no native/client acceptance."""
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('flax_connected_source_prepare', Path(__file__).with_name('prepare_connected_scene.py'))
prepare = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prepare)


class ConnectedSceneSource(unittest.TestCase):
    def inputs(self, root):
        for path in (*prepare.HOOK_PATHS,'civ13.dme','interface/chat/chat.html',
                     'tests/flax_processing/connected_scene.dm','tests/flax_processing/connected_notice_observer.js'):
            target=root/path; target.parent.mkdir(parents=True,exist_ok=True)
            target.write_bytes((ROOT/path).read_bytes())

    def test_staging_preserves_include_order_and_production_files_without_launch(self):
        with tempfile.TemporaryDirectory(prefix='flax-scene-source-') as directory:
            root=Path(directory); self.inputs(root)
            original={path:(root/path).read_bytes() for path in prepare.HOOK_PATHS}
            with patch.object(prepare.subprocess,'Popen',side_effect=AssertionError('No native launch')), \
                 patch.object(prepare.subprocess,'run',side_effect=AssertionError('No native launch')):
                manifest=prepare.stage(root,root/'review','a'*40,'.flax_connected_offline')
            self.assertFalse(manifest['native_launch_authorized'])
            self.assertFalse(manifest['acceptance_complete'])
            self.assertFalse(manifest['enabled_by_default'])
            self.assertEqual(original,{path:(root/path).read_bytes() for path in prepare.HOOK_PATHS})
            dme=Path(manifest['entry_point']).read_text()
            paths=['code\\game\\mob\\inventory.dm','code\\game\\mob\\living\\living.dm',
                   'code\\game\\mob\\living\\carbon\\human\\human.dm']
            offsets=[dme.index(path) for path in paths]
            self.assertEqual(offsets,sorted(offsets))
            self.assertNotIn('.dmm"',dme)
            self.assertIn('#define CIV13_FLAX_CONNECTED_SCENE',dme)
            self.assertIn('tests/flax_processing/connected_scene.dm',dme)
            for entry in manifest['generated']:
                path=Path(entry['path'])
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),entry['sha256'])
                self.assertTrue((root/'review/generated-source'/path.name).exists())

    def test_missing_hook_or_existing_owned_files_fail_closed_and_are_preserved(self):
        with tempfile.TemporaryDirectory(prefix='flax-scene-source-negative-') as directory:
            root=Path(directory); self.inputs(root)
            keep=root/'.flax_connected_existing_chat.html'; keep.write_text('preserve me')
            with self.assertRaises(ValueError): prepare.stage(root,root/'blocked','a'*40,'.flax_connected_existing')
            self.assertEqual(keep.read_text(),'preserve me')
            path=root/'code/modules/1713/flax_processing.dm'
            path.write_text(path.read_text().replace('/mob/proc/flax_processing_wait(', '/mob/proc/renamed_wait(',1))
            with self.assertRaises(ValueError): prepare.stage(root,root/'negative','a'*40,'.flax_connected_negative')
            manifest=json.loads((root/'negative/scene-source-manifest.json').read_text())
            self.assertEqual(manifest['status'],'source_preparation_failed')
            self.assertFalse(manifest['native_launch_authorized'])

    def test_observer_hooks_do_not_replace_gameplay_or_synthesize_a_wait_result(self):
        sources=prepare.prepared_sources(ROOT,'.flax_connected_offline')
        flax=sources['code/modules/1713/flax_processing.dm']
        self.assertIn('var/scene_wait_result = do_after(src, delay, target)',flax)
        self.assertIn('return scene_wait_result',flax)
        self.assertIn('if (!user.drop_from_inventory(src, W) || loc != W)',flax)
        self.assertIn('if (flax_scene)\n\t\tflax_scene.dispatch("afterattack"',flax)
        table=sources['code/game/objects/structures/table.dm']
        self.assertIn('if (!user.drop_item())',table)
        self.assertIn('step(O, get_dir(O, src))',table)
        paddle=sources['code/game/objects/items/weapons/defib.dm']
        self.assertIn('if(M.drop_from_inventory(paddles))',paddle)
        self.assertIn('paddles.forceMove(src)',paddle)
        self.assertIn('C.chat.send_message(message)',sources['code/modules/chat/chat.dm'])

    def test_real_client_callbacks_base_human_fresh_water_and_nonacceptance_are_explicit(self):
        scene=(ROOT/'tests/flax_processing/connected_scene.dm').read_text()
        self.assertTrue(scene.lstrip().startswith('// Prepared only'))
        self.assertIn('#ifdef CIV13_FLAX_CONNECTED_SCENE',scene)
        self.assertIn('actor = new /mob/living/human(',scene)
        self.assertIn('actor.type == /mob/living/human',scene)
        self.assertNotRegex(scene,r'/mob/living/human/(?:New|drop_from_inventory|put_in_\w+hand|flax_processing_wait)\(')
        self.assertIn('/client/Click(atom/object, location, control, params)',scene)
        self.assertIn('/client/MouseDrop(atom/src_object',scene)
        self.assertEqual(scene.count('. = ..()'),2)
        self.assertNotRegex(scene,r'\.(?:ClickOn|afterattack|MouseDrop_T|reattach_paddles|soak)\(')
        self.assertIn('water = new(case_index == 1 ? locate(4,3,1) : locate(3,4,1))',scene)
        self.assertIn('event["waits"] != 3',scene)
        self.assertIn('delay != 100',scene)
        self.assertIn('token != active_action',scene)
        self.assertIn('"rendered_pixels_verified" = FALSE',scene)
        self.assertNotIn('"acceptance_complete" = TRUE',scene)
        self.assertNotIn('connected_scene.dm',(ROOT/'civ13.dme').read_text())
        self.assertNotIn('prepare_connected_scene.py',(ROOT/'.github/workflows/test.yml').read_text())


if __name__ == '__main__': unittest.main(verbosity=2)
