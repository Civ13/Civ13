"""Injected current-runtime contracts; no native process, socket or download."""
import ast
from copy import deepcopy
import importlib.util
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
from types import SimpleNamespace as NS
import unittest
from unittest.mock import Mock, patch

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    return module


current = load('current_runtime_test', HERE/'current_runtime.py')
compile_contract = load('current_compile_test', ROOT/'tests/new_z_budget/z_budget_evidence.py')
IDENTITY = dict(version='516.1688', platform='linux', archive=dict(sha256='a'*64, bytes=4887281),
                members={name:dict(sha256='b'*64, bytes=10) for name in ('DreamMaker','DreamDaemon','libbyond.so','libext.so')})


class CurrentRuntimeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Harmless immutable Git reads before process/socket prohibitions.
        cls.old_durable = subprocess.check_output(['git','show','1572e6c:tests/world_save/run-durable-world.py'],cwd=ROOT,text=True)
        cls.feature_durable = subprocess.check_output(['git','show',
            'f97c2940b0b1202ed97f5f413bd1a4a6f24e0962:tests/world_save/run-durable-world.py'],cwd=ROOT,text=True)

    def setUp(self):
        self.spawn=self.enterContext(patch.object(subprocess,'Popen',side_effect=AssertionError('Native process forbidden')))
        self.enterContext(patch.object(socket,'socket',side_effect=AssertionError('Socket forbidden')))

    def runtime(self, verifier=None):
        verifier=verifier or NS(verify_linux=Mock(return_value=deepcopy(IDENTITY)))
        with patch.object(current.sys,'platform','linux'), patch.object(current,'load',side_effect=[verifier,compile_contract]):
            return current.CurrentRuntime(Path('unused-bin'),Path('unused.zip'))

    def test_identity_uses_existing_passive_verifier_and_rechecks_all_members(self):
        verifier=NS(verify_linux=Mock(return_value=deepcopy(IDENTITY)))
        runtime=self.runtime(verifier)
        with tempfile.TemporaryDirectory() as directory:
            runtime.before_launch('compile',Path(directory)); runtime.before_launch('daemon',Path(directory))
            receipt=json.loads((Path(directory)/'runtime-identity.json').read_text())
            self.assertEqual(receipt['runtime'],IDENTITY)
            self.assertEqual(receipt['verified_before'],['compile','daemon'])
        self.assertEqual(verifier.verify_linux.call_count,3)
        verifier.verify_linux.assert_called_with(Path('unused-bin').absolute(),Path('unused.zip').absolute())
        self.spawn.assert_not_called()

    def test_wrong_archive_or_member_and_later_drift_stop_before_launch(self):
        for error in ('archive differs','DreamMaker differs','DreamDaemon differs','libbyond differs','libext differs'):
            with self.subTest(error=error), self.assertRaisesRegex(ValueError,error):
                self.runtime(NS(verify_linux=Mock(side_effect=ValueError(error))))
        runtime=self.runtime()
        with tempfile.TemporaryDirectory() as directory:
            for member in IDENTITY['members']:
                changed=deepcopy(IDENTITY); changed['members'][member]['sha256']='c'*64
                runtime.verifier.verify_linux.return_value=changed
                with self.subTest(member=member), self.assertRaisesRegex(ValueError,'identity changed'):
                    runtime.before_launch('daemon',Path(directory))
                self.assertEqual(json.loads((Path(directory)/'runtime-identity.json').read_text())['runtime'],IDENTITY)
        self.spawn.assert_not_called()

    def test_legacy_does_not_claim_archive_identity_and_current_requires_linux(self):
        with patch.object(current,'load') as loader:
            self.assertIsNone(current.select(Path('unused'),None)); loader.assert_not_called()
        with patch.object(current.sys,'platform','win32'), self.assertRaisesRegex(ValueError,'requires Linux'):
            current.select(Path('unused'),Path('unused.zip'))

    def test_exact_compiler_evidence_and_all_old_diagnostic_categories_fail_closed(self):
        runtime=self.runtime()
        good='DM compiler version 516.1688\nprobe.dmb - 0 errors, 0 warnings\n'
        runtime.validate_compile(0,good,'probe.dmb')
        runtime.validate_compile(0,good.replace('warnings','warnings (10/26/26 1:00 am)'),'probe.dmb')
        bad=(good.replace('1688','1681'),good.replace('1688','16880'),good.replace('1688','1688-beta'),
             good+good,good.replace('DM compiler','prefix DM compiler'),good.replace('probe.dmb','other.dmb'),
             good.replace('0 errors','1 errors'),good.replace('0 warnings','1 warnings'),
             '\n'.join(good.strip().splitlines()[::-1]),good+'x'*1048576)
        for log in (*bad,*(good+word for word in ('runtime error:','bad ref','bad loc','BUG:','## ERROR:',
                        'RUNTIME:','assertion failed','infinite loop','segmentation','fatal error','unexpected runtime',
                        'OOM','out of memory','access violation','CRASHED','invalid file'))):
            with self.subTest(log=log[:90]), self.assertRaises(RuntimeError): runtime.validate_compile(0,log,'probe.dmb')
        with self.assertRaises(RuntimeError): runtime.validate_compile(1,good,'probe.dmb')

    def round_trip(self, negative=None, drift=False, bad_result=False, native_error=False):
        runner=load('round_identity_test',HERE/'run-round-metadata.py')
        runtime=self.runtime(); calls=[]
        expected={None:'PASS','restore':'FAIL: round-mode flag lost: persistence',
                  'preflight':'FAIL: invalid round extension passed preflight: partial',
                  'integrity':'FAIL: modern metadata tamper passed preflight'}[negative]
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory); byond=root/'bin'; byond.mkdir(); output=root/'output'; output.mkdir()
            # The explicit archive contract always selects Linux binaries even
            # when these inert injected tests are executed on Windows.
            names=('DreamMaker','DreamDaemon')
            for name in names: (byond/name).write_bytes(b'inert; never executable')
            def popen(command,**kwargs):
                compiler=Path(command[0]).name==names[0]; calls.append('compile' if compiler else 'daemon')
                text='DM compiler version 516.1688\nroundtrip.dmb - 0 errors, 0 warnings\n' if compiler else ''
                kwargs['stdout'].write(text)
                if not compiler:
                    (output/'runtime.log').write_text('runtime error:' if native_error else 'clean')
                    (output/'result.txt').write_text('wrong result' if bad_result else expected)
                if compiler and drift:
                    changed=deepcopy(IDENTITY); changed['members']['DreamDaemon']['sha256']='c'*64
                    runtime.verifier.verify_linux.return_value=changed
                return NS(pid=123,wait=lambda timeout:None,poll=lambda:0,terminate=lambda:None,kill=lambda:None)
            args=['round','--byond-bin',str(byond),'--byond-archive',str(root/'archive.zip')]
            if negative: args+=['--negative-control',negative]
            with patch.object(sys,'argv',args), patch.object(runner,'selected_runtime',return_value=runtime), \
                    patch.object(runner.tempfile,'mkdtemp',return_value=str(output)), patch('builtins.print'), \
                    patch.object(runner.subprocess,'Popen',side_effect=popen):
                error=None
                try: runner.main()
                except Exception as caught: error=caught
            summary=json.loads((output/'summary.json').read_text()) if (output/'summary.json').exists() else None
            return calls,error,summary,runtime.checks

    def test_actual_round_main_preserves_positive_and_all_named_negative_oracles(self):
        for control in (None,'restore','preflight','integrity'):
            with self.subTest(control=control):
                calls,error,summary,checks=self.round_trip(control)
                self.assertIsNone(error); self.assertEqual(calls,['compile','daemon'])
                self.assertEqual(checks,['compile','daemon']); self.assertEqual(summary['negative_control'],control)
                self.assertTrue(all(p['exit']==0 and not p['cancelled'] for p in summary['processes']))

    def test_actual_round_main_blocks_drift_wrong_result_and_runtime_diagnostics(self):
        calls,error,summary,checks=self.round_trip(drift=True)
        self.assertIsInstance(error,ValueError); self.assertEqual(calls,['compile']); self.assertIsNone(summary)
        for fault in ('bad_result','native_error'):
            with self.subTest(fault=fault):
                calls,error,summary,checks=self.round_trip(**{fault:True})
                self.assertIsInstance(error,RuntimeError); self.assertIsNone(summary)

    def test_durable_collector_and_held_paths_remain_unchanged(self):
        runner=load('durable_identity_test',HERE/'run-durable-world.py')
        def function(source,name):
            return ast.dump(next(n for n in ast.parse(source).body if isinstance(n,ast.FunctionDef) and n.name==name))
        self.assertEqual(function(self.old_durable,'run_lighting'),function((HERE/'run-durable-world.py').read_text(),'run_lighting'))
        marker = "        result_path = output / 'metadata-result.json'"
        self.assertEqual(self.feature_durable.split(marker,1)[1],(HERE/'run-durable-world.py').read_text().split(marker,1)[1])
        for flags in (['--roof-areas'],['--zone-topology'],['--prepare-only'],['--persistence-year']):
            with self.subTest(flags=flags), patch.object(sys,'argv',['durable','--byond-bin','unused','--byond-archive','unused.zip',*flags]), \
                    patch.object(runner,'selected_runtime') as selected, patch('sys.stderr'), self.assertRaises(SystemExit):
                runner.main()
            selected.assert_not_called()
        with patch.object(sys,'argv',['durable','--byond-bin','unused','--byond-archive','unused.zip','--lighting']), \
                patch.object(runner,'selected_runtime',side_effect=ValueError('identity mismatch')), \
                patch.object(runner.tempfile,'mkdtemp') as temporary, self.assertRaisesRegex(ValueError,'identity mismatch'):
            runner.main()
        temporary.assert_not_called(); self.spawn.assert_not_called()

    def test_actual_lighting_main_rechecks_before_compile_and_owned_collector(self):
        runner=load('lighting_identity_test',HERE/'run-durable-world.py')
        runtime=self.runtime(); calls=[]
        with tempfile.TemporaryDirectory() as directory:
            output=Path(directory)
            def git(command,**kwargs):
                self.assertEqual(command[0],'git')
                return 'offline-head\n' if kwargs.get('text') else b''
            def compile(command,**kwargs):
                self.assertEqual(runtime.checks,['compile']); self.assertEqual(kwargs['timeout'],180)
                calls.append('compile'); dme=ROOT/command[-1]
                for suffix in ('.dmb','.rsc'): dme.with_suffix(suffix).write_bytes(b'inert; not a native artifact')
                return NS(returncode=0,stdout='DM compiler version 516.1688\n'+dme.with_suffix('.dmb').name+' - 0 errors, 0 warnings\n',stderr='')
            def collector(command,destination,flags):
                self.assertEqual(runtime.checks,['compile','daemon']); calls.append('collector')
                (destination/'runtime.log').write_text('clean')
                (destination/'metadata-result.json').write_text(json.dumps(dict(done=1,checks=50)))
                return NS(returncode=0,stdout='',stderr='')
            args=['durable','--lighting','--byond-bin',str(output/'unused-bin'),'--byond-archive',str(output/'unused.zip')]
            with patch.object(sys,'argv',args), patch.object(runner,'selected_runtime',return_value=runtime), \
                    patch.object(runner.tempfile,'mkdtemp',return_value=directory), patch('builtins.print'), \
                    patch.object(runner.subprocess,'check_output',side_effect=git), \
                    patch.object(runner.subprocess,'run',side_effect=compile), patch.object(runner,'run_lighting',side_effect=collector):
                runner.main()
            self.assertEqual(calls,['compile','collector'])
            self.assertEqual(json.loads((output/'runtime-identity.json').read_text())['verified_before'],['compile','daemon'])
        self.spawn.assert_not_called()

    def test_selected_workflow_threads_archive_without_new_modes_or_historical_engine_changes(self):
        workflow=(ROOT/'.github/workflows/test.yml').read_text()
        block=workflow.split('- name: Offline lighting recovery regression',1)[1].split('      - name:',1)[0]
        calls=[line for line in block.splitlines() if 'run-round-metadata.py ' in line or 'run-durable-world.py ' in line]
        self.assertEqual(len(calls),3)
        for line in calls:
            if 'run-round-metadata.py ' in line:
                self.assertIn('--current-linux-toolchain', line)
            else:
                self.assertIn('--byond-archive "$PWD/BYOND/pinned.zip"', line)
        self.assertIn('for control in lighting-export lighting-legacy lighting-rebuild lighting-opacity lighting-view lighting-eager lighting-shared;',block)
        self.assertIn('DM compiler version 516.1681',(ROOT/'tests/new_z_budget/z_budget_evidence.py').read_text())


if __name__=='__main__': unittest.main()
