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
          GITHUB_EVENT_NAME='push',GITHUB_REF='refs/heads/'+activation.BRANCH,GITHUB_JOB='bakery',
          GITHUB_RUN_ATTEMPT='1',EVENT_BEFORE='0'*40,GITHUB_SHA='a'*40,GITHUB_RUN_ID='123')
    def validate(self,a=None,env=None,now=None):
        return activation.validate(a or self.a,env or self.env,now or datetime(2026,10,30,tzinfo=timezone.utc),
          activation.PARENT,activation.MESSAGE,native_os='nt')
    def test_actual_package_state_and_explicit_held_rejection(self):
        import deferred_recording
        d=json.loads((HERE/'derived-source.json').read_text())
        activation.validate_release_states(self.a['released'],d['native_released'],deferred_recording.NATIVE_RELEASED)
        if not self.a['released']:
            with self.assertRaisesRegex(RuntimeError,'HELD'): activation.require_runtime()
        with self.assertRaisesRegex(RuntimeError,'HELD'): self.validate(dict(self.a,released=False))
    def test_both_coherent_states_and_mismatches(self):
        for state in (False,True):self.assertEqual(activation.validate_release_states(state,state,False),state)
        for states in [(False,True,False),(True,False,False),(True,True,True),(1,True,False)]:
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
            with self.assertRaises(RuntimeError):self.validate(dict(self.a,released=True),now=datetime(2026,10,31,19,minute,tzinfo=timezone.utc))
    def test_flatbread_identity_real_timer_and_completion(self):
        from test_continuity import WitnessChecks
        case=WitnessChecks(methodName='test_valid');case.setUp()
        before,after=case.before,case.after
        continuity(before,after,260)
        for key,value in [('received_ref','replacement'),('produced_at',79),('fuel_paid',0),('customer_holds_output',0),('cooking_time',1),('time',121),('product','loaf'),('flour_after',10)]:
            with self.assertRaises(ValueError):continuity(before,dict(after,**{key:value}),260)
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
        self.assertEqual(d['changes']['filming/bakery.dmm'],'6f361982bb0c8dd5822d0aae840651e7826db69eda91fa63dc12665a134597ae')
    def test_existing_destination_refused_without_git_or_native(self):
        with tempfile.TemporaryDirectory() as root:
            with self.assertRaisesRegex(ValueError,'Fresh'):stage(root,root)

if __name__=='__main__':unittest.main()
