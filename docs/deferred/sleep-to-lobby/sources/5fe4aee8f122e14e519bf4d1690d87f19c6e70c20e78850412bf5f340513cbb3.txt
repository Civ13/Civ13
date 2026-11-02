"""Offline outer-supervisor checks. No Docker, compiler or daemon runs."""
from pathlib import Path
import hashlib
import importlib.util
import json
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('sleep_outer_runner',ROOT/'outer_container_runner.py')
r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
class FakeInner:
    MAX_FILE=256*1024**2
    def __init__(self):self.payload={'payload_sha256':'a'*64}
    def receipt(self,path,mode):return {'mode':mode}
    def validate_payload(self,work):return self.payload
class Tests(unittest.TestCase):
    def test_outer_pins_reviewed_dependencies(self):
        for name,want in [('controller_linux.py',r.CONTROLLER),('outer_container_contract.py',r.CONTRACT),('owned_container_watchdog.py',r.WATCHDOG)]:
            self.assertEqual(hashlib.sha256((ROOT/name).read_bytes()).hexdigest(),want)
    def test_atomic_owner_state(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'state.json';r.atomic_state(p,{'create_started':False},0)
            self.assertEqual(json.loads(p.read_text()),{'create_started':False})
            r.atomic_state(p,{'create_started':True},1)
            self.assertEqual(json.loads(p.read_text()),{'create_started':True})
    def test_nonzero_attached_exit_is_observation_not_success_or_unknown(self):
        self.assertEqual(r.attached_exit(None,1),1)
        self.assertEqual(r.attached_exit(None,0),0)
        for problem,code in [('timeout',1),(None,-9),(None,256),(None,False),(None,None)]:
            with self.subTest(problem=problem,code=code),self.assertRaises(ValueError):r.attached_exit(problem,code)
    def test_outer_verifies_writer_bytes_payload_and_compiled_artifacts(self):
        with tempfile.TemporaryDirectory() as d:
            run=Path(d);work=run/'fixture';work.mkdir()
            writer=b'{"mode":"writer"}';(work/'writer-result.json').write_bytes(writer)
            (work/'reader-result.json').write_text('{}')
            builds={}
            for ext in ('.dmb','.rsc'):
                data=('synthetic'+ext).encode();(work/('fixture'+ext)).write_bytes(data);builds[ext]=hashlib.sha256(data).hexdigest()
            fake=FakeInner();accepted={'status':'passed_synthetic','controller_sha256':r.CONTROLLER,'stage_manifest_sha256':r.STAGE,
                'native_game_or_authority_proved':False,'payload':fake.payload,'writer_receipt_sha256':hashlib.sha256(writer).hexdigest(),'compiled_sha256':builds}
            (run/'accepted.json').write_text(json.dumps(accepted))
            self.assertEqual(r.verify_inner(fake,run)['compiled_sha256'],builds)
            (work/'writer-result.json').write_bytes(writer+b' ')
            with self.assertRaises(ValueError):r.verify_inner(fake,run)
            (work/'writer-result.json').write_bytes(writer);(work/'fixture.dmb').write_bytes(b'mutated')
            with self.assertRaises(ValueError):r.verify_inner(fake,run)
    def test_start_state_brackets_attach(self):
        source=(ROOT/'outer_container_runner.py').read_text(encoding='utf-8')
        start=source.index("state['start_started']=True;atomic_state")
        attach=source.index('attach(docker,container_id,env,main,watcher,deadline)',start)
        inspect=source.index("contract.validate_inspect(details[0],spec,container_id,expected_state='exited',expected_exit_code=attach_exit)",attach)
        done=source.index("state['start_confirmed']=True;atomic_state",attach)
        self.assertLess(start,attach);self.assertLess(attach,inspect);self.assertLess(inspect,done)
        self.assertIn("if attach_exit!=0:raise RuntimeError('fixture container exited nonzero: '+str(attach_exit))",source)
        self.assertIn("'docker_exit_state':exit_state",source)
    def test_explicit_reviewed_execution_gate(self):
        source=(ROOT/'outer_container_runner.py').read_text(encoding='utf-8')
        self.assertIn("p.add_argument('--run-native',action='store_true',required=True)",source)
        self.assertIn("contract.validate_image(image_data[0],image)",source)
        self.assertIn("contract.validate_inspect(details[0],spec,container_id)",source)
        self.assertIn("await_watchdog(watcher,watch,90,container_id)",source)
    def test_job_binding_rejects_stale_or_prepare_only_receipt(self):
        env={'GITHUB_RUN_ID':'7','GITHUB_RUN_ATTEMPT':'1','GITHUB_JOB':'fixture','GITHUB_SHA':'a'*40}
        row={'schema':1,'status':'prepared','phase':'before_native','mode':'execute','native_executed':False,
             'image_id':'image','docker_sha256':'docker','python_sha256':'python','endpoint':'unix:///var/run/docker.sock',
             'run_id':'7','run_attempt':'1','job':'fixture','head':'a'*40,'boot_id':'boot','socket':{},'daemon':{}}
        self.assertEqual(r.verify_job_binding(row,'image','docker','python',env,'boot'),{'socket':{},'daemon':{}})
        for key,value in [('mode','prepare'),('schema',True),('run_id','8'),('boot_id','old'),('head','b'*40),('endpoint','tcp://x'),('docker_sha256','other')]:
            changed=dict(row);changed[key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):r.verify_job_binding(changed,'image','docker','python',env,'boot')
if __name__=='__main__':unittest.main()
