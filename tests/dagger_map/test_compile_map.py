"""Offline harness contracts only; these tests do not execute BYOND."""
from pathlib import Path
import unittest
import tempfile
import subprocess
from unittest.mock import patch

import compile_map


class CompileMapTests(unittest.TestCase):
    def test_only_map_selection_block_changes(self):
        source = (compile_map.ROOT / 'civ13.dme').read_text()
        for key, map_path in compile_map.MAPS.items():
            generated = compile_map.fixture_dme(source, map_path)
            self.assertIn('#include "' + map_path.as_posix() + '"', generated)
            self.assertNotIn(map_path.name, source)
            self.assertEqual(len(compile_map.MAP_INCLUDE.findall(generated)), 1)
            start, end = source.index(compile_map.BEGIN), source.index(compile_map.END)
            self.assertEqual(generated[:start], source[:start])
            self.assertEqual(generated[generated.index(compile_map.END):], source[end:])
            # Every production declaration outside the marked block is retained.
            self.assertEqual(generated[start:generated.index(compile_map.END)],
                             compile_map.BEGIN + '\n#include "' + map_path.as_posix() + '"\n')

    def test_missing_or_multiple_blocks_fail_closed(self):
        for source in ('#include "source.dm"', '// BEGIN_SELECTED_MAP\n#include "a.dmm"\n',
                       '// BEGIN_SELECTED_MAP\n// END_SELECTED_MAP\n// BEGIN_SELECTED_MAP\n// END_SELECTED_MAP\n',
                       '// END_SELECTED_MAP\n// BEGIN_SELECTED_MAP\n'):
            with self.assertRaises(ValueError):
                compile_map.fixture_dme(source, Path('fixture.dmm'))

    def test_pinned_version_comes_from_the_toolchain_pin(self):
        import json
        pin = json.loads((compile_map.ROOT / 'tools/byond/version.json').read_text(encoding='utf-8'))
        self.assertEqual(compile_map.pinned_version(), pin['version'])
        self.assertRegex(compile_map.pinned_version(), r'^\d+\.\d+$')

    def test_control_mutates_one_real_dmm_type(self):
        for map_path in compile_map.MAPS.values():
            source = (compile_map.ROOT / map_path).read_text()
            mutated = compile_map.missing_type_control(source)
            self.assertEqual(mutated.count(compile_map.MISSING_TYPE), 1)
            original = compile_map.re.search(r'/turf/[\w/]+', source).group()
            self.assertEqual(mutated.replace(compile_map.MISSING_TYPE, original), source)
            with self.assertRaises(ValueError):
                compile_map.missing_type_control(mutated)

    def test_positive_requires_pinned_clean_success(self):
        good = 'DM compiler version 516.1681\nfixture.dmb - 0 errors, 0 warnings'
        self.assertTrue(compile_map.accepted(good, 0, version='516.1681'))
        for log, code in ((good, 1), (good.replace('516.1681', '516.1680'), 0),
                          (good.replace('0 warnings', '1 warnings'), 0), ('', 0)):
            self.assertFalse(compile_map.accepted(log, code, version='516.1681'))
        self.assertFalse(compile_map.accepted(good, 0, version='516.1688'))

    def test_control_requires_exact_missing_type_failure(self):
        good = ('DM compiler version 516.1681\n'
                '.dagger-native-example/missing-type.dmm:2:error: undefined type: '
                + compile_map.MISSING_TYPE + '\n'
                '.dagger-native-example/missing-type.dmm:2:error: unknown type\n'
                'fixture.dmb - 2 errors, 0 warnings')
        self.assertTrue(compile_map.accepted(good, 1, True, version='516.1681'))
        for log in (good.replace(compile_map.MISSING_TYPE, '/turf/unrelated'),
                    good.replace('undefined type', 'syntax'),
                    good.replace('2 errors', '1 error'),
                    good.replace('0 warnings', '1 warnings'),
                    good.replace(':2:error: unknown', ':3:error: unknown'),
                    good.replace('unknown type', 'unrelated failure'),
                    good + '\nother.dm:1:error: unrelated',
                    good.replace('missing-type.dmm', 'other.dm')):
            self.assertFalse(compile_map.accepted(log, 1, True, version='516.1681'))


    def test_runner_preserves_sources_and_cleans_products(self):
        for fail in (False, True):
            with self.subTest(fail=fail), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                (root / compile_map.MAP).parent.mkdir(parents=True)
                (root / compile_map.MAP).write_text('"aa" = (/turf/floor,/area)')
                (root / 'civ13.dme').write_text('#include "code.dm"\n// BEGIN_SELECTED_MAP\n#include "active.dmm"\n// END_SELECTED_MAP\n')
                (root / 'tools/byond').mkdir(parents=True)
                (root / 'tools/byond/version.json').write_text('{"version": "516.1681"}')
                before = (root / 'civ13.dme').read_bytes()
                calls = []

                def compiler(command, **kwargs):
                    self.assertNotIn('DreamDaemon', command[0])
                    dme = root / command[-1]
                    control = 'missing-type' in dme.name
                    self.assertIn(compile_map.MAP.as_posix() if not control else 'missing-type.dmm', dme.read_text())
                    calls.append(control)
                    dme.with_suffix('.dmb').write_bytes(b'mocked output')
                    dme.with_suffix('.rsc').write_bytes(b'mocked output')
                    if fail:
                        raise subprocess.TimeoutExpired(command, 600)
                    log = 'DM compiler version 516.1681\n'
                    if control:
                        log += ('missing-type.dmm:1:error: undefined type: ' +
                                compile_map.MISSING_TYPE +
                                '\nmissing-type.dmm:1:error: unknown type\n'
                                'fixture.dmb - 2 errors, 0 warnings')
                    else:
                        log += 'fixture.dmb - 0 errors, 0 warnings'
                    return subprocess.CompletedProcess(command, int(control), log, '')

                with patch.object(compile_map.subprocess, 'check_output', return_value='fixture-head'), \
                     patch.object(compile_map.subprocess, 'run', side_effect=compiler), \
                     patch('builtins.print'):
                    if fail:
                        with self.assertRaises(subprocess.TimeoutExpired):
                            compile_map.run(root, Path('/mock/DreamMaker'), root / 'evidence')
                    else:
                        compile_map.run(root, Path('/mock/DreamMaker'), root / 'evidence')
                        self.assertEqual(calls, [False, True])
                self.assertEqual((root / 'civ13.dme').read_bytes(), before)
                self.assertEqual((root / compile_map.MAP).read_text(), '"aa" = (/turf/floor,/area)')
                self.assertEqual(list(root.glob('.dagger-native-*')), [])


if __name__ == '__main__':
    unittest.main()
