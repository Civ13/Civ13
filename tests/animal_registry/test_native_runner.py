"""Offline preparation/injected evidence tests. These never execute BYOND."""
import argparse
import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest

import run_native as native

LOG = "World opened on network port 43210 for address 127.0.0.1.\nWorld no longer opened to new users.\nDONE registry fixture\n"


def result_for(control=None):
    failures = native.expected_failures(control)
    return dict(version=native.VERSION, initial_port=43210, closed_port=0, reopen=0,
                cases=[{'case': c, 'passed': int(c not in failures)} for c in native.case_names()])


class NativeRunnerTests(unittest.TestCase):
    def setUp(self):
        self.source = (native.ROOT / native.SOURCE).read_text()

    def test_hooks_extracted_unchanged_and_no_full_game(self):
        generated = native.prepare(self.source)
        self.assertEqual(set(generated), {'probe.dme', 'hooks.dm', 'fixture.dm'})
        for body in native.extract(self.source).values():
            self.assertIn(body, generated['hooks.dm'])
        self.assertNotIn('civ13.dme', generated['probe.dme'])
        self.assertNotIn('.dmm', generated['probe.dme'])
        fixture = generated['fixture.dm']
        self.assertIn('if(src in get_registry(active_registry_name))', fixture)
        self.assertIn('var/list/registry = get_registry(registry_name)', fixture)
        self.assertIn('set_registry(registry_name, list())', fixture)
        self.assertIn('visibility = 0', fixture)
        self.assertIn('/client/New()\n\tdel(src)', fixture)
        self.assertEqual(len(native.case_names()), len(native.HOOKS) * 3 + 7)

    def test_each_control_changes_only_its_exact_production_hook(self):
        baseline = native.prepare(self.source)
        for hook, registry in native.HOOKS.items():
            with self.subTest(hook=hook):
                changed = native.prepare(self.source, hook)
                old = native.extract(self.source)[hook]
                expected = old.replace(registry + ' -= src', registry + ' &= src', 1)
                self.assertEqual(changed['hooks.dm'], baseline['hooks.dm'].replace(old, expected, 1))
                self.assertEqual(changed['fixture.dm'], baseline['fixture.dm'])
                self.assertEqual(changed['probe.dme'], baseline['probe.dme'])

    def test_source_drift_and_unknown_mutations_fail_closed(self):
        with self.assertRaises(ValueError):
            native.prepare(self.source.replace('_count -= src', '_count &= src', 1))
        with self.assertRaises(ValueError):
            native.prepare(self.source, 'missing/death')

    def test_baseline_and_every_exact_control_verdict(self):
        for control in (None, *native.HOOKS):
            native.verify(result_for(control), LOG, control)
            broken = result_for(control)
            broken['cases'][0]['passed'] = 1 - broken['cases'][0]['passed']
            with self.assertRaises(ValueError):
                native.verify(broken, LOG, control)

    def test_missing_duplicate_cases_bad_types_and_network_fail(self):
        changes = [lambda r: r['cases'].pop(),
                   lambda r: r['cases'].append(copy.deepcopy(r['cases'][0])),
                   lambda r: r['cases'][0].update(passed=True),
                   lambda r: r.update(initial_port=1234),
                   lambda r: r.update(closed_port=None),
                   lambda r: r.update(reopen=1),
                   lambda r: r.update(version='516.1680')]
        for change in changes:
            with self.subTest(change=change):
                result = result_for()
                change(result)
                with self.assertRaises(ValueError):
                    native.verify(result, LOG)

    def test_diagnostics_completion_and_listener_fail(self):
        for log in ('', LOG * 2, LOG.replace('127.0.0.1', '0.0.0.0'), LOG.replace('World no longer opened to new users.', ''),
                    LOG + 'runtime error: failed',
                    LOG + 'World opened on network port 1000 for address 127.0.0.1.'):
            with self.subTest(log=log), self.assertRaises(ValueError):
                native.verify(result_for(), log)
        native.verify(result_for(), LOG * 2, runtime_log=LOG)

    def test_prepare_only_never_invokes_runner(self):
        with tempfile.TemporaryDirectory() as directory:
            args = argparse.Namespace(output=Path(directory)/'out', byond_bin=None,
                                      prepare_only=True, all_controls=True, negative_control=None, suite='farm', expected_byond_version=native.VERSION)
            def forbidden(*args):
                self.fail('prepare-only invoked a process')
            result = native.execute(args, runner=forbidden)
            self.assertEqual(result['status'], 'prepared-only')
            self.assertFalse(result['native_execution'])
            self.assertEqual(len(result['modes']), 16)
            with self.assertRaises(FileExistsError):
                native.execute(args, runner=forbidden)

    def test_injected_compiler_runtime_and_diagnostics(self):
        for bad_role in (None, 'compile', 'daemon'):
            with self.subTest(bad_role=bad_role), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                binary = root/'bin'
                binary.mkdir()
                for name in ('DreamMaker', 'DreamDaemon'):
                    (binary/name).write_bytes(b'not an executable; injected test only')
                args = argparse.Namespace(output=root/'out', byond_bin=binary,
                                          prepare_only=False, all_controls=True, negative_control=None, suite='farm', expected_byond_version=native.VERSION)
                controls = iter([None, *native.HOOKS])
                def injected(command, work, role, deadline):
                    if role == 'compile':
                        return 'DM compiler version 516.1681\n0 errors, 0 warnings\n' + ('runtime error' if bad_role == role else '')
                    self.assertIn('-trusted', command)
                    self.assertNotIn('-safe', command)
                    self.assertNotIn('-port', command)
                    (work/'runtime.log').write_text(LOG)
                    (work/'result.json').write_text(json.dumps(result_for(next(controls))))
                    # Simulates a diagnostic on stdout/stderr despite clean canonical log.
                    return 'runtime error' if bad_role == role else ''
                if bad_role:
                    with self.assertRaises(ValueError):
                        native.execute(args, runner=injected)
                    self.assertEqual(json.loads((args.output/'summary.json').read_text())['status'], 'incomplete')
                else:
                    self.assertEqual(native.execute(args, runner=injected)['status'], 'passed')

    @unittest.skipUnless(sys.platform == 'linux', 'Linux bounded process runner')
    def test_real_subprocess_timeout_exit_and_output_limit(self):
        # Python children only; no native engine, game, or sockets.
        cases = [("import time; time.sleep(10)", 0.1, subprocess.TimeoutExpired),
                 ("raise SystemExit(3)", 5, RuntimeError),
                 ("import os; os.write(1, b'x' * (3 * 1024 * 1024))", 5, ValueError)]
        for script, timeout, error in cases:
            with self.subTest(script=script), tempfile.TemporaryDirectory() as directory:
                work = Path(directory)
                with self.assertRaises(error):
                    native.run([sys.executable, '-c', script], work, 'test', time.monotonic() + timeout)
                receipt = json.loads((work/'test-process.json').read_text())
                self.assertTrue(receipt['reaped'])
                self.assertLessEqual((work/'test.stdout').stat().st_size, native.LIMIT)


if __name__ == '__main__':
    unittest.main()
