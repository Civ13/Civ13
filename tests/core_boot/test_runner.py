"""Offline runner controls. No compiler, DreamDaemon, game, port or network."""
import ast
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest import mock

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('core_boot_runner', HERE / 'run.py')
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class FakeDaemon:
    def __init__(self, result, returncode=0, timed_out=False, diagnostic=''):
        self.result = result
        self.exit_code = returncode
        self.timed_out = timed_out
        self.diagnostic = diagnostic
        self.returncode = None
        self.killed = False

    def start(self, command, *, cwd, stdout, stderr, creationflags):
        if self.result is not None:
            (cwd / 'result.txt').write_text(self.result, encoding='utf-8')
        stdout.write(self.diagnostic)
        stdout.flush()
        return self

    def wait(self, timeout):
        if self.timed_out and not self.killed:
            raise subprocess.TimeoutExpired('offline fake daemon', timeout)
        self.returncode = self.exit_code

    def kill(self):
        self.killed = True


class RunnerTests(unittest.TestCase):
    phases = [('save', 'PASS: save'), ('load', 'PASS: load')]

    def run_fakes(self, work, fakes):
        iterator = iter(fakes)
        with mock.patch.object(runner.subprocess, 'Popen',
                               side_effect=lambda *a, **kw: next(iterator).start(*a, **kw)) as launch:
            rows = runner.run_phases(['offline-fake'], work, self.phases)
        return rows, launch.call_count

    def test_restart_requires_both_clean_phases_and_preserves_results(self):
        with tempfile.TemporaryDirectory() as temporary:
            work = Path(temporary)
            rows, launches = self.run_fakes(work, [FakeDaemon('PASS: save'), FakeDaemon('PASS: load')])
            runner.verify_results(rows, self.phases)
            self.assertEqual(launches, 2)
            self.assertEqual((work / 'save-result.txt').read_text(), 'PASS: save')
            self.assertEqual((work / 'load-result.txt').read_text(), 'PASS: load')

    def test_pass_with_nonzero_exit_stops_before_load(self):
        with tempfile.TemporaryDirectory() as temporary:
            rows, launches = self.run_fakes(Path(temporary), [FakeDaemon('PASS: save', returncode=7)])
        self.assertEqual(launches, 1)
        self.assertEqual(rows[0]['returncode'], 7)
        with self.assertRaisesRegex(RuntimeError, 'did not exit cleanly'):
            runner.verify_results(rows, self.phases)

    def test_pass_then_timeout_is_rejected_even_after_fake_clean_wait(self):
        daemon = FakeDaemon('PASS: save', timed_out=True)
        with tempfile.TemporaryDirectory() as temporary:
            rows, launches = self.run_fakes(Path(temporary), [daemon])
        self.assertTrue(daemon.killed)
        self.assertTrue(rows[0]['timed_out'])
        self.assertEqual(rows[0]['returncode'], 0)
        self.assertEqual(launches, 1)
        with self.assertRaisesRegex(RuntimeError, 'did not exit cleanly'):
            runner.verify_results(rows, self.phases)

    def test_missing_load_receipt_cannot_reuse_save_pass(self):
        with tempfile.TemporaryDirectory() as temporary:
            work = Path(temporary)
            rows, _ = self.run_fakes(work, [FakeDaemon('PASS: save'), FakeDaemon(None)])
            self.assertFalse((work / 'result.txt').exists())
            self.assertFalse((work / 'load-result.txt').exists())
        with self.assertRaisesRegex(RuntimeError, 'assertions incomplete'):
            runner.verify_results(rows, self.phases)

    def control_case(self):
        site = {'file': '.core_boot_offline_control.dm', 'line': 117}
        receipt = dict(site, message=runner.RUNTIME_CONTROL_MESSAGE, phase='chemistry')
        row = {'phase': 'boot', 'returncode': 0, 'timed_out': False,
               'wall_seconds': 1, 'deadline_seconds': 1500,
               'result': runner.CONTROLS['runtime'][3],
               'diagnostics': ['boot-startup.log: CORE BOOT runtime control: ' +
                               runner.RUNTIME_CONTROL_MESSAGE + ' at ' + site['file'] + ':117']}
        return row, site, receipt

    def test_exact_runtime_control_receipt_is_accepted(self):
        row, site, receipt = self.control_case()
        runner.verify_results([row], [('boot', runner.EXPECTED)], 'runtime', site, receipt)

    def test_unrelated_diagnostic_alone_cannot_discharge_runtime_control(self):
        row, site, receipt = self.control_case()
        row['diagnostics'] = ['boot-startup.log: runtime error: unrelated startup failure']
        with self.assertRaisesRegex(RuntimeError, 'outside its intended exception'):
            runner.verify_results([row], [('boot', runner.EXPECTED)], 'runtime', site, receipt)

    def test_unrelated_diagnostic_alongside_expected_control_is_rejected(self):
        row, site, receipt = self.control_case()
        row['diagnostics'].append('errors.txt: Bad ref during startup')
        with self.assertRaisesRegex(RuntimeError, 'outside its intended exception'):
            runner.verify_results([row], [('boot', runner.EXPECTED)], 'runtime', site, receipt)

    def test_wrong_phase_source_line_message_or_missing_receipt_is_rejected(self):
        row, site, receipt = self.control_case()
        for bad in [dict(receipt, phase='startup'), dict(receipt, file='unrelated.dm'),
                    dict(receipt, line=118), dict(receipt, message='unrelated'), None]:
            with self.subTest(receipt=bad), self.assertRaises(RuntimeError):
                runner.verify_results([row], [('boot', runner.EXPECTED)], 'runtime', site, bad)

    def test_expected_control_never_overrides_abnormal_exit_or_timeout(self):
        row, site, receipt = self.control_case()
        for bad in [dict(row, returncode=3), dict(row, timed_out=True)]:
            with self.subTest(row=bad), self.assertRaisesRegex(RuntimeError, 'did not exit cleanly'):
                runner.verify_results([bad], [('boot', runner.EXPECTED)], 'runtime', site, receipt)

    def test_elapsed_deadline_is_rejected_even_without_timeout_exception(self):
        row, _, _ = self.control_case()
        row.update(result=runner.EXPECTED, diagnostics=[], wall_seconds=1500)
        with self.assertRaisesRegex(RuntimeError, 'did not exit cleanly'):
            runner.verify_results([row], [('boot', runner.EXPECTED)])

    def test_diagnostic_from_another_source_is_not_the_expected_control(self):
        row, site, receipt = self.control_case()
        row['diagnostics'][0] = row['diagnostics'][0].replace(site['file'], 'unrelated.dm')
        with self.assertRaisesRegex(RuntimeError, 'outside its intended exception'):
            runner.verify_results([row], [('boot', runner.EXPECTED)], 'runtime', site, receipt)

    def test_fatal_diagnostic_stops_even_a_successful_phase(self):
        with tempfile.TemporaryDirectory() as temporary:
            rows, launches = self.run_fakes(Path(temporary), [FakeDaemon('PASS: save', diagnostic='fatal error: unrelated\n')])
        self.assertEqual(launches, 1)
        self.assertTrue(rows[0]['diagnostics'])
        with self.assertRaises(RuntimeError):
            runner.verify_results(rows, self.phases)

    def test_restored_lighting_control_rejects_additional_diagnostics(self):
        row, _, _ = self.control_case()
        row['result'] = runner.CONTROLS['restored-lighting'][3] + ' (3 hidden)'
        row['diagnostics'] = []
        runner.verify_results([row], [('boot', runner.EXPECTED)], 'restored-lighting')
        row['diagnostics'] = ['errors.txt: runtime error: unrelated']
        with self.assertRaisesRegex(RuntimeError, 'outside its intended assertion'):
            runner.verify_results([row], [('boot', runner.EXPECTED)], 'restored-lighting')

    def test_generated_site_is_the_actual_unique_control_throw_line(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            path, old, _, _ = runner.CONTROLS['runtime']
            source = root / path
            source.parent.mkdir(parents=True)
            source.write_text('// unchanged prefix\n' + old + '\treturn FALSE\n', encoding='utf-8')
            include = '#include "' + path.replace('/', '\\') + '"\n'
            (root / 'civ13.dme').write_text(include, encoding='utf-8')
            with mock.patch.object(runner, 'ROOT', root):
                created = []
                _, site = runner.generate('runtime', created)
            generated = root / site['file']
            text = generated.read_text(encoding='utf-8')
            self.assertIn('throw EXCEPTION("' + runner.RUNTIME_CONTROL_MESSAGE + '")',
                          text.splitlines()[site['line'] - 1])
            self.assertIn('my_atom == core_boot_probe.beaker', text)
            self.assertIn('core_boot_probe.current_phase == "chemistry"', text)


class CompileOnlyTests(unittest.TestCase):
    def runtime(self):
        module = runner.load_current_runtime()
        runtime = object.__new__(module.CurrentRuntime)
        runtime.identity = {'version': json.loads((HERE.parents[1] / 'tools/byond/version.json').read_text())['version']}
        runtime.compiler = module.load('core_boot_compile_contract', HERE.parents[1] / 'tests/new_z_budget/z_budget_evidence.py')
        runtime.bin_dir, runtime.archive = Path('inert-bin'), Path('inert.zip')
        runtime.verifier = SimpleNamespace(verify_linux=mock.Mock(return_value=dict(runtime.identity)))
        runtime.checks = []
        runtime.before_launch = mock.Mock(wraps=runtime.before_launch)
        return runtime

    def invoke(self, root, options=(), build=None, runtime=None, select_error=None, missing_identity=False):
        runtime = runtime or self.runtime()
        probe = root / 'tests/core_boot/probe.dm'
        probe.parent.mkdir(parents=True)
        for name in ('probe.dm', 'run.py', 'lighting_load.dm'):
            (probe.parent / name).write_text('// offline fixture', encoding='utf-8')
        for name in ('tests/world_save/current_runtime.py', 'scripts/byond_runtime.py',
                     'scripts/byond_toolchain.py', 'tools/byond/version.json',
                     'tests/new_z_budget/z_budget_evidence.py'):
            item = root / name
            item.parent.mkdir(parents=True, exist_ok=True)
            item.write_text('offline hashed input', encoding='utf-8')
        path, old, _, _ = runner.CONTROLS['runtime']
        production = root / path
        production.parent.mkdir(parents=True)
        production.write_text(old + '\treturn FALSE\n', encoding='utf-8')
        (root / 'civ13.dme').write_text('#include "' + path.replace('/', '\\') + '"\n', encoding='utf-8')
        output, calls = root / 'evidence', []
        def compiler(command, **kwargs):
            calls.append(command)
            runtime.before_launch.assert_called_once_with('compiler', output)
            source = Path(command[-1])
            self.assertEqual(command[:3], [str(root / 'DreamMaker'), '-max_errors', '0'])
            self.assertEqual(kwargs['timeout'], 600)
            self.assertTrue(source.is_file())
            manifest = json.loads((output / 'compile-inputs.json').read_text())
            self.assertEqual(manifest['source_sha256'], hashlib.sha256(source.read_bytes()).hexdigest())
            for name, digest in manifest['inputs_sha256'].items():
                self.assertEqual(digest, hashlib.sha256((root / name).read_bytes()).hexdigest())
            for name, digest in manifest['generated_controls_sha256'].items():
                self.assertEqual(digest, hashlib.sha256((root / name).read_bytes()).hexdigest())
            if isinstance(build, BaseException): raise build
            log = 'DM compiler version ' + runtime.identity['version'] + '\n' + source.with_suffix('.dmb').name + ' - 0 errors, 0 warnings\n'
            result = subprocess.CompletedProcess(command, 0, log, '')
            return build(result) if callable(build) else result
        def git(*args):
            if args == ('rev-parse', 'HEAD'): return 'a' * 40
            if args == ('rev-parse', 'HEAD^{tree}'): return 'b' * 40
            if args == ('diff', 'HEAD'): return ''
            self.fail('Compile-only entered runtime config enumeration: ' + repr(args))
        selector = mock.Mock(return_value=None if missing_identity else runtime, side_effect=select_error)
        argv = ['run.py', '--byond-bin', str(root), '--byond-archive', str(root / 'inert.zip'),
                '--output', str(output), '--compile-only', *options]
        with mock.patch.object(runner, 'ROOT', root), mock.patch.object(runner, 'git', side_effect=git), \
                mock.patch.object(runner, 'load_current_runtime', return_value=SimpleNamespace(select=selector)), \
                mock.patch.object(runner.subprocess, 'run', side_effect=compiler), \
                mock.patch.object(runner.subprocess, 'Popen', side_effect=AssertionError('Daemon forbidden')), \
                mock.patch.object(runner, 'run_phases', side_effect=AssertionError('Runtime phases forbidden')), \
                mock.patch.object(runner, 'verify_results', side_effect=AssertionError('Runtime assertions forbidden')), \
                mock.patch.object(runner.shutil, 'copy2', side_effect=AssertionError('Runtime staging forbidden')), \
                mock.patch.object(sys, 'argv', argv), \
                mock.patch.dict(runner.os.environ, {'CORE_BOOT_CI_HEAD_SHA': 'c' * 40}):
            runner.main()
        selector.assert_called_once_with(root.absolute(), root / 'inert.zip')
        return output, calls, runtime

    def test_three_canonical_variants_compile_without_runtime(self):
        for options in ((), ('--negative-control', 'runtime'), ('--lighting-load',)):
            with self.subTest(options=options), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                output, calls, runtime = self.invoke(root, options)
                metadata = json.loads((output / 'metadata.json').read_text())
                summary = json.loads((output / 'compile-summary.json').read_text())
                receipt = json.loads((output / 'runtime-identity.json').read_text())
                self.assertEqual(len(calls), 1)
                self.assertEqual(metadata['toolchain_mode'], 'canonical-linux-archive')
                self.assertEqual(metadata['expected_byond'], runtime.identity['version'])
                self.assertEqual(metadata['checkout_commit_sha'], 'a' * 40)
                self.assertEqual(metadata['checkout_tree_sha'], 'b' * 40)
                self.assertEqual(metadata['ci_event_head_sha'], 'c' * 40)
                self.assertEqual(metadata['canonical_manifest_sha256'], hashlib.sha256((root / 'tools/byond/version.json').read_bytes()).hexdigest())
                self.assertEqual(receipt['verified_before'], ['compiler'])
                self.assertFalse(summary['runtime_executed'])
                self.assertEqual(bool(summary['runtime_control_site']), 'runtime' in options)
                self.assertFalse((output / 'runtime').exists())
                self.assertFalse(list(root.glob('.core_boot_*')))

    def test_wrong_version_summary_diagnostics_or_exit_reject_without_fallback(self):
        for defect in ('old-version', 'duplicate-banner', 'missing-summary', 'warnings',
                       'errors', 'wrong-artifact', 'diagnostic', 'nonzero-exit', 'reversed-order'):
            def mutate(result):
                lines = result.stdout.splitlines()
                if defect == 'old-version': lines[0] = 'DM compiler version 516.1681'
                if defect == 'duplicate-banner': lines.insert(0, lines[0])
                if defect == 'missing-summary': lines.pop()
                if defect == 'warnings': lines[1] = lines[1].replace('0 warnings', '1 warning')
                if defect == 'errors': lines[1] = lines[1].replace('0 errors', '10 errors')
                if defect == 'wrong-artifact': lines[1] = 'unrelated.dmb - 0 errors, 0 warnings'
                if defect == 'diagnostic': lines.append('fatal error')
                if defect == 'nonzero-exit': result.returncode = 7
                if defect == 'reversed-order': lines.reverse()
                result.stdout = '\n'.join(lines) + '\n'
                return result
            with self.subTest(defect=defect), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                with self.assertRaises(RuntimeError): self.invoke(root, build=mutate)
                self.assertTrue((root / 'evidence/compile.log').is_file())
                self.assertFalse((root / 'evidence/compile-summary.json').exists())
                self.assertFalse(list(root.glob('.core_boot_*')))

    def test_compile_timeout_retains_identity_and_failed_input_evidence(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            with self.assertRaises(subprocess.TimeoutExpired):
                self.invoke(root, ('--negative-control', 'runtime'),
                    build=subprocess.TimeoutExpired('offline compiler', 600, output=b'partial current compile'))
            self.assertEqual((root / 'evidence/compile.log').read_text(), 'partial current compile')
            self.assertTrue((root / 'evidence/runtime-identity.json').exists())
            self.assertTrue(json.loads((root / 'evidence/compile-status.json').read_text())['timed_out'])
            manifest = json.loads((root / 'evidence/compile-inputs.json').read_text())
            self.assertIsNotNone(manifest['runtime_control_site'])
            self.assertEqual(len(manifest['generated_controls_sha256']), 1)
            self.assertFalse(list(root.glob('.core_boot_*')))

    def test_bad_archive_or_platform_stops_before_generation(self):
        for reason in ('Archive hash mismatch', 'Current fixture archive identity requires Linux'):
            with self.subTest(reason=reason), tempfile.TemporaryDirectory() as temporary, \
                    mock.patch.object(runner, 'generate', side_effect=AssertionError('Generation forbidden')):
                root = Path(temporary)
                with self.assertRaisesRegex(ValueError, reason): self.invoke(root, select_error=ValueError(reason))
                self.assertTrue((root / 'evidence/metadata.json').exists())
                self.assertFalse((root / 'evidence/compile.log').exists())

    def test_missing_identity_is_not_accepted(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            with self.assertRaisesRegex(ValueError, 'no fallback'):
                self.invoke(root, missing_identity=True)
            self.assertFalse(list(root.glob('.core_boot_*')))

    def test_changed_identity_stops_before_compiler_and_preserves_error(self):
        runtime = self.runtime()
        runtime.verifier.verify_linux.return_value = {'version': '516.1681'}
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            with self.assertRaisesRegex(ValueError, 'identity changed'):
                self.invoke(root, runtime=runtime, build=AssertionError('Compiler forbidden'))
            receipt = json.loads((root / 'evidence/runtime-identity.json').read_text())
            self.assertIn('identity changed', receipt['error'])
            self.assertTrue((root / 'evidence/compile-inputs.json').exists())
            self.assertFalse((root / 'evidence/compile.log').exists())
            self.assertFalse(list(root.glob('.core_boot_*')))

    def test_archive_and_compile_only_required_and_old_option_removed(self):
        for options in ((), ('--compile-only',), ('--byond-archive', 'inert.zip'),
                        ('--byond-archive', 'inert.zip', '--compile-only', '--legacy-fixture-5161681')):
            with self.subTest(options=options), tempfile.TemporaryDirectory() as temporary, \
                    mock.patch.object(runner, 'generate', side_effect=AssertionError('Generation forbidden')):
                output = Path(temporary) / 'absent'
                argv = ['run.py', '--byond-bin', temporary, '--output', str(output), *options]
                with mock.patch.object(sys, 'argv', argv), self.assertRaises(SystemExit): runner.main()
                self.assertFalse(output.exists())

    def test_workflow_compile_commands_preserve_existing_admission(self):
        workflow = (HERE.parents[1] / '.github/workflows/test.yml').read_text()
        step = workflow.split('      - name: Check core-boot runner offline and compile generated variants\n', 1)[1].split('\n      - name:', 1)[0]
        self.assertIn("if: needs.changes.outputs.extensive == 'true' || contains(fromJSON(needs.changes.outputs.new_tests || '[]'), 'tests/core_boot')", step)
        self.assertIn('timeout-minutes: 32', step)
        commands = [line.strip() for line in step.splitlines() if 'tests/core_boot/run.py ' in line]
        self.assertEqual(len(commands), 3)
        self.assertTrue(all('--compile-only' in line and '--byond-archive "$PWD/BYOND/pinned.zip"' in line for line in commands))
        self.assertEqual(sum('--negative-control runtime' in line for line in commands), 1)
        self.assertEqual(sum('--lighting-load' in line for line in commands), 1)
        self.assertNotIn('--legacy-fixture', step)

    def test_workflow_retains_started_identity_and_compile_evidence_on_failure(self):
        workflow = (HERE.parents[1] / '.github/workflows/test.yml').read_text()
        retain = workflow.split('      - name: Retain core-boot compile-only evidence\n', 1)[1].split('\n      - name:', 1)[0]
        self.assertIn("always() && needs.changes.result == 'success' && steps.core_boot_compile.outputs.started == 'true'", retain)
        self.assertIn('retention-days: 7', retain)
        self.assertIn('*/runtime-identity.json', retain)
        self.assertIn('if-no-files-found: error', retain)


class DMList:
    def __init__(self, length):
        self.len = length

    def __bool__(self):
        return True  # A native list reference is truthy even when empty.


class LightingQuietTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        source = (HERE / 'lighting_load.dm').read_text(encoding='utf-8')
        body = source.split('/datum/core_boot_probe/proc/lighting_quiet()\n', 1)[1].split('\n\n', 1)[0]
        if 'var/process/lighting_overlays/overlays = processes.lighting_overlays' not in body:
            raise AssertionError('Lighting process binding changed; review the offline adapter')
        cls.expression = re.search(r'^\treturn (.+)$', body, re.M).group(1)

    def evaluate(self, expression=None, *, overlay_queue=0, light_queue=0, tod=False,
                 batch=None, index=1, processing=False, present=True):
        # Evaluate the actual side-effect-free DM expression, not a separate
        # Python implementation. This narrow syntax adapter is not a DM compiler.
        text = (expression or self.expression).replace('&&', ' and ').replace('||', ' or ')
        text = re.sub(r'!(?!=)', ' not ', text).strip()
        tree = ast.parse(text, mode='eval')
        allowed = (ast.Expression, ast.BoolOp, ast.And, ast.Or, ast.UnaryOp, ast.Not,
                   ast.Compare, ast.Gt, ast.Name, ast.Load, ast.Attribute)
        self.assertTrue(all(isinstance(node, allowed) for node in ast.walk(tree)))
        overlays = SimpleNamespace(current_list=DMList(batch) if batch is not None else None,
                                   batch_index=index, processing_batch=processing) if present else None
        scope = {'overlays': overlays, 'lighting_update_overlays': DMList(overlay_queue),
                 'lighting_update_lights': DMList(light_queue),
                 'processes': SimpleNamespace(time_of_day_change=SimpleNamespace(updating_lighting=tod))}
        return bool(eval(compile(tree, '<actual lighting_quiet expression>', 'eval'), {'__builtins__': {}}, scope))

    def test_idle_and_exhausted_batches(self):
        self.assertTrue(self.evaluate())
        self.assertTrue(self.evaluate(batch=0))
        self.assertTrue(self.evaluate(batch=3, index=4))

    def test_live_work_or_missing_process_is_not_quiet(self):
        for state in [{'overlay_queue': 1}, {'light_queue': 1}, {'tod': True},
                      {'processing': True}, {'present': False}]:
            with self.subTest(state=state):
                self.assertFalse(self.evaluate(**state))

    def test_detached_budget_yielded_final_batch_is_not_quiet(self):
        self.assertFalse(self.evaluate(batch=3, index=2))
        self.assertFalse(self.evaluate(batch=3, index=3))

    def test_old_queue_only_predicate_misses_that_state(self):
        old = '!lighting_update_overlays.len && !lighting_update_lights.len && !processes.time_of_day_change.updating_lighting'
        self.assertTrue(self.evaluate(old, batch=3, index=2))
        self.assertFalse(self.evaluate(batch=3, index=2))


if __name__ == '__main__':
    unittest.main()
