"""Offline binding/source tests. No network, native API, compiler or capture."""
import ast
from datetime import datetime, timezone
import hashlib
import itertools
import json
from pathlib import Path
import re
import tempfile
import unittest
from unittest.mock import patch
import activation
import stage

HERE = Path(__file__).resolve().parent


class Packet(unittest.TestCase):
    def setUp(self):
        self.a=json.loads((HERE/'activation.json').read_text())
        self.env=dict(GITHUB_ACTIONS='true',RUNNER_ENVIRONMENT='github-hosted',
            GITHUB_REPOSITORY='Civ13/Civ13',GITHUB_RUN_ATTEMPT='1',
            GITHUB_REF='refs/heads/'+activation.BRANCH,GITHUB_EVENT_NAME='push',
            GITHUB_SHA='f'*40,GITHUB_RUN_ID='123',GITHUB_JOB='lighting_off',
            LIGHTING_MODE='0',EVENT_BEFORE='0'*40)
    def validate(self, a=None, env=None, now=None, parent=None, message=None):
        return activation.validate(a or dict(self.a,released=True),env or self.env,
            now or datetime(2026,10,27,3,tzinfo=timezone.utc),native_os='nt',
            parent=parent or activation.SOURCE,message=message or activation.MESSAGE)
    def test_held_entry_stops_before_git_or_any_native_import(self):
        with tempfile.TemporaryDirectory() as temp:
            (Path(temp)/'activation.json').write_text(json.dumps(dict(self.a,released=False)))
            with patch.object(activation,'HERE',Path(temp)),patch.object(activation.subprocess,'check_output') as git:
                with self.assertRaisesRegex(RuntimeError,'HELD'):activation.require_runtime()
                git.assert_not_called()
    def test_two_distinct_jobs_with_live_assigned_run_binding(self):
        self.assertEqual(self.validate()['mode'],0)
        self.assertEqual(self.validate(env=dict(self.env,GITHUB_JOB='lighting_on',LIGHTING_MODE='1'))['mode'],1)
    def test_stale_attempt_branch_parent_job_mode_event_and_run_rejected(self):
        for key,value in [('GITHUB_RUN_ATTEMPT','2'),('GITHUB_REF','refs/heads/old'),
            ('GITHUB_JOB','bakery'),('LIGHTING_MODE','1'),('GITHUB_EVENT_NAME','workflow_dispatch'),
            ('GITHUB_RUN_ID',''),('EVENT_BEFORE','a'*40)]:
            with self.subTest(key=key),self.assertRaises(RuntimeError):self.validate(env=dict(self.env,**{key:value}))
        with self.assertRaises(RuntimeError):self.validate(parent='a'*40)
        with self.assertRaises(RuntimeError):self.validate(message='old admission')
        with self.assertRaises(RuntimeError):self.validate(a=dict(self.a,released=True,run_id='999'))
    def test_expiry_and_five_minute_reserve_are_not_extended(self):
        for hour,minute in [(11,55),(12,0),(13,0)]:
            with self.assertRaises(RuntimeError):self.validate(now=datetime(2026,10,27,hour,minute,tzinfo=timezone.utc))
    def test_original_protection_files_are_byte_identical(self):
        m=json.loads((HERE/'unchanged-reference.json').read_text())
        for n,h in m['files'].items():self.assertEqual(hashlib.sha256((HERE/n).read_bytes()).hexdigest(),h,n)
    def assert_release_state(self, a, d, scene, capture, workflow):
        flags=[a['released'],d['native_released']]
        for text,flag in [(scene,'FILMING_NATIVE_RELEASED'),(capture,'LIGHTING_CAPTURE_SCENE_RELEASED')]:
            rows=re.findall(r'^#define '+flag+r'\b[^\r\n]*',text,re.M)
            self.assertEqual(len(rows),1,flag)
            self.assertIn(rows[0],['#define '+flag+' FALSE','#define '+flag+' TRUE'])
            flags.append(rows[0].endswith(' TRUE'))
        guards=re.findall(r'^      (.*?)github\.repository ==',workflow,re.M)
        self.assertEqual(len(guards),2,'both workflow job guards required')
        for guard in guards:
            self.assertIn(guard,('false && ',''))
            flags.append(guard=='')
        for flag in flags:self.assertIs(type(flag),bool)
        self.assertTrue(all(flag is flags[0] for flag in flags),'release flags disagree')
        return flags[0]
    def test_release_state_coherence_in_both_states_and_every_mismatch(self):
        # In-memory fixtures only: no actual release flags are rewritten.
        for flags in itertools.product((False,True),repeat=6):
            a,d,scene,capture,off,on=flags
            args=({'released':a},{'native_released':d},
                '#define FILMING_NATIVE_RELEASED '+('TRUE' if scene else 'FALSE'),
                '#define LIGHTING_CAPTURE_SCENE_RELEASED '+('TRUE' if capture else 'FALSE'),
                '\n'.join('      '+('' if flag else 'false && ')+"github.repository == 'Civ13/Civ13' &&"
                    for flag in (off,on)))
            with self.subTest(flags=flags):
                if all(flag is flags[0] for flag in flags):
                    self.assertIs(self.assert_release_state(*args),flags[0])
                else:
                    with self.assertRaisesRegex(AssertionError,'release flags disagree'):
                        self.assert_release_state(*args)
    def test_actual_package_identity_state_and_derivative_hashes(self):
        d=json.loads((HERE/'derived-source.json').read_text())
        self.assertEqual(d['scene_revision'],activation.SOURCE)
        self.assertEqual(d['reference_controller'],'209e852bb81c25aaba53fa06ecf125ea532c7bc4')
        # Validate identity with a test-only released copy; state is checked below.
        self.validate(a=dict(self.a,released=True))
        for n,h in d['changes'].items():self.assertEqual(stage.digest(HERE/'changed-source'/n),h,n)
        self.assert_release_state(self.a,d,
            (HERE/'changed-source/filming/scene.dm').read_text(),
            (HERE/'changed-source/filming/capture_scene.dm').read_text(),
            (HERE.parents[1]/'.github/workflows/cloud-lighting-5161688.yml').read_text())
    def test_world_and_plane_entry_not_simulated_rgb(self):
        s=(HERE/'changed-source/filming/scene.dm').read_text()
        for v in ['create_lighting("Night")','apply_restored_lighting()',
            'lighting_capture_attach_hud(light_viewer)','lighting_capture_clear_control()',
            'S.fire()','O.fire()','rand_seed(3225)','C.lum_r','C.lum_g','C.lum_b']:
            self.assertIn(v,s)
        self.assertNotIn('screen.Cut',s)
        self.assertNotIn('SEE_TURFS',s)
    def test_only_compile_define_differs_between_mode_projects(self):
        dme=(HERE/'changed-source/civ13.dme').read_bytes()
        self.assertEqual(dme.count(b'#define CIV13_ZONE_PERSISTENCE'),1)
        self.assertEqual(dme.count(b'.dmm"'),1)
        self.assertIn(b'filming/canopy.dmm',dme)
        self.assertNotIn(b'#define LIGHTING_COMPOSITION_V2',dme)
        outputs=[]
        def export(repo,rev,dest,paths,expected):
            self.assertEqual(paths,['civ13.dme','code','icons','sound','UI','interface','config/names'])
            dest.mkdir();return {'count':3678,'bytes':1}
        with tempfile.TemporaryDirectory() as temp:
            for mode in (0,1):
                dest=Path(temp)/str(mode)
                with patch.object(stage.subprocess,'check_output',return_value=activation.SOURCE),patch.object(stage,'export_blobs',side_effect=export):
                    stage.stage(Path(temp),dest,mode)
                outputs.append((dest/'civ13.dme').read_bytes())
                for name in ('scene.dm','capture_scene.dm'):
                    self.assertEqual((dest/'filming'/name).read_bytes(),
                        (HERE/'changed-source/filming'/name).read_bytes())
            self.assertEqual(outputs[0].split(b'\n',1)[1],outputs[1].split(b'\n',1)[1])
    def test_existing_output_and_invalid_mode_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            with self.assertRaises(ValueError):stage.stage(temp,temp,0)
            with self.assertRaises(ValueError):stage.stage(temp,Path(temp)/'bad',2)
    def test_all_acceptance_gates_and_workflow_bounds_retained(self):
        required=json.loads((HERE/'required-controls.json').read_text())
        self.assertEqual(len(required['required']),15)
        self.assertIs(required['native_acceptance'],False)
        w=(HERE.parents[1]/'.github/workflows/cloud-lighting-5161688.yml').read_text()
        self.assertEqual(w.count('timeout-minutes: 15'),2)
        self.assertEqual(w.count('retention-days: 7'),2)
        self.assertNotIn('workflow_dispatch:',w)
    def test_all_python_parses_without_importing_native_entry(self):
        for p in HERE.rglob('*.py'):ast.parse(p.read_text(encoding='utf-8'),filename=str(p))


if __name__=='__main__':unittest.main()
