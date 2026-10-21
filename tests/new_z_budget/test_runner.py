"""Offline oracle checks; these tests never launch a compiler/runtime."""
import tempfile
import unittest
from pathlib import Path
from prepare import ROOT, omit_headless_interface, prepare
from run import MAX_COMPILE_LOG, validate_compile, validate_native


class RunnerEvidenceTests(unittest.TestCase):
    def receipt(self, **updates):
        result = dict(byond_version=516, byond_build=1681, port=0, checks=61,
                      maxz=9, default_refusal=1, existing_plane=1)
        result.update(updates)
        return result

    def compiler_log(self, banner='DM compiler version 516.1681', result='probe.dmb - 0 errors, 0 warnings'):
        return banner + '\nloading probe.dme\nsaving probe.dmb (DEBUG mode)\n' + result + '\nTotal time: 0:06\n'

    def test_exact_compiler_evidence(self):
        validate_compile(0, self.compiler_log())
        validate_compile(0, self.compiler_log(result='probe.dmb - 0 errors, 0 warnings (10/18/26 4:39 pm)').replace('\n', '\r\n'))

    def test_invalid_interface_diagnostic_overrides_zero_summary(self):
        for path in ['D:/GitHub/civ13-z-budget-20261018/interface/skin.dmf', '/tmp/repo/interface/skin.dmf']:
            log = self.compiler_log().replace('saving probe.dmb', path + ': invalid file\nsaving probe.dmb')
            with self.subTest(path=path), self.assertRaises(RuntimeError):
                validate_compile(0, log)

    def test_headless_preparation_omits_exact_interface_and_records_limit(self):
        source = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        transformed = omit_headless_interface(source)
        self.assertNotIn('.dmf', transformed)
        self.assertIn('interface\\skin.dmf', source)
        for changed in [transformed, source + '\n#include "interface\\skin.dmf"\n']:
            with self.assertRaises(AssertionError):
                omit_headless_interface(changed)
        with tempfile.TemporaryDirectory(prefix='new-z-headless-source-') as temporary:
            output = Path(temporary) / 'prepared'
            prepare(output, None)
            self.assertNotIn('.dmf', (output / 'probe.dme').read_text(encoding='utf-8'))
            import json
            receipt = json.loads((output / 'receipt.json').read_text(encoding='utf-8'))
            self.assertFalse(receipt['ui_rendering_verified'])
            self.assertEqual(receipt['interface'], 'skin.dmf explicitly omitted from headless fixture')

    def test_shared_disk_runner_artifact_names(self):
        for artifact in ['dimension_bootstrap.dmb', '.durable_world_deadbeef.dmb']:
            log = self.compiler_log().replace('probe.dmb', artifact)
            validate_compile(0, log, artifact)
            with self.assertRaises(RuntimeError):
                validate_compile(0, log, 'wrong.dmb')

    def test_compiler_banner_rejection_vectors(self):
        for banner in ['DM compiler version 516.1682', 'prefix DM compiler version 516.1681',
                       'DM compiler version 516.16810', 'DM compiler version 516.1681 suffix',
                       'DM compiler version 516.1681\nDM compiler version 516.1681',
                       'DM compiler version 516.1681\nDM compiler version 516.1682', '']:
            with self.subTest(banner=banner), self.assertRaises(RuntimeError):
                validate_compile(0, self.compiler_log(banner=banner))

    def test_compiler_summary_rejection_vectors(self):
        for result in ['prefix probe.dmb - 0 errors, 0 warnings', 'probe.dmb - 0 errors, 0 warnings suffix',
                       'probe.dmb - 10 errors, 0 warnings', 'probe.dmb - 0 errors, 10 warnings',
                       'other.dmb - 0 errors, 0 warnings',
                       'probe.dmb - 0 errors, 0 warnings\nprobe.dmb - 0 errors, 0 warnings',
                       'probe.dmb - 1 error, 0 warnings\nprobe.dmb - 0 errors, 0 warnings',
                       'probe.dmb - 0 errors, 0 warnings\nwarning: injected',
                       'probe.dmb - 0 errors, 0 warnings (unbounded contamination)', '']:
            with self.subTest(result=result), self.assertRaises(RuntimeError):
                validate_compile(0, self.compiler_log(result=result))
        for exit_code, log in [(1, self.compiler_log()), (0, 'x' * (MAX_COMPILE_LOG + 1)),
                               (0, 'probe.dmb - 0 errors, 0 warnings\nDM compiler version 516.1681')]:
            with self.subTest(exit_code=exit_code, length=len(log)), self.assertRaises(RuntimeError):
                validate_compile(exit_code, log)

    def test_fatal_diagnostics_reject_compile_positive_and_expected_control(self):
        receipt = self.receipt(maxz=2, checks=22, default_refusal=0, existing_plane=0)
        for diagnostic in ['OOM', 'out of memory', 'Access violation', 'CRASH', 'crashed']:
            with self.subTest(diagnostic=diagnostic):
                with self.assertRaises(RuntimeError):
                    validate_compile(0, self.compiler_log() + diagnostic)
                with self.assertRaises(RuntimeError):
                    validate_native(0, diagnostic, 'PASS: new-z budget', self.receipt(), None)
                with self.assertRaises(RuntimeError):
                    validate_native(0, diagnostic, 'FAIL: default unmeasured allocation preserves grid', receipt, 'memory-admission')

    def test_complete_positive(self):
        validate_native(0, '', 'PASS: new-z budget', self.receipt(), None)

    def test_success_cannot_hide_nonzero_exit_or_diagnostic(self):
        for exit_code, text in [(1, ''), (0, 'runtime error: injected'), (0, 'BUG: injected'), (0, 'Bad ref')]:
            with self.subTest(exit_code=exit_code, text=text), self.assertRaises(RuntimeError):
                validate_native(exit_code, text, 'PASS: new-z budget', self.receipt(), None)

    def test_version_port_and_incomplete_checks_rejected(self):
        for changed in [dict(byond_build=1682), dict(port=1234), dict(checks=3), dict(default_refusal=0), dict(existing_plane=0), dict(maxz=2)]:
            with self.subTest(changed=changed), self.assertRaises(RuntimeError):
                validate_native(0, '', 'PASS: new-z budget', self.receipt(**changed), None)

    def test_control_requires_exact_intended_failure(self):
        receipt = self.receipt(maxz=2, checks=22, default_refusal=0, existing_plane=0)
        validate_native(0, '', 'FAIL: default unmeasured allocation preserves grid', receipt, 'memory-admission')
        for result, diagnostic in [('PASS: new-z budget', ''), ('FAIL: unrelated', ''), ('FAIL: default unmeasured allocation preserves grid', 'runtime error: unrelated')]:
            with self.subTest(result=result, diagnostic=diagnostic), self.assertRaises(RuntimeError):
                validate_native(0, diagnostic, result, receipt, 'memory-admission')


if __name__ == '__main__':
    unittest.main()
