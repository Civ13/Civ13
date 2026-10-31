"""Offline complete-profile and native-startup-evidence controls; no native calls."""
import copy
import hashlib
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

import bakery_profile as profile
import bakery_startup as startup
import stage

HERE=Path(__file__).resolve().parent


class Profile(unittest.TestCase):
    def copy_profile(self):
        temp=tempfile.TemporaryDirectory();self.addCleanup(temp.cleanup)
        root=Path(temp.name)
        shutil.copytree(HERE/'profiles',root/'profiles')
        return root,root/'profiles/bakery225'

    def test_all_eighteen_original_projections_and_coherent_states(self):
        root,directory=self.copy_profile()
        _,active,changes=profile.load(root)
        self.assertEqual(len(changes),18)
        self.assertEqual(active['changes']['filming/bakery.dmm'],
                         'c78f44ca5f834be56e382fa2e71e84d814cce4fa0ea1ec872912fddb33b97788')
        self.assertIn(b'maxx == 15 && maxy == 15 && maxz == 1',changes['filming/scene.dm'])
        self.assertNotIn(b'city_route',changes['civ13.dme'])
        # Only a disposable offline fixture is projected into the released state.
        actions=directory/'changed-source/filming/actions.dm'
        raw=actions.read_bytes().replace(b'#define BAKERY_VIDEO_RELEASED FALSE',b'#define BAKERY_VIDEO_RELEASED TRUE')
        actions.write_bytes(raw);active['native_released']=True
        active['changes']['filming/actions.dm']=hashlib.sha256(raw).hexdigest()
        (directory/'derived-source.json').write_text(json.dumps(active))
        _,released,restored=profile.load(root)
        baseline=json.loads((directory/'baseline-derived-source.json').read_bytes())
        self.assertIs(released['native_released'],True)
        self.assertEqual({n:hashlib.sha256(b).hexdigest() for n,b in restored.items()},baseline['changes'])

    def test_changed_missing_extra_or_city_substitute_rejected_even_with_rehashed_active_file(self):
        for mode in ('changed','missing','extra','city'):
            with self.subTest(mode=mode):
                root,directory=self.copy_profile()
                path=directory/'changed-source/filming/scene.dm'
                active=json.loads((directory/'derived-source.json').read_text())
                if mode=='missing':path.unlink()
                elif mode=='extra':(path.parent/'unadmitted.dm').write_text('ignored')
                else:
                    raw=path.read_bytes()+b'\n// unreviewed\n' if mode=='changed' else (HERE/'changed-source/filming/scene.dm').read_bytes()
                    path.write_bytes(raw);active['changes']['filming/scene.dm']=hashlib.sha256(raw).hexdigest()
                    (directory/'derived-source.json').write_text(json.dumps(active))
                with self.assertRaises(ValueError):profile.load(root)

    def test_missing_manifest_member_changed_baseline_or_hold_mismatch_rejected(self):
        for mode in ('membership','baseline','hold'):
            with self.subTest(mode=mode):
                root,directory=self.copy_profile()
                active=json.loads((directory/'derived-source.json').read_text())
                if mode=='baseline':(directory/'baseline-derived-source.json').write_text('{}')
                elif mode=='membership':
                    del active['changes']['filming/bakery.dmf']
                    (directory/'derived-source.json').write_text(json.dumps(active))
                else:
                    active['native_released']=not active['native_released']
                    (directory/'derived-source.json').write_text(json.dumps(active))
                with self.assertRaises(ValueError):profile.load(root)

    def test_full_authored_crop_matches_every_cell_and_direction(self):
        from test_authored_map import parse
        before=parse(HERE/'authored-little-creek.dmm')
        after=parse(HERE/'profiles/bakery225/changed-source/filming/bakery.dmm')
        self.assertEqual(len(after),225)
        for x in range(67,82):
            for y in range(142,157):
                self.assertEqual(before[x,y,2],after[x-66,y-141,1],(x,y))

    def test_stage_applies_only_complete_selected_profile_without_city_mixture(self):
        with tempfile.TemporaryDirectory() as tmp:
            destination=Path(tmp)/'fresh'
            def export(repository,revision,path,*args):
                path.mkdir();return {'count':3673,'bytes':241269067}
            with patch.object(stage.subprocess,'check_output',return_value=profile.SOURCE+'\n'), \
                 patch.object(stage,'export_blobs',side_effect=export):
                row=stage.stage(tmp,destination)
            _,_,expected=profile.load(HERE)
            actual={p.relative_to(destination).as_posix() for p in destination.rglob('*') if p.is_file()}
            self.assertEqual(actual,set(expected)|{'source-receipt.json'})
            self.assertEqual(row['scene_profile'],profile.PROFILE_ID)
            for name,raw in expected.items():self.assertEqual((destination/name).read_bytes(),raw)

    def test_only_pinned_profile_and_diagnostic_admission_can_validate_a_release(self):
        from test_integration import Integration
        fixture=Integration();fixture.setUp()
        valid=dict(fixture.a,released=True,client_startup_diagnostic=True)
        self.assertEqual(fixture.validate(valid)['scene_profile'],profile.PROFILE_ID)
        for key,value in [('scene_profile','city7200'),('scene_profile',None),
                          ('client_startup_diagnostic',False),('client_startup_diagnostic',1)]:
            with self.subTest(key=key,value=value),self.assertRaises(RuntimeError):
                fixture.validate(dict(valid,**{key:value}))


class Readiness(unittest.TestCase):
    def fixture(self):
        temp=tempfile.TemporaryDirectory();self.addCleanup(temp.cleanup)
        source=Path(temp.name)
        (source/'intro-checks.txt').write_text('\n'.join('25.5 '+p for p in startup.PHASES)+'\n')
        (source/'cloud-client.txt').write_text('guest=1;version=516;build=1688\n')
        debug={'observation_seconds':5.0001,'outcome':'five_second_limit','exit_seen':False,'errors':[]}
        cleanup=[{'role':role,'all_exited':True,'exits':[{'exit_code':1,'debug_events_drained':True}]}
                 for role in ('client','server','compiler')]
        ended=dict(debug,exit_seen=True,exit_during_cleanup=True,exit_code=1)
        return source,debug,cleanup,ended

    def test_ready_survival_and_cleanup_are_all_required_and_not_gameplay_acceptance(self):
        source,debug,cleanup,ended=self.fixture()
        observed=startup.observe(source,debug,True)
        observed['sampled_at_seconds']=4.9
        self.assertTrue(observed['ready_checkpoints_observed'])
        self.assertTrue(observed['survived_observation'])
        self.assertEqual(startup.finalize(observed,ended,cleanup)['status'],'STARTUP_OBSERVED_REVIEW_REQUIRED')
        self.assertFalse(startup.finalize(observed,ended,cleanup)['native_acceptance'])

    def test_green_metadata_without_ordered_ready_markers_is_inconclusive(self):
        for mode in ('missing','duplicate','order','wrong_version'):
            with self.subTest(mode=mode):
                source,debug,cleanup,ended=self.fixture()
                labels=list(startup.PHASES)
                if mode=='missing':labels.pop()
                elif mode=='duplicate':labels.append(labels[0])
                elif mode=='order':labels.reverse()
                else:(source/'cloud-client.txt').write_text('guest=1;version=516;build=1681')
                (source/'intro-checks.txt').write_text('\n'.join('25.5 '+p for p in labels))
                observed=startup.observe(source,debug,True)
                self.assertFalse(observed['ready_checkpoints_observed'])
                self.assertEqual(startup.finalize(observed,ended,cleanup)['status'],'INCONCLUSIVE_STARTUP_CONTROL')

    def test_exit_timeout_short_observation_or_nonfinite_time_never_proves_survival(self):
        source,debug,cleanup,ended=self.fixture()
        for key,value in [('exit_seen',True),('outcome','exited'),('errors',['failed']),
                          ('observation_seconds',4.999),('observation_seconds',float('nan'))]:
            with self.subTest(key=key,value=value):
                self.assertFalse(startup.observe(source,dict(debug,**{key:value}),True)['survived_observation'])
        self.assertFalse(startup.observe(source,debug,False)['survived_observation'])

    def test_cleanup_failure_or_unexpected_boundary_exit_is_not_a_startup_pass(self):
        source,debug,cleanup,ended=self.fixture();observed=startup.observe(source,debug,True)
        observed['sampled_at_seconds']=4.9
        for mode in ('cleanup','av','not_drained','missing_role'):
            rows=copy.deepcopy(cleanup)
            if mode=='cleanup':rows[0]['all_exited']=False
            elif mode=='av':rows[0]['exits'][0]['exit_code']=0xc0000005
            elif mode=='not_drained':rows[0]['exits'][0]['debug_events_drained']=False
            else:rows.pop()
            self.assertEqual(startup.finalize(observed,ended,rows)['status'],'INCONCLUSIVE_STARTUP_CONTROL')

    def test_crash_result_preserved_and_unavailable_witness_not_invented(self):
        source,debug,cleanup,ended=self.fixture()
        (source/'cloud-client.txt').unlink()
        observed=startup.observe(source,dict(debug,outcome='unhandled_exception',exit_seen=True),False)
        self.assertFalse(observed['ready_checkpoints_observed'])
        self.assertEqual(startup.finalize(observed,dict(ended,outcome='unhandled_exception'),cleanup)['status'],
                         'CLIENT_CRASH_REPRODUCED')

    def test_oversized_witness_fails_bounded_and_cloud_client_is_independently_retained(self):
        import evidence
        source,debug,_,_=self.fixture()
        original=(source/'cloud-client.txt').read_bytes()
        with tempfile.TemporaryDirectory() as tmp:
            result={'cleanup':[],'status':'REVIEW'}
            records=evidence.retain_independent(source,Path(tmp),result)
            self.assertEqual((Path(tmp)/'cloud-client.txt').read_bytes(),original)
            self.assertEqual(records['cloud-client.txt']['sha256'],hashlib.sha256(original).hexdigest())
        (source/'intro-checks.txt').write_bytes(b'x'*65536)
        row=startup.observe(source,debug,True)
        self.assertFalse(row['ready_checkpoints_observed'])
        self.assertEqual(row['errors'],['startup_witness_unavailable_or_malformed'])

    def test_late_readiness_is_inconclusive_without_extending_the_five_second_window(self):
        source,debug,cleanup,ended=self.fixture()
        for moment in (5,5.01,float('nan')):
            row=startup.sample_within_observation(source,0,lambda:moment)
            self.assertFalse(row['ready_checkpoints_observed'])
            row=startup.end_observation(row,debug,True)
            self.assertEqual(startup.finalize(row,ended,cleanup)['status'],'INCONCLUSIVE_STARTUP_CONTROL')
        sample=startup.sample_within_observation(source,0,lambda:4.9)
        result=startup.end_observation(sample,debug,True)
        self.assertEqual(startup.finalize(result,ended,cleanup)['status'],'STARTUP_OBSERVED_REVIEW_REQUIRED')


if __name__=='__main__':unittest.main()
