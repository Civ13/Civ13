"""Whole parent workflow preservation and actual manual admission truth cases.

No GitHub request, subprocess, download or game launch is performed here.
The expression evaluator covers only the operators/functions in these fixtures;
actionlint independently checks GitHub expression syntax/types.
"""
import ast
import hashlib
import io
import importlib.util
import itertools
import json
import os
from pathlib import Path
import re
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
PARENT = (HERE / 'fixtures/test.f562.yml').read_text(encoding='utf-8')
WORKFLOW = HERE / 'proposed-test.yml'
if not WORKFLOW.exists():
    WORKFLOW = HERE.parents[2] / '.github/workflows/test.yml'
PROPOSED = WORKFLOW.read_text(encoding='utf-8')
OLD_INPUTS = tuple(re.findall(r'^      (\w+):$', PARENT.split('permissions:', 1)[0], re.M))
SHA = 'a' * 40


def jobs(text):
    body = text.split('\njobs:\n', 1)[1]
    starts = list(re.finditer(r'^  ([a-z][a-z0-9-]*):\n', body, re.M))
    return {m[1]: body[m.start(): starts[i+1].start() if i+1 < len(starts) else len(body)].rstrip()
            for i, m in enumerate(starts)}


def predicates(text):
    return [line.strip()[4:] for line in text.splitlines() if line.strip().startswith('if: ')]


def expression(source, context, *, raw=False):
    source = source.removeprefix('${{').removesuffix('}}').strip()
    token = re.compile(r"\s*(('[^']*')|&&|\|\||!=|==|!|[(),]|[0-9]+|[A-Za-z_][A-Za-z0-9_.-]*)")
    tokens = []; end = 0
    functions = {'always': lambda: True, 'cancelled': lambda: context.get('cancelled', False),
                 'contains': lambda container, value: value in container, 'fromJSON': json.loads}
    for match in token.finditer(source):
        if source[end:match.start()].strip():
            raise AssertionError('Unsupported predicate: ' + source)
        value = match[1]; end = match.end()
        if value in {'&&', '||', '!'}:
            tokens.append({'&&': 'and', '||': 'or', '!': 'not'}[value])
        elif value in {'true', 'false'}:
            tokens.append(value.title())
        elif value.isdecimal() or value[0] == "'" or value in {'(', ')', ',', '==', '!='} or value in functions:
            tokens.append(value)
        else:
            tokens.append('lookup(' + repr(value) + ')')
    if source[end:].strip():
        raise AssertionError('Unsupported predicate tail')
    code = ast.parse(' '.join(tokens), mode='eval')
    allowed = (ast.Expression, ast.BoolOp, ast.UnaryOp, ast.Compare, ast.Call, ast.Name,
               ast.Load, ast.Constant, ast.And, ast.Or, ast.Not, ast.Eq, ast.NotEq)
    assert all(isinstance(node, allowed) for node in ast.walk(code))
    result = eval(compile(code, '<workflow-predicate>', 'eval'), {'__builtins__': {}},
                  dict(functions, lookup=lambda name: context.get(name, '')))
    return result if raw else bool(result)


def policy_inputs():
    policy = {'enabled': True, 'allocated': True, 'run_id': 'bind-current-run', 'run_attempt': '1'}
    return dict.fromkeys(OLD_INPUTS, False) | {
        'opendream_store_only': True, 'opendream_store_selected_sha': SHA,
        'opendream_store_policy_json': json.dumps(policy),
        'opendream_store_policy_sha256': hashlib.sha256(
            json.dumps(policy, sort_keys=True, separators=(',', ':')).encode()).hexdigest()}


def admission_result(values, *, workflow=PROPOSED, **overrides):
    block = jobs(workflow)['opendream-store-admission'].split('        run: |\n', 1)[1]
    code = '\n'.join(line[10:] for line in block.splitlines())
    env = {'EVENT_NAME':'workflow_dispatch', 'INPUTS_JSON': json.dumps(values), 'SELECTED_SHA': SHA,
           'REPOSITORY': 'Civ13/Civ13','RUN_ATTEMPT': '1','GITHUB_OUTPUT': '/injected-output'} | overrides
    output = io.StringIO()
    class Writer:
        def __enter__(self): return output
        def __exit__(self, *args): return False
    result='success'
    with patch.dict(os.environ, env, clear=True), patch('builtins.open', return_value=Writer()):
        try:
            exec(compile(code, '<actual-admission-step>', 'exec'), {})
        except SystemExit as error:
            if error.code not in (None,0): result='failure'
        except (AssertionError, ValueError, TypeError):
            result='failure'
    raw=output.getvalue()
    if result=='failure': assert raw=='', 'Rejected admission must never publish outputs'
    return {'result':result,'only':{'only=true\n':'true','only=false\n':'false','':''}[raw]}


def admission(values, **overrides):
    return admission_result(values,**overrides)=={'result':'success','only':'true'}


def topology(workflow,event,values,*,game=False,extensive=False,offline='success',cancelled=False):
    # Model the documented status/ancestor gate, not just predicate truth. The
    # frozen CI counterexample checks that skipped ancestors suppress ordinary
    # default-success jobs even when their direct changes dependency succeeded.
    blocks=jobs(workflow); statuses={}; ancestors={}; context={'github.event_name':event,'cancelled':cancelled}
    context.update({'inputs.'+name:value for name,value in values.items()})
    for name,block in blocks.items():
        needs=re.search(r'^    needs: (.+)$',block,re.M)
        parents=needs[1].strip('[]').replace(' ','').split(',') if needs else []
        lineage=set(parents)
        for parent in parents: lineage.update(ancestors[parent])
        ancestors[name]=lineage
        gate=re.search(r'^    if: (.+)$',block,re.M)
        predicate=gate[1] if gate else 'true'
        status_override=bool(re.search(r'\b(always|cancelled|success|failure)\(',predicate))
        implicit_success=status_override or all(statuses[parent]=='success' for parent in lineage)
        should_run=implicit_success and expression(predicate,context)
        if name=='opendream-store-admission' and should_run and not cancelled:
            admitted=admission_result(values,workflow=workflow,EVENT_NAME=event)
            status=admitted['result']; context['needs.'+name+'.outputs.only']=admitted['only']
        else:
            status=('cancelled' if cancelled else offline if name=='opendream-store-offline' else 'success') if should_run else 'skipped'
        statuses[name]=status; context['needs.'+name+'.result']=status
        if name=='changes':
            context.update({'needs.changes.outputs.game':str(game).lower() if status=='success' else '',
                            'needs.changes.outputs.extensive':str(extensive).lower() if status=='success' else '',
                            'needs.changes.outputs.new_tests':'[]' if status=='success' else '[]'})
    return statuses


class WorkflowRouteTests(unittest.TestCase):
    def test_exact_parent_workflow_preserved_except_narrow_route_changes(self):
        self.assertEqual(hashlib.sha256(PARENT.encode()).hexdigest(),
                         'bed4ed1841b1fab13842c8f33a9b6432e161c161dbcfe8423795715463c49f18')
        before, after = jobs(PARENT), jobs(PROPOSED)
        self.assertEqual(set(before), {'changes', 'evidence-checker', 'extraction-instances', 'build'})
        self.assertEqual(set(after) - set(before), {'opendream-store-admission', 'opendream-store-recovery', 'opendream-store-offline'})
        for key in ('evidence-checker', 'extraction-instances'):
            projected = '\n'.join(line for line in after[key].splitlines()
                                  if key != 'evidence-checker' or not line.startswith('    timeout-minutes:'))
            self.assertEqual(before[key], projected)
        changes = after['changes'].splitlines()
        self.assertEqual('\n'.join(line for line in [changes[0]] + changes[3:] if not line.startswith('      selection_timeout_minutes:')), before['changes'])
        build = after['build'].splitlines()
        self.assertEqual('\n'.join([build[0]] + before['build'].splitlines()[1:3] + build[3:]), before['build'])
        old_header = PARENT.split('\njobs:\n', 1)[0]
        new_header = PROPOSED.split('\njobs:\n', 1)[0]
        start = new_header.index('      opendream_store_only:')
        stop = new_header.index('\npermissions:', start)
        self.assertEqual(new_header[:start].rstrip() + '\n' + new_header[stop:], old_header.rstrip())

    def test_all_163_parent_predicates_retain_truth_across_normal_contexts(self):
        original = predicates(PARENT)
        self.assertEqual(len(original), 163)
        after = predicates(PROPOSED)
        # Only the build job predicate changes among existing predicates.
        new_build = predicates(jobs(PROPOSED)['build'])[0]
        after.remove(new_build)
        after += ['always() && !cancelled()']
        for expression_text in original:
            self.assertIn(expression_text, after)
        suites = sorted(set(re.findall(r"contains\(fromJSON\(needs.changes.outputs.new_tests\), '([^']+)'\)", PARENT)))
        for event, extensive, game, cancelled in itertools.product(
                ('push', 'pull_request', 'workflow_dispatch'), (False, True), (False, True), (False, True)):
            for selected in ([], suites):
                context = {'github.event_name': event, 'cancelled': cancelled,
                           'needs.changes.outputs.extensive': str(extensive).lower(),
                           'needs.changes.outputs.game': str(game).lower(),
                           'needs.changes.outputs.new_tests': json.dumps(selected),
                           'needs.changes.result': 'success',
                           'needs.opendream-store-admission.result': 'success',
                           'needs.opendream-store-admission.outputs.only': 'false'}
                context.update({'inputs.' + name: False for name in OLD_INPUTS})
                context['inputs.opendream_store_only'] = False
                for step in re.findall(r'^        id: ([\w_-]+)', PARENT, re.M):
                    context['steps.' + step + '.outcome'] = 'success'
                    context['steps.' + step + '.outputs.started'] = 'true'
                for text in original:
                    # Evaluate every full parent expression, not a rewritten selection model.
                    self.assertIsInstance(expression(text, context), bool)
                self.assertEqual(expression('always() && !cancelled()', context), expression(new_build, context))
                self.assertEqual(expression(predicates(jobs(PROPOSED)['changes'])[0], context), not cancelled)

    def test_ordinary_admission_is_checkout_free_success_with_false_output(self):
        job=jobs(PROPOSED)['opendream-store-admission']
        self.assertIsNone(re.search(r'^    if:',job,re.M))
        self.assertNotIn('uses:',job)
        for event in ('push','pull_request','workflow_dispatch'):
            for bits in itertools.product((False,True),repeat=len(OLD_INPUTS)):
                values=dict(zip(OLD_INPUTS,bits)) | {'opendream_store_only':False}
                self.assertEqual(admission_result(values,EVENT_NAME=event),{'result':'success','only':'false'})
        for event in ('push','pull_request'):
            self.assertEqual(admission_result(policy_inputs(),EVENT_NAME=event),{'result':'success','only':'false'})
        self.assertEqual(admission_result({},EVENT_NAME='unknown')['result'],'failure')
        for invalid in (None,'true',1):
            self.assertEqual(admission_result(policy_inputs() | {'opendream_store_only':invalid})['result'],'failure')

    def test_actual_dependency_topology_reproduces_frozen_skips_and_preserves_ordinary_jobs(self):
        frozen=(HERE/'fixtures/test.c25.yml').read_text(encoding='utf-8')
        self.assertEqual(hashlib.sha256(frozen.encode()).hexdigest(),
                         '4a9430b0fb3e5838803a67e42bac4a7c73f6c18e0f818ac0188478cda179ebdb')
        ordinary=dict.fromkeys(OLD_INPUTS,False) | {'opendream_store_only':False}
        for event in ('push','pull_request','workflow_dispatch'):
            for game,extensive in itertools.product((False,True),repeat=2):
                old=topology(frozen,event,ordinary,game=game,extensive=extensive)
                new=topology(PROPOSED,event,ordinary,game=game,extensive=extensive)
                self.assertEqual(old['opendream-store-admission'],'skipped')
                self.assertEqual(old['changes'],'success')
                self.assertEqual(old['evidence-checker'],'skipped')
                self.assertEqual(new['opendream-store-admission'],'success')
                self.assertEqual(new['changes'],'success')
                self.assertEqual(new['evidence-checker'],'success')
                self.assertEqual(new['build'],'success')
                # Existing extraction selection must retain its actual predicate.
                expected=expression(re.search(r'^    if: (.+)$',jobs(PARENT)['extraction-instances'],re.M)[1],
                    {'github.event_name':event,'needs.changes.outputs.extensive':str(extensive).lower(),
                     'needs.changes.outputs.new_tests':'[]','inputs.extraction_instance_regressions':False})
                self.assertEqual(new['extraction-instances'],'success' if expected else 'skipped')
                self.assertEqual(new['opendream-store-recovery'],'skipped')

    def test_dependency_topology_keeps_manual_admission_failure_and_offline_failure_closed(self):
        valid=policy_inputs()
        good=topology(PROPOSED,'workflow_dispatch',valid)
        self.assertEqual(good['opendream-store-recovery'],'success')
        self.assertEqual(good['build'],'skipped')
        for values in (valid | {'extensive_regressions':True},valid | {'opendream_store_selected_sha':'b'*40}):
            result=topology(PROPOSED,'workflow_dispatch',values)
            self.assertEqual(result['opendream-store-admission'],'failure')
            for name in ('changes','evidence-checker','extraction-instances','opendream-store-offline','opendream-store-recovery'):
                self.assertEqual(result[name],'skipped',name)
        for outcome in ('failure','cancelled','skipped'):
            self.assertEqual(topology(PROPOSED,'workflow_dispatch',valid,offline=outcome)['opendream-store-recovery'],'skipped')
        self.assertEqual(topology(PROPOSED,'workflow_dispatch',valid,cancelled=True)['opendream-store-recovery'],'skipped')

    def test_actual_admission_accepts_only_pure_optin_all_2048_native_combinations(self):
        for bits in itertools.product((False, True), repeat=len(OLD_INPUTS)):
            values = policy_inputs() | dict(zip(OLD_INPUTS, bits))
            self.assertEqual(admission(values), not any(bits), bits)

    def test_actual_admission_rejects_changed_head_rerun_policy_or_repository(self):
        for update in ({'opendream_store_selected_sha': 'b' * 40},
                       {'opendream_store_policy_sha256': '0' * 64},
                       {'opendream_store_policy_json': '{"enabled":false}'},
                       {'opendream_store_only': False}):
            self.assertFalse(admission(policy_inputs() | update))
        for update in ({'RUN_ATTEMPT': '2'}, {'REPOSITORY': 'other/repo'}):
            self.assertFalse(admission(policy_inputs(), **update))

    def test_pure_manual_route_skips_build_and_enables_only_new_native_job(self):
        context = {'github.event_name': 'workflow_dispatch', 'inputs.opendream_store_only': True,
                   'needs.opendream-store-admission.outputs.only': 'true', 'cancelled': False,
                   'needs.changes.outputs.extensive': 'false', 'needs.changes.outputs.new_tests': '[]',
                   'inputs.extraction_instance_regressions': False,
                   'needs.opendream-store-offline.result': 'success'}
        self.assertFalse(expression(predicates(jobs(PROPOSED)['build'])[0], context))
        self.assertFalse(expression(predicates(jobs(PROPOSED)['extraction-instances'])[0], context))
        self.assertTrue(expression(predicates(jobs(PROPOSED)['opendream-store-recovery'])[0], context))
        context['needs.opendream-store-admission.outputs.only'] = ''
        self.assertTrue(expression(predicates(jobs(PROPOSED)['build'])[0], context))
        self.assertFalse(expression(predicates(jobs(PROPOSED)['opendream-store-recovery'])[0], context))
        context['needs.opendream-store-admission.result'] = 'failure'
        self.assertFalse(expression(predicates(jobs(PROPOSED)['changes'])[0], context))

    def test_exact_parent_selector_keeps_branch_and_build_prefix_policy(self):
        spec = importlib.util.spec_from_file_location('parent_selector', HERE / 'fixtures/select-ci.f562.py')
        selector = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(selector)
        changed = b'.github/workflows/test.yml\0tests/extraction/opendream_store/entry.py\0'
        cases = [
            ('push', {'ref': 'refs/heads/helper', 'commits': [{'message': 'Prepare recovery route'}]}, False, []),
            ('push', {'ref': 'refs/heads/helper', 'commits': [{'message': 'build: explicit compile request'}]}, True, []),
            ('push', {'ref': 'refs/heads/master', 'commits': [{'message': 'Prepare recovery route'}]}, True, []),
            ('pull_request', {'action': 'opened', 'pull_request': {'base': {'ref': 'extraction-survival'}, 'title': 'Prepare recovery route'}}, False, []),
            ('pull_request', {'action': 'opened', 'pull_request': {'base': {'ref': 'extraction-survival'}, 'title': 'build: explicit compile request'}}, True, []),
            ('pull_request', {'action': 'opened', 'pull_request': {'base': {'ref': 'master'}, 'title': 'Prepare recovery route'}}, True, ['tests/extraction']),
            ('workflow_dispatch', {}, True, []),
        ]
        for event, payload, expected_game, expected_suites in cases:
            with self.subTest(event=event, payload=payload), \
                 patch.object(selector.subprocess, 'check_output', return_value=changed):
                game, extensive, suites, _ = selector.selections('base', 'head', event, False, True, payload)
            self.assertEqual((game, extensive, suites), (expected_game, False, expected_suites))

    def test_offline_job_runs_for_automatic_events_despite_skipped_admission(self):
        job = jobs(PROPOSED)['opendream-store-offline']
        self.assertIn('    needs: opendream-store-admission', job)
        predicate = predicates(job)[0]
        for event, admitted, selected, expected in (
                ('push', 'skipped', False, True),
                ('pull_request', 'skipped', False, True),
                ('workflow_dispatch', 'skipped', False, False),
                ('workflow_dispatch', 'failure', True, False),
                ('workflow_dispatch', 'success', True, True)):
            context = {'github.event_name': event, 'inputs.opendream_store_only': selected,
                       'needs.opendream-store-admission.result': admitted,
                       'needs.opendream-store-admission.outputs.only': 'true' if admitted == 'success' else '',
                       'cancelled': False}
            self.assertEqual(expression(predicate, context), expected, (event, admitted, selected))
            context['cancelled'] = True
            self.assertFalse(expression(predicate, context))
        self.assertIn('    timeout-minutes: 2', job)
        self.assertIn('persist-credentials: false', job)
        self.assertEqual(job.count('        run:'), 1)
        command = job.split('        run: ', 1)[1].strip()
        self.assertEqual(command.split(), ['/usr/bin/python3', '-B', '-m', 'unittest', '-v',
                        'test_run', 'test_backend', 'test_signals', 'test_hosted',
                        'test_preparation_receipts', 'test_workflow_route'])
        self.assertNotIn('secrets.', job)

    def test_recovery_requires_offline_pass_and_keeps_native_job_bound(self):
        job = jobs(PROPOSED)['opendream-store-recovery']
        self.assertIn('needs: [opendream-store-admission, changes, opendream-store-offline]', job)
        self.assertIn('    timeout-minutes: 40', job)
        predicate = predicates(job)[0]
        context = {'github.event_name': 'workflow_dispatch', 'inputs.opendream_store_only': True,
                   'needs.opendream-store-admission.outputs.only': 'true'}
        for outcome in ('failure', 'cancelled', 'skipped', ''):
            self.assertFalse(expression(predicate, context | {'needs.opendream-store-offline.result': outcome}))
        self.assertTrue(expression(predicate, context | {'needs.opendream-store-offline.result': 'success'}))

    def test_support_timeouts_bound_only_manual_od_and_preserve_reusable_parent(self):
        reusable_path = HERE / 'proposed-ci-selection.yml'
        if not reusable_path.exists():
            reusable_path = HERE.parents[2] / '.github/workflows/ci-selection.yml'
        reusable = reusable_path.read_text(encoding='utf-8')
        parent = (HERE / 'fixtures/ci-selection.f562.yml').read_text(encoding='utf-8')
        extra = '''      selection_timeout_minutes:
        description: Bound selection only for an explicitly selected OpenDream manual route
        type: number
        default: 360
'''
        self.assertEqual(reusable.count(extra), 1)
        timeout = '    timeout-minutes: ${{ inputs.selection_timeout_minutes }}\n'
        self.assertEqual(reusable.count(timeout), 1)
        self.assertEqual(reusable.replace(extra, '', 1).replace(timeout, '', 1), parent)
        caller = next(line.split(': ', 1)[1] for line in jobs(PROPOSED)['changes'].splitlines()
                      if line.startswith('      selection_timeout_minutes:'))
        evidence = next(line.split(': ', 1)[1] for line in jobs(PROPOSED)['evidence-checker'].splitlines()
                        if line.startswith('    timeout-minutes:'))
        for event, selected in itertools.product(('push', 'pull_request', 'workflow_dispatch'), (False, True)):
            context = {'github.event_name': event, 'inputs.opendream_store_only': selected}
            expected = 3 if event == 'workflow_dispatch' and selected else 360
            self.assertEqual(expression(caller, context, raw=True), expected)
            self.assertEqual(expression(evidence, context, raw=True), expected)
        self.assertEqual(expression('${{ inputs.selection_timeout_minutes }}',
                                    {'inputs.selection_timeout_minutes': 360}, raw=True), 360)


if __name__ == '__main__':
    unittest.main()
