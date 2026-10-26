"""Selected ordinary CI migration: source and injected processes only; no native runs."""
import ast
from contextlib import redirect_stdout
from copy import deepcopy
import hashlib
import importlib.util
import io
from itertools import combinations, product
import json
import os
from pathlib import Path
import shlex
import socket
import subprocess
import sys
import tempfile
from types import SimpleNamespace as NS
import unittest
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[2]
HERE = ROOT/'tests/world_save'
BEFORE = 'f05659dd5d117302b7ab494ad6e226f2b3f50ab1'
# Verbatim reviewed #3105 helper; no other branch Git objects are needed in CI.
REVIEWED_HELPER_SHA256 = 'a89a5191b43b304d7a1e6d6ea74b17a0c1630ed05b25ff09650b5f775268aab2'
STEPS = ('Offline lighting recovery regression',
         'Verify protected sleep transfers and version-2 saves',
         'Offline world-save round-trip regression')
DRIVERS = ('run-durable-world.py', 'run-sleep-transfer.py', 'run-cross-level.py',
           'inspect-partial-save.py', 'run-dimension-bootstrap.py', 'run-reader-contract.py')
IDENTITY = dict(version='516.1688', platform='linux', archive=dict(sha256='a'*64, bytes=4887281),
                members={name: dict(sha256='b'*64, bytes=10) for name in
                         ('DreamMaker', 'DreamDaemon', 'libbyond.so', 'libext.so')})


def load(path):
    spec = importlib.util.spec_from_file_location('selected_'+path.stem.replace('-', '_'), path)
    module = importlib.util.module_from_spec(spec)
    if path.name == 'inspect-partial-save.py' and sys.platform != 'linux':
        with patch.dict(sys.modules, resource=NS()): spec.loader.exec_module(module)
    else: spec.loader.exec_module(module)
    return module


def calls(workflow):
    """Expand fixed selected shell loops as data, without executing shell commands."""
    result = []
    def walk(lines, env):
        i = 0
        while i < len(lines):
            line = lines[i].strip()
            if line.startswith('for ') and line.endswith('; do'):
                header = shlex.split(line[:-4]); depth = 1; end = i+1
                while depth:
                    current = lines[end].strip()
                    if current.startswith('for ') and current.endswith('; do'): depth += 1
                    if current == 'done': depth -= 1
                    end += 1
                for value in header[3:]: walk(lines[i+1:end-1], dict(env, **{header[1]: value}))
                i = end; continue
            line = line.removeprefix('if ! ').removesuffix('; then')
            if line.startswith('python3 tests/') and any(name+' ' in line for name in DRIVERS):
                tokens = [env.get(token.removeprefix('$'), token) for token in shlex.split(line)]
                result.append((tokens[1], tokens[2:]))
            i += 1
    for step in STEPS:
        block = workflow.split('      - name: '+step+'\n', 1)[1].split('      - name:', 1)[0]
        walk(block.splitlines(), {})
    return result


CURRENT = load(HERE/'current_runtime.py')
CONTRACT = load(ROOT/'tests/new_z_budget/z_budget_evidence.py')


class SelectedToolchains(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        def old(path, ref=BEFORE):
            return subprocess.check_output(['git', 'show', ref+':'+path], cwd=ROOT).decode()
        cls.before = {path: old(path) for path in (
            '.github/workflows/test.yml', 'tests/world_save/run-durable-world.py',
            'tests/world_save/run-cross-level.py', 'tests/world_save/run-sleep-transfer.py',
            'tests/world_save/run-dimension-bootstrap.py', 'tests/world_save/run-reader-contract.py',
            'tests/world_save/partial_save_inspector/inspect-partial-save.py')}
        cls.historical_wounds = {path: old(path, 'd0ffbfb2335eb735756b998f3f2ff617c28f144b')
                                 for path in ('code/modules/organs/wound.dm', 'code/modules/persistence/loading.dm')}

    def setUp(self):
        self.enterContext(patch.object(socket, 'socket', side_effect=AssertionError('Socket forbidden')))
        self.enterContext(patch.object(subprocess, 'Popen', side_effect=AssertionError('Native launch forbidden')))
        self.enterContext(patch.object(subprocess, 'run', side_effect=AssertionError('Native run forbidden')))

    def runtime(self):
        verifier = NS(verify_linux=Mock(return_value=deepcopy(IDENTITY)))
        with patch.object(CURRENT.sys, 'platform', 'linux'), patch.object(CURRENT, 'load', side_effect=[verifier, CONTRACT]):
            return CURRENT.CurrentRuntime('inert-bin', 'inert.zip')

    def tools(self, root):
        binary = root/'tools'; binary.mkdir()
        for name in ('dm.exe', 'dd.exe', 'DreamMaker', 'DreamDaemon'):
            (binary/name).write_bytes(b'Nonexecutable placeholder')
        return binary

    def git(self, command, **kwargs):
        self.assertEqual(command[0], 'git')
        if command[1] == 'show': return self.historical_wounds[command[2].split(':', 1)[1]]
        return BEFORE+'\n' if kwargs.get('text') else b''

    def test_reviewed_helper_is_verbatim_and_workflow_changes_only_thread_identity_and_offline_test(self):
        self.assertEqual(hashlib.sha256((HERE/'current_runtime.py').read_text().encode()).hexdigest(), REVIEWED_HELPER_SHA256)
        workflow = (ROOT/'.github/workflows/test.yml').read_text()
        command = '          python3 -B -m unittest discover -s tests/world_save -p test_selected_toolchains.py -v\n'
        normalized = workflow.replace(command, '').replace(' --byond-archive "$PWD/BYOND/pinned.zip"', '')
        self.assertEqual(normalized, self.before['.github/workflows/test.yml'])
        selected = calls(workflow)
        self.assertEqual(len(selected), 42)
        for path, args in selected:
            with self.subTest(path=path, args=args):
                module = load(ROOT/path)
                target = module.BASE if path.endswith('run-sleep-transfer.py') else module
                self.assertIn('--byond-archive', args)
                with patch.object(sys, 'argv', [path, *args]), \
                     patch.object(target, 'selected_runtime', side_effect=ValueError('identity gate')), \
                     patch.object(os, 'geteuid', return_value=1000, create=True), \
                     self.assertRaisesRegex(ValueError, 'identity gate'):
                    module.main()

    def test_all_existing_process_arguments_timeouts_and_control_tables_are_preserved(self):
        for path, before in self.before.items():
            if not path.endswith('.py'): continue
            after = (ROOT/path).read_text()
            def launches(source):
                return [ast.dump(node) for node in ast.walk(ast.parse(source)) if isinstance(node, ast.Call)
                        and isinstance(node.func, ast.Attribute) and isinstance(node.func.value, ast.Name)
                        and node.func.value.id == 'subprocess' and node.func.attr in ('run', 'Popen')]
            with self.subTest(path=path): self.assertEqual(launches(before), launches(after))
            for name in ('CASES', 'CONTROLS', 'BASELINE_DEFECTS', 'MINIMUM_CHECKS'):
                def table(source):
                    return [ast.dump(node) for node in ast.parse(source).body if isinstance(node, ast.Assign)
                            and any(isinstance(target, ast.Name) and target.id == name for target in node.targets)]
                self.assertEqual(table(before), table(after))
        def function(source, name):
            return ast.dump(next(n for n in ast.parse(source).body if isinstance(n, ast.FunctionDef) and n.name == name))
        for path, names in {
            'tests/world_save/run-durable-world.py': ('run_lighting',),
            'tests/world_save/run-cross-level.py': ('owned_process', 'adjudicate', 'prepare'),
            'tests/world_save/partial_save_inspector/inspect-partial-save.py': ('limits', 'selftest', 'stable_copy', 'sanitize_report')
        }.items():
            for name in names: self.assertEqual(function(self.before[path], name), function((ROOT/path).read_text(), name))
        marker = "        result_path = output / 'metadata-result.json'"
        self.assertEqual(self.before['tests/world_save/run-durable-world.py'].split(marker, 1)[1],
                         (HERE/'run-durable-world.py').read_text().split(marker, 1)[1])

    def test_explicit_current_mode_keeps_platform_version_and_held_mode_boundaries(self):
        with patch.object(CURRENT, 'load') as loader:
            self.assertIsNone(CURRENT.select('inert', None)); loader.assert_not_called()
        with patch.object(CURRENT.sys, 'platform', 'win32'), self.assertRaisesRegex(ValueError, 'requires Linux'):
            CURRENT.select('inert', 'inert.zip')
        wrong = deepcopy(IDENTITY); wrong['version'] = '516.1681'
        with patch.object(CURRENT.sys, 'platform', 'linux'), patch.object(CURRENT, 'load', side_effect=[
                NS(verify_linux=Mock(return_value=wrong)), CONTRACT]), self.assertRaisesRegex(ValueError, 'exactly 516.1688'):
            CURRENT.select('inert', 'inert.zip')
        rejected = {'run-durable-world.py': (['--roof-areas'], ['--zone-topology'], ['--persistence-year'], ['--prepare-only']),
                    'run-cross-level.py': (['--compile-only'], ['--run-native', '--case', 'pins'],
                                           ['--run-native', '--case', 'move-direct']),
                    'run-sleep-transfer.py': (['--compile-only'], ['--run-native', '--case', 'entry']),
                    'run-dimension-bootstrap.py': (['--prepare-only'], ['--negative-control', 'memory-admission'])}
        for name, rows in rejected.items():
            for flags in rows:
                module = load(HERE/name); target = module.BASE if name == 'run-sleep-transfer.py' else module
                with self.subTest(name=name, flags=flags), patch.object(sys, 'argv', [name, '--byond-bin', 'inert', '--byond-archive', 'inert.zip', *flags]), \
                     patch.object(target, 'selected_runtime') as selected, patch.object(sys, 'stderr', io.StringIO()), self.assertRaises(SystemExit): module.main()
                selected.assert_not_called()

    def test_current_compiler_and_identity_drift_remain_fail_closed(self):
        runtime = self.runtime()
        good = 'DM compiler version 516.1688\nprobe.dmb - 0 errors, 0 warnings\n'
        runtime.validate_compile(0, good, 'probe.dmb')
        for log in (good.replace('1688', '1681'), good.replace('1688', '16880'), good+good,
                    good.replace('probe.dmb', 'wrong.dmb'), good+'warning: extra', good+'runtime error:'):
            with self.subTest(log=log), self.assertRaises(RuntimeError): runtime.validate_compile(0, log, 'probe.dmb')
        with tempfile.TemporaryDirectory() as directory:
            runtime.before_launch('compile', directory)
            changed = deepcopy(IDENTITY); changed['members']['libbyond.so']['sha256'] = 'c'*64
            runtime.verifier.verify_linux.return_value = changed
            with self.assertRaisesRegex(ValueError, 'identity changed'): runtime.before_launch('daemon', directory)
            self.assertEqual(runtime.checks, ['compile'])
            self.assertIn('error', json.loads((Path(directory)/'runtime-identity.json').read_text()))

    def test_durable_current_admission_matches_pinned_workflow_exhaustively(self):
        module = load(HERE/'run-durable-world.py')
        modes = ('lighting', 'wounds', 'dimension_bootstrap', 'recovery_reconnect', 'lifecycle_shutdown', 'startup_only')
        expected = set()
        for path, args in calls(self.before['.github/workflows/test.yml']):
            if not path.endswith('run-durable-world.py'): continue
            active = tuple(name for name in modes if '--'+name.replace('_', '-') in args)
            profile = args[args.index('--profile')+1] if '--profile' in args else 'gaia'
            control = args[args.index('--negative-control')+1] if '--negative-control' in args else None
            expected.add((active, profile, control))
        self.assertEqual(len(expected), 26)
        controls = next(ast.literal_eval(keyword.value) for node in ast.walk(ast.parse(
            self.before['tests/world_save/run-durable-world.py'])) if isinstance(node, ast.Call)
            and node.args and isinstance(node.args[0], ast.Constant) and node.args[0].value == '--negative-control'
            for keyword in node.keywords if keyword.arg == 'choices')
        defaults = dict(prepare_only=False, zone_topology=False, roof_areas=False, roof_control=None, persistence_year=False)
        accepted = set()
        for enabled, profile, control in product(product((False, True), repeat=len(modes)), ('gaia', 'europe'), (None, *controls)):
            flags = dict(zip(modes, enabled))
            args = NS(**defaults, **flags, profile=profile, negative_control=control)
            signature = (tuple(name for name in modes if flags[name]), profile, control)
            self.assertEqual(module.current_ci_case(args), signature in expected, signature)
            if module.current_ci_case(args): accepted.add(signature)
        self.assertEqual(accepted, expected)
        rejected = [['--'+first.replace('_', '-'), '--'+second.replace('_', '-')] for first, second in combinations(modes, 2)]
        rejected += [['--lighting', '--negative-control', control] for control in controls if not control.startswith('lighting-')]
        rejected += [['--lighting', '--profile', 'europe']]
        for flags in rejected:
            with self.subTest(flags=flags), patch.object(sys, 'argv', ['durable', '--byond-bin', 'inert', '--byond-archive', 'inert.zip', *flags]), \
                 patch.object(module, 'selected_runtime') as selected, patch.object(module.tempfile, 'mkdtemp') as stage, \
                 patch.object(sys, 'stderr', io.StringIO()), self.assertRaises(SystemExit): module.main()
            selected.assert_not_called(); stage.assert_not_called()

    def test_frozen_dimension_projection_changes_only_one_exact_build_assertion(self):
        module = load(HERE/'run-dimension-bootstrap.py')
        source = (HERE/'dimension_bootstrap_probe.dm').read_text()
        projected, receipt = module.current_probe(source)
        self.assertEqual(projected, source.replace('world.byond_build == 1681', 'world.byond_build == 1688', 1))
        self.assertEqual(receipt['original_sha256'], hashlib.sha256(source.encode()).hexdigest())
        for bad in (source+'\n', source.replace('1681', '1688'), source+source):
            with self.assertRaisesRegex(RuntimeError, 'hash or runtime assertion'): module.current_probe(bad)

    def test_cross_and_sleep_selected_cases_preserve_exact_results_and_verify_each_child(self):
        selected = [(path, args) for path, args in calls((ROOT/'.github/workflows/test.yml').read_text())
                    if path.endswith(('run-cross-level.py', 'run-sleep-transfer.py'))]
        for path, args in selected:
            with self.subTest(path=path, args=args), tempfile.TemporaryDirectory() as directory:
                root = Path(directory); binary = self.tools(root); output = root/'packet'; output.mkdir()
                module = load(ROOT/path); base = module.BASE if path.endswith('run-sleep-transfer.py') else module
                runtime = self.runtime(); launched = []
                def popen(command, **kwargs):
                    cwd = Path(kwargs['cwd']); compiler = Path(command[0]).name in ('dm.exe', 'DreamMaker')
                    label = 'compile' if compiler else 'daemon:'+cwd.name
                    self.assertEqual(runtime.checks[-1], label); launched.append(label)
                    if compiler: kwargs['stdout'].write('DM compiler version 516.1688\nprobe.dmb - 0 errors, 0 warnings\n')
                    else:
                        receipt = json.loads((output/'receipt.json').read_text()); result = receipt['expected_results'].get(cwd.name, 'PASS')
                        if isinstance(result, dict): result = result['pattern'].replace('[1-9][0-9]*', '1')
                        (cwd/'native.log').write_text('clean')
                        (cwd/'result.json').write_text(json.dumps(dict(case=cwd.name, done=1, runtime_failed=0, checks=100, port=0, result=result)))
                    return NS(pid=123, wait=lambda timeout: None, poll=lambda: 0)
                args = list(args); args[args.index('--byond-bin')+1] = str(binary)
                with patch.object(sys, 'argv', [path, *args]), patch.object(base, 'selected_runtime', return_value=runtime), \
                     patch.object(module.tempfile, 'mkdtemp', return_value=str(output)), patch.object(subprocess, 'Popen', side_effect=popen), \
                     patch.object(subprocess, 'check_output', side_effect=self.git), \
                     redirect_stdout(io.StringIO()): module.main()
                self.assertEqual(launched, runtime.checks)
                self.assertTrue(json.loads((output/'receipt.json').read_text())['native_verified'])

    def dimension(self, control=None, wrong_build=False):
        module = load(HERE/'run-dimension-bootstrap.py'); runtime = self.runtime(); launched = []
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); binary = self.tools(root); output = root/'packet'; output.mkdir()
            def popen(command, **kwargs):
                cwd = Path(kwargs['cwd']); writer = cwd.name.startswith('write'); compiler = Path(command[0]).name in ('dm.exe', 'DreamMaker')
                label = 'compile' if compiler else cwd.name
                self.assertEqual(runtime.checks[-1], label); launched.append(label)
                if compiler: kwargs['stdout'].write('DM compiler version 516.1688\ndimension_bootstrap.dmb - 0 errors, 0 warnings\n')
                else:
                    allocated = cwd.name in ('positive', 'custody-positive', 'allocation-failure', 'exact-post') or bool(control)
                    count = int(cwd.name[-1]) if writer else 3 if allocated else 2
                    (cwd/'map_saves').mkdir(exist_ok=True); (cwd/'map_saves/seed.sav').write_bytes(b'synthetic')
                    (cwd/'runtime.log').write_text('clean')
                    (cwd/'result.txt').write_text('FAIL: rejected save allocated levels' if control and not writer else 'PASS')
                    (cwd/'receipt.json').write_text(json.dumps(dict(checks=4 if writer else 20, maxz=count,
                        allocations=0 if writer else int(allocated), byond_version=516, byond_build=1681 if wrong_build else 1688)))
                return NS(pid=123, wait=lambda timeout: None, poll=lambda: 0)
            args = ['dimension', '--byond-bin', str(binary), '--byond-archive', 'inert.zip']
            if control: args += ['--negative-control', control]
            with patch.object(sys, 'argv', args), patch.object(module, 'selected_runtime', return_value=runtime), \
                 patch.object(module.tempfile, 'mkdtemp', return_value=str(output)), patch.object(subprocess, 'Popen', side_effect=popen), redirect_stdout(io.StringIO()):
                if wrong_build:
                    with self.assertRaisesRegex(RuntimeError, 'Pinned runtime'): module.main()
                else: module.main()
            self.assertEqual(launched, runtime.checks)
            return json.loads((output/'summary.json').read_text())

    def test_dimension_full_current_matrix_keeps_custody_and_rejects_wrong_observed_runtime(self):
        receipt = self.dimension()
        self.assertTrue({'custody-positive', 'custody-denied', 'custody-binding'} <= receipt['cases'].keys())
        self.assertEqual(len(receipt['processes']), 31)
        self.assertEqual(len(self.dimension('preflight')['processes']), 5)
        self.dimension(wrong_build=True)

    def test_all_selected_durable_variants_compile_strictly_and_recheck_before_first_daemon(self):
        class ReachedDaemon(Exception): pass
        selected = [(path, args) for path, args in calls((ROOT/'.github/workflows/test.yml').read_text())
                    if path.endswith('run-durable-world.py')]
        self.assertEqual(len(selected), 26)
        for path, args in selected:
            with self.subTest(args=args), tempfile.TemporaryDirectory() as directory:
                output = Path(directory); module = load(ROOT/path); runtime = self.runtime()
                def run(command, **kwargs):
                    if Path(command[0]).name in ('DreamMaker', 'dm.exe'):
                        self.assertEqual(runtime.checks, ['compile'])
                        self.assertEqual(kwargs['timeout'], 180)
                        dme = ROOT/command[-1]
                        for suffix in ('.dmb', '.rsc'): dme.with_suffix(suffix).write_bytes(b'inert')
                        return NS(returncode=0, stdout='DM compiler version 516.1688\n'+dme.with_suffix('.dmb').name+' - 0 errors, 0 warnings\n', stderr='')
                    self.assertEqual(runtime.checks[-1], 'daemon:write' if '--dimension-bootstrap' in args else 'daemon')
                    raise ReachedDaemon()
                def collector(*unused):
                    self.assertEqual(runtime.checks, ['compile', 'daemon']); raise ReachedDaemon()
                with patch.object(sys, 'argv', [path, *args]), patch.object(module, 'selected_runtime', return_value=runtime), \
                     patch.object(module.tempfile, 'mkdtemp', return_value=str(output)), patch.object(subprocess, 'check_output', side_effect=self.git), \
                     patch.object(subprocess, 'run', side_effect=run), patch.object(module, 'run_lighting', side_effect=collector), \
                     redirect_stdout(io.StringIO()), self.assertRaises(ReachedDaemon): module.main()
                self.assertEqual(len(runtime.checks), 2)
                self.assertFalse(list(ROOT.glob('.durable_world_*')))

    def reader(self, control=None, current=True, wrong_build=False, drift=False):
        module = load(HERE/'run-reader-contract.py'); runtime = self.runtime(); launched = []
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); binary = self.tools(root); output = root/'packet'; output.mkdir()
            version = '516.1688' if current else '516.1681'
            def compile(command, **kwargs):
                self.assertEqual(kwargs['timeout'], 60)
                if current: self.assertEqual(runtime.checks, ['compile'])
                launched.append('compile')
                if drift: runtime.verifier.verify_linux.side_effect = ValueError('member changed')
                return NS(returncode=0, stdout='DM compiler version '+version+'\nprobe.dmb - 0 errors, 0 warnings\n', stderr='')
            def popen(command, **kwargs):
                role = command[-1].split('=')[1]
                if current: self.assertEqual(runtime.checks[-1], 'daemon:'+role)
                launched.append(role)
                if role == 'owner': (output/'owner_locked.txt').write_text('locked')
                result = ('UNSUPPORTED: WRONG_OPERATION_REJECTED' if control == 'binding' and role == 'owner'
                          else 'UNSUPPORTED: PEER_LOCK_AFTER_OWNER_CLOSE' if control == 'close' and role == 'peer' else 'PASS')
                (output/(role+'.result')).write_text(result)
                (output/(role+'.json')).write_text(json.dumps(dict(result=result, byond_version=516,
                    byond_build=1681 if wrong_build else int(version.split('.')[1]))))
                return NS(pid=123, returncode=0, poll=lambda: 0)
            args = ['reader', '--byond-bin', str(binary)]
            if current: args += ['--byond-archive', 'inert.zip']
            if control: args += ['--negative-control', control]
            with patch.object(sys, 'argv', args), patch.object(module, 'selected_runtime', return_value=runtime if current else None), \
                 patch.object(module.tempfile, 'mkdtemp', return_value=str(output)), patch.object(subprocess, 'run', side_effect=compile), \
                 patch.object(subprocess, 'Popen', side_effect=popen), redirect_stdout(io.StringIO()):
                if wrong_build or drift:
                    with self.assertRaisesRegex((RuntimeError, ValueError), 'Runtime receipt|member changed'): module.main()
                else: module.main()
            if drift: self.assertEqual(launched, ['compile'])
            else: self.assertEqual(launched, ['compile', 'owner', 'peer'])

    def test_reader_positive_and_controls_keep_receipts_historical_mode_and_drift_rejection(self):
        for current in (False, True):
            for control in (None, 'binding', 'close'):
                with self.subTest(current=current, control=control): self.reader(control, current)
        self.reader(wrong_build=True)
        self.reader(drift=True)

    def test_inspector_identity_keeps_privacy_limits_and_rejects_private_source_current_mode(self):
        module = load(HERE/'partial_save_inspector/inspect-partial-save.py'); runtime = self.runtime()
        with tempfile.TemporaryDirectory() as directory:
            stage = Path(directory)
            def run(command, **kwargs):
                self.assertEqual(runtime.checks[-1], 'writer-compile')
                self.assertEqual(kwargs['timeout'], 60)
                self.assertIs(kwargs['preexec_fn'], module.limits)
                self.assertEqual(kwargs['stdin'], subprocess.DEVNULL)
                kwargs['stdout'].write(b'DM compiler version 516.1688\nwriter.dmb - 0 errors, 0 warnings\n')
                (stage/'writer.dmb').write_bytes(b'inert')
                return NS(returncode=0)
            with patch.object(module, 'CURRENT_RUNTIME', runtime), patch.object(subprocess, 'run', side_effect=run):
                module.compile_world(stage, 'writer', 'synthetic')
            self.assertEqual(runtime.checks, ['writer-compile'])
        with patch.object(sys, 'argv', ['inspector', '--byond-archive', 'inert.zip', '--byond-bin', 'inert',
                                        '--source', 'C:/private/map_saves/2.sav']), \
             patch.object(module, 'selected_runtime') as selected, self.assertRaisesRegex(RuntimeError, 'synthetic self-test only'):
            module.main()
        selected.assert_not_called()


if __name__ == '__main__': unittest.main()
