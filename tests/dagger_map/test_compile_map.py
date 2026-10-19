"""Offline harness contracts only; these tests do not execute BYOND."""
from pathlib import Path
import unittest
import tempfile
import subprocess
from unittest.mock import patch

import compile_map


class CompileMapTests(unittest.TestCase):
    def test_only_map_include_changes(self):
        source = (compile_map.ROOT / 'civ13.dme').read_text()
        generated = compile_map.fixture_dme(source, compile_map.MAP)
        self.assertIn('#include "maps/WIP/dagger_train_home.dmm"', generated)
        self.assertEqual(compile_map.MAP_INCLUDE.sub('', source),
                         compile_map.MAP_INCLUDE.sub('', generated))
        self.assertNotIn('dagger_train_home.dmm', source)
        self.assertEqual(len(compile_map.MAP_INCLUDE.findall(generated)), 1)

    def test_missing_or_multiple_maps_fail_closed(self):
        for source in ('#include "source.dm"', '#include "a.dmm"\n#include "b.dmm"'):
            with self.assertRaises(ValueError):
                compile_map.fixture_dme(source, Path('fixture.dmm'))

    def test_control_mutates_one_real_dmm_type(self):
        source = (compile_map.ROOT / compile_map.MAP).read_text()
        mutated = compile_map.missing_type_control(source)
        self.assertEqual(mutated.count(compile_map.MISSING_TYPE), 1)
        original = compile_map.re.search(r'/turf/[\w/]+', source).group()
        self.assertEqual(mutated.replace(compile_map.MISSING_TYPE, original), source)
        with self.assertRaises(ValueError):
            compile_map.missing_type_control(mutated)

    def test_positive_requires_pinned_clean_success(self):
        good = 'DM compiler version 516.1681\nfixture.dmb - 0 errors, 0 warnings'
        self.assertTrue(compile_map.accepted(good, 0))
        for log, code in ((good, 1), (good.replace('516.1681', '516.1680'), 0),
                          (good.replace('0 warnings', '1 warnings'), 0), ('', 0)):
            self.assertFalse(compile_map.accepted(log, code))

    def test_control_requires_exact_missing_type_failure(self):
        good = ('DM compiler version 516.1681\nmissing-type.dmm:2:error: ' +
                compile_map.MISSING_TYPE + ': undefined type path\nfixture.dmb - 1 error, 0 warnings')
        self.assertTrue(compile_map.accepted(good, 1, True))
        for log in (good.replace(compile_map.MISSING_TYPE, '/turf/unrelated'),
                    good.replace('undefined type', 'syntax'),
                    good.replace('1 error', '2 errors'),
                    good.replace('0 warnings', '1 warnings')):
            self.assertFalse(compile_map.accepted(log, 1, True))


    def test_runner_preserves_sources_and_cleans_products(self):
        for fail in (False, True):
            with self.subTest(fail=fail), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                (root / compile_map.MAP).parent.mkdir(parents=True)
                (root / compile_map.MAP).write_text('"aa" = (/turf/floor,/area)')
                (root / 'civ13.dme').write_text('#include "code.dm"\n#include "active.dmm"\n')
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
                        log += ('missing-type.dmm:1:error: ' + compile_map.MISSING_TYPE +
                                ': undefined type path\nfixture.dmb - 1 error, 0 warnings')
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
