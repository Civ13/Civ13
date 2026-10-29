"""File-only fixture preparation and CI selection; no native execution."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('root_tree_prepare',Path(__file__).with_name('prepare.py'))
prepare=importlib.util.module_from_spec(spec);spec.loader.exec_module(prepare)


class Preparation(unittest.TestCase):
    def test_exact_source_and_art_staged_without_processes(self):
        with tempfile.TemporaryDirectory() as temp, patch('subprocess.Popen',side_effect=AssertionError('No process')):
            out=Path(temp)/'fresh';manifest=prepare.prepare(out)
            self.assertEqual(json.loads((out/'source-manifest.json').read_text()),manifest)
            for path,entry in manifest['inputs'].items():
                target=out/path if path.startswith('icons/') else out/Path(path).name
                self.assertEqual(target.read_bytes(),(ROOT/path).read_bytes())
                self.assertEqual(hashlib.sha256(target.read_bytes()).hexdigest(),entry['sha256'])
            light=(out/'production-light-update.dm').read_text()
            self.assertIn('/atom/movable/lighting_overlay/proc/update_overlay()',light)
            self.assertIn('/obj/screen/plane_master/light_mask/backdrop(',light)
            self.assertIn('/turf/proc/needs_fullbright_coverage()',light)
            self.assertEqual(hashlib.sha256(light.encode()).hexdigest(),manifest['production_light_update_sha256'])
            with self.assertRaises(FileExistsError):prepare.prepare(out)

    def test_fixture_contains_separate_native_controls_and_no_production_startup(self):
        source=(Path(__file__).with_name('fixture.dm')).read_text()
        for phase in range(1,10):self.assertIn('phase == '+str(phase),source)
        self.assertIn('No game startup, live state or credentials',source)
        self.assertIn('opacity = TRUE',source)
        self.assertNotIn('opacity = FALSE',source)
        self.assertIn('M.client.view = "15x15"',source)
        self.assertIn('new /obj/hidden_witness',source)
        self.assertIn('T.sync_fullbright_coverage()',source)
        self.assertIn('if(copytext(key,1,6) != "Guest")',source)
        # text2file appends; replace the prior sample before publishing new JSON.
        self.assertLess(source.index('fdel("phase.ready.json")'),source.index('text2file(json_encode('))
        client_del=source.split('/client/Del()',1)[1].split('/proc/',1)[0]
        self.assertLess(client_del.index('los_context.retire()'),client_del.index('root_tree_presenter.retire()'))
        self.assertNotIn('civ13.dmb',source)
        self.assertIn('/atom/movable\n\tplane = GAME_PLANE',source)
        caller=source.split('spawn(1)',1)[1].split('/proc/fixture_phase',1)[0]
        self.assertLess(caller.index('fixture_phase(phase, src) != TRUE'),caller.index('text2file(json_encode(witness)'))
        self.assertIn('fixture_failed || !witness',caller)
        self.assertIn('phase == 9 && !fixture_failed',caller)
        error=source.split('/world/Error(',1)[1].split('/proc/',1)[0]
        self.assertIn('fixture_fail("native_runtime")',error)
        for name in ('tree_identity','plane_identity','plane_constructor_[name]','plane_refresh_[name]'):
            self.assertIn('"'+name+'"',source)

    def test_ci_registers_offline_files_only(self):
        spec=importlib.util.spec_from_file_location('root_ci',ROOT/'scripts/ci_baseline.py')
        ci=importlib.util.module_from_spec(spec);spec.loader.exec_module(ci)
        self.assertEqual(ci.SUITES['root_tree_presentation']['files'],(
            'tests/root_tree_presentation/test_contract.py',
            'tests/root_tree_presentation/test_preparation.py',
            'tests/root_tree_presentation/test_protocol.py'))
        for path in ['code/modules/visibility/root_tree_presenter.dm',
                     'tests/root_tree_presentation/fixture.dm','code/__defines/_planes+layers.dm',
                     'tests/save_movement/source_adapter.py']:
            self.assertTrue(ci.impact([path])['suites']['root_tree_presentation']['selected'])
        for path in ['code/modules/lighting/lighting_overlay.dm','code/game/mob/mob_movement.dm']:
            self.assertEqual(set(k for k,v in ci.impact([path])['suites'].items() if v['selected']),set(ci.SUITES))


if __name__=='__main__':unittest.main()
