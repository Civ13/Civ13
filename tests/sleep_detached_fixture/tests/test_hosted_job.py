"""Offline scope, review gate and retained-evidence controls."""
import hashlib
import copy
import importlib.util
import json
import os
from pathlib import Path
import stat
import tempfile
from types import SimpleNamespace
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('sleep_hosted_job', ROOT / 'hosted_job.py')
h = importlib.util.module_from_spec(spec); spec.loader.exec_module(h)
cspec = importlib.util.spec_from_file_location('sleep_retention_contract_test', ROOT / 'outer_container_contract.py')
c = importlib.util.module_from_spec(cspec); cspec.loader.exec_module(c)

def proof_fixture():
    cid='c'*64;token='b'*32;image=c.IMAGE_ID
    spec=c.command(image,token,1001,1001,'/tmp/fixture/source','/tmp/fixture/runtime','/tmp/fixture/tmp')
    info={'Id':cid,'Name':'/'+spec['name'],'Image':image,
          'State':{'Status':'exited','Running':False,'ExitCode':1,'OOMKilled':False,'Error':'','StartedAt':'2026-11-02T12:00:00Z','FinishedAt':'2026-11-02T12:00:01Z'},
          'Config':{'Labels':{c.LABEL:token},'User':spec['user'],'Entrypoint':['/usr/local/bin/python3.12'],'Cmd':spec['entry'],'Env':['PATH=/usr/bin:/bin','LANG=C','LC_ALL=C'],'Healthcheck':{'Test':['NONE']}},
          'HostConfig':{'NetworkMode':'none','Privileged':False,'ReadonlyRootfs':True,'PortBindings':{},'PublishAllPorts':False,'Links':None,'CapDrop':['ALL'],'CapAdd':None,'SecurityOpt':['no-new-privileges'],'PidsLimit':32,'Memory':c.MEMORY,'MemorySwap':c.MEMORY,'NanoCpus':c.NANOCPUS,'PidMode':'','IpcMode':'private','Devices':None,'DeviceRequests':None},
          'NetworkSettings':{'Networks':{'none':{'IPAddress':'','GlobalIPv6Address':''}}},
          'Mounts':[{'Type':'bind','Destination':d,'Source':src,'RW':rw} for d,(src,rw) in spec['mounts'].items()]}
    state={'container_id':cid,'token':token,'image':image,'create_started':True,'create_confirmed':True,'start_started':True,'start_confirmed':True}
    ready={'token':token,'owner_pid':10,'watchdog_pid':20}
    watch={'status':'docker_cleanup_verified','trigger':'requested','owner_deadline_signal':'not_requested','container_id':cid,'create_uncertain':False,'start_uncertain':False,'census_after':[]}
    outer={'status':'held','container_id':cid,'token':token,'image_id':image,'cleanup':watch,'attach_exit':1,'docker_exit_state':copy.deepcopy(info['State'])}
    monitor={'binding':'pidfd_bound','termination':'pidfd_exit_observed','owner_error':None,'owner_pid':10,'watchdog_pid':20,'watchdog_start_ticks':55}
    return [state,ready,watch,outer,[info],[copy.deepcopy(info)],cid+'\n',cid+'\n','',monitor,{'image_id':image},spec,c]

class Tests(unittest.TestCase):
    def test_scope_is_exact_and_changed_input_fails(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d); (root / 'source').write_bytes(b'fixture')
            manifest = root / 'scope.json'
            raw = json.dumps({'schema': 1, 'files': {'source': hashlib.sha256(b'fixture').hexdigest()}}).encode()
            manifest.write_bytes(raw); expected = hashlib.sha256(raw).hexdigest()
            self.assertEqual(h.verify_scope(root, manifest, expected)['schema'], 1)
            (root / 'source').write_bytes(b'changed')
            with self.assertRaises(ValueError): h.verify_scope(root, manifest, expected)
            with self.assertRaises(ValueError): h.verify_scope(root, manifest, '0' * 64)
    def test_scope_refuses_parent_traversal(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d); raw = json.dumps({'schema': 1, 'files': {'../outside': '0' * 64}}).encode()
            manifest = root / 'scope.json'; manifest.write_bytes(raw)
            with self.assertRaises(ValueError): h.verify_scope(root, manifest, hashlib.sha256(raw).hexdigest())
    def test_execute_rejects_missing_or_changed_reviewed_host_before_launch(self):
        receipt = {'python_sha256': 'a' * 64, 'docker_sha256': 'b' * 64, 'mode': 'execute', 'native_executed': False}
        for python, docker in (('', ''), ('c' * 64, 'b' * 64), ('a' * 64, 'c' * 64)):
            args = SimpleNamespace(expected_python=python, expected_docker=docker)
            with mock.patch.object(h.subprocess, 'run') as run, self.assertRaises(ValueError): h.execute(args, receipt)
            run.assert_not_called()
    def test_unknown_cleanup_only_reads_host_controlled_roots(self):
        self.assertEqual(h.evidence_roots(False), ('main', 'watch'))
        self.assertEqual(h.evidence_roots(None), ('main', 'watch'))
        self.assertIn('tmp', h.evidence_roots(True))
    def test_nonzero_fixture_can_retain_logs_only_with_complete_cleanup_proof(self):
        args=proof_fixture();self.assertTrue(h.retention_proof(*args))
        self.assertEqual(args[3]['status'],'held');self.assertEqual(args[3]['attach_exit'],1)
        for index,key,value in [(0,'start_confirmed',False),(0,'create_confirmed',False),(2,'status','cleanup_unverified_start_outcome'),(2,'start_uncertain',True),(3,'attach_exit',0),(9,'termination','unknown'),(9,'owner_pid',11),(9,'owner_error','unexpected'),(1,'watchdog_pid',21)]:
            bad=proof_fixture();bad[index][key]=value
            with self.subTest(index=index,key=key),self.assertRaises(ValueError):h.retention_proof(*bad)
        for which in (4,5):
            bad=proof_fixture();bad[which][0]['State']['OOMKilled']=True
            with self.assertRaises(ValueError):h.retention_proof(*bad)
        for index,value in [(6,''),(7,''),(8,'unexpected')]:
            bad=proof_fixture();bad[index]=value
            with self.assertRaises(ValueError):h.retention_proof(*bad)
    def test_failure_is_reported_after_capture_with_roots_selected_by_cleanup(self):
        receipt={'python_sha256':'a'*64,'docker_sha256':'b'*64,'mode':'execute','native_executed':False,
                 'python_path':'python','docker_path':'docker','image_id':c.IMAGE_ID}
        for eligible in (True,False):
            with tempfile.TemporaryDirectory() as d:
                root=Path(d);evidence=root/'evidence';evidence.mkdir()
                args=SimpleNamespace(expected_python='a'*64,expected_docker='b'*64,scope_sha256='c'*64,work=root,evidence=evidence)
                decision={'fixture_passed':False,'retention_eligible':eligible,'reason':'compiler identity or diagnostics'}
                with mock.patch.object(h,'verify_scope'),mock.patch.object(h.tempfile,'mkdtemp',return_value=str(root/'sandbox')), \
                     mock.patch.object(h,'supervise_outer',return_value=decision), \
                     mock.patch.object(h,'copy_evidence',return_value={}) as copy_files, \
                     mock.patch.object(h,'retained_compiler_diagnostic',return_value={'status':'not_retained'}):
                    with self.assertRaisesRegex(ValueError,'compiler identity or diagnostics'):h.execute(args,receipt)
                self.assertEqual(copy_files.call_args.args[2],h.evidence_roots(eligible))
                self.assertTrue((evidence/'retention-decision.json').is_file())
                self.assertTrue((evidence/'evidence-capture.json').is_file())
    def test_capture_failure_preserves_original_failure_in_receipt(self):
        receipt={'python_sha256':'a'*64,'docker_sha256':'b'*64,'mode':'execute','native_executed':False,
                 'python_path':'python','docker_path':'docker','image_id':c.IMAGE_ID}
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);evidence=root/'evidence';evidence.mkdir()
            args=SimpleNamespace(expected_python='a'*64,expected_docker='b'*64,scope_sha256='c'*64,work=root,evidence=evidence)
            decision={'fixture_passed':False,'retention_eligible':True,'reason':'compiler identity or diagnostics'}
            with mock.patch.object(h,'verify_scope'),mock.patch.object(h.tempfile,'mkdtemp',return_value=str(root/'sandbox')), \
                 mock.patch.object(h,'supervise_outer',return_value=decision), \
                 mock.patch.object(h,'copy_evidence',side_effect=ValueError('log too large')):
                with self.assertRaisesRegex(RuntimeError,'compiler identity or diagnostics; evidence capture unavailable'):h.execute(args,receipt)
            row=json.loads((evidence/'evidence-capture.json').read_text());self.assertEqual(row['original_reason'],decision['reason']);self.assertEqual(row['status'],'unavailable')
    def test_compiler_diagnostic_matches_exact_copied_hashes(self):
        prefix='tmp/sleep-fixture/run/';stdout=b'raw stdout';stderr=b'raw stderr';proc={'role':'compile','pid':42,'exit':0,'timeout':False,'error':None,'cleanup':'group_signal_sent'}
        raw=json.dumps(proc).encode();sha=lambda b:hashlib.sha256(b).hexdigest()
        captured={prefix+'compile.stdout.log':{'bytes':len(stdout),'sha256':sha(stdout)},prefix+'compile.stderr.log':{'bytes':len(stderr),'sha256':sha(stderr)},prefix+'compile.process.json':{'bytes':len(raw),'sha256':sha(raw)},prefix+'compile-diagnostic.json':{'bytes':1,'sha256':'d'*64}}
        row={'schema':1,'phase':'compile','status':'retained','controller_sha256':sha((ROOT/'controller_linux.py').read_bytes()),'logs':{'stdout':captured[prefix+'compile.stdout.log'],'stderr':captured[prefix+'compile.stderr.log']},'process_sha256':sha(raw),'process':proc}
        with mock.patch.object(h,'read_host_file',side_effect=[json.dumps(row).encode(),raw]):
            self.assertEqual(h.retained_compiler_diagnostic(captured,Path('fixture'))['status'],'retained')
        bad=copy.deepcopy(row);bad['logs']['stdout']['sha256']='0'*64
        with mock.patch.object(h,'read_host_file',return_value=json.dumps(bad).encode()):
            self.assertEqual(h.retained_compiler_diagnostic(captured,Path('fixture'))['status'],'unverified')
    def test_bounded_fd_copy_rejects_concurrent_growth_and_total_overflow(self):
        info = SimpleNamespace(st_mode=stat.S_IFREG, st_size=1, st_dev=1, st_ino=2, st_mtime_ns=3, st_ctime_ns=4)
        with tempfile.TemporaryDirectory() as d:
            with mock.patch.object(h.os, 'fstat', return_value=info), mock.patch.object(h.os, 'read', side_effect=[b'x', b'y', b'']):
                with self.assertRaises(ValueError): h.bounded_fd_copy(7, Path(d) / 'changed', {'bytes': 0})
            with mock.patch.object(h.os, 'fstat', return_value=info), mock.patch.object(h.os, 'read', side_effect=[b'x', b'']):
                with self.assertRaises(ValueError): h.bounded_fd_copy(7, Path(d) / 'overflow', {'bytes': 512 * 1024**2})
    def test_evidence_copy_preserves_regular_bytes_and_rejects_links(self):
        if not (hasattr(os, 'O_NOFOLLOW') and hasattr(os, 'O_DIRECTORY') and os.scandir in os.supports_fd and os.open in os.supports_dir_fd):
            self.skipTest('descriptor-bound traversal is Linux-specific')
        with tempfile.TemporaryDirectory() as d:
            root = Path(d); src = root / 'src'; src.mkdir(); (src / 'main').mkdir(); (src / 'main' / 'receipt').write_bytes(b'raw receipt\n')
            h.copy_evidence(src, root / 'copy', ('main',)); self.assertEqual((root / 'copy' / 'main' / 'receipt').read_bytes(), b'raw receipt\n')
            try: (src / 'main' / 'link').symlink_to(src / 'main' / 'receipt')
            except OSError: return
            with self.assertRaises(ValueError): h.copy_evidence(src, root / 'copy2', ('main',))
    def test_image_inspect_accepts_valid_list_and_retains_raw_bytes(self):
        class Binding:
            ENDPOINT='unix:///var/run/docker.sock'; IMAGE_ID='image'
            def same_daemon(self, *args): pass
        class Contract:
            def validate_image(self, row, image): self.row=row
        binding=Binding(); contract=Contract(); raw=b'[{"Id":"image","Os":"linux","Architecture":"386"}]'
        with tempfile.TemporaryDirectory() as d:
            def load(name, path): return binding if name == 'sleep_binding_check' else contract
            with mock.patch.object(h, 'load_module', side_effect=load), mock.patch.object(h, 'capture', return_value=raw):
                self.assertEqual(h.image_inspect('/docker', Path(d), {}, Path(d))['id'], 'image')
            self.assertEqual((Path(d) / 'image-inspect.json').read_bytes(), raw)
            self.assertEqual(contract.row['Architecture'], '386')
    def test_watchdog_pidfd_rejects_reparent_or_replacement(self):
        class Poll:
            def register(self, fd, event): pass
            def poll(self, timeout): return []
        ready = json.dumps({'owner_pid': 10, 'watchdog_pid': 20}).encode()
        for second in ((11, 55), (10, 56)):
            with mock.patch.object(h, 'read_host_receipt', return_value=ready), \
                 mock.patch.object(h, 'proc_identity', side_effect=[(10, 55), second]), \
                 mock.patch.object(h.os, 'pidfd_open', return_value=77, create=True), \
                 mock.patch.object(h.os, 'close') as close, \
                 mock.patch.object(h.select, 'poll', return_value=Poll(), create=True), \
                 mock.patch.object(h.select, 'POLLIN', 1, create=True):
                with self.assertRaises(ValueError): h.bind_watchdog(Path('ready'), 10)
                close.assert_called_once_with(77)
    def test_watchdog_pidfd_accepts_only_stable_parent_and_identity(self):
        class Poll:
            def register(self, fd, event): pass
            def poll(self, timeout): return []
        poll = Poll(); ready = json.dumps({'owner_pid': 10, 'watchdog_pid': 20}).encode()
        with mock.patch.object(h, 'read_host_receipt', return_value=ready), \
             mock.patch.object(h, 'proc_identity', return_value=(10, 55)), \
             mock.patch.object(h.os, 'pidfd_open', return_value=77, create=True), \
             mock.patch.object(h.os, 'close') as close, \
             mock.patch.object(h.select, 'poll', return_value=poll, create=True), \
             mock.patch.object(h.select, 'POLLIN', 1, create=True):
            self.assertEqual(h.bind_watchdog(Path('ready'), 10), (77, poll, {'owner_pid':10,'watchdog_pid':20,'watchdog_start_ticks':55}))
            close.assert_not_called()
    def test_watchdog_pidfd_requires_readable_event_on_exact_descriptor(self):
        self.assertEqual(h.classify_watchdog_events([(77, 1)], 77, 1), 'pidfd_exit_observed')
        self.assertEqual(h.classify_watchdog_events([(77, 8)], 77, 1), 'pidfd_unexpected_event')
        self.assertEqual(h.classify_watchdog_events([(78, 1)], 77, 1), 'pidfd_unexpected_event')
        self.assertEqual(h.classify_watchdog_events([], 77, 1), 'not_observed_before_deadline')

if __name__ == '__main__': unittest.main()
