"""Offline contracts. No WSL, compiler, daemon, signals or live sockets."""
import importlib.util
from contextlib import ExitStack
import os
from pathlib import Path
import sys
import tempfile
import types
import unittest
from unittest.mock import Mock, patch

if sys.platform == 'win32':
    sys.modules.setdefault('fcntl', types.SimpleNamespace(LOCK_EX=2, flock=lambda *_: None))
spec = importlib.util.spec_from_file_location('local_wsl', Path(__file__).resolve().parents[1] / 'scripts/local-wsl.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class LocalWslTests(unittest.TestCase):
    def test_build_runs_production_catalog_in_detached_git_snapshot(self):
        real_run = module.subprocess.run
        root = Path(__file__).resolve().parents[1]
        with tempfile.TemporaryDirectory(prefix='civ13-local-build-') as directory:
            temporary = Path(directory)
            source, runtime = temporary / 'source', temporary / 'runtime'
            source.mkdir()
            (runtime / 'config').mkdir(parents=True)
            env = dict(os.environ, GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL=os.devnull,
                       GIT_TERMINAL_PROMPT='0', GIT_CEILING_DIRECTORIES=str(temporary.parent))

            def git(*arguments):
                return real_run(['git', '-C', str(source), *arguments], env=env,
                                check=True, capture_output=True, text=True).stdout.strip()

            for name in ('scripts/build-crafting-atlas.py', 'scripts/atlas/catalog_metadata.py',
                         'scripts/atlas/tanning.py', 'scripts/atlas/variants.py',
                         'scripts/atlas/tanning-contracts.json',
                         'code/modules/1713/production.dm',
                         'code/game/objects/items/stacks/sheets/leather.dm',
                         'code/modules/1713/animal_harvest.dm',
                         'code/modules/materials/material_sheets.dm',
                         'code/game/objects/structures/converters.dm',
                         'code/modules/materials/materials.dm'):
                path = source / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes((root / name).read_bytes())
            for name, value in {'config/crafting/fixture.txt':
                                'RECIPE: /material/wood/,fixture item,/obj/item/fixture,1,1,0,1,none,0,0,0,8,null\n',
                                'maps/fixture.txt': 'synthetic map placeholder\n',
                                'UI/fixture.txt': 'synthetic UI placeholder\n',
                                'civ13.dme': '// Compiler is injected, never executed.\n'}.items():
                path = source / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(value)
            git('init', '--quiet')
            git('config', 'core.hooksPath', str(temporary / 'no-hooks'))
            git('add', '.')
            git('-c', 'user.name=Offline fixture', '-c', 'user.email=fixture@example.invalid',
                'commit', '--quiet', '-m', 'synthetic source')
            sha = git('rev-parse', 'HEAD')
            refs, worktrees = git('show-ref'), git('worktree', 'list', '--porcelain')
            stages = []

            def run(command, **kwargs):
                if command[0] == 'python3':
                    return real_run([sys.executable, *command[1:]], **kwargs)
                if command[0] == str(module.BIN / 'DreamMaker'):
                    stage = Path(kwargs['cwd'])
                    stages.append(stage)
                    self.assertNotEqual(stage, source)
                    actual = real_run(['git', '-C', str(stage), 'rev-parse', 'HEAD'], env=env,
                                      check=True, capture_output=True, text=True).stdout.strip()
                    self.assertEqual(actual, sha)
                    detached = real_run(['git', '-C', str(stage), 'symbolic-ref', '-q', 'HEAD'],
                                        env=env, capture_output=True)
                    self.assertEqual(detached.returncode, 1)
                    catalog = module.json.loads((stage / 'UI/crafting-atlas.json').read_text())
                    self.assertTrue(any(row['name'] == 'fixture item' for row in catalog['recipes']))
                    (stage / 'civ13.dmb').write_bytes(b'fake compiler output')
                    (stage / 'civ13.rsc').write_bytes(b'fake resource output')
                    return module.subprocess.CompletedProcess(command, 0, 'DM compiler version 516.1688\n- 0 errors, 0 warnings')
                if command[0] == 'git':
                    return real_run(command, **kwargs)
                raise AssertionError('Unexpected executable: ' + command[0])

            with patch.object(module.subprocess, 'run', side_effect=run):
                module.build(source, runtime, env)
            self.assertEqual(len(stages), 1)
            self.assertFalse(stages[0].exists())
            self.assertEqual((runtime / 'source-sha.txt').read_text().strip(), sha)
            self.assertTrue((runtime / 'UI/crafting-atlas.json').is_file())
            self.assertFalse((source / 'UI/crafting-atlas.json').exists())
            self.assertEqual(git('status', '--porcelain'), '')
            self.assertEqual(git('rev-parse', 'HEAD'), sha)
            self.assertEqual(git('show-ref'), refs)
            self.assertEqual(git('worktree', 'list', '--porcelain'), worktrees)

    def start_fixture(self, failure=None, cleanup_timeout=False):
        stack = self.enterContext(ExitStack())
        directory = stack.enter_context(tempfile.TemporaryDirectory())
        home = Path(directory)
        runtime = home / '.local/share/civ13-local/nomads'
        runtime.mkdir(parents=True)
        (runtime / 'source-sha.txt').write_text('a' * 40)
        (runtime / 'byond-version.txt').write_text(module.REQUIREMENT['version'])
        process = Mock(pid=77)
        process.poll.return_value = None
        process.wait.side_effect = module.subprocess.TimeoutExpired('owned fake', 10) if cleanup_timeout else None
        process.wait.return_value = 0
        read_text, write_text = Path.read_text, Path.write_text

        def read(path, *args, **kwargs):
            if path == Path('/proc/77/stat'):
                if failure == 'stat-read':
                    raise OSError('injected stat read failure')
                if failure == 'stat-parse':
                    return '77 (DreamDaemon)'
                return '77 (DreamDaemon) ' + ' '.join(['S'] + ['0'] * 18 + ['123'])
            return read_text(path, *args, **kwargs)

        def write(path, *args, **kwargs):
            if path.name == 'process.json' and failure == 'state-write':
                raise OSError('injected state write failure')
            return write_text(path, *args, **kwargs)

        stack.enter_context(patch.object(sys, 'argv', ['local-wsl', 'start', '--server', 'nomads', '--source', directory]))
        stack.enter_context(patch.object(Path, 'home', return_value=home))
        stack.enter_context(patch.object(Path, 'read_text', read))
        stack.enter_context(patch.object(Path, 'write_text', write))
        stack.enter_context(patch.object(module, 'process_matches', return_value=False))
        stack.enter_context(patch.object(module.fcntl, 'flock'))
        stack.enter_context(patch.object(module.subprocess, 'Popen', return_value=process))
        stack.enter_context(patch.object(module.os, 'kill', side_effect=AssertionError('Unexpected signal')))
        stack.enter_context(patch.object(module.time, 'sleep', side_effect=OSError('injected startup interruption') if cleanup_timeout else None))
        return process, runtime / 'process.json'

    def test_failed_start_reaps_exact_owned_child(self):
        for failure in ('stat-read', 'stat-parse', 'state-write'):
            with self.subTest(failure=failure):
                process, state = self.start_fixture(failure)
                with self.assertRaises((OSError, IndexError)):
                    module.main()
                process.terminate.assert_called_once_with()
                process.wait.assert_called_once_with(timeout=10)
                self.assertFalse(state.exists())

    def test_failed_cleanup_preserves_identity_record(self):
        process, state = self.start_fixture(cleanup_timeout=True)
        with self.assertRaisesRegex(RuntimeError, 'owned daemon 77.*exit unconfirmed'):
            module.main()
        process.terminate.assert_called_once_with()
        process.wait.assert_called_once_with(timeout=10)
        process.kill.assert_not_called()
        self.assertEqual(module.json.loads(state.read_text()), {'pid': 77, 'started': '123', 'byond': module.REQUIREMENT['version']})

    def test_successful_start_retains_identity_without_stopping_child(self):
        process, state = self.start_fixture()
        module.main()
        process.terminate.assert_not_called()
        process.wait.assert_not_called()
        self.assertEqual(module.json.loads(state.read_text()), {'pid': 77, 'started': '123', 'byond': module.REQUIREMENT['version']})

    def test_old_runtime_record_is_preserved_before_process_observation(self):
        for original in ('{"pid":77,"started":"123"}', '[]', '{"pid":77,"byond":"516.1681"}'):
            process, state = self.start_fixture()
            state.write_text(original)
            with self.subTest(original=original), patch.object(module, 'process_matches', side_effect=AssertionError('Unexpected process observation')):
                with self.assertRaisesRegex(RuntimeError, 'older or unknown BYOND version'):
                    module.main()
            module.subprocess.Popen.assert_not_called()
            process.terminate.assert_not_called()
            self.assertEqual(state.read_text(), original)

    def test_missing_or_old_compiled_version_refuses_start(self):
        for value in (None, '516.1681', 'malformed'):
            process, state = self.start_fixture()
            metadata = state.parent / 'byond-version.txt'
            if value is None:
                metadata.unlink()
            else:
                metadata.write_text(value)
            with self.subTest(value=value), self.assertRaisesRegex(RuntimeError, 'Run Build with BYOND 516.1688'):
                module.main()
            module.subprocess.Popen.assert_not_called()
            process.terminate.assert_not_called()
            self.assertFalse(state.exists())

    def test_exited_start_reaps_without_termination(self):
        process, state = self.start_fixture()
        process.poll.return_value = 7
        process.wait.return_value = 7
        with self.assertRaisesRegex(RuntimeError, 'Daemon exited'):
            module.main()
        process.terminate.assert_not_called()
        process.wait.assert_called_once_with(timeout=10)
        self.assertFalse(state.exists())

    def test_separate_mode_and_no_official_integrations(self):
        for server, mode in [('nomads', 'PERSISTENCE'), ('tdm', 'TDM')]:
            value = module.config(server, Path('/tmp/isolated') / server)
            self.assertIn('ALLOWED_GAMEMODES ' + mode, value)
            self.assertIn('HUB NO', value)
            self.assertIn('TTS_ON 0', value)
            self.assertIn('SCRIPTS_DIRECTORY null', value)
            self.assertNotIn('WEBHOOK', value)
            self.assertNotIn('civ13.com', value)
            self.assertNotIn('SKIP_PERSISTENCE', value)
        self.assertNotEqual(module.PORTS['nomads'], module.PORTS['tdm'])

    def test_stop_identity_rejects_reused_pid(self):
        root = Path('/tmp/nomads')
        fields = ['S'] + ['0'] * 18 + ['123'] + ['0'] * 5
        with patch.object(Path, 'read_text', return_value='77 (DreamDaemon) ' + ' '.join(fields)), patch.object(Path, 'read_bytes', return_value=(str(module.BIN / 'DreamDaemon') + '\0' + str(root / 'civ13.dmb') + '\0').encode()):
            self.assertTrue(module.process_matches({'pid': 77, 'started': '123'}, root))
            self.assertFalse(module.process_matches({'pid': 77, 'started': '456'}, root))
            self.assertFalse(module.process_matches({'pid': 77, 'started': '123'}, Path('/tmp/tdm')))

    def test_dirty_build_stops_before_export_or_compiler(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(module.subprocess, 'check_output', side_effect=['a' * 40, ' M code/example.dm']), patch.object(module.subprocess, 'run') as run:
            with self.assertRaisesRegex(RuntimeError, 'Commit tracked changes'):
                module.build(Path(directory), Path(directory), {})
            run.assert_not_called()

    def test_stop_identity_rejects_incomplete_process_metadata(self):
        root = Path('/tmp/nomads')
        command = (str(module.BIN / 'DreamDaemon') + '\0' + str(root / 'civ13.dmb') + '\0').encode()
        for stat in ('', '77 (DreamDaemon)', '77 (DreamDaemon) S 0'):
            with self.subTest(stat=stat), patch.object(Path, 'read_text', return_value=stat), patch.object(Path, 'read_bytes', return_value=command):
                self.assertFalse(module.process_matches({'pid': 77, 'started': '123'}, root))


if __name__ == '__main__':
    unittest.main()
