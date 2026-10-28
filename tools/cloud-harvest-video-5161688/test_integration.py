"""Offline contract/error-path tests. No native calls or network."""
import copy, hashlib, json, tempfile, unittest
from datetime import datetime, timezone
from pathlib import Path
import activation
from integration import continuity, config_at
from stage import stage

HERE=Path(__file__).resolve().parent

class Integration(unittest.TestCase):
    def setUp(self):
        self.a=json.loads((HERE/'activation.json').read_text())
        self.env=dict(GITHUB_ACTIONS='true',RUNNER_ENVIRONMENT='github-hosted',GITHUB_REPOSITORY='Civ13/Civ13',
          GITHUB_EVENT_NAME='push',GITHUB_REF='refs/heads/'+activation.BRANCH,GITHUB_JOB='harvest',
          GITHUB_RUN_ATTEMPT='1',EVENT_BEFORE='0'*40,GITHUB_SHA='a'*40,GITHUB_RUN_ID='123')
    def validate(self,a=None,env=None,now=None):
        return activation.validate(a or self.a,env or self.env,now or datetime(2026,10,27,tzinfo=timezone.utc),
          activation.PARENT,activation.MESSAGE,native_os='nt')
    def test_actual_package_state_and_explicit_held_rejection(self):
        import deferred_recording
        d=json.loads((HERE/'derived-source.json').read_text())
        activation.validate_release_states(self.a['released'],d['native_released'],deferred_recording.NATIVE_RELEASED)
        if not self.a['released']:
            with self.assertRaisesRegex(RuntimeError,'HELD'): activation.require_runtime()
        with self.assertRaisesRegex(RuntimeError,'HELD'): self.validate(dict(self.a,released=False))
    def test_both_coherent_states_and_mismatches(self):
        for state in (False,True):self.assertEqual(activation.validate_release_states(state,state,state),state)
        for states in [(False,True,False),(True,False,True),(True,True,False),(1,True,True)]:
            with self.assertRaises(RuntimeError):activation.validate_release_states(*states)
    def test_explicit_released_fixture_contract(self):
        a=dict(self.a,released=True)
        result=self.validate(a)
        self.assertEqual(result['run_id'],'123')
        self.assertEqual(result['controller'],'a'*40)
    def test_wrong_attempt_job_branch_and_ancestry_rejected(self):
        a=dict(self.a,released=True)
        for key,value in [('GITHUB_RUN_ATTEMPT','2'),('GITHUB_JOB','lighting_on'),('GITHUB_REF','refs/heads/master'),('EVENT_BEFORE','b'*40),('GITHUB_RUN_ID','')]:
            with self.subTest(key=key),self.assertRaises(RuntimeError):self.validate(a,dict(self.env,**{key:value}))
    def test_expired_or_small_margin_rejected(self):
        for minute in (55,59):
            with self.assertRaises(RuntimeError):self.validate(dict(self.a,released=True),now=datetime(2026,10,30,11,minute,tzinfo=timezone.utc))
    def test_native_input_output_continuity(self):      
        b=dict(phase='before',time=0,actor='a',tool='t',targets=['p1','p2','p3'],staged_mature=1,growth_observed=0)
        a=dict(b,phase='after',time=70,rows=[dict(plant=f'p{i}',time=i*20-10,removed=1,outputs=[f'g{i}'],seed_units=2) for i in range(1,4)],picked_ref='g1',actor_holds_output=1);continuity(b,a,80)
        for key,value in [('picked_ref','unrelated'),('growth_observed',1),('targets',['p1']),('time',81),('actor_holds_output',0)]:
         with self.assertRaises(ValueError):continuity(b,dict(a,**{key:value}),80)
    def test_native_cadence_normalization_and_owner_failure(self):
        with tempfile.TemporaryDirectory() as root:
            p=Path(root)/'intro-cadence-start.json'
            row=dict(phase='start',world_time_ds=10,world_fps=20,world_tick_lag=.5,client_fps=20,client_tick_lag=.5,same_admitted_client=1)
            p.write_text(json.dumps(row))
            self.assertIs(config_at(Path(root),'start')[0]['same_admitted_client'],True)
            for value in (0,2,'1',True):
                p.write_text(json.dumps(dict(row,same_admitted_client=value)))
                with self.assertRaises(ValueError):config_at(Path(root),'start')
    def test_derivative_hashes_holds_and_map_preserved(self):
        d=json.loads((HERE/'derived-source.json').read_text())
        self.assertIs(d['native_released'],self.a['released'])
        self.assertEqual(hashlib.sha256((HERE/'derived-source.json').read_bytes()).hexdigest(),self.a['scene_sha256'])
        for name,h in d['changes'].items():self.assertEqual(hashlib.sha256((HERE/'changed-source'/name).read_bytes()).hexdigest(),h,name)
        self.assertEqual(d['changes']['filming/harvest.dmm'],'55f245424868c71ef3838b4c66a1c042a2ab7a4336837ac996a113f4737dafea')
    def test_existing_destination_refused_without_git_or_native(self):
        with tempfile.TemporaryDirectory() as root:
            with self.assertRaisesRegex(ValueError,'Fresh'):stage(root,root)

if __name__=='__main__':unittest.main()
