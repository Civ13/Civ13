"""Offline preparation contracts. These do not execute or validate native DM."""
import ast
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import socket
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]

class PreparationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location('save_latency_preparation', ROOT / 'tests/save_latency/run.py')
        cls.runner = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.runner)
        # Only immutable/local Git reads precede the process/socket prohibition.
        commands = [('git', 'show', cls.runner.OLD_READER_COMMIT + ':code/modules/persistence/loading.dm'),
                    ('git', 'rev-parse', 'HEAD'), ('git', 'diff', 'HEAD')]
        cls.git_reads = {command: subprocess.check_output(command, cwd=ROOT) for command in commands}

    def setUp(self):
        self.spawn = self.enterContext(patch.object(subprocess, 'Popen', side_effect=AssertionError('Native process forbidden')))
        self.sockets = self.enterContext(patch.object(socket, 'socket', side_effect=AssertionError('Socket forbidden')))

    def tearDown(self):
        self.spawn.assert_not_called()
        self.sockets.assert_not_called()

    def stage(self, *arguments):
        def git_read(command, **kwargs):
            self.assertIn(tuple(command), self.git_reads)
            value = self.git_reads[tuple(command)]
            return value.decode('utf-8') if kwargs.get('text') else value
        output = Path(self.enterContext(tempfile.TemporaryDirectory(prefix='save-latency-offline-')))
        with patch.object(self.runner.tempfile, 'mkdtemp', return_value=str(output)), \
                patch.object(self.runner.subprocess, 'check_output', side_effect=git_read), \
                patch.object(sys, 'argv', ['run.py', '--byond-bin', '/not-installed', '--prepare-only', *arguments]), \
                patch('builtins.print'):
            self.runner.main()
        metadata = json.loads((output / 'metadata.json').read_text())
        for relative, expected in metadata['sources'].items():
            self.assertEqual(hashlib.sha256((output / relative).read_bytes()).hexdigest(), expected)
        for name in ('result.txt', 'compile.log', 'runtime.log', 'probe.dmb'):
            self.assertFalse((output / name).exists())
        return output, metadata

    def test_current_admission_and_transfers_are_staged(self):
        output, _ = self.stage()
        source = (output / 'code/modules/persistence/saving.dm').read_text()
        self.assertIn('return run_world_operation("save")', source)
        for call in ('operation.enter_contents', 'prepare_player_ownership()', 'capture_durable_world()',
                     'capture_round_state(', 'durable_export.bind_entry', 'before_save_context',
                     'require_export_frame(frame)', 'drain_save_transfers(frame)'):
            self.assertIn(call, source)
        self.assertIn('player_reclaim.dm', (output / 'probe.dme').read_text())
        self.assertIn('world_z_budget.dm', (output / 'probe.dme').read_text())
        functions = (output / 'code/modules/persistence/functions.dm').read_text()
        self.assertIn('storage.dimension_budget_hold || world_z_budget.active', functions)
        publication = source[source.index('var/content_value = encode_saved_contents'): ]
        self.assertLess(publication.index('drain_save_transfers(frame)'), publication.index('savefile["content"] << content_value'))

    def test_version_three_and_current_reader(self):
        output, _ = self.stage('--dense', '--verify-backup')
        writer = (output / 'code/modules/persistence/saving.dm').read_text()
        reader = (output / 'code/modules/persistence/loading.dm').read_text()
        self.assertIn('savefile["/format_version"] << 3', writer)
        self.assertIn('version && version != 2 && version != 3', reader)
        self.assertIn('saved_content_refs(value, version)', reader)

    def test_pinned_old_reader_rejects_version_three(self):
        output, metadata = self.stage('--negative-control', 'old-reader')
        historical = self.git_reads[('git', 'show', self.runner.OLD_READER_COMMIT + ':code/modules/persistence/loading.dm')]
        staged = (output / 'code/modules/persistence/loading.dm').read_bytes()
        self.assertEqual(staged, historical)
        reader = staged.decode('utf-8')
        self.assertIn('if(version && version != 2)', reader)
        self.assertNotIn('/map_storage/proc/saved_content_refs', reader)
        loading = (ROOT / 'code/modules/persistence/loading.dm').read_text(encoding='utf-8')
        roof = loading[:loading.index('\n/map_storage/proc/Load_Entry(')]
        marker = '/map_storage/proc/saved_content_refs(value, version)\n'
        start = loading.index(marker)
        end = loading.find('\n/map_storage/proc/', start + len(marker))
        codec = loading[start:end if end >= 0 else len(loading)]
        original = (ROOT / 'code/modules/persistence/functions.dm').read_bytes()
        functions = (output / 'code/modules/persistence/functions.dm').read_bytes()
        self.assertEqual(functions, original + ('\n' + roof + '\n' + codec).encode())
        self.assertEqual(metadata['old_reader_compatibility'], {
            'commit': self.runner.OLD_READER_COMMIT, 'loader_sha256': hashlib.sha256(historical).hexdigest(),
            'roof_helpers_sha256': hashlib.sha256(roof.encode()).hexdigest(),
            'content_helper_sha256': hashlib.sha256(codec.encode()).hexdigest()})
        # Added helpers cannot replace the historical loader or its version refusal.
        procs = lambda text: re.findall(r'^/map_storage/proc/(\w+)\(', text, re.M)
        self.assertFalse(set(procs(roof + codec)) & set(procs(reader)))
        combined = reader + '\n' + functions.decode('utf-8')
        for name in procs(roof + codec):
            self.assertEqual(procs(combined).count(name), 1)

    def test_compatibility_rejects_changed_or_repeated_boundaries(self):
        loading = (ROOT / 'code/modules/persistence/loading.dm').read_text(encoding='utf-8')
        end = '\n/map_storage/proc/Load_Entry('
        marker = '/map_storage/proc/saved_content_refs(value, version)\n'
        for changed in (loading.replace('// Only roof transformations', '// Changed roof transformations', 1),
                        loading.replace(end, '\n/map_storage/proc/Changed_Load_Entry(', 1), loading + end,
                        loading + loading[:loading.index(end)], loading.replace(marker, ''), loading + marker):
            with self.subTest(), self.assertRaisesRegex(RuntimeError, 'compatibility anchor'):
                self.runner.old_reader_helpers(changed, '')

    def test_compatibility_rejects_missing_or_duplicate_dependencies(self):
        loading = (ROOT / 'code/modules/persistence/loading.dm').read_text(encoding='utf-8')
        member = '\tvar/list/validated_roof_types = list()\n'
        proc = '/map_storage/proc/clear_saved_roof_areas()'
        for changed in (loading.replace(member, ''), loading.replace(member, member * 2),
                        loading.replace(proc, '/map_storage/proc/renamed_clear_saved_roof_areas()'),
                        loading.replace(proc, proc + '\n' + proc)):
            with self.subTest(), self.assertRaisesRegex(RuntimeError, 'compatibility (members|procedures) changed'):
                self.runner.old_reader_helpers(changed, '')
        for existing in (proc, member, '/map_storage/proc/saved_content_refs(value, version)\n'):
            with self.subTest(), self.assertRaisesRegex(RuntimeError, 'duplicated'):
                self.runner.old_reader_helpers(loading, existing)

    def test_actual_adjudication_requires_the_version_three_preflight_refusal(self):
        tree = ast.parse((ROOT / 'tests/save_latency/run.py').read_text(encoding='utf-8'))
        main = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == 'main')
        begin = next(i for i, node in enumerate(main.body) if isinstance(node, ast.Assign)
                     and any(isinstance(target, ast.Name) and target.id == 'expected' for target in node.targets))
        end = next(i for i in range(begin, len(main.body)) if isinstance(main.body[i], ast.If)
                   and isinstance(main.body[i].test, ast.Attribute) and main.body[i].test.attr == 'verify_backup')
        guard = compile(ast.Module(body=main.body[begin:end], type_ignores=[]), '<actual-native-adjudication>', 'exec')
        good = 'World-save preflight rejected: Unsupported save version 3 on code/modules/persistence/loading.dm:625\n'
        cases = [('FAIL: save preflight failed', good, 0, False),
                 ('PASS', good, 0, True), ('FAIL: save preflight failed for another reason', good, 0, True),
                 ('FAIL: save preflight failed', 'error: undefined proc clear_saved_roof_areas', 0, True),
                 ('FAIL: save preflight failed', good.replace('version 3', 'version 2'), 0, True),
                 ('FAIL: save preflight failed', good.replace('loading.dm', 'other.dm'), 0, True),
                 ('FAIL: save preflight failed', 'World-save preflight rejected: Missing saved turf', 0, True),
                 ('FAIL: save preflight failed', good + 'runtime error: undefined proc', 0, True),
                 ('FAIL: save preflight failed', good + 'BUG: engine diagnostic', 0, True),
                 ('FAIL: save preflight failed', good, 1, True)]
        output = Path(self.enterContext(tempfile.TemporaryDirectory()))
        for result, log, status, rejected in cases:
            with self.subTest(result=result, log=log, status=status):
                (output / 'result.txt').write_text(result)
                env = {'args': SimpleNamespace(negative_control='old-reader'), 'output': output, 'log': log, 're': re,
                       'result': SimpleNamespace(returncode=status),
                       'require_old_reader_preflight': self.runner.require_old_reader_preflight}
                if rejected:
                    with self.assertRaises(RuntimeError): exec(guard, env)
                else:
                    exec(guard, env)

    def test_yield_mutation_is_effective(self):
        output, _ = self.stage('--negative-control', 'yield')
        writer = (output / 'code/modules/persistence/saving.dm').read_text()
        self.assertNotRegex(writer, r'(?m)^\s*sleep\((world.tick_lag|0)\)$')
        self.assertGreaterEqual(writer.count('negative control: no yield'), 2)

    def test_mutation_scenarios_are_fail_closed(self):
        for scenario in ('movement', 'parent-deletion', 'concurrent'):
            with self.subTest(scenario=scenario):
                output, metadata = self.stage('--scenario', scenario)
                self.assertEqual(metadata['scenario'], scenario)
                probe = (output / 'tests/save_latency/probe.dm').read_text()
                self.assertIn('invalidated frame was published', probe)
                self.assertIn('prior completed generation lost', probe)

    def test_native_launch_preserves_trusted_isolated_contract(self):
        runner = (ROOT / 'tests/save_latency/run.py').read_text()
        self.assertIn("['-trusted','-log','runtime.log']", runner)
        self.assertNotIn("'-safe'", runner)
        probe = (ROOT / 'tests/save_latency/probe.dm').read_text()
        self.assertIn('return ..("none")', probe)
        self.assertIn('visibility = 0', probe)

    def test_interrupted_writer_is_staged(self):
        _, metadata = self.stage('--interrupt')
        self.assertTrue(metadata['interrupt'])

if __name__ == '__main__':
    unittest.main()
