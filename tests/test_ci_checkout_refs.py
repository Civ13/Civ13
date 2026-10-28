"""Exact-event shallow preparation and failed-selection regression controls."""
import importlib.util
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('checkout_refs', ROOT / 'scripts/ci_checkout_refs.py')
refs = importlib.util.module_from_spec(spec)
spec.loader.exec_module(refs)
spec = importlib.util.spec_from_file_location('checkout_baseline', ROOT / 'scripts/ci_baseline.py')
baseline = importlib.util.module_from_spec(spec)
spec.loader.exec_module(baseline)


class CheckoutRefsTests(unittest.TestCase):
    def test_real_depth_one_checkout_fetches_exact_base_and_preserves_head(self):
        with tempfile.TemporaryDirectory(prefix='ci-refs-') as directory:
            origin, clone = Path(directory) / 'origin', Path(directory) / 'clone'
            origin.mkdir()
            def run(*args, cwd=origin):
                return subprocess.check_output(['git', *args], cwd=cwd, stderr=subprocess.PIPE, text=True).strip()
            run('init', '-q')
            run('config', 'user.email', 'fixture@example.invalid')
            run('config', 'user.name', 'CI fixture')
            (origin / 'README.md').write_text('base', encoding='utf-8')
            run('add', '.')
            run('commit', '-qm', 'base')
            base = run('rev-parse', 'HEAD')
            (origin / 'README.md').write_text('head', encoding='utf-8')
            run('commit', '-qam', 'docs')
            head = run('rev-parse', 'HEAD')
            run('clone', '-q', '--depth=1', origin.as_uri(), str(clone))
            self.assertEqual(run('rev-parse', '--is-shallow-repository', cwd=clone), 'true')
            self.assertNotEqual(subprocess.run(['git', 'cat-file', '-e', base + '^{commit}'], cwd=clone).returncode, 0)
            previous = os.getcwd()
            try:
                os.chdir(clone)
                refs.prepare(head, base, 'pull_request')
                self.assertEqual(run('rev-parse', 'HEAD', cwd=clone), head)
                with patch.object(baseline, 'ROOT', clone):
                    plan = baseline.selection_receipt(base, head, False, False, [], 'docs', 'pull_request')
                self.assertEqual(plan['comparison']['status'], 'available')
                self.assertEqual(plan['comparison']['paths'], ['README.md'])
                refs.prepare(head, '0' * 40, 'push')
                with self.assertRaises(ValueError):
                    refs.prepare(head, '', 'pull_request')
                with self.assertRaises(ValueError):
                    refs.prepare('1' * 40, base, 'pull_request')
                with self.assertRaises(RuntimeError):
                    refs.prepare(head, '2' * 40, 'pull_request')
            finally:
                os.chdir(previous)

    def test_fetch_timeout_fails_closed(self):
        with patch.object(refs, 'git', side_effect=subprocess.TimeoutExpired('git', 90)):
            with self.assertRaises(subprocess.TimeoutExpired):
                refs.prepare('1' * 40, '2' * 40, 'pull_request')

    def test_failed_selection_step_writes_verdict_and_fails(self):
        workflow = (ROOT / '.github/workflows/test.yml').read_text(encoding='utf-8')
        block = workflow.split('      - name: Record failed selection verdict\n', 1)[1].split('\n      - ', 1)[0]
        script = '\n'.join(line[10:] for line in block.split('        run: |\n', 1)[1].splitlines())
        bash = r'C:\Program Files\Git\bin\bash.exe' if os.name == 'nt' else shutil.which('bash')
        self.assertTrue(bash and Path(bash).is_file(), 'Git Bash or bash is required')
        with tempfile.TemporaryDirectory(prefix='ci-selection-failed-') as directory:
            result = subprocess.run([bash, '-c', script], cwd=directory, capture_output=True, text=True, timeout=10)
            self.assertNotEqual(result.returncode, 0)
            import json
            verdict = json.loads((Path(directory) / '.ci/aggregate/selection-failed.json').read_text())
            self.assertEqual(verdict, {'status': 'failed', 'reason': 'selection job did not succeed'})

    def test_failed_baseline_step_writes_verdict_and_fails(self):
        workflow = (ROOT / '.github/workflows/test.yml').read_text(encoding='utf-8')
        block = workflow.split('      - name: Record failed baseline verdict\n', 1)[1].split('\n      - ', 1)[0]
        self.assertIn("if: always() && needs.changes.result == 'success' && needs.baseline.result != 'success'", block)
        script = '\n'.join(line[10:] for line in block.split('        run: |\n', 1)[1].splitlines())
        bash = r'C:\Program Files\Git\bin\bash.exe' if os.name == 'nt' else shutil.which('bash')
        self.assertTrue(bash and Path(bash).is_file(), 'Git Bash or bash is required')
        with tempfile.TemporaryDirectory(prefix='ci-baseline-failed-') as directory:
            env = dict(os.environ, BASELINE_RESULT='cancelled')
            result = subprocess.run([bash, '-c', script], cwd=directory, env=env, capture_output=True, text=True, timeout=10)
            self.assertNotEqual(result.returncode, 0)
            import json
            verdict = json.loads((Path(directory) / '.ci/aggregate/baseline-failed.json').read_text())
            self.assertEqual(verdict, {'status': 'failed', 'reason': 'baseline job did not succeed', 'result': 'cancelled'})
            env['BASELINE_RESULT'] = 'unexpected"value'
            result = subprocess.run([bash, '-c', script], cwd=directory, env=env, capture_output=True, text=True, timeout=10)
            self.assertNotEqual(result.returncode, 0)
            verdict = json.loads((Path(directory) / '.ci/aggregate/baseline-failed.json').read_text())
            self.assertEqual(verdict['result'], 'unknown')

    def test_workflow_preserves_failed_verdict_and_guarded_downloads(self):
        selection = (ROOT / '.github/workflows/ci-selection.yml').read_text(encoding='utf-8')
        workflow = (ROOT / '.github/workflows/test.yml').read_text(encoding='utf-8')
        aggregate = workflow.split('\n  ci-required:\n', 1)[1]
        self.assertIn('fetch-depth: 1', selection)
        self.assertIn('scripts/ci_checkout_refs.py', selection)
        self.assertIn('if: needs.changes.result == \'success\'', aggregate)
        self.assertIn('fetch-depth: 1', aggregate)
        self.assertIn("if: always() && needs.changes.result != 'success'", aggregate)
        verdict = aggregate.split('      - name: Record failed selection verdict\n', 1)[1].split('\n      - ', 1)[0]
        self.assertIn('selection-failed.json', verdict)
        self.assertIn('exit 1', verdict)
        self.assertNotIn('fromJSON(needs.changes.outputs.new_tests)', workflow)
        build = workflow.split('\n  build:\n', 1)[1].split('\n  ci-required:\n', 1)[0]
        self.assertIn("    if: always() && !cancelled() && (needs.changes.result != 'success' || needs.changes.outputs.skip_duplicate != 'true'", build)
        self.assertIn("if: always() && needs.changes.result == 'success'", build)
        self.assertIn('test "$SELECTION_RESULT" = success', build)
        self.assertNotIn('if: always()\n', build)
        baseline = re.split(r'\n  [\w-]+:\n', workflow.split('\n  baseline:\n', 1)[1], 1)[0]
        self.assertIn('fetch-depth: 1', baseline)
        self.assertIn('scripts/ci_checkout_refs.py', baseline)
        self.assertIn("if: always() && steps.baseline.outcome != 'skipped' && steps.baseline.outcome != ''", baseline)
        self.assertIn('Baseline execution did not complete', baseline)
        for name in ('evidence-checker', 'build'):
            block = re.split(r'\n  [\w-]+:\n', workflow.split('\n  ' + name + ':\n', 1)[1], 1)[0]
            self.assertIn('fetch-depth: 0', block)


if __name__ == '__main__':
    unittest.main()
