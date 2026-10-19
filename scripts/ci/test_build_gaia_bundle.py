"""Synthetic packaging checks: no compiler, engine, network, or host operations."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('gaia', Path(__file__).with_name('build_gaia_bundle.py'))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


class BuildTests(unittest.TestCase):
    def test_exact_gaia_replacement(self):
        source = '#include "code/a.dm"\n#include "maps\\nomads\\nomads.dmm"\n#include "code/b.dm"\n'
        selected = m.select_gaia(source)
        self.assertEqual(selected, source.replace('nomads.dmm', 'nomads_gaia.dmm'))
        self.assertEqual(m.MAP_PATTERN.findall(selected), ['maps\\nomads\\nomads_gaia.dmm'])

    def test_wrong_missing_or_multiple_map_rejected(self):
        for source in ('', '#include "/absolute/world.dmm"\n',
                       '#include "maps/nomads/nomads.dmm"\n#include "another.dmm"\n'):
            with self.subTest(source=source), self.assertRaises(RuntimeError):
                m.select_gaia(source)

    def fixture(self, root):
        source = root/'source'
        source.mkdir()
        for name in m.EXTRA:
            path = source/name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('synthetic')
        for folder in m.TREES:
            path = source/folder/'fixture.txt'
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('runtime fixture')
        return source

    def test_compile_contract(self):
        with tempfile.TemporaryDirectory() as temp:
            source = self.fixture(Path(temp))
            good = 'DM compiler version 516.1681\nciv13.dmb - 0 errors, 0 warnings\n'
            m.validate_compile(good, source)
            for log in (good.replace('1681', '1680'), good+'1 warning\n', good.replace('0 errors', '2 errors'), ''):
                with self.subTest(log=log), self.assertRaises(RuntimeError):
                    m.validate_compile(log, source)
            (source/'civ13.dmb').write_bytes(b'')
            with self.assertRaises(RuntimeError):
                m.validate_compile(good, source)

    def test_exact_package_inventory_and_hashes(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source = self.fixture(root)
            (source/'private-unselected.txt').write_text('must not be included')
            log = root/'compile-source.log'
            log.write_text('synthetic compile receipt')
            output = root/'bundle'
            manifest = m.package(source, output, log, {'synthetic': True})
            actual = {p.relative_to(output).as_posix() for p in output.rglob('*') if p.is_file()}
            self.assertEqual(actual, {'build-manifest.json', 'compile.log'} | {'game/'+n for n in manifest['files']})
            self.assertEqual(json.loads((output/'build-manifest.json').read_text()), manifest)
            self.assertEqual(manifest['revision'], m.REVISION)
            self.assertEqual(manifest['compiler_version'], '516.1681')
            self.assertEqual(manifest['compile_log_sha256'], m.digest(output/'compile.log'))
            self.assertNotIn('private-unselected.txt', manifest['files'])
            for name, receipt in manifest['files'].items():
                self.assertEqual(receipt, {'bytes': (output/'game'/name).stat().st_size, 'sha256': m.digest(source/name)})
            with self.assertRaises(RuntimeError):
                m.package(source, output, log, {})

    def test_symlink_member_and_tree_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            source = self.fixture(Path(temp))
            (source/'UI'/'link').symlink_to(source/'civ13.dmb')
            with self.assertRaises(RuntimeError):
                m.selected_files(source)

    def test_empty_runtime_tree_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            source = self.fixture(Path(temp))
            (source/'sound/music/fixture.txt').unlink()
            with self.assertRaises(RuntimeError):
                m.selected_files(source)

    def test_compiler_library_path_is_explicit(self):
        original = {'LD_LIBRARY_PATH': '/existing', 'OTHER': 'unchanged'}
        env = m.compiler_environment(Path('/pinned/bin'), original)
        self.assertEqual(env['LD_LIBRARY_PATH'], '/pinned/bin:/existing')
        self.assertEqual(original['LD_LIBRARY_PATH'], '/existing')
        self.assertEqual(env['OTHER'], 'unchanged')
        self.assertEqual(m.compiler_environment(Path('/pinned/bin'), {})['LD_LIBRARY_PATH'], '/pinned/bin')

    def test_workflow_pins_source_and_never_runs_game(self):
        text = Path(__file__).resolve().parents[2].joinpath('.github/workflows/test.yml').read_text()
        self.assertIn('ref: '+m.REVISION, text)
        self.assertIn('persist-credentials: false', text)
        self.assertNotIn('DreamDaemon', text)
        self.assertNotIn('secrets.', text)
        self.assertIn('contents: read', text)


if __name__ == '__main__':
    unittest.main()
