"""Fixture callback and injected supervisor tests; never launches a native child."""
from datetime import datetime, timedelta, timezone
import importlib.util
import json
from pathlib import Path
import re
import sys
import tempfile
import time
from types import SimpleNamespace as N
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
spec = importlib.util.spec_from_file_location('mount_linux_runner_test', HERE/'run_linux.py')
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)
sys.path.insert(0,str(ROOT/'tests/save_movement'))
from source_adapter import extract, project


class RunnerTests(unittest.TestCase):
    def test_both_actual_fixture_destroyed_callbacks_mark_injection_before_binding(self):
        declaration = '/datum/mount_native_case/proc/destroyed'
        body = extract((HERE/'probe.dm').read_text(),declaration)
        # Project only this new fixture's callback, not production qdel/Destroy.
        body = re.sub(r'([,(])\s*"(\w+)"\s*=',r'\1\2=',body).replace('list(', 'dict(')
        pieces = re.split(r'("(?:[^"\\]|\\.)*")',body)
        fields = ('active','events','operation','kind','observed_clear','injected','H','A','note','bind_b','bind_j')
        for index in range(0,len(pieces),2):
            for field in fields:
                pieces[index] = re.sub(r'(?<![\w.])'+field+r'\b','src.'+field,pieces[index])
        for operation in ('mount_qdel','rider_qdel'):
            calls = []
            case = N(active=True,events=0,operation=operation,kind='reassignment',
                     observed_clear=False,injected=False,H=N(riding=False,riding_mob=None),
                     A=N(ride=False,rider=None,stop_automated_movement=False))
            case.note = lambda *args: calls.append(('note',args[0]))
            case.bind_b = lambda: calls.append(('bind_b',case.injected))
            case.bind_j = lambda: calls.append(('bind_j',case.injected))
            callback = project('/callback()\n'+''.join(pieces),' /callback'.strip(),'src,target',
                               dict(qdel=lambda target:calls.append(('qdel',target)),isnull=lambda x:x is None))
            target = N(gc_destroyed=-2)
            callback(case,target)
            self.assertTrue(case.injected)
            self.assertTrue(case.observed_clear)
            self.assertEqual(case.events,1)
            self.assertIn(('bind_b' if operation=='mount_qdel' else 'bind_j',True),calls)
            self.assertEqual(sum(row[0]=='qdel' for row in calls),1)

    def simulate(self, folder, *, sockets=None, foreign=False, birth_bad=False):
        state = N(reaped=False,calls=[])
        birth = dict(pid=123,start_ticks=77,pgrp=999 if birth_bad else 123,session=123,state='R',resident_pages=1)
        def members(pid):
            return [] if state.reaped else [birth]+([dict(pid=124,pgrp=123,session=123)] if foreign else [])
        def memory(*args):
            counts={'count':0,'peak_rss':0}
            def sample(*unused): counts['count']+=1
            return sample,counts
        def process(command,cwd,phase,limit,**kwargs):
            self.assertTrue(kwargs['retain_leader'])
            self.assertIs(kwargs['preexec_fn'],runner.common.bounded_child)
            state.calls.append(kwargs)
            try:
                kwargs['on_event']('spawn',123)
                kwargs['monitor'](123,cwd)
            finally:
                kwargs['on_event']('group_signal_sent',123)
                kwargs['on_event']('wait',0)
                state.reaped=True
            return dict(returncode=0)
        with patch.object(runner.linux,'identity',return_value=birth), \
             patch.object(runner.os,'sysconf',return_value=4096,create=True), \
             patch.object(runner.linux,'group_members',side_effect=members), \
             patch.object(runner.linux,'native_census',return_value=[]), \
             patch.object(runner.linux,'owned_sockets',return_value=sockets or []), \
             patch.object(runner.common,'monitor_for',side_effect=memory), \
             patch.object(runner.common.legacy,'run_process',side_effect=process):
            result = runner.supervised(['synthetic'],folder,'runtime-none',30,time.monotonic()+100,
                datetime.now(timezone.utc)+timedelta(hours=1),Path('/reviewed/bin'))
        return result,state

    def test_retained_monitor_event_ack_and_final_censuses(self):
        with tempfile.TemporaryDirectory(prefix='mount-supervisor-') as temp:
            folder=Path(temp);(folder/'port-closed.txt').write_bytes(b'closed\n')
            result,state=self.simulate(folder)
            self.assertEqual(result['returncode'],0)
            self.assertTrue(state.reaped)
            self.assertEqual((folder/'port-closed.ack').read_bytes(),b'closed\n')
            receipt=json.loads((folder/'runtime-none-supervision.json').read_text())
            self.assertEqual(receipt['final_group'],[])
            self.assertEqual(receipt['final_native'],[])
            self.assertEqual(receipt['final_socket_census']['rows'],[])
            self.assertTrue(receipt['final_socket_census']['retained_leader'])

    def test_foreign_members_and_birth_failure_are_retained_and_fail(self):
        for options in (dict(foreign=True),dict(birth_bad=True)):
            with self.subTest(**options),tempfile.TemporaryDirectory(prefix='mount-supervisor-failure-') as temp:
                folder=Path(temp);(folder/'port-closed.txt').write_bytes(b'closed\n')
                with self.assertRaises(RuntimeError): self.simulate(folder,**options)
                receipt=json.loads((folder/'runtime-none-supervision.json').read_text())
                self.assertTrue(receipt.get('error') or receipt['errors'])
                self.assertEqual(receipt['final_group'],[])

    def test_nonloopback_or_connected_socket_never_acknowledges(self):
        rows=[dict(protocol='tcp',address='0.0.0.0',port=59474,state='listen')]
        with tempfile.TemporaryDirectory(prefix='mount-socket-refusal-') as temp:
            folder=Path(temp);(folder/'port-closed.txt').write_bytes(b'closed\n')
            with self.assertRaises(RuntimeError): self.simulate(folder,sockets=rows)
            self.assertFalse((folder/'port-closed.ack').exists())

    def test_windows_gate_refuses_before_host_queries_or_output(self):
        with tempfile.TemporaryDirectory(prefix='mount-no-windows-') as temp:
            output=Path(temp)/'new'
            with patch.object(runner.sys,'platform','win32'),patch.object(runner.linux,'native_census') as census:
                with self.assertRaisesRegex(RuntimeError,'Windows startup-socket hold'):
                    runner.gate(Path(temp),output,'a'*40,'b'*64,datetime.now(timezone.utc)+timedelta(hours=1))
                census.assert_not_called()
                self.assertFalse(output.exists())


if __name__=='__main__': unittest.main()
