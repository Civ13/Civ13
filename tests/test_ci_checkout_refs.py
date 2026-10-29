"""Exact-event shallow preparation and failed-selection regression controls."""
import ast
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
    def test_unselected_evidence_never_hides_a_fixture(self):
        workflow = (ROOT / '.github/workflows/test.yml').read_text(encoding='utf-8')
        build = workflow.split('\n  build:\n', 1)[1].split('\n  ci-required:\n', 1)[0]
        evidence = workflow.split('\n  evidence-checker:\n', 1)[1].split('\n  extraction-instances:\n', 1)[0]
        def condition(block, name):
            step = block.split('      - name: ' + name + '\n', 1)[1].split('\n      - ', 1)[0]
            return next(line.strip() for line in step.splitlines() if line.startswith('        if: '))
        self.assertEqual(condition(evidence, 'Explain unselected evidence fixtures'),
                         condition(build, 'Check out simple compilation source'))
        self.assertEqual(condition(evidence, 'Check out selected evidence sources and history'),
                         condition(build, 'Check out history for selected or manual fixtures'))
        self.assertIn('this job did not execute native or source fixtures', evidence)
        self.assertIn("coverage: ${{ steps.no_evidence.outputs.coverage || 'selected_or_unknown' }}", evidence)
        self.assertIn("echo 'coverage=not_selected' >> \"$GITHUB_OUTPUT\"", evidence)

        def require_closed_guards(section):
            self.assertEqual(re.findall(r'^      - (?!name:)[^\n]*', section, re.M), [])
            steps = re.split(r'\n      - name: ', section)[1:]
            fixtures = [x for x in steps if not x.startswith(('Explain unselected evidence fixtures\n',
                                                               'Check out selected evidence sources and history\n'))]
            self.assertGreaterEqual(len(fixtures), 40)
            for step in fixtures:
                guards = [line.strip()[4:] for line in step.splitlines() if line.startswith('        if: ')]
                self.assertEqual(len(guards), 1, step.splitlines()[0])
                expression = guards[0]
                roof = "(github.event_name == 'pull_request' && github.event.action != 'edited' && needs.changes.outputs.game == 'true' && contains(github.event.pull_request.labels.*.name, format('roof-ci:{0}', github.event.pull_request.head.sha)))"
                expression = expression.replace(roof, 'False')
                expression = expression.replace("needs.changes.outputs.extensive == 'true'", 'False')
                expression = re.sub(r"contains\(fromJSON\(needs\.changes\.outputs\.new_tests \|\| '\[\]'\), '[a-zA-Z0-9_./-]+'\)", 'False', expression)
                expression = re.sub(r'inputs\.(?:save_latency_regressions|protected_sleep_regressions|persistence_integration_regressions) == true', 'False', expression)
                expression = expression.replace('||', ' or ')
                parsed = ast.parse(expression, mode='eval')
                for node in ast.walk(parsed):
                    self.assertIsInstance(node, (ast.Expression, ast.BoolOp, ast.Or, ast.Constant))
                    if isinstance(node, ast.Constant):
                        self.assertIs(node.value, False)
                self.assertFalse(eval(compile(parsed, '<unselected fixture>', 'eval'), {'__builtins__': {}}, {}))

        require_closed_guards(evidence)
        guard = "needs.changes.outputs.extensive == 'true' || contains(fromJSON(needs.changes.outputs.new_tests || '[]'), 'tests/aotd_map')"
        self.assertIn(guard, evidence)
        with self.assertRaises((AssertionError, SyntaxError)):
            require_closed_guards(evidence.replace(guard, guard + ' || true', 1))

    def test_build_checkout_conditions_partition_simple_and_fixture_events(self):
        workflow = (ROOT / '.github/workflows/test.yml').read_text(encoding='utf-8')
        build = workflow.split('\n  build:\n', 1)[1].split('\n  ci-required:\n', 1)[0]
        expressions = []
        for name in ('Check out simple compilation source', 'Check out history for selected or manual fixtures'):
            block = build.split('      - name: ' + name + '\n', 1)[1].split('\n      - ', 1)[0]
            expressions.append(next(line.strip()[4:] for line in block.splitlines() if line.startswith('        if: ')))
        self.assertIn('fetch-depth: 1', build)
        self.assertIn('fetch-depth: 0', build)
        self.assertIn('Prepare simple compilation comparison commit', build)
        receipt = build.split('      - name: Record compilation outcome and source receipts\n', 1)[1].split('\n      - ', 1)[0]
        self.assertIn("steps.simple_checkout.outcome == 'success' && steps.simple_prepare.outcome == 'success' || steps.history_checkout.outcome == 'success'", receipt)
        self.assertIn('Compilation receipt did not complete', receipt)
        upload = build.split('      - name: Retain compiler diagnostics and source receipts including failures\n', 1)[1].split('\n      - ', 1)[0]
        self.assertIn("steps.compile_receipt.outcome != 'skipped' && steps.compile_receipt.outcome != ''", upload)
        for event, extensive, new_tests, labels, expected in (
                ('pull_request', 'false', '[]', '[]', 'shallow'),
                ('push', 'false', '[]', 'null', 'shallow'),
                ('pull_request', 'false', '[]', '["roof-ci:head"]', 'history'),
                ('pull_request', 'false', '["tests/fixture"]', '[]', 'history'),
                ('pull_request', 'true', '[]', '[]', 'history'),
                ('workflow_dispatch', 'false', '[]', 'null', 'history'),
                ('pull_request', 'false', '', '[]', 'history'),
                ('pull_request', 'false', '[]', 'null', 'history')):
            values = dict(event=event, extensive=extensive, new_tests=new_tests, labels=labels)
            outcomes = []
            for expression in expressions:
                for old, new in (('toJSON(github.event.pull_request.labels)', 'labels'),
                                 ('github.event_name', 'event'),
                                 ('needs.changes.outputs.extensive', 'extensive'),
                                 ('needs.changes.outputs.new_tests', 'new_tests'),
                                 ('&&', ' and '), ('||', ' or ')):
                    expression = expression.replace(old, new)
                parsed = ast.parse(expression, mode='eval')
                for node in ast.walk(parsed):
                    self.assertIsInstance(node, (ast.Expression, ast.BoolOp, ast.And, ast.Or,
                                                 ast.Compare, ast.Eq, ast.NotEq, ast.Name,
                                                 ast.Load, ast.Constant))
                    if isinstance(node, ast.Name):
                        self.assertIn(node.id, values)
                outcomes.append(bool(eval(compile(parsed, '<checkout admission>', 'eval'), {'__builtins__': {}}, values)))
            with self.subTest(values=values):
                self.assertEqual(outcomes, [expected == 'shallow', expected == 'history'])

    def test_shallow_build_never_runs_fixture_steps(self):
        workflow = (ROOT / '.github/workflows/test.yml').read_text(encoding='utf-8')
        build = workflow.split('\n  build:\n', 1)[1].split('\n  ci-required:\n', 1)[0]
        steps = re.split(r'\n      - ', build)[1:]
        # Only the compiler and its plumbing may run on the simple path.
        plumbing = {
            'Require successful change selection', 'Explain compilation skip',
            'Check out simple compilation source', 'Prepare simple compilation comparison commit',
            'Check out history for selected or manual fixtures', 'Read reviewed BYOND archive cache identity',
            'Restore exact BYOND archive only', 'Compile selected exact-head game',
            'Save verified BYOND archive after successful compilation',
            'Record compilation outcome and source receipts',
            'Retain compiler diagnostics and source receipts including failures',
            'Explain opt-in runtime coverage',
        }
        named = {}
        by_id = {}
        for step in steps:
            first = step.splitlines()[0]
            if first.startswith('uses: '):
                self.assertEqual(first, 'uses: actions/download-artifact@d3f86a106a0bac45b974a628896c90dbdf5c8093')
                continue
            self.assertTrue(first.startswith('name: '), first)
            name = first[6:]
            self.assertNotIn(name, named)
            named[name] = step
            ids = re.findall(r'^        id: ([\w-]+)$', step, re.M)
            self.assertLessEqual(len(ids), 1)
            if ids:
                self.assertNotIn(ids[0], by_id)
                by_id[ids[0]] = name
        self.assertTrue(plumbing <= named.keys())
        self.assertEqual(named['Explain opt-in runtime coverage'].count('\n        run: echo '), 1)
        self.assertEqual(len(named['Explain opt-in runtime coverage'].splitlines()), 3)
        self.assertGreaterEqual(len(named) - len(plumbing), 140)

        def fixture_cannot_run(name, checking):
            self.assertNotIn(name, plumbing, name)
            self.assertNotIn(name, checking, name)
            checking = checking | {name}
            step = named[name]
            guards = re.findall(r'^        if: (.*)$', step, re.M)
            self.assertEqual(len(guards), 1, name)
            expression = guards[0]
            # Compilation may succeed on the shallow path; treat it as true,
            # so it cannot by itself make a fixture guard pass this check.
            expression = expression.replace("steps.compile.outcome == 'success'", 'True')
            expression = expression.removeprefix('${{').removesuffix('}}').strip()
            for ref in set(re.findall(r'steps\.([\w-]+)\.', expression)):
                self.assertIn(ref, by_id, name)
                fixture_cannot_run(by_id[ref], checking)
            expression = re.sub(r"steps\.[\w-]+\.(?:outcome != 'skipped'|outputs\.started == 'true')", 'False', expression)
            expression = re.sub(r"contains\(fromJSON\(needs\.changes\.outputs\.new_tests \|\| '\[\]'\), '[a-zA-Z0-9_./-]+'\)", 'False', expression)
            expression = expression.replace("needs.changes.outputs.extensive == 'true'", 'False')
            expression = expression.replace('(inputs.world_save_regressions || inputs.save_latency_regressions) == true', 'False')
            expression = re.sub(r'inputs\.[\w_]+(?: == true)?', 'False', expression)
            expression = expression.replace("github.event_name == 'workflow_dispatch'", 'False')
            expression = expression.replace("github.event_name == 'pull_request'", 'True')
            expression = expression.replace("github.event.action != 'edited'", 'True')
            expression = expression.replace("needs.changes.outputs.game == 'true'", 'True')
            expression = expression.replace("needs.changes.result == 'success'", 'True')
            expression = expression.replace("contains(github.event.pull_request.labels.*.name, format('roof-ci:{0}', github.event.pull_request.head.sha))", 'False')
            expression = expression.replace('always()', 'True').replace('!cancelled()', 'True').replace('&&', ' and ').replace('||', ' or ')
            parsed = ast.parse(expression, mode='eval')
            for node in ast.walk(parsed):
                self.assertIsInstance(node, (ast.Expression, ast.BoolOp, ast.And, ast.Or, ast.Constant), f'{name}: {expression}')
                if isinstance(node, ast.Constant):
                    self.assertIsInstance(node.value, bool)
            self.assertFalse(eval(compile(parsed, '<shallow build fixture>', 'eval'), {'__builtins__': {}}, {}), name)

        for name in named.keys() - plumbing:
            fixture_cannot_run(name, set())
        name = 'Compile Art of the Deal with current game declarations'
        original = named[name]
        named[name] = original.replace("needs.changes.outputs.extensive == 'true'", 'true', 1)
        with self.assertRaises((AssertionError, SyntaxError)):
            fixture_cannot_run(name, set())

    def test_build_rejects_missing_and_invalid_suite_output(self):
        workflow = (ROOT / '.github/workflows/test.yml').read_text(encoding='utf-8')
        build = workflow.split('\n  build:\n', 1)[1].split('\n  ci-required:\n', 1)[0]
        block = build.split('      - name: Require successful change selection\n', 1)[1].split('\n      - ', 1)[0]
        script = '\n'.join(line[10:] for line in block.split('        run: |\n', 1)[1].splitlines())
        bash = r'C:\Program Files\Git\bin\bash.exe' if os.name == 'nt' else shutil.which('bash')
        self.assertTrue(bash and Path(bash).is_file(), 'Git Bash or bash is required')
        if os.name == 'nt':
            import sys
            script = script.replace('python3 -c ', "'" + Path(sys.executable).as_posix() + "' -c ")
        for value, expected in (('[]', 0), ('["tests/sawmill"]', 0), ('', 1), ('null', 1), ('[1]', 1), ('[""]', 1)):
            env = dict(os.environ, SELECTION_RESULT='success', GAME_SELECTION='true',
                       EXTENSIVE_SELECTION='false', GATING_SELECTION='1', NEW_TEST_SELECTION=value)
            result = subprocess.run([bash, '-e', '-c', script], env=env, capture_output=True, text=True, timeout=10)
            with self.subTest(value=value):
                self.assertEqual(result.returncode == 0, expected == 0)

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

    def test_manual_baseline_and_aggregate_prepare_separate_exact_base_checkouts(self):
        workflow = (ROOT / '.github/workflows/test.yml').read_text(encoding='utf-8')
        comparison = "${{ github.event_name == 'workflow_dispatch' && inputs.comparison_base || github.event.pull_request.base.sha || github.event.before || '' }}"
        baseline_job = workflow.split('\n  baseline:\n', 1)[1].split('\n  evidence-checker:\n', 1)[0]
        aggregate_job = workflow.split('\n  ci-required:\n', 1)[1]
        for job in (baseline_job, aggregate_job):
            preparation = job.split('      - name: Prepare exact comparison commit\n', 1)[1].split('\n      - ', 1)[0]
            self.assertIn('          BASE_REF: ' + comparison + '\n', preparation)
            self.assertIn('          HEAD_REF: ${{ github.event.pull_request.head.sha || github.sha }}\n', preparation)
            self.assertIn('scripts/ci_checkout_refs.py --head "$HEAD_REF" --base "$BASE_REF" --event "$EVENT_NAME"', preparation)
            self.assertIn('          CI_BASE: ' + comparison + '\n', job)
        with tempfile.TemporaryDirectory(prefix='manual-ci-refs-') as directory:
            root = Path(directory); origin = root / 'origin'; origin.mkdir()
            def git(*args, cwd=origin):
                return subprocess.check_output(['git', *args], cwd=cwd, stderr=subprocess.PIPE, text=True).strip()
            git('init', '-q'); git('config', 'user.email', 'fixture@example.invalid'); git('config', 'user.name', 'CI fixture')
            (origin / 'README.md').write_text('base', encoding='utf-8')
            git('add', '.'); git('commit', '-qm', 'base'); base = git('rev-parse', 'HEAD')
            (origin / 'README.md').write_text('head', encoding='utf-8')
            git('commit', '-qam', 'head'); head = git('rev-parse', 'HEAD')
            previous = os.getcwd()
            try:
                for name in ('baseline', 'aggregate'):
                    clone = root / name
                    git('clone', '-q', '--depth=1', origin.as_uri(), str(clone))
                    self.assertNotEqual(subprocess.run(['git', 'cat-file', '-e', base + '^{commit}'], cwd=clone, capture_output=True).returncode, 0)
                    os.chdir(clone)
                    refs.prepare(head, base, 'workflow_dispatch')
                    self.assertEqual(git('rev-parse', 'HEAD', cwd=clone), head)
                    eligibility = {'action': None, 'metadata_valid': True,
                                   **{key: {'eligible': key != 'gating', 'reason': 'manual fixture'}
                                      for key in ('compile', 'native', 'gating')}}
                    with patch.object(baseline, 'ROOT', clone), patch.dict(os.environ, {'GITHUB_RUN_ID': '123', 'GITHUB_RUN_ATTEMPT': '2'}):
                        receipt = baseline.selection_receipt(base, head, False, False, [], 'manual', 'workflow_dispatch', eligibility)
                        import json
                        receipt_path = clone / 'selection.json'
                        receipt_path.write_text(json.dumps(receipt), encoding='utf-8')
                        self.assertEqual(baseline.load_selection(receipt_path, head, base, selection_attempt='2'), receipt)
                        with self.assertRaisesRegex(ValueError, 'Selection provenance mismatch'):
                            baseline.load_selection(receipt_path, head, head, selection_attempt='2')
                        with self.assertRaisesRegex(ValueError, 'run_attempt'):
                            baseline.load_selection(receipt_path, head, base, selection_attempt='1')
                    self.assertEqual(receipt['requested_base'], base)
                    self.assertEqual(receipt['head'], head)
                    self.assertEqual(receipt['comparison']['status'], 'available')
                    self.assertEqual(receipt['comparison']['paths'], ['README.md'])
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

    def test_failed_build_step_writes_verdict_and_fails(self):
        workflow = (ROOT / '.github/workflows/test.yml').read_text(encoding='utf-8')
        block = workflow.split('      - name: Record failed build verdict\n', 1)[1].split('\n      - ', 1)[0]
        self.assertIn("if: always() && needs.changes.result == 'success' && needs.baseline.result == 'success' && needs.build.result != 'success'", block)
        script = '\n'.join(line[10:] for line in block.split('        run: |\n', 1)[1].splitlines())
        bash = r'C:\Program Files\Git\bin\bash.exe' if os.name == 'nt' else shutil.which('bash')
        self.assertTrue(bash and Path(bash).is_file(), 'Git Bash or bash is required')
        with tempfile.TemporaryDirectory(prefix='ci-build-failed-') as directory:
            env = dict(os.environ, BUILD_RESULT='failure')
            result = subprocess.run([bash, '-c', script], cwd=directory, env=env, capture_output=True, text=True, timeout=10)
            self.assertNotEqual(result.returncode, 0)
            import json
            verdict = json.loads((Path(directory) / '.ci/aggregate/build-failed.json').read_text())
            self.assertEqual(verdict, {'status': 'failed', 'reason': 'build job did not succeed', 'result': 'failure'})
            env['BUILD_RESULT'] = 'unexpected"value'
            result = subprocess.run([bash, '-c', script], cwd=directory, env=env, capture_output=True, text=True, timeout=10)
            self.assertNotEqual(result.returncode, 0)
            verdict = json.loads((Path(directory) / '.ci/aggregate/build-failed.json').read_text())
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
