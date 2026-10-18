"""Offline oracle checks; these tests never launch a compiler/runtime."""
import unittest
from run import validate_native


class RunnerEvidenceTests(unittest.TestCase):
    def receipt(self, **updates):
        result = dict(byond_version=516, byond_build=1681, port=0, checks=61,
                      maxz=9, default_refusal=1, existing_plane=1)
        result.update(updates)
        return result

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
        validate_native(0, '', 'FAIL: default unmeasured roof preserves paid builder and grid', receipt, 'memory-admission')
        for result, diagnostic in [('PASS: new-z budget', ''), ('FAIL: unrelated', ''), ('FAIL: default unmeasured roof preserves paid builder and grid', 'runtime error: unrelated')]:
            with self.subTest(result=result, diagnostic=diagnostic), self.assertRaises(RuntimeError):
                validate_native(0, diagnostic, result, receipt, 'memory-admission')


if __name__ == '__main__':
    unittest.main()
