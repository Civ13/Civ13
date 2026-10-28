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
          GITHUB_EVENT_NAME='push',GITHUB_REF='refs/heads/'+activation.BRANCH,GITHUB_JOB='mill',
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
        self.assertEqual(d['changes']['filming/mill.dmm'],'bf6c99352d4db0cb1c2c85b0441d10d425665fe6038d324cede8b411c434ded2')
    def test_existing_destination_refused_without_git_or_native(self):
        with tempfile.TemporaryDirectory() as root:
            with self.assertRaisesRegex(ValueError,'Fresh'):stage(root,root)


import math
class WorkContract(unittest.TestCase):
 def case(self,c=1.15,late=0):
  inc=15*c;n=math.ceil(100/inc);b=dict(phase='before',time=2,actor='a',mill='m',input='grain',input_staged=1,strength_coeff=c,stamina_coeff=c,dexterity_coeff=c,raw_strength=100,raw_stamina=100,raw_dexterity=100,mood_modifier=c,work_increment=inc,work_steps=n,requested_wait_ds=10,stamina_cost_constant=0,mood_cost_constant=0)
  rows=[dict(time=7+i*10+(late if i else 0),progress=i*inc,**{k:b[k] for k in ['strength_coeff','stamina_coeff','dexterity_coeff','raw_strength','raw_stamina','raw_dexterity','mood_modifier']}) for i in range(n)]
  a=dict(phase='after',time=7+n*10+late,actor='a',mill='m',input='grain',input_consumed=1,mill_idle=1,produced_ref='flour',picked_ref='flour',actor_holds_output=1,flour_units=10,work_started=7,work_elapsed=n*10+late,work_increment=inc,work_steps=n,observed_progress=rows,final_increment_evidence='native finish_work output and cleared work; not directly sampled')
  return b,a
 def test_six_and_seven_real_waits_and_scheduler_delay(self):
  for c in [1,1.15]:
   for late in [0,.5,2]:
    b,a=self.case(c,late);continuity(b,a,82)
 def test_refuses_shortcut_modified_coefficients_progress_and_output(self):
  b,a=self.case()
  for k,v in [('work_elapsed',59),('work_steps',7),('work_increment',20),('input_consumed',0),('picked_ref','replacement'),('flour_units',9),('mill_idle',0),('time',83)]:
   with self.subTest(k=k),self.assertRaises(ValueError):continuity(b,dict(a,**{k:v}),82)
  for k,v in [('time',15),('progress',99),('strength_coeff',1.2),('raw_stamina',105),('mood_modifier',1.1)]:
   altered=copy.deepcopy(a);altered['observed_progress'][1][k]=v
   with self.subTest(k=k),self.assertRaises(ValueError):continuity(b,altered,82)
  altered=copy.deepcopy(a);altered['observed_progress'].pop()
  with self.assertRaises(ValueError):continuity(b,altered,82)

