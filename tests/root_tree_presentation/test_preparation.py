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
        self.assertNotIn('civ13.dmb',source)

    def test_ci_registers_offline_files_only(self):
        spec=importlib.util.spec_from_file_location('root_ci',ROOT/'scripts/ci_baseline.py')
        ci=importlib.util.module_from_spec(spec);spec.loader.exec_module(ci)
        self.assertEqual(ci.SUITES['root_tree_presentation']['files'],(
            'tests/root_tree_presentation/test_contract.py',
            'tests/root_tree_presentation/test_preparation.py'))
        for path in ['code/modules/visibility/root_tree_presenter.dm',
                     'tests/root_tree_presentation/fixture.dm','code/__defines/_planes+layers.dm']:
            self.assertTrue(ci.impact([path])['suites']['root_tree_presentation']['selected'])
        for path in ['code/modules/lighting/lighting_overlay.dm','code/game/mob/mob_movement.dm']:
            self.assertEqual(set(k for k,v in ci.impact([path])['suites'].items() if v['selected']),set(ci.SUITES))


if __name__=='__main__':unittest.main()
