"""Focused new review controls. No native process, Docker, GitHub or encoding."""
import ast
import copy
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import cloud
import contract
import test_contract


def context():
    head='a'*40;tree='b'*40;ref='refs/heads/reviewed-train-proof'
    env={'GITHUB_ACTIONS':'true','RUNNER_ENVIRONMENT':'github-hosted','RUNNER_OS':'Linux','RUNNER_ARCH':'X64',
         'GITHUB_REPOSITORY':'Civ13/Civ13','GITHUB_REPOSITORY_ID':'141349998','GITHUB_EVENT_NAME':'workflow_dispatch',
         'GITHUB_SHA':head,'CIV13_REPOSITORY_VISIBILITY':'public','GITHUB_RUN_ID':'41599999999','GITHUB_RUN_ATTEMPT':'1',
         'GITHUB_REF':ref,'GITHUB_WORKFLOW_REF':'Civ13/Civ13/.github/workflows/train-collision.yml@'+ref,
         'GITHUB_WORKFLOW_SHA':head}
    return head,tree,env


class Review(unittest.TestCase):
    def test_first_attempt_binding_retains_actual_run_and_workflow(self):
        head,tree,env=context();r=cloud.github_binding(head,tree,env)
        self.assertEqual((r['run_id'],r['run_attempt']),('41599999999',1))
        self.assertEqual(r['workflow_sha'],head);self.assertEqual(r['candidate_tree'],tree)
    def test_rerun_rejected(self):
        head,tree,env=context();env['GITHUB_RUN_ATTEMPT']='2'
        with self.assertRaisesRegex(RuntimeError,'first attempt'):cloud.github_binding(head,tree,env)
    def test_missing_run_id_rejected(self):
        head,tree,env=context();del env['GITHUB_RUN_ID']
        with self.assertRaisesRegex(RuntimeError,'run ID'):cloud.github_binding(head,tree,env)
    def test_different_workflow_source_rejected(self):
        head,tree,env=context();env['GITHUB_WORKFLOW_SHA']='c'*40
        with self.assertRaisesRegex(RuntimeError,'workflow ref/SHA'):cloud.github_binding(head,tree,env)
    def test_different_workflow_path_rejected(self):
        head,tree,env=context();env['GITHUB_WORKFLOW_REF']=env['GITHUB_WORKFLOW_REF'].replace('train-collision.yml','test.yml')
        with self.assertRaisesRegex(RuntimeError,'workflow ref/SHA'):cloud.github_binding(head,tree,env)
    def test_different_branch_ref_rejected(self):
        head,tree,env=context();env['GITHUB_REF']='refs/tags/v1'
        with self.assertRaisesRegex(RuntimeError,'branch ref'):cloud.github_binding(head,tree,env)

    def capabilities(self,output=None,returncode=0):
        calls=[]
        def command(argv,**kw):
            calls.append((argv,kw))
            value=(b'ffmpeg version test\n' if argv[-1]=='-version' and argv[0].endswith('ffmpeg') else
                   b'ffprobe version test\n' if argv[-1]=='-version' else b'Encoder libx264 [test]:\n')
            if output is not None and argv[-1]=='encoder=libx264':value=output
            return subprocess.CompletedProcess(argv,returncode,value,b'')
        return command,calls
    def test_capabilities_bounded_and_read_only(self):
        command,calls=self.capabilities()
        with tempfile.TemporaryDirectory() as tmp,patch.object(cloud.shutil,'which',side_effect=lambda n,path:'/usr/bin/'+n):
            r=cloud.renderer_capabilities(command,Path(tmp))
        self.assertEqual(r['status'],'passed');self.assertEqual(len(calls),3)
        for argv,kw in calls:
            self.assertEqual(kw,dict(timeout=5,maximum=65536,optional=True))
            self.assertNotIn('-i',argv);self.assertNotIn('install',argv)
    def test_missing_libx264_fails_and_retains_preflight_receipt(self):
        command,_=self.capabilities(b'Codec libx264 is not recognized\n')
        with tempfile.TemporaryDirectory() as tmp,patch.object(cloud.shutil,'which',side_effect=lambda n,path:'/usr/bin/'+n):
            with self.assertRaisesRegex(RuntimeError,'libx264'):cloud.renderer_capabilities(command,Path(tmp))
            self.assertEqual(json.loads((Path(tmp)/'renderer-capabilities.json').read_text())['status'],'failed')
    def test_failed_capability_process_rejected(self):
        command,_=self.capabilities(returncode=1)
        with tempfile.TemporaryDirectory() as tmp,patch.object(cloud.shutil,'which',side_effect=lambda n,path:'/usr/bin/'+n):
            with self.assertRaisesRegex(RuntimeError,'ffmpeg_version'):cloud.renderer_capabilities(command,Path(tmp))
    def test_missing_ffprobe_refused_without_commands(self):
        command,calls=self.capabilities()
        with tempfile.TemporaryDirectory() as tmp,patch.object(cloud.shutil,'which',side_effect=lambda n,path:None if n=='ffprobe' else '/usr/bin/'+n):
            with self.assertRaisesRegex(RuntimeError,'preinstalled'):cloud.renderer_capabilities(command,Path(tmp))
        self.assertEqual(calls,[])
    def test_capabilities_precede_any_acquisition_or_native_work(self):
        source=(Path(__file__).parent/'cloud.py').read_text()
        host=source.split('def host(',1)[1]
        self.assertLess(host.index("renderer_capabilities(command,out)"),host.index("['pull'"))

    def test_correct_service_berths_pass_new_oracle(self):
        rows=test_contract.synthetic();self.assertTrue(contract.validate(rows)['accepted'])
        for name,engine,tail in [('passenger',(13,1),(6,1)),('depot',(32,-8),(25,-8))]:
            dwell=next(r for r in rows if r['case']==name and r.get('kind')=='service_dwell')
            self.assertEqual(contract.xy(dwell['cars'][0]),engine);self.assertEqual(contract.xy(dwell['cars'][-1]),tail)
    def test_old_passenger_target_refused(self):
        rows=test_contract.synthetic()
        next(r for r in rows if r['case']=='passenger' and r['event']=='target_stop')['x']=14
        with self.assertRaisesRegex(ValueError,'target stop sequence'):contract.validate(rows)
    def test_old_cargo_target_refused(self):
        rows=test_contract.synthetic()
        next(r for r in rows if r['case']=='depot' and r['event']=='target_stop')['x']=33
        with self.assertRaisesRegex(ValueError,'target stop sequence'):contract.validate(rows)
    def test_same_tick_lever_control_causally_rejected(self):
        rows=test_contract.synthetic();frames=[r for r in rows if r['case']=='lever_radius' and r['event']=='frame']
        frames[1]['tick']=frames[0]['tick']
        with self.assertRaisesRegex(ValueError,'lever control observations must advance time'):contract.validate(rows)
    def test_same_tick_rotator_control_causally_rejected(self):
        rows=test_contract.synthetic();frames=[r for r in rows if r['case']=='detached_rotator' and r['event']=='frame']
        frames[1]['tick']=frames[0]['tick']
        with self.assertRaisesRegex(ValueError,'rotator control observations must advance time'):contract.validate(rows)

    def test_exited_leader_with_surviving_child_group_is_killed_and_checked(self):
        leader=dict(pid=101,pgrp=101,session=101,start_ticks=300,state='Z')
        child=dict(pid=102,pgrp=101,session=101,start_ticks=301,state='S')
        samples=iter([[leader,child],[leader,{**child,'state':'Z'}]])
        sent=[]
        result=cloud.cleanup_group(leader,scan=lambda _:next(samples),send=lambda p,s:sent.append((p,s)))
        self.assertEqual(sent,[(101,9)])
        self.assertTrue(result['leader_exited_before_cleanup'] and result['survivors_after_leader_exit'])
        self.assertTrue(result['no_running_members'])
    def test_changed_leader_identity_refuses_group_signal(self):
        leader=dict(pid=101,pgrp=101,session=101,start_ticks=300,state='Z');sent=[]
        with self.assertRaisesRegex(RuntimeError,'owner identity changed'):
            cloud.cleanup_group(leader,scan=lambda _:[{**leader,'start_ticks':999}],send=lambda *x:sent.append(x))
        self.assertEqual(sent,[])
    def test_group_not_quiescent_remains_a_failure(self):
        leader=dict(pid=101,pgrp=101,session=101,start_ticks=300,state='Z')
        child=dict(pid=102,pgrp=101,session=101,start_ticks=301,state='S')
        clock=iter([0,1])
        with self.assertRaisesRegex(RuntimeError,'still has running members'):
            cloud.cleanup_group(leader,scan=lambda _:[leader,child],send=lambda *x:None,now=lambda:next(clock),seconds=0)
    def test_renderer_cleanup_precedes_leader_reap(self):
        source=(Path(__file__).parent/'cloud.py').read_text()
        section=source.split('if binding:\n',1)[1].split('elif child.poll()',1)[0]
        self.assertLess(section.index('cleanup_group(binding)'),section.index('child.wait(timeout=3)'))
        self.assertIn('retain_group=True',source)
        self.assertIn('watcher.wait(timeout=budget)',source)
    def test_changed_python_sources_parse(self):
        for name in ('cloud.py','contract.py','replay.py','test_review_corrections.py'):
            ast.parse((Path(__file__).parent/name).read_text(),filename=name)


if __name__=='__main__':unittest.main()
