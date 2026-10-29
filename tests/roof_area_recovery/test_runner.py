"""Exercise the real runner phase with injected OS effects; never launches BYOND."""
import ast
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

PATH = Path(__file__).with_name('run_linux.py')
spec = importlib.util.spec_from_file_location('roof_bounded_runner_test', PATH)
runner = importlib.util.module_from_spec(spec); spec.loader.exec_module(runner)


def actual_phase():
    tree = ast.parse(PATH.read_text())
    outer = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == 'run')
    node = next(n for n in outer.body if isinstance(n, ast.FunctionDef) and n.name == 'phase')
    return copy.deepcopy(node)


class RunnerTests(unittest.TestCase):
    def test_request_claim_is_exclusive_across_outputs_and_packet_copies(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary); digest='b'*64
            claim=runner.claim_request(digest,'a'*40,root/'first',root)
            original=claim.read_bytes()
            # A copied packet has the same request bytes/hash; changing its
            # path or output does not change the atomic consumption key.
            for output in (root/'first',root/'second',root/'copied-packet'/'output'):
                with self.assertRaisesRegex(RuntimeError,'already consumed'):
                    runner.claim_request(digest,'a'*40,output,root)
                self.assertFalse(output.exists())
                self.assertEqual(claim.read_bytes(),original)
            # An interrupted empty claim is uncertain, hence also retained.
            claim.write_bytes(b'')
            with self.assertRaisesRegex(RuntimeError,'already consumed'):
                runner.claim_request(digest,'a'*40,root/'third',root)
            self.assertEqual(claim.read_bytes(),b'')

    def test_request_claim_rejects_outside_output_and_invalid_digest(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary)
            for output,digest in ((root.parent/'outside','b'*64),(root,'b'*64),(root/'ok','../bad')):
                with self.assertRaises(RuntimeError):
                    runner.claim_request(digest,'a'*40,output,root)
            self.assertFalse((root/'roof-area-request-claims').exists())

    def test_contract_is_uuid_and_line_ending_independent_but_binds_code_and_limits(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary)
            def packet(name,prefix,newline):
                folder=root/name; prepared=folder/'generated'; prepared.mkdir(parents=True)
                (prepared/(prefix+'_probe.dm')).write_bytes(b'/world/New()\n    return\n')
                (prepared/(prefix+'_0.dm')).write_bytes(b'var/example = 1\n')
                (prepared/'probe.dme').write_bytes(('#include "'+prefix+'_probe.dm"\n#include "'+prefix+'_0.dm"\n').replace('\n',newline).encode())
                (folder/'expected-crafting-atlas.json').write_bytes(b'{}\n')
                request=dict(prepared_directory='generated',head='a'*40,variant='main',caps=dict(runner.CAPS),
                    completion_contract=dict(runner.COMPLETION),
                    modes=list(runner.PHASES['main']),port=runner.PORT,outer_seconds=990,
                    binary_sha256=runner.ENGINE,source_sha256={'example.dm':'c'*64})
                return request,folder
            first,a=packet('first','.durable_world_'+'1'*32,'\r\n')
            second,b=packet('second','.durable_world_'+'2'*32,'\n')
            expected=runner.execution_contract(first,a)
            self.assertEqual(expected,runner.execution_contract(second,b))
            for field,value in (('head','d'*40),('outer_seconds',991),('port',19328),
                                ('completion_contract',dict(runner.COMPLETION,expected_exit=0)),
                                ('caps',dict(runner.CAPS,child_seconds=61))):
                changed=copy.deepcopy(second); changed[field]=value
                self.assertNotEqual(expected,runner.execution_contract(changed,b))
            probe=next((b/'generated').glob('*_probe.dm'))
            probe.write_bytes(probe.read_bytes()+b'// changed code\n')
            self.assertNotEqual(expected,runner.execution_contract(second,b))

    def phase(self, fault=None, *, denied_exit=None, work_end=960, end=990, second_sample_at=.1,
              completed=False, completion_fault=None, completion_exit=-9, variant='main'):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary); case = output/'cases/read'; case.mkdir(parents=True)
            if fault != 'early-exit': (case/'probe-port-closed.txt').write_bytes(b'closed\n')
            calls = dict(cleanup=0, sockets=0, exit=0, popen=0, sleeps=[], signals=[])
            clock = SimpleNamespace(value=0)
            process = SimpleNamespace(pid=123)
            def exited(_):
                calls['exit'] += 1
                if denied_exit:
                    if calls['sockets'] < 2: return False
                    if denied_exit == 'terminal': return True
                    return denied_exit == 'late' and clock.value >= second_sample_at+.03
                if completed: return completion_fault == 'early-exit' and calls['exit'] > 1
                if fault == 'early-exit': return True
                if fault == 'deadline': clock.value = 61
                return calls['exit'] > 1
            def identity(pid):
                return dict(pid=pid,start_ticks=8 if completion_fault == 'identity' and clock.value >= .1 else 7,pgrp=pid,session=pid,resident_pages=1,
                    cpu_ticks=10 if completion_fault == 'cpu' and clock.value >= .1 else 0)
            def sockets(*args):
                calls['sockets'] += 1
                if denied_exit and calls['sockets'] == 2:
                    raise PermissionError('injected post-closure denial')
                if fault == 'denied-read': raise PermissionError('injected read denial')
                if fault == 'public-socket':
                    return [dict(protocol='tcp',state='listen',address='0.0.0.0',port=runner.PORT)]
                return []
            def cleanup(*args):
                calls['cleanup'] += 1
                return dict(exit_code=completion_exit if completed else (-9 if denied_exit == 'live' else 0),
                    group_empty=fault != 'cleanup',errors=['injected'] if fault == 'cleanup' else [])
            def pulse(number):
                if not completed: return
                result = dict(done=0 if completion_fault == 'assertion' else 1,checks=24 if completion_fault == 'counter' and number > 1 else 23,mode='read')
                if variant == 'cleanup-namespace':
                    result=dict(done=0, checks=9, mode='read', error='other failure' if completion_fault == 'assertion' else 'Cross-z equal numeric roof ref was retained')
                raw = json.dumps(result).encode(); (case/'roof-result.json').write_bytes(raw)
                if completion_fault == 'missing' or completion_fault == 'stalled' and number > 1: return
                data = dict(session='b'*64 if completion_fault == 'session' else 'a'*64,
                    mode='write' if completion_fault == 'mode' else 'read', checks=result['checks'],pulse=number,
                    result_md5='0'*32 if completion_fault == 'digest' else hashlib.md5(raw).hexdigest())
                if completion_fault == 'pulse-bool': data['pulse']=True
                if completion_fault == 'gap' and number == 1: number=2
                payload=json.dumps(data)
                if completion_fault == 'duplicate': payload+=payload
                if completion_fault == 'oversize': payload+=' '*1024
                (case/('roof-quiet-'+str(number)+'.json')).write_text(payload)
                (case/('roof-quiet-'+str(number)+'.ready')).write_text('a'*64)
            def popen(*args, **kwargs):
                calls['popen'] += 1; calls['environment'] = kwargs['env']
                if completed:
                    (case/'roof-session.txt').write_text('a'*64)
                    (output/'program').mkdir(); (output/'program/native-read.log').write_text('x'*(runner.CAPS['log_bytes']+1) if completion_fault == 'output' else 'quiet')
                    pulse(1)
                return process
            old = SimpleNamespace(native_census=lambda:[identity(123)] if completion_fault == 'census' and calls['signals'] else [],identity=identity,exited_unreaped=exited,
                group_members=lambda pid: [identity(pid),identity(124)] if fault == 'descendant' else [identity(pid)],
                owned_sockets=sockets,cleanup=cleanup)
            usage_calls = []
            def usage(_):
                usage_calls.append(1)
                return SimpleNamespace(ru_utime=61 if fault == 'cpu' and len(usage_calls) > 1 else 0,ru_stime=0)
            resource = SimpleNamespace(RUSAGE_CHILDREN=0,getrusage=usage)
            def sleep(seconds):
                calls['sleeps'].append(seconds); clock.value += seconds
                if denied_exit and len(calls['sleeps']) == 1: clock.value = second_sample_at
                if completed:
                    pulse(len(calls['sleeps'])+1)
                    if completion_fault == 'log': (output/'program/native-read.log').write_text('changed')
                    if completion_fault == 'session-file': (case/'roof-session.txt').write_text('b'*64)
            receipt = {'children':[]}
            def observed_completion(*args):
                state=runner.completion(*args)
                if completion_fault == 'final-deadline' and calls['sockets'] >= 2: clock.value=60
                return state
            namespace = dict(runner.__dict__, old=old,output=output,byond=Path('/test-engine'),
                completion=observed_completion,
                work_end=work_end,end=end,owned=[],fixed_inputs=0,receipt=receipt,variant=variant,signal=SimpleNamespace(SIGKILL=9),check=lambda:None,save=lambda:None,
                sha=lambda p:runner.ENGINE['DreamDaemon'] if Path(p).name == 'DreamDaemon' else runner.sha(p),subprocess=SimpleNamespace(Popen=popen,DEVNULL=-3),
                time=SimpleNamespace(monotonic=lambda:clock.value,sleep=sleep))
            unit = ast.fix_missing_locations(ast.Module(body=[actual_phase()],type_ignores=[]))
            exec(compile(unit,str(PATH),'exec'),namespace)
            error = None
            # Only a fake resource module and fake Popen are reachable here.
            def terminate(pid, sig):
                calls['signals'].append((pid,int(sig)))
                if completion_fault == 'signal': raise PermissionError('injected signal denial')
            with patch.dict(sys.modules,resource=resource), patch.object(runner.os,'sysconf',
                    lambda key:4096 if key == 'SC_PAGE_SIZE' else 100,create=True), patch.object(runner.os,'killpg',terminate,create=True):
                try: namespace['phase'](['/test-engine/DreamDaemon'],case,'read','read',completion_session='a'*64 if completed else None)
                except Exception as caught: error = caught
            return calls,receipt,error,(case/'probe-port-closed.ack').exists()

    def test_actual_phase_accepts_external_closure_and_reuses_owned_cleanup(self):
        calls,receipt,error,ack = self.phase()
        self.assertIsNone(error)
        self.assertEqual((calls['popen'],calls['cleanup']),(1,1)); self.assertTrue(ack)
        self.assertEqual(set(calls['environment']),{'PATH','LD_LIBRARY_PATH','HOME','TMPDIR','LANG'})
        self.assertTrue(receipt['children'][0]['cleanup']['group_empty'])

    def test_each_failure_still_cleans_only_its_one_owned_child(self):
        for fault in ('early-exit','deadline','descendant','public-socket','cleanup','cpu'):
            with self.subTest(fault=fault):
                calls,receipt,error,ack = self.phase(fault)
                self.assertIsNotNone(error)
                self.assertEqual((calls['popen'],calls['cleanup']),(1,1))
                self.assertEqual(len(receipt['children']),1)

    def test_denied_socket_read_is_not_retried(self):
        calls,receipt,error,ack = self.phase('denied-read')
        self.assertIsNotNone(error)
        self.assertEqual(calls['sockets'],1)
        self.assertEqual(calls['cleanup'],1)
        self.assertFalse(ack)

    def test_live_denial_stays_rejected_even_when_diagnostic_wait_observes_exit(self):
        calls,receipt,error,ack=self.phase(denied_exit='late')
        observation=receipt['children'][0]['socket_observation_denial']
        self.assertIsInstance(error,PermissionError)
        self.assertTrue(ack)
        self.assertFalse(observation['terminal_at_first_waitid'])
        self.assertTrue(observation['terminal_after_wait'])
        self.assertLessEqual(observation['wait_seconds'],.25)
        self.assertEqual((calls['popen'],calls['sockets'],calls['cleanup']),(1,2,1))
        self.assertEqual(receipt['children'][0]['cleanup']['exit_code'],0)

    def test_immediate_terminal_denial_keeps_existing_acceptance_without_wait(self):
        calls,receipt,error,ack=self.phase(denied_exit='terminal')
        observation=receipt['children'][0]['socket_observation_denial']
        self.assertIsNone(error)
        self.assertTrue(ack)
        self.assertTrue(observation['terminal_at_first_waitid'])
        self.assertNotIn('terminal_after_wait',observation)
        self.assertEqual(calls['sleeps'],[.1])
        self.assertEqual((calls['popen'],calls['sockets'],calls['cleanup']),(1,2,1))

    def test_live_denial_diagnostics_respect_window_phase_work_and_outer_caps(self):
        for work,end,second,expected in ((960,990,.1,.25),(960,990,59.9,.1),
                                        (.15,30.15,.1,.05),(960,.12,.1,.02),(960,.1,.1,0)):
            with self.subTest(work=work,end=end,second=second):
                calls,receipt,error,ack=self.phase(denied_exit='live',work_end=work,end=end,second_sample_at=second)
                observation=receipt['children'][0]['socket_observation_denial']
                self.assertIsInstance(error,PermissionError)
                self.assertFalse(observation['terminal_at_first_waitid'])
                self.assertFalse(observation['terminal_after_wait'])
                self.assertAlmostEqual(observation['wait_seconds'],expected)
                self.assertEqual((calls['popen'],calls['sockets'],calls['cleanup']),(1,2,1))

    def test_completion_requires_live_progress_then_exact_recorded_owned_termination(self):
        calls,receipt,error,ack=self.phase(completed=True)
        self.assertIsNone(error); self.assertTrue(ack)
        row=receipt['children'][0]
        self.assertEqual(calls['signals'],[(123,9)])
        self.assertEqual(row['shutdown'],dict(signal=9,pid=123,start_ticks=7,sent=True))
        self.assertEqual(row['exit_contract'],'controller-terminated-completion')
        self.assertEqual([r['pulse'] for r in row['completion']['quiet_samples']],[1,2])
        self.assertEqual(row['cleanup']['exit_code'],-9)
        self.assertEqual((calls['popen'],calls['sockets'],calls['cleanup']),(1,2,1))

    def test_completion_missing_forged_changed_or_nonquiet_evidence_never_authorizes_signal(self):
        for fault in ('missing','stalled','session','session-file','mode','digest','assertion','counter','log','cpu','early-exit','pulse-bool','gap','duplicate','oversize','output','identity','final-deadline'):
            with self.subTest(fault=fault):
                calls,receipt,error,ack=self.phase(completed=True,completion_fault=fault,work_end=.3)
                self.assertIsNotNone(error); self.assertEqual(calls['signals'],[])
                self.assertEqual(calls['cleanup'],1)

    def test_completion_observation_denials_fail_immediately_even_if_terminal_is_imminent(self):
        for state in ('live','late','terminal'):
            with self.subTest(state=state):
                calls,receipt,error,ack=self.phase(completed=True,denied_exit=state)
                self.assertIsInstance(error,PermissionError)
                self.assertEqual((calls['sockets'],calls['cleanup']),(2,1))
                self.assertEqual(calls['sleeps'],[.1]); self.assertEqual(calls['signals'],[])
                self.assertTrue(receipt['children'][0]['socket_observation_denial']['completion_contract'])

    def test_completion_retains_socket_identity_and_final_cleanup_rejections(self):
        for fault in ('public-socket','descendant','cleanup','cpu'):
            with self.subTest(fault=fault):
                calls,receipt,error,ack=self.phase(fault,completed=True)
                self.assertIsNotNone(error); self.assertEqual(calls['cleanup'],1)
        for status in (0,1,-11,-15):
            with self.subTest(status=status):
                calls,receipt,error,ack=self.phase(completed=True,completion_exit=status)
                self.assertIsNotNone(error); self.assertEqual(calls['signals'],[(123,9)])
        calls,receipt,error,ack=self.phase(completed=True,completion_fault='census')
        self.assertIsNotNone(error)
        self.assertIn('Native baseline not empty',str(error))

    def test_completion_termination_denial_preserves_original_error_over_cleanup_failure(self):
        calls,receipt,error,ack=self.phase('cleanup',completed=True,completion_fault='signal')
        self.assertIsInstance(error,PermissionError)
        self.assertEqual(str(error),'injected signal denial')
        self.assertFalse(receipt['children'][0]['shutdown']['sent'])
        self.assertEqual(calls['cleanup'],1)

    def test_completion_control_preserves_exact_named_assertion_oracle(self):
        calls,receipt,error,ack=self.phase(completed=True,variant='cleanup-namespace')
        self.assertIsNone(error); self.assertEqual(receipt['children'][0]['completion']['checks'],9)
        calls,receipt,error,ack=self.phase(completed=True,variant='cleanup-namespace',completion_fault='assertion')
        self.assertIsNotNone(error); self.assertEqual(calls['signals'],[])

    def test_completion_needs_observed_interval_and_live_pulse_within_phase_budget(self):
        for work in (0,.05,.1):
            with self.subTest(work=work):
                calls,receipt,error,ack=self.phase(completed=True,work_end=work)
                self.assertIsNotNone(error); self.assertEqual(calls['signals'],[])

    def test_probe_assertions_and_legacy_natural_exit_remain_byte_identical(self):
        name='tests/roof_area_recovery/probe.dm'
        before=runner.git('show','d5cb5a0ec450f580656e7f9dd11658c98b9dfd2b:'+name).decode()
        current=(runner.ROOT/name).read_text()
        self.assertEqual(current.split('\t// Optional fixture-only post-assertion park.')[0],before.removesuffix('\tdel(world)\n'))
        self.assertTrue(current.endswith('\tdel(world)\n'))
        calls,receipt,error,ack=self.phase()
        self.assertIsNone(error); self.assertEqual(calls['signals'],[])
        self.assertEqual(receipt['children'][0]['exit_contract'],'natural-exit')

    def test_socket_contract_rejects_wrong_port_and_reopening(self):
        good = dict(protocol='tcp',state='listen',address='127.0.0.1',port=runner.PORT)
        runner.socket_contract([good],True,False)
        for rows,runtime,closed in (([good],True,True),([good],False,False),
                                   ([dict(good,port=runner.PORT+1)],True,False),
                                   ([dict(good,protocol='udp')],True,False)):
            with self.assertRaises(RuntimeError): runner.socket_contract(rows,runtime,closed)

    def test_gate_denies_desktop_before_reading_packet_or_creating_output(self):
        with tempfile.TemporaryDirectory() as temporary, patch.object(sys,'platform','win32'):
            output = Path(temporary)/'absent'
            with self.assertRaisesRegex(RuntimeError,'isolated Linux PR CI'):
                runner.run(output,Path(temporary)/'no-engine',Path(temporary)/'no-packet','a'*40,'b'*64)
            self.assertFalse(output.exists())

    def test_control_requires_exact_named_failure_and_count(self):
        runner.adjudicate('read','cleanup-namespace',dict(mode='read',done=False,
            error='Cross-z equal numeric roof ref was retained',checks=9))
        for result in (dict(mode='read',done=False,error='other failure',checks=9),
                       dict(mode='read',done=False,error='Cross-z equal numeric roof ref was retained',checks=8),
                       dict(mode='read',done=True,checks=23)):
            with self.assertRaises(RuntimeError): runner.adjudicate('read','cleanup-namespace',result)
        with self.assertRaises(RuntimeError): runner.adjudicate('read','main',dict(mode='read',done=False,checks=23))

    def test_retained_byond_numeric_flags_preserve_success_and_named_failure(self):
        # Exact non-private writer result retained from CI40040804351.
        actual=json.loads('{"done":1,"checks":10,"mode":"write"}')
        runner.adjudicate('write','main',actual)
        failure=dict(mode='read',done=0,error='Cross-z equal numeric roof ref was retained',checks=9)
        runner.adjudicate('read','cleanup-namespace',failure)
        for changed in (dict(actual,done=0),dict(actual,checks=9),dict(actual,error='unexpected'),
                        dict(failure,done=1),dict(failure,checks=8),dict(failure,error='different')):
            with self.assertRaises(RuntimeError):
                runner.adjudicate(changed['mode'],'main' if changed['mode']=='write' else 'cleanup-namespace',changed)

    def test_native_flag_rejects_noncanonical_numbers_strings_and_null(self):
        for value in (True,1): self.assertIs(runner.native_flag(value),True)
        for value in (False,0): self.assertIs(runner.native_flag(value),False)
        for value in (None,-1,2,0.0,1.0,float('nan'),'0','1','true','false','',[],{}):
            with self.subTest(value=value), self.assertRaises(RuntimeError): runner.native_flag(value)

    def test_git_blob_inventory_is_streamed_and_complete(self):
        head = runner.git('rev-parse','HEAD').decode().strip()
        hashes = runner.tree_hashes(head)
        name = 'code/modules/persistence/loading.dm'
        self.assertGreater(len(hashes),4900)
        expected = hashlib.sha256(runner.git('show',head+':'+name)).hexdigest()
        self.assertEqual(hashes[name],expected)

    def test_public_catalog_preparer_keeps_isolation_and_resolves_only_reviewed_siblings(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)/'atlas.json'
            command = runner.atlas_command(output)
            self.assertEqual(command[1:3],['-I','-B'])
            result = subprocess.run(command,cwd=runner.ROOT,capture_output=True,text=True,timeout=40)
            self.assertEqual(result.returncode,0,result.stderr)
            self.assertTrue(output.is_file())
            self.assertIn('without starting gameplay',result.stdout)


if __name__ == '__main__':
    unittest.main()
