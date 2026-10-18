"""Offline runner controls. No compiler, DreamDaemon, game, port or network."""
import ast
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

    def test_main_preserves_failed_receipt_and_cleans_generated_files(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            output = root / 'evidence'
            created = [root / ('probe' + suffix) for suffix in ('.dme', '.dmb', '.rsc')]
            for path in created:
                path.write_bytes(b'offline fixture')
            def generated(control, files, *args):
                files.extend(created)
                return created[0], None
            def git(*args):
                return 'a' * 40 if args[0] == 'rev-parse' else ''
            probe = root / 'tests/core_boot/probe.dm'
            probe.parent.mkdir(parents=True)
            probe.write_text('// offline fixture', encoding='utf-8')
            daemon = FakeDaemon(runner.EXPECTED, returncode=7)
            build = subprocess.CompletedProcess([], 0, '516.1681: 0 errors, 0 warnings', '')
            argv = ['run.py', '--byond-bin', str(root), '--output', str(output)]
            with mock.patch.object(runner, 'ROOT', root), mock.patch.object(runner, 'git', side_effect=git), \
                    mock.patch.object(runner, 'generate', side_effect=generated), \
                    mock.patch.object(runner.subprocess, 'run', return_value=build), \
                    mock.patch.object(runner.subprocess, 'Popen', side_effect=daemon.start), \
                    mock.patch.object(sys, 'argv', argv):
                with self.assertRaisesRegex(RuntimeError, 'did not exit cleanly'):
                    runner.main()
            receipt = json.loads((output / 'summary.json').read_text())
            self.assertEqual(receipt['phases'][0]['returncode'], 7)
            self.assertTrue((output / 'runtime/boot-result.txt').is_file())
            self.assertTrue(all(not path.exists() for path in created))

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
