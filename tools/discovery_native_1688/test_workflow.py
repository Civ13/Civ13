"""Pure offline hosted-policy and synthetic retention tests. No dispatch or subprocess."""
from pathlib import Path
import re
import tempfile
import unittest
from unittest.mock import patch
from audit_offline import install
install()
import collect_evidence as collector

WORKFLOW = Path(__file__).absolute().parents[2] / '.github/workflows/discovery-native-1688-once.yml'
HEAD = '9c54e1b57097035d51c35e4ea9cb755e7aa12a92'
TREE = '0ad1eda47a01440c1839b836f6e313d4e3b481a1'
BRANCH = 'codex/discovery-native-1688-9c54e1-attempt1'


class WorkflowTests(unittest.TestCase):
    def test_exact_controller_seal_and_one_shot_grant(self):
        from backend_proposal import controller_hashes
        from prepare import canonical, digest
        text = WORKFLOW.read_text()
        self.assertIn("if seal != '" + digest(canonical(controller_hashes())) + "':", text)
        self.assertIn(".open('xb')", text)
        self.assertIn('--grant "$RUNNER_TEMP/discovery-1688-grant.json"', text)
        self.assertIn('phases=12, compiler_phases=5, daemon_phases=7, aggregate_wall_seconds=1200', text)

    def test_one_initial_branch_first_attempt(self):
        text = WORKFLOW.read_text()
        self.assertIn('      - ' + BRANCH + '\n', text)
        for gate in ("github.repository == 'Civ13/Civ13'", 'github.event.created == true',
                     'github.run_attempt == 1', "github.ref == 'refs/heads/" + BRANCH + "'"):
            self.assertIn(gate, text)
        self.assertNotIn('workflow_dispatch:', text)
        self.assertNotIn('pull_request', text)
        self.assertIn('  cancel-in-progress: false\n', text)

    def test_exact_source_single_parent_and_archive(self):
        text = WORKFLOW.read_text()
        self.assertIn('test "$(git -C runner rev-parse HEAD^)" = ' + HEAD, text)
        self.assertIn('test "$(git -C runner rev-list --parents -n 1 HEAD | wc -w)" -eq 2', text)
        self.assertIn('test "$(git -C source rev-parse HEAD)" = ' + HEAD, text)
        self.assertIn('test "$(git -C source rev-parse \'HEAD^{tree}\')" = ' + TREE, text)
        self.assertIn('58e60ef0263cba1f1af04c0a135d1a14f486d799', text)
        self.assertIn('738fecfaf195bfbe31ed68fa4f0e4d05b9912248', text)
        self.assertIn('--source repository-release', text)
        self.assertIn('16278f318cdeb4b77c57868dd7135032fde717ea6226269d22b2a1a50968e7f9', text)
        self.assertIn('sha256sum --check', text)

    def test_read_only_hosted_pinned_actions_no_secrets(self):
        text = WORKFLOW.read_text()
        self.assertEqual(text.count('          persist-credentials: false'), 2)
        self.assertIn('permissions:\n  contents: read\n', text)
        self.assertNotIn('secrets.', text)
        self.assertNotIn('self-hosted', text)
        self.assertIn('runs-on: ubuntu-22.04', text)
        for action in re.findall(r'uses: (\S+)', text):
            self.assertRegex(action, r'@[0-9a-f]{40}$')

    def test_limits_native_flag_and_bounded_retention_only(self):
        text = WORKFLOW.read_text()
        self.assertIn('    timeout-minutes: 40\n', text)
        self.assertIn('        timeout-minutes: 21\n', text)
        self.assertEqual(text.count('            --reviewed-native\n'), 1)
        self.assertNotIn('--source-export', text)
        self.assertIn('DISCOVERY_TEST_SOURCE: ${{ github.workspace }}/source', text)
        self.assertIn('          path: ${{ runner.temp }}/discovery-1688-retained/\n', text)
        self.assertEqual(text.count('        if: always()'), 2)
        self.assertIn('          retention-days: 7\n', text)

    def test_unchanged_source_regressions_before_native(self):
        text = WORKFLOW.read_text()
        for command in ('python -I -S -B -m unittest discover -s tests/character_discoveries -p \'test_*.py\' -v',
                        'python -I -S -B -m unittest discover -s tests -p \'test_ci_regression_policy.py\' -v'):
            self.assertIn(command, text)
            self.assertLess(text.index(command), text.index('Execute reviewed discovery'))
        self.assertIn('        working-directory: source\n', text)
        self.assertEqual(text.count('ulimit -f 4096; timeout -k 5 110 python'), 2)
        self.assertIn('exit "$status"', text)
        self.assertIn('discovery-source-tests.log', text)
        self.assertIn('ci-policy-tests.log', text)


class RetentionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.evidence = self.root / 'evidence'
        self.acquisition = self.root / 'acquisition'
        self.tooling = self.root / 'tooling'
        for p in (self.evidence, self.acquisition, self.tooling): p.mkdir()
        self.output = self.root / 'retained'

    def write(self, name, data=b'bounded evidence'):
        p = self.evidence / name
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(data)
        return p

    def collect(self):
        return collector.collect(self.evidence, self.acquisition, self.tooling, self.output)

    def test_expected_layout_and_no_saves_binaries_or_private_home(self):
        wanted = ['result.json', 'prepared/preparation.json', 'runs/result.json',
                  'runs/baseline-writer/process.json', 'runs/baseline-writer/retired-inputs.json',
                  'runs/baseline-writer/nested/extra.log',
                  'prepared/generated/baseline/discovery1688-probe.dm']
        for name in wanted: self.write(name)
        denied = ['runs/baseline-writer/discovery-mind.sav', 'runs/baseline-writer/discovery1688.dmb',
                  'runs/baseline-writer/discovery1688.rsc', 'runs/baseline-writer/home/.byond/private.log',
                  'runs/baseline-compile/code/old.log']
        for name in denied: self.write(name, b'DO NOT RETAIN')
        report = self.collect()
        self.assertFalse(report['rejected'])
        self.assertEqual(len(report['files']), len(wanted))
        self.assertTrue(report['missing'])
        self.assertFalse(report['native_execution_performed_by_collector'])
        self.assertNotIn(b'DO NOT RETAIN', b''.join(p.read_bytes() for p in self.output.rglob('*') if p.is_file()))

    def test_all_original_inputs_and_source_regression_logs_retained(self):
        for name in collector.INPUTS:
            self.write('prepared/inputs/' + name, name.encode())
        for name in ('discovery-source-tests.log', 'ci-policy-tests.log'):
            (self.acquisition / name).write_text('unchanged source test output')
        report = self.collect()
        retained = {row['path']: row for row in report['files']}
        self.assertEqual(len(collector.INPUTS), 6)
        self.assertEqual(len(retained), 8)
        for name in collector.INPUTS:
            self.assertIn('inputs/' + name, retained)
            self.assertEqual((self.output / 'inputs' / name).read_bytes(), name.encode())
        self.assertFalse(report['rejected'])

    def test_oversize_receipt_retained_as_rejection(self):
        self.write('result.json', b'12345')
        with patch.object(collector, 'MAX_FILE', 4): report = self.collect()
        self.assertEqual(report['status'], 'partial-evidence-rejected')
        self.assertTrue(report['rejected'])
        self.assertTrue((self.output / 'retention.json').is_file())

    def test_link_and_hardlink_refused(self):
        target = self.write('target', b'private')
        (self.evidence / 'result.json').symlink_to(target)
        self.write('prepared/target', b'private')
        (self.evidence / 'prepared/preparation.json').hardlink_to(self.evidence / 'prepared/target')
        report = self.collect()
        self.assertEqual(len(report['rejected']), 2)
        self.assertEqual(report['files'], [])

    def test_fresh_unlinked_output_required(self):
        self.output.symlink_to(self.evidence, target_is_directory=True)
        with self.assertRaises(ValueError): self.collect()

    def test_extra_log_symlink_directory_rejected(self):
        (self.root / 'foreign').mkdir()
        self.write('runs/baseline-writer/process.log')
        (self.evidence / 'runs/baseline-writer/link').symlink_to(self.root / 'foreign', target_is_directory=True)
        report = self.collect()
        self.assertTrue(report['rejected'])
        self.assertEqual(len(report['files']), 1)

    def test_aggregate_limit_reserves_receipt(self):
        self.write('result.json', b'1234')
        with patch.object(collector, 'MAX_TOTAL', 1024**2 + 3): report = self.collect()
        self.assertTrue(report['rejected'])
        self.assertEqual(report['files'], [])


if __name__ == '__main__':
    unittest.main()
