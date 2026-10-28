"""Source and injected continuous-round processes only; never execute BYOND."""
import ast
from contextlib import redirect_stdout
from copy import deepcopy
import importlib.util
import io
import hashlib
import json
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[2]
BEFORE = '5475bac8893da62926467a08fa52952d6663e838'
EXPECTED = {None: 'PASS: fixture complete', 'vote': 'FAIL: vote creation blocked',
    'ticker': 'FAIL: finished flag cleared', 'deferred': 'FAIL: deferred round end cancelled',
    'save': 'FAIL: save guard preserves persistent round state',
    'startup': 'FAIL: startup guard preserves persistent round state'}
IDENTITY = dict(version='516.1688', platform='linux', archive=dict(sha256='a'*64, bytes=4887281),
    members={name: dict(sha256='b'*64, bytes=10)
             for name in ('DreamMaker', 'DreamDaemon', 'libbyond.so', 'libext.so')})


def load(path):
    spec = importlib.util.spec_from_file_location('round_test_'+path.stem.replace('-', '_'), path)
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    return module


class ContinuousRoundToolchain(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.before = {name: subprocess.check_output(['git', 'show', BEFORE+':'+name], cwd=ROOT).decode()
            for name in ('tests/persistence_round/run.py', '.github/workflows/test.yml')}
        cls.current = load(ROOT/'tests/world_save/current_runtime.py')
        cls.contract = load(ROOT/'tests/new_z_budget/z_budget_evidence.py')

    def setUp(self):
        self.spawn = self.enterContext(patch.object(subprocess, 'Popen', side_effect=AssertionError('Native launch forbidden')))
        self.sockets = self.enterContext(patch.object(socket, 'socket', side_effect=AssertionError('Socket forbidden')))

    def tearDown(self):
        self.spawn.assert_not_called(); self.sockets.assert_not_called()

    def runtime(self, drift=False):
        verifier = SimpleNamespace(verify_linux=Mock(return_value=deepcopy(IDENTITY)))
        if drift:
            verifier.verify_linux.side_effect = [deepcopy(IDENTITY), deepcopy(IDENTITY), ValueError('member changed')]
        with patch.object(self.current.sys, 'platform', 'linux'), \
             patch.object(self.current, 'load', side_effect=[verifier, self.contract]):
            return self.current.CurrentRuntime('inert-bin', 'inert.zip')

    def exercise(self, control=None, current=True, compile_output=None, compile_exit=0,
                 drift=False, result=None, daemon_exit=0, diagnostic=False, collision=False):
        runner = load(ROOT/'tests/persistence_round/run.py'); toolchain = self.runtime(drift) if current else None
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); binary = root/'tools'; binary.mkdir()
            for name in ('dm.exe', 'dd.exe', 'DreamMaker', 'DreamDaemon'): (binary/name).write_bytes(b'Inert placeholder')
            for name in ('civ13.dme', 'code/world.dm', 'code/game/gameticker.dm', 'code/datums/vote.dm',
                         'tests/persistence_round/probe.dm'):
                target = root/name; target.parent.mkdir(parents=True, exist_ok=True); shutil.copy2(ROOT/name, target)
            (root/'config/names').mkdir(parents=True); (root/'config/names/inert.txt').write_text('offline')
            runner_path = root/'tests/persistence_round/run.py'; runner_path.write_text('source path only')
            prefix = '.persistence_round_ci'; marker = root/(prefix+'.dme')
            if collision: marker.write_bytes(b'owned preexisting probe')
            launched = []; staged = {}
            def run(command, **kwargs):
                compiler = Path(command[0]).name in ('dm.exe', 'DreamMaker')
                role = 'compile' if compiler else 'daemon'; launched.append(role)
                if current: self.assertEqual(toolchain.checks[-1], role)
                self.assertEqual(kwargs['timeout'], 120 if compiler else 60)
                if compiler:
                    staged.update({p.name: p.read_text(encoding='utf-8') for p in root.glob(prefix+'*.dm*')})
                    environment = marker.read_text(encoding='utf-8')
                    self.assertNotIn('.dmm"', environment)
                    self.assertIn('#include "tests/persistence_round/probe.dm"', environment)
                    for suffix in ('.dmb', '.rsc'): (root/(prefix+suffix)).write_bytes(b'Nonexecutable compiled placeholder')
                    output = compile_output if compile_output is not None else (
                        'DM compiler version '+('516.1688' if current else '516.1681')+'\n'+prefix+'.dmb - 0 errors, 0 warnings\n')
                    return subprocess.CompletedProcess(command, compile_exit, output, '')
                self.assertEqual(command[command.index('-ip')+1], '127.0.0.1')
                self.assertIn('-nowebclient', command)
                logs = Path(kwargs['cwd']); (logs/'result.txt').write_text(result or EXPECTED[control])
                (logs/'runtime.log').write_text('BUG: injected engine failure' if diagnostic else 'clean')
                return subprocess.CompletedProcess(command, daemon_exit, '', '')
            args = ['round', '--byond-bin', str(binary)]
            if current: args += ['--byond-archive', 'inert.zip']
            if control: args += ['--negative-control', control]
            with patch.object(runner, '__file__', str(runner_path)), \
                 patch.object(runner, 'selected_runtime', return_value=toolchain), \
                 patch.object(subprocess, 'check_output', return_value=BEFORE+'\n'), \
                 patch.object(subprocess, 'run', side_effect=run), \
                 patch.object(sys, 'argv', args), redirect_stdout(io.StringIO()):
                try: runner.main()
                finally:
                    if collision: self.assertEqual(marker.read_bytes(), b'owned preexisting probe')
                    else: self.assertFalse(list(root.glob(prefix+'*')))
            if current:
                receipt = json.loads(next((root/'data/persistence-round-tests').glob('run-*/runtime-identity.json')).read_text(encoding='utf-8'))
                self.assertEqual(receipt['runtime'], IDENTITY)
                self.assertEqual(receipt['verified_before'], ['compile', 'daemon'])
            self.assertEqual(launched, ['compile', 'daemon'])
            return staged

    def test_all_six_cases_preserve_historical_mode_and_recheck_current_identity_before_each_child(self):
        for control in EXPECTED:
            with self.subTest(control=control):
                self.assertEqual(self.exercise(control, current=False), self.exercise(control))

    def test_current_compile_rejects_wrong_duplicate_or_dirty_banner_and_process_failure(self):
        clean = 'DM compiler version 516.1688\n.persistence_round_ci.dmb - 0 errors, 0 warnings\n'
        for output, code in ((clean.replace('1688', '1681'), 0), (clean+clean, 0),
                             (clean.replace('0 warnings', '1 warning'), 0), (clean+'BUG: injected\n', 0), (clean, 1)):
            with self.subTest(output=output, code=code), self.assertRaises(RuntimeError):
                self.exercise(compile_output=output, compile_exit=code)

    def test_legacy_mode_still_rejects_current_banner(self):
        with self.assertRaisesRegex(RuntimeError, 'Pinned compilation failed'):
            self.exercise(current=False, compile_output='DM compiler version 516.1688\n.persistence_round_ci.dmb - 0 errors, 0 warnings\n')

    def test_identity_drift_and_owned_probe_collision_refuse_progress(self):
        with self.assertRaisesRegex(ValueError, 'member changed'): self.exercise(drift=True)
        with self.assertRaisesRegex(RuntimeError, 'Preserve existing probe files'): self.exercise(collision=True)

    def test_existing_positive_and_negative_runtime_oracles_reject_wrong_results_and_diagnostics(self):
        for control in EXPECTED:
            for options in ({'result': 'FAIL: unrelated'}, {'daemon_exit': 1}, {'diagnostic': True}):
                with self.subTest(control=control, options=options), self.assertRaises(RuntimeError):
                    self.exercise(control, **options)

    def test_actual_shared_route_retains_default_and_refuses_current_mode_on_windows(self):
        runner = load(ROOT/'tests/persistence_round/run.py')
        self.assertIsNone(runner.selected_runtime('inert', None))
        with patch.object(sys, 'platform', 'win32'), self.assertRaisesRegex(ValueError, 'requires Linux'):
            runner.selected_runtime('inert', 'inert.zip')

    def test_source_workflow_scope_commands_deadlines_and_native_oracles_are_preserved(self):
        source = (ROOT/'tests/persistence_round/run.py').read_text(encoding='utf-8'); before = self.before['tests/persistence_round/run.py']
        def launches(text):
            return [ast.dump(n) for n in ast.walk(ast.parse(text)) if isinstance(n, ast.Call)
                and isinstance(n.func, ast.Attribute) and isinstance(n.func.value, ast.Name)
                and n.func.value.id == 'subprocess' and n.func.attr == 'run']
        self.assertEqual(launches(source), launches(before))
        marker = "        runtime = subprocess.run([str(daemon)"
        self.assertEqual(source[source.index(marker):], before[before.index(marker):])
        workflow = (ROOT/'.github/workflows/test.yml').read_text(encoding='utf-8')
        step = ('      - name: Test continuous persistence round contracts offline\n'
            "        if: needs.changes.outputs.extensive == 'true' || contains(fromJSON(needs.changes.outputs.new_tests), 'tests/persistence_round') || inputs.persistence_integration_regressions == true\n"
            '        run: python3 -B -m unittest discover -s tests/persistence_round -v\n')
        self.assertEqual(workflow.count(step), 1)
        normalized = workflow.replace(step, '')
        original = '          /usr/bin/python3 tests/persistence_round/run.py --byond-bin "$PWD/BYOND/byond/bin"'
        current = original.replace(' --byond-bin', ' --byond-archive "$PWD/BYOND/pinned.zip" --byond-bin')
        self.assertEqual(normalized.count(current), 6)
        marker = '      - name: Verify continuous persistence rounds and negative controls\n'
        after_step = normalized.split(marker, 1)[1].split('      - name:', 1)[0]
        before_step = self.before['.github/workflows/test.yml'].split(marker, 1)[1].split('      - name:', 1)[0]
        self.assertEqual(after_step.replace(current, original), before_step)
        # Pin the full merged workflow as well: other branches' guards and
        # attempt-bound receipts are not covered by this local step comparison.
        self.assertEqual(hashlib.sha256(workflow.encode()).hexdigest(),
                         '98526839e1e64921c98f4ede8fcf117683c02ec101981d0cdb39f967b7659a2b')


if __name__ == '__main__': unittest.main()
