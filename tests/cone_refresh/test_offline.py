"""Offline source-binding/evidence tests. Does not compile or execute DM."""
import json
from pathlib import Path
import tempfile
import unittest

from evidence import validate_compile
from prepare import AXIS, CONE, CONTROLS, HUMAN, ROOT, WHEELS, prepare, transform_sources
from run import validate_native


class EvidenceTests(unittest.TestCase):
    def test_exact_compiler_banner_and_clean_summary(self):
        good = 'DM compiler version 516.1681\nprobe.dmb - 0 errors, 0 warnings\n'
        validate_compile(0, good)
        for bad in (good.replace('516.1681', '516.16810'),
                    good.replace('DM compiler', 'prefix DM compiler'),
                    good + 'DM compiler version 516.1681\n',
                    good.replace('0 errors, 0 warnings', '0 errors, 0 warnings EXTRA'),
                    good + 'interface/skin.dmf: invalid file\n', good + 'out of memory\n',
                    good + 'CRASH\n', good + 'access violation\n'):
            with self.subTest(log=bad), self.assertRaises(RuntimeError):
                validate_compile(0, bad)

    def test_native_oracle_requires_exact_intended_control(self):
        receipt = {'byond_version': 516, 'byond_build': 1681, 'port': 0, 'checks': 44, 'save_roundtrip': 1, 'phases': ['forced', 'vehicle', 'seats', 'save']}
        validate_native(0, '', 'PASS: cone refresh', receipt, None)
        for control, (label, _) in CONTROLS.items():
            phases = [] if control == 'forced-move' else ['forced', 'vehicle'] if control == 'seat-facing' else ['forced']
            validate_native(0, '', 'FAIL: ' + label, dict(receipt, phases=phases, save_roundtrip=0), control)
            for result in ('PASS: cone refresh', 'FAIL: unrelated assertion'):
                with self.assertRaises(RuntimeError):
                    validate_native(0, '', result, receipt, control)
        for diagnostics in ('Unexpected runtime error', 'invalid file', 'out of memory'):
            with self.assertRaises(RuntimeError):
                validate_native(0, diagnostics, 'PASS: cone refresh', receipt, None)
        for field, value in (('byond_build', 1682), ('port', 1234), ('checks', 0), ('save_roundtrip', 0)):
            with self.assertRaises(RuntimeError):
                validate_native(0, '', 'PASS: cone refresh', dict(receipt, **{field: value}), None)

    def test_client_adapter_does_not_replace_cone_algorithm(self):
        actual = transform_sources()['vision_cone.dm']
        self.assertEqual(actual.replace('cone_client', 'client'), (ROOT / CONE).read_text(encoding='utf-8'))
        self.assertEqual(transform_sources()['human.dm'], (ROOT / HUMAN).read_text(encoding='utf-8'))
        self.assertEqual(transform_sources()['axis.dm'], (ROOT / AXIS).read_text(encoding='utf-8'))
        self.assertEqual(transform_sources()['wheels.dm'], (ROOT / WHEELS).read_text(encoding='utf-8'))

    def test_every_control_removes_only_its_bound_mechanism(self):
        baseline = transform_sources()
        expected = {'forced-move': 'human.dm', 'translation': 'axis.dm', 'rotation': 'axis.dm',
                    'early-refresh': 'human.dm', 'seat-facing': 'wheels.dm'}
        probe = (ROOT / 'tests/cone_refresh/probe.dm').read_text(encoding='utf-8')
        for control, (label, _) in CONTROLS.items():
            changed = transform_sources(control)
            self.assertEqual([p for p in baseline if baseline[p] != changed[p]], [expected[control]])
            self.assertIn('"' + label + '"', probe)
        self.assertNotIn('/mob/living/human/forceMove(', transform_sources('forced-move')['human.dm'])
        for control in ('translation', 'rotation'):
            self.assertEqual(transform_sources(control)['axis.dm'].count('\n\trefresh_passenger_vision()'), 1)

    def test_six_preparations_bound_and_headless(self):
        with tempfile.TemporaryDirectory() as temp:
            for control in (None, *CONTROLS):
                target = Path(temp) / (control or 'positive')
                prepare(target, control)
                receipt = json.loads((target / 'receipt.json').read_text(encoding='utf-8'))
                self.assertFalse(receipt['native_executed'])
                self.assertEqual(receipt['control'], control)
                dme = (target / 'probe.dme').read_text(encoding='utf-8')
                self.assertNotIn('.dmf', dme)
                self.assertNotIn('.dmm"', dme)
                for name in ('human.dm', 'axis.dm', 'wheels.dm', 'vision_cone.dm'):
                    self.assertIn((target / name).as_posix(), dme)
                self.assertEqual(len(receipt['generated_sha256']), 7)


if __name__ == '__main__':
    unittest.main()
