"""Exercise the real runner phase with injected OS effects; never launches BYOND."""
import ast
import copy
import hashlib
import importlib.util
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
    def phase(self, fault=None):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary); case = output/'cases/read'; case.mkdir(parents=True)
            if fault != 'early-exit': (case/'probe-port-closed.txt').write_bytes(b'closed\n')
            calls = dict(cleanup=0, sockets=0, exit=0, popen=0)
            clock = SimpleNamespace(value=0)
            process = SimpleNamespace(pid=123)
            def exited(_):
                calls['exit'] += 1
                if fault == 'early-exit': return True
                if fault == 'deadline': clock.value = 61
                return calls['exit'] > 1
            def identity(pid):
                return dict(pid=pid,start_ticks=7,pgrp=pid,session=pid,resident_pages=1,cpu_ticks=0)
            def sockets(*args):
                calls['sockets'] += 1
                if fault == 'denied-read': raise PermissionError('injected read denial')
                if fault == 'public-socket':
                    return [dict(protocol='tcp',state='listen',address='0.0.0.0',port=runner.PORT)]
                return []
            def cleanup(*args):
                calls['cleanup'] += 1
                return dict(exit_code=0,group_empty=fault != 'cleanup',errors=['injected'] if fault == 'cleanup' else [])
            def popen(*args, **kwargs):
                calls['popen'] += 1; calls['environment'] = kwargs['env']; return process
            old = SimpleNamespace(native_census=lambda:[],identity=identity,exited_unreaped=exited,
                group_members=lambda pid: [identity(pid),identity(124)] if fault == 'descendant' else [identity(pid)],
                owned_sockets=sockets,cleanup=cleanup)
            usage_calls = []
            def usage(_):
                usage_calls.append(1)
                return SimpleNamespace(ru_utime=61 if fault == 'cpu' and len(usage_calls) > 1 else 0,ru_stime=0)
            resource = SimpleNamespace(RUSAGE_CHILDREN=0,getrusage=usage)
            receipt = {'children':[]}
            namespace = dict(runner.__dict__, old=old,output=output,byond=Path('/test-engine'),
                work_end=960,end=990,owned=[],fixed_inputs=0,receipt=receipt,check=lambda:None,save=lambda:None,
                sha=lambda _:runner.ENGINE['DreamDaemon'],subprocess=SimpleNamespace(Popen=popen,DEVNULL=-3),
                time=SimpleNamespace(monotonic=lambda:clock.value,sleep=lambda seconds:setattr(clock,'value',clock.value+seconds)))
            unit = ast.fix_missing_locations(ast.Module(body=[actual_phase()],type_ignores=[]))
            exec(compile(unit,str(PATH),'exec'),namespace)
            error = None
            # Only a fake resource module and fake Popen are reachable here.
            with patch.dict(sys.modules,resource=resource), patch.object(runner.os,'sysconf',
                    lambda key:4096 if key == 'SC_PAGE_SIZE' else 100,create=True):
                try: namespace['phase'](['/test-engine/DreamDaemon'],case,'read','read')
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

    def test_git_blob_inventory_is_streamed_and_complete(self):
        head = runner.git('rev-parse','HEAD').decode().strip()
        hashes = runner.tree_hashes(head)
        name = 'code/modules/persistence/loading.dm'
        self.assertGreater(len(hashes),4900)
        expected = hashlib.sha256(runner.git('show',head+':'+name)).hexdigest()
        self.assertEqual(hashes[name],expected)


if __name__ == '__main__':
    unittest.main()
