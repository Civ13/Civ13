"""Standalone source/admission/readiness checks; no vendor or security effects."""
import copy
from datetime import datetime,timezone
import hashlib
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

import activation
import bakery_startup as startup
import client_debug
from compiled_identity import identify
import minimal_profile as profile
import run_scene
import stage

HERE=Path(__file__).resolve().parent


class MinimalWorld(unittest.TestCase):
    def test_frozen_three_file_profile_and_both_coherent_states(self):
        with tempfile.TemporaryDirectory(prefix='civ13-minimal-offline-') as d:
            root=Path(d)
            shutil.copytree(HERE/'profiles/minimal-world',root/'profiles/minimal-world')
            # Explicit held fixture, independent of a future actual release.
            directory=root/'profiles/minimal-world'
            dm=directory/'changed-source/filming/minimal.dm'
            dm.write_bytes(dm.read_bytes().replace(b'MINIMAL_WORLD_RELEASED TRUE',b'MINIMAL_WORLD_RELEASED FALSE'))
            (directory/'derived-source.json').write_bytes((directory/'baseline-derived-source.json').read_bytes())
            _,held,files=profile.load(root)
            self.assertEqual(set(files),profile.NAMES)
            self.assertFalse(held['native_released'])
            manifest=root/'profiles/minimal-world/derived-source.json'
            dm=root/'profiles/minimal-world/changed-source/filming/minimal.dm'
            dm.write_bytes(dm.read_bytes().replace(b'MINIMAL_WORLD_RELEASED FALSE',b'MINIMAL_WORLD_RELEASED TRUE'))
            held['native_released']=True
            held['changes']['filming/minimal.dm']=hashlib.sha256(dm.read_bytes()).hexdigest()
            manifest.write_text(json.dumps(held))
            self.assertTrue(profile.load(root)[1]['native_released'])
            held['native_released']=False
            manifest.write_text(json.dumps(held))
            with self.assertRaisesRegex(ValueError,'release mismatch'): profile.load(root)

    def test_changed_missing_extra_and_rehashed_wrong_source_rejected(self):
        for change in ('changed','missing','extra'):
            with self.subTest(change=change),tempfile.TemporaryDirectory(prefix='civ13-minimal-offline-') as d:
                root=Path(d)
                shutil.copytree(HERE/'profiles/minimal-world',root/'profiles/minimal-world')
                tree=root/'profiles/minimal-world/changed-source'
                if change=='missing': (tree/'civ13.dme').unlink()
                elif change=='extra': (tree/'icons.dmi').write_bytes(b'not a resource')
                else:
                    p=tree/'filming/minimal.dm';p.write_bytes(p.read_bytes()+b'\nworld/Topic()\n')
                    m=root/'profiles/minimal-world/derived-source.json'
                    data=json.loads(m.read_text());data['changes']['filming/minimal.dm']=hashlib.sha256(p.read_bytes()).hexdigest()
                    m.write_text(json.dumps(data))
                with self.assertRaises(ValueError): profile.load(root)

    def test_staging_has_no_git_game_assets_or_existing_destination(self):
        with tempfile.TemporaryDirectory(prefix='civ13-minimal-offline-') as d:
            destination=Path(d)/'source'
            receipt=stage.stage(destination)
            self.assertEqual(receipt['source_blob_count'],3)
            self.assertFalse(receipt['project_art_or_gameplay_included'])
            self.assertEqual(receipt['source_revision'],profile.SOURCE)
            actual={p.relative_to(destination).as_posix() for p in destination.rglob('*') if p.is_file()}
            self.assertEqual(actual,profile.NAMES|{'source-receipt.json'})
            with self.assertRaises(ValueError): stage.stage(destination)

    def test_fixture_has_only_minimal_lifecycle_and_no_project_resources(self):
        _,_,files=profile.load(HERE)
        self.assertEqual(files['civ13.dme'].decode().count('#include'),2)
        self.assertNotIn(b'code\\',files['civ13.dme'])
        dm=files['filming/minimal.dm'].decode()
        for phase in startup.PHASES: self.assertEqual(dm.count('"'+phase+'"'),1)
        for banned in ('shell(', 'Export(', 'Browse(', '.dmi', '.ogg', '.wav', 'verbs.Copy'):
            self.assertNotIn(banned,dm)
        self.assertIn('maxx = 15',dm);self.assertIn('maxy = 15',dm);self.assertIn('maxz = 1',dm)
        self.assertIn('address != "127.0.0.1"',dm)
        self.assertIn('spawn(2400)',dm)
        self.assertIn('..()\n\tminimal_marker("minimal client after native New")',dm)

    def test_actual_gate_state_matches_manifest_and_recording_stays_disabled(self):
        a=json.loads((HERE/'activation.json').read_text())
        _,p,_=profile.load(HERE)
        self.assertEqual(a['released'],p['native_released'])
        self.assertEqual(a['scene_profile'],profile.PROFILE_ID)
        self.assertEqual(a['source'],profile.SOURCE)
        self.assertEqual(a['scene_sha256'],hashlib.sha256((HERE/'profiles/minimal-world/derived-source.json').read_bytes()).hexdigest())
        self.assertEqual(run_scene.NETWORK_RUNTIME_ADMITTED,a['released'])
        self.assertEqual(client_debug.CLIENT_STARTUP_DIAGNOSTIC_ENABLED,a['client_startup_diagnostic'])
        self.assertIn('$FirewallReviewReleased = $'+str(a['released']).lower(),(HERE/'firewall_supervisor.ps1').read_text())
        self.assertIn(('true' if a['released'] else 'false')+' &&',(HERE/'workflow.reference.txt').read_text())
        for left,right in ((False,False),(True,True)):
            self.assertEqual(activation.validate_release_states(left,right,False),left)
        for args in ((False,True,False),(True,False,False),(True,True,True)):
            with self.assertRaises(RuntimeError): activation.validate_release_states(*args)

    def test_held_entry_has_no_git_or_native_effect_and_other_mode_is_rejected(self):
        with tempfile.TemporaryDirectory(prefix='civ13-minimal-offline-') as d:
            root=Path(d);(root/'activation.json').write_text('{"released":false}')
            with patch.object(activation,'HERE',root),patch.object(activation.subprocess,'check_output',side_effect=AssertionError('must not run')):
                with self.assertRaisesRegex(RuntimeError,'HELD'): run_scene.run(None,None,None,client_diagnostic=True)
        with patch.object(activation,'require_runtime',return_value={}):
            with self.assertRaisesRegex(RuntimeError,'only metadata'):run_scene.run(None,None,None,client_diagnostic=False)

    def test_fresh_pure_admission_contract_and_expiry(self):
        a=json.loads((HERE/'activation.json').read_text())
        a.update(released=True,client_startup_diagnostic=True)
        env=dict(GITHUB_ACTIONS='true',RUNNER_ENVIRONMENT='github-hosted',GITHUB_REPOSITORY='Civ13/Civ13',
                 GITHUB_EVENT_NAME='push',GITHUB_REF='refs/heads/'+activation.BRANCH,GITHUB_JOB='bakery',
                 GITHUB_RUN_ATTEMPT='1',GITHUB_SHA='a'*40,GITHUB_RUN_ID='123',EVENT_BEFORE='0'*40)
        now=datetime(2026,10,31,10,tzinfo=timezone.utc)
        result=activation.validate(a,env,now,activation.PARENT,activation.MESSAGE,native_os='nt')
        self.assertEqual(result['scene_profile'],profile.PROFILE_ID)
        for key,value in [('GITHUB_RUN_ATTEMPT','2'),('GITHUB_REF','refs/heads/master'),
                          ('EVENT_BEFORE','b'*40),('GITHUB_EVENT_NAME','workflow_dispatch')]:
            with self.subTest(key=key),self.assertRaises(RuntimeError):
                activation.validate(a,dict(env,**{key:value}),now,activation.PARENT,activation.MESSAGE,native_os='nt')
        with self.assertRaises(RuntimeError):
            activation.validate(a,env,datetime(2026,10,31,19,55,tzinfo=timezone.utc),activation.PARENT,activation.MESSAGE,native_os='nt')

    def test_workflow_has_no_encoder_installer_or_game_export(self):
        workflow=(HERE/'workflow.reference.txt').read_text()
        self.assertEqual(workflow,(HERE.parents[1]/'.github/workflows/cloud-bakery-video-5161688.yml').read_text())
        for banned in ('source-checkout','run_encoder_proof.py --root','directx_setup.py --root',
                       'directx_official_setup.py --root','pip install','--execute-reviewed-scene'):
            self.assertNotIn(banned,workflow)
        prepare=(HERE/'prepare_nuget_toolchain.py').read_text()
        self.assertNotIn('ffmpeg_download',prepare)
        self.assertNotIn('ffmpeg_extract',prepare)
        for name in ('client_debug.py','client_debug_windows.py','windows.py','evidence.py','nuget_pins.py','vendor.json'):
            self.assertTrue((HERE/name).is_file())

    def test_optional_empty_resource_archive_is_recorded_without_fake_hash(self):
        with tempfile.TemporaryDirectory(prefix='civ13-minimal-offline-') as d:
            root=Path(d)
            with self.assertRaises(ValueError): identify(root)
            (root/'civ13.dmb').write_bytes(b'offline fixture')
            before=identify(root)
            self.assertEqual(before['civ13.rsc'],{'present':False})
            (root/'civ13.rsc').write_bytes(b'')
            self.assertNotEqual(before,identify(root))
            self.assertEqual(identify(root)['civ13.rsc']['bytes'],0)
            (root/'civ13.dmb').write_bytes(b'changed')
            self.assertNotEqual(before,identify(root))


class MinimalReadiness(unittest.TestCase):
    def fixture(self):
        temp=tempfile.TemporaryDirectory(prefix='civ13-minimal-offline-');self.addCleanup(temp.cleanup)
        root=Path(temp.name)
        (root/'intro-checks.txt').write_text(''.join(f'{i} {p}\n' for i,p in enumerate(startup.PHASES)))
        (root/'cloud-client.txt').write_text('guest=1;version=516;build=1688')
        return root

    def debug(self):
        return {'observation_seconds':5.,'outcome':'five_second_limit','exit_seen':False,'errors':[],
                'exit_during_cleanup':True}

    def cleanup(self):
        return [{'role':r,'all_exited':True,'exits':[{'exit_code':1,'debug_events_drained':True}]}
                for r in ('compiler','server','client')]

    def test_ordered_marker_survival_and_cleanup_required_without_acceptance(self):
        source=self.fixture()
        sample=startup.sample_within_observation(source,10,lambda:12)
        result=startup.finalize(startup.end_observation(sample,self.debug(),True),self.debug(),self.cleanup())
        self.assertEqual(result['status'],'STARTUP_OBSERVED_REVIEW_REQUIRED')
        self.assertFalse(result['startup_verified']);self.assertFalse(result['native_acceptance'])
        self.assertEqual(result['profile'],'minimal-world-control')

    def test_late_missing_reordered_markers_wrong_version_and_boundary_av_fail(self):
        source=self.fixture()
        late=startup.sample_within_observation(source,10,lambda:15)
        self.assertFalse(late['ready_checkpoints_observed'])
        for text in ('',''.join(f'{i} {p}\n' for i,p in enumerate(reversed(startup.PHASES)))):
            (source/'intro-checks.txt').write_text(text)
            self.assertFalse(startup.observe(source,self.debug(),True)['ready_checkpoints_observed'])
        source=self.fixture();(source/'cloud-client.txt').write_text('guest=1;version=516;build=1681')
        self.assertFalse(startup.observe(source,self.debug(),True)['ready_checkpoints_observed'])
        source=self.fixture();sample=startup.sample_within_observation(source,10,lambda:12)
        for debug,alive,cleanup in ((dict(self.debug(),outcome='unhandled_exception'),False,self.cleanup()),
                                    (self.debug(),False,self.cleanup()),
                                    (self.debug(),True,[dict(r,all_exited=False) for r in self.cleanup()])):
            result=startup.finalize(startup.end_observation(sample,debug,alive),debug,cleanup)
            self.assertNotEqual(result['status'],'STARTUP_OBSERVED_REVIEW_REQUIRED')


if __name__=='__main__':unittest.main()
