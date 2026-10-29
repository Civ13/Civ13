"""Mocked current-runtime admission/pipeline controls; never launch BYOND."""
import ast
import base64
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
from types import ModuleType, SimpleNamespace
import unittest
from unittest.mock import Mock, patch
from historical_fixtures import text as historical_text

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, HERE / filename)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


current = load('current_exclusion_ci_test', 'run-ci-current.py')
# Only the mocked pipeline needs pure historical validators on Windows. The
# native Linux cleanup tests retain their genuine resource/process dependency.
with patch.dict(sys.modules, {'resource': ModuleType('resource')}):
    historical = load('historical_exclusion_ci_test', 'run-ci.py')

BUILD = 'DM compiler version 516.1688\nprobe.dmb - 0 errors, 0 warnings (1/1/26 12:00 am)\n'
BIND = 'World opened on network port 12345 for address 127.0.0.1.\n'


class CurrentCITests(unittest.TestCase):
    def harness(self, directory, *, runtime_identity=None, daemon_version='516.1688',
                survive=None, bad_network=False, target_counts=None):
        root = Path(directory)
        args = SimpleNamespace(base='a' * 40, head='b' * 40, byond_bin=root / 'byond/bin',
                               byond_archive=root / 'pinned.zip', output=root / 'evidence')
        selected = dict(version='516.1688', archive={'sha256': 'c' * 64}, members={'stub': 'mock only'})
        runtime = SimpleNamespace(verify_linux=Mock(return_value=runtime_identity or selected))

        def run(command, work, role, deadline, *, environment):
            if role.endswith('-prepare'):
                self.assertIn('--source-only', command)
                self.assertEqual(command[command.index('--base') + 1], args.base)
                self.assertEqual(command[command.index('--head') + 1], args.head)
                packet = Path(command[command.index('--output') + 1])
                packet.write_text('{"native_execution":false}')
                packet.with_suffix('.sources').mkdir()
                return ''
            if role == 'compile':
                self.assertEqual(command[1:], ['-max_errors', '0', 'probe.dme'])
                return BUILD
            self.assertEqual(role, 'daemon')
            self.assertEqual(command[1:], ['probe.dmb', '-ip', '127.0.0.1', '-invisible', '-close',
                                           '-trusted', '-log', 'runtime.log'])
            mode = work.name.split('.')[0]
            result = dict(cases=1000, failures=0 if mode in ('parity', survive) else 1, samples=[],
                          byond_version=516, byond_build=1688,
                          target_failures=(target_counts or {}).get(mode, 2 if mode == 'parent' else 0),
                          network=dict(closed_port=1 if bad_network else 0, reopen_result=0, after_reopen_port=0))
            (work / 'result.json').write_text(json.dumps(result))
            (work / 'runtime.log').write_text('BYOND version ' + daemon_version + '\n' + BIND)
            return ''

        ci = SimpleNamespace(identities=Mock(return_value=dict(base=args.base, head=args.head)),
                             MODES=historical.MODES, DIAGNOSTIC=historical.DIAGNOSTIC,
                             validate_result=historical.validate_result, run=Mock(side_effect=run))
        source = dict(head=args.head, tree='d' * 40, tracked_dirty=False)
        return args, ci, runtime, selected, source

    def execute(self, args, ci, runtime, source):
        with patch.object(current.sys, 'platform', 'linux'), \
             patch.object(current, 'source_identity', return_value=source), \
             patch.dict(os.environ, {'LD_PRELOAD': '', 'LD_AUDIT': ''}):
            current.execute(args, ci=ci, runtime=runtime)

    def test_all_four_modes_keep_exact_identity_loader_limits_and_controls(self):
        with tempfile.TemporaryDirectory() as directory:
            args, ci, runtime, selected, source = self.harness(directory)
            self.execute(args, ci, runtime, source)
            receipt = json.loads((args.output / 'native-ci.json').read_text())
            self.assertEqual(receipt['status'], 'passed')
            self.assertEqual(tuple(receipt['modes']), historical.MODES)
            self.assertEqual(receipt['modes']['parent']['target_failures'], 2)
            self.assertEqual(receipt['runtime_identity'], selected)
            self.assertEqual(len(receipt['runtime_checks']), 13)
            self.assertEqual(runtime.verify_linux.call_count, 13)
            self.assertEqual(ci.run.call_count, 12)
            self.assertEqual(len({call.args[3] for call in ci.run.call_args_list}), 1)
            for call in ci.run.call_args_list:
                self.assertEqual(call.kwargs['environment']['LD_LIBRARY_PATH'], str(args.byond_bin))
                self.assertEqual(call.kwargs['environment']['BYOND_SYSTEM'], str(args.byond_bin.parent))

    def test_observed_version_and_target_guard_remain_strict(self):
        good=dict(byond_version=516, byond_build=1688, target_failures=0)
        current.validate_observed_result(good)
        for field,value in (('byond_version',516.0), ('byond_version',515), ('byond_build',1681),
                            ('byond_build',16880), ('byond_build',1688.0),
                            ('target_failures',1), ('target_failures',True), ('target_failures',None)):
            with self.subTest(field=field,value=value), self.assertRaises(RuntimeError):
                current.validate_observed_result(dict(good, **{field:value}))

    def test_target_counts_are_exact_and_mode_specific(self):
        for mode in historical.MODES:
            expected = 2 if mode == 'parent' else 0
            good = dict(byond_version=516, byond_build=1688, target_failures=expected)
            current.validate_observed_result(good, mode)
            for value in (-1, 0, 1, 2, 3, 5, True, None, float(expected)):
                if type(value) is int and value == expected:
                    continue
                with self.subTest(mode=mode, value=value), self.assertRaises(RuntimeError):
                    current.validate_observed_result(dict(good, target_failures=value), mode)
        for mode in ('', None, 'unknown', 'target-omit'):
            with self.subTest(mode=mode), self.assertRaises(RuntimeError):
                current.validate_observed_result(dict(byond_version=516, byond_build=1688, target_failures=0), mode)

    def test_parent_target_drift_stops_pipeline_before_eager(self):
        for count in (0, 1, 3):
            with self.subTest(count=count), tempfile.TemporaryDirectory() as directory:
                args, ci, runtime, _, source = self.harness(directory, target_counts={'parent': count})
                with self.assertRaisesRegex(RuntimeError, 'Original-target'):
                    self.execute(args, ci, runtime, source)
                receipt = json.loads((args.output / 'native-ci.json').read_text())
                self.assertEqual(receipt['status'], 'failed')
                self.assertEqual(tuple(receipt['modes']), ('parity', 'omit'))
                self.assertFalse((args.output / 'eager.json').exists())

    def test_historical_pin_limits_and_result_guards_are_preserved(self):
        encoded = (HERE / 'historical/lighting-historical-run-ci.py.b64.txt').read_text(encoding='ascii')
        data = base64.b64decode(''.join(encoded.split()), validate=True)
        self.assertEqual(hashlib.sha256(data).hexdigest(),
                         '2f60ed53221e560a3711b05b625fa22c40ce3cebdd96a616dc4bf628a330b412')
        prior = data.decode('utf-8')
        prior = historical_text('3b0be7a483bada0649d954d09045968999e538e0', 'tests/exclusion_dispatch/run-ci.py')
        self.assertEqual(prior, data.decode('utf-8'))
        def bodies(text):
            return {node.name: ast.dump(node, include_attributes=False) for node in ast.parse(text).body
                    if isinstance(node, ast.FunctionDef)}
        old, new = bodies(prior), bodies((HERE / 'run-ci.py').read_text())
        for name in ('limits', 'validate_result', 'main'):
            self.assertEqual(old[name], new[name], name)
        self.assertEqual(prior.replace(
            'def run(command, work, role, deadline):',
            'def run(command, work, role, deadline, *, environment=None):').replace(
            'environment = dict(os.environ, GIT_CONFIG_COUNT=',
            'environment = dict(os.environ if environment is None else environment, GIT_CONFIG_COUNT='),
            (HERE / 'run-ci.py').read_text())
        self.assertEqual(current.VERSION, '516.1688')
        self.assertEqual(historical.MODES, ('parity', 'omit', 'parent', 'eager'))

    def test_wrong_compiler_banners_warnings_and_diagnostics_fail(self):
        current.validate_build(BUILD, historical.DIAGNOSTIC)
        for log in (BUILD.replace('1688', '1681'), BUILD.replace('1688', '16880'),
                    'DM compiler version 516.1681\n' + BUILD,
                    BUILD.replace('0 warnings', '1 warning'), BUILD + 'runtime error: bad loc\n',
                    BUILD + 'cannot open file\n', BUILD + BUILD.splitlines()[1] + '\n',
                    BUILD + 'warning: additional diagnostics\n',
                    '\n'.join(reversed(BUILD.splitlines())) + '\n', BUILD + 'x' * 1048576,
                    *(BUILD + word + '\n' for word in ('unexpected runtime', 'OOM', 'out of memory',
                                                        'access violation', 'CRASHED', 'invalid file'))):
            with self.subTest(log=log), self.assertRaises(RuntimeError):
                current.validate_build(log, historical.DIAGNOSTIC)

    def test_wrong_archive_version_refuses_every_child(self):
        with tempfile.TemporaryDirectory() as directory:
            args, ci, runtime, _, source = self.harness(directory, runtime_identity={'version': '516.1681'})
            with self.assertRaisesRegex(ValueError, '516.1688'):
                self.execute(args, ci, runtime, source)
            ci.run.assert_not_called()
            self.assertFalse(args.output.exists())

    def test_runtime_identity_drift_stops_before_next_launch_and_keeps_failure(self):
        for changed_at in (2, 3, 4):
            with self.subTest(changed_at=changed_at), tempfile.TemporaryDirectory() as directory:
                args, ci, runtime, selected, source = self.harness(directory)
                runtime.verify_linux.side_effect = [selected] * (changed_at - 1) + [{'version': 'changed'}]
                with self.assertRaisesRegex(RuntimeError, 'Runtime identity changed'):
                    self.execute(args, ci, runtime, source)
                self.assertEqual(ci.run.call_count, changed_at - 1)
                receipt = json.loads((args.output / 'native-ci.json').read_text())
                self.assertEqual(receipt['status'], 'failed')
                self.assertTrue((args.output / 'parity.json').exists())

    def test_wrong_daemon_version_and_surviving_mutation_fail(self):
        for kwargs in ({'daemon_version': '516.1681'}, {'daemon_version': '516.16880'},
                       {'survive': 'omit'}, {'survive': 'parent'}, {'survive': 'eager'}, {'bad_network': True}):
            with self.subTest(kwargs=kwargs), tempfile.TemporaryDirectory() as directory:
                args, ci, runtime, _, source = self.harness(directory, **kwargs)
                with self.assertRaises(RuntimeError):
                    self.execute(args, ci, runtime, source)
                self.assertEqual(json.loads((args.output / 'native-ci.json').read_text())['status'], 'failed')

    def test_source_drift_and_existing_evidence_fail_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            args, ci, runtime, _, source = self.harness(directory)
            with self.assertRaisesRegex(ValueError, 'unchanged checked-out head'):
                self.execute(args, ci, runtime, dict(source, tracked_dirty=True))
            ci.run.assert_not_called()
            args.output.mkdir()
            sentinel = args.output / 'prior.txt'
            sentinel.write_text('preserve')
            with self.assertRaisesRegex(ValueError, 'Preserve prior exclusion evidence'):
                self.execute(args, ci, runtime, source)
            self.assertEqual(sentinel.read_text(), 'preserve')

    def test_loader_injection_and_non_linux_fail_before_children(self):
        with tempfile.TemporaryDirectory() as directory:
            args, ci, runtime, _, source = self.harness(directory)
            for key in ('LD_PRELOAD', 'LD_AUDIT'):
                with patch.object(current.sys, 'platform', 'linux'), \
                     patch.object(current, 'source_identity', return_value=source), \
                     patch.dict(os.environ, {key: 'injected'}), self.assertRaisesRegex(ValueError, 'Loader injection'):
                    current.execute(args, ci=ci, runtime=runtime)
            with patch.object(current.sys, 'platform', 'win32'), self.assertRaisesRegex(ValueError, 'Linux only'):
                current.execute(args, ci=ci, runtime=runtime)
            ci.run.assert_not_called()


if __name__ == '__main__':
    unittest.main()
