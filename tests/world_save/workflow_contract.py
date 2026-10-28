"""Reviewable scoped CI contracts; unrelated workflow steps may evolve."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FIXTURE = ROOT / 'tests/world_save/reviewed_workflow_steps.json'
REVIEWED_STEPS = (
    'Run required bounded offline baseline',
    'Retain offline commands, counts, logs and skips',
    'Require successful change selection',
    'Read reviewed BYOND archive cache identity',
    'Restore exact BYOND archive only',
    'Compile selected exact-head game',
    'Save verified BYOND archive after successful compilation',
    'Record compilation outcome and source receipts',
    'Retain compiler diagnostics and source receipts including failures',
    'Test continuous persistence round contracts offline',
    'Verify protected sleep transfers and bounded save compatibility',
    'Retain protected sleep regression evidence',
    'Retain synthetic save inspector receipt',
    'Offline world-save round-trip regression',
    'Retain ordinary world-save evidence',
    'Verify bounded admitted save traversal and backup recovery',
    'Retain bounded save source and native evidence',
    'Verify continuous persistence rounds and negative controls',
    'Retain continuous-round integration evidence',
    'Check exclusion dispatch source while native execution is held',
    'Verify Linux exclusion dispatch parity and mutation controls',
    'Retain Linux exclusion dispatch evidence',
    'Retain dependency job outcomes before validating artifacts',
    'Require selected jobs and exact-source execution receipts',
    'Retain aggregate verdict and dependency outcomes',
)


def assert_workflow_contract(workflow):
    reviewed = json.loads(FIXTURE.read_text(encoding='utf-8'))
    if set(reviewed) != set(REVIEWED_STEPS) or len(reviewed) != len(REVIEWED_STEPS):
        raise AssertionError('Reviewed workflow fixture step list changed')
    for name, expected in reviewed.items():
        marker = '      - name: ' + name + '\n'
        if workflow.count(marker) != 1:
            raise AssertionError('Missing or duplicate reviewed step: ' + name)
        prefix = workflow.split(marker, 1)[0]
        jobs = re.findall(r'^  ([A-Za-z_][A-Za-z0-9_-]*):$', prefix, re.M)
        expected_job = ('baseline' if name in ('Run required bounded offline baseline',
                        'Retain offline commands, counts, logs and skips') else
                        'evidence-checker' if name == 'Test continuous persistence round contracts offline' else
                        'ci-required' if name in ('Retain dependency job outcomes before validating artifacts',
                        'Require selected jobs and exact-source execution receipts',
                        'Retain aggregate verdict and dependency outcomes') else 'build')
        if not jobs or jobs[-1] != expected_job:
            raise AssertionError('Reviewed step moved from job: ' + name)
        lines = []
        for line in workflow.split(marker, 1)[1].splitlines():
            if line and not line.startswith('        '):
                break
            lines.append(line)
        while lines and not lines[-1]:
            lines.pop()
        if '\n'.join(lines) + '\n' != expected:
            raise AssertionError('Reviewed workflow step changed: ' + name)

    for sequence in (
        ('Run required bounded offline baseline', 'Retain offline commands, counts, logs and skips'),
        ('Require successful change selection', 'Read reviewed BYOND archive cache identity',
         'Restore exact BYOND archive only', 'Compile selected exact-head game',
         'Save verified BYOND archive after successful compilation',
         'Record compilation outcome and source receipts',
         'Retain compiler diagnostics and source receipts including failures'),
        ('Check exclusion dispatch source while native execution is held',
         'Verify Linux exclusion dispatch parity and mutation controls', 'Retain Linux exclusion dispatch evidence'),
        ('Verify protected sleep transfers and bounded save compatibility',
         'Retain protected sleep regression evidence', 'Retain synthetic save inspector receipt'),
        ('Offline world-save round-trip regression', 'Retain ordinary world-save evidence'),
        ('Verify bounded admitted save traversal and backup recovery', 'Retain bounded save source and native evidence'),
        ('Verify continuous persistence rounds and negative controls', 'Retain continuous-round integration evidence'),
        ('Retain dependency job outcomes before validating artifacts',
         'Require selected jobs and exact-source execution receipts', 'Retain aggregate verdict and dependency outcomes'),
    ):
        positions = [workflow.index('      - name: ' + name + '\n') for name in sequence]
        if positions != sorted(positions):
            raise AssertionError('Reviewed workflow step ordering changed: ' + ', '.join(sequence))

    # Pin the version and dispatch identity input in their own scopes, without
    # fixing other inputs or unrelated jobs to a whole-file fingerprint.
    for fragment in (
        'env:\n  BYOND_MAJOR: "516"\n  BYOND_MINOR: "1688"\n',
        "      exclusion_comparison_base:\n        description: 'Full immutable base commit SHA, distinct from the selected head; required when running exclusion checks'\n        type: string\n        required: false\n        default: ''\n",
    ):
        if workflow.count(fragment) != 1:
            raise AssertionError('Required workflow identity or compiler contract changed')

    changes_marker = '  changes:\n'
    if workflow.count(changes_marker) != 1:
        raise AssertionError('Missing or duplicate selection job')
    changes = re.split(r'^  [A-Za-z_][A-Za-z0-9_-]*:\s*$', workflow.split(changes_marker, 1)[1],
                       maxsplit=1, flags=re.M)[0]
    for fragment in (
        '    uses: ./.github/workflows/ci-selection.yml\n',
        '      build_prefix: true\n',
        "      extensive: ${{ github.event_name == 'workflow_dispatch' && inputs.extensive_regressions }}\n",
        "      base: ${{ github.event.pull_request.base.sha || github.event.before || '' }}\n",
    ):
        if changes.count(fragment) != 1:
            raise AssertionError('Selection contract changed: ' + fragment.strip())

    # Selection and attempt identities must be bound at producer and consumer;
    # inspect only job headers/checkout/download before the named body steps.
    for job, end in (('baseline', 'Run required bounded offline baseline'),
                     ('build', 'Read reviewed BYOND archive cache identity')):
        marker = '  ' + job + ':\n'
        if workflow.count(marker) != 1:
            raise AssertionError('Missing or duplicate job: ' + job)
        job_body = re.split(r'^  [A-Za-z_][A-Za-z0-9_-]*:\s*$', workflow.split(marker, 1)[1],
                            maxsplit=1, flags=re.M)[0]
        end_marker = '      - name: ' + end + '\n'
        if job_body.count(end_marker) != 1:
            raise AssertionError('Missing job identity boundary: ' + job)
        section = job_body.split(end_marker, 1)[0]
        required = (
            '    needs: changes\n',
            '      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683\n',
            '      - uses: actions/download-artifact@d3f86a106a0bac45b974a628896c90dbdf5c8093\n',
            '      attempt: ${{ github.run_attempt }}\n',
            '          ref: ${{ github.event.pull_request.head.sha || github.sha }}\n',
            '          fetch-depth: 0\n',
            '          persist-credentials: false\n',
            '          name: ci-selection-${{ github.event.pull_request.head.sha || github.sha }}-${{ github.run_id }}-${{ needs.changes.outputs.attempt }}\n',
            '          path: .ci/selection\n',
        )
        for fragment in required:
            if section.count(fragment) != 1:
                raise AssertionError('Missing or duplicate ' + job + ' identity/provenance: ' + fragment.strip())

    # The aggregate downloads each producer's attempt, not its own attempt on
    # a failed-job rerun. Bind names, paths, actions and the dependency graph.
    aggregate_marker = '  ci-required:\n'
    if workflow.count(aggregate_marker) != 1:
        raise AssertionError('Missing or duplicate required aggregate job')
    aggregate = re.split(r'^  [A-Za-z_][A-Za-z0-9_-]*:\s*$', workflow.split(aggregate_marker, 1)[1],
                         maxsplit=1, flags=re.M)[0]
    for fragment in (
        "    name: ${{ needs.changes.result == 'success' && needs.changes.outputs.gating && needs.changes.outputs.gating == '0' && 'CI informational aggregate' || 'CI required aggregate' }}\n",
        '    if: always()\n',
        '    needs: [changes, baseline, evidence-checker, build, extraction-instances]\n',
        '    runs-on: ubuntu-latest\n',
        '    timeout-minutes: 5\n',
        "      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683\n        if: needs.changes.result == 'success'\n        timeout-minutes: 2\n        with:\n          ref: ${{ github.event.pull_request.head.sha || github.sha }}\n          fetch-depth: 1\n",
        '          persist-credentials: false\n',
        "      - name: Prepare exact comparison commit\n        if: needs.changes.result == 'success'\n        timeout-minutes: 2\n        env:\n          EVENT_NAME: ${{ github.event_name }}\n          BASE_REF: ${{ github.event.pull_request.base.sha || github.event.before || '' }}\n          HEAD_REF: ${{ github.event.pull_request.head.sha || github.sha }}\n        run: python3 -B scripts/ci_checkout_refs.py --head \"$HEAD_REF\" --base \"$BASE_REF\" --event \"$EVENT_NAME\"\n",
        '      - uses: actions/download-artifact@d3f86a106a0bac45b974a628896c90dbdf5c8093\n        with:\n          name: ci-selection-${{ github.event.pull_request.head.sha || github.sha }}-${{ github.run_id }}-${{ needs.changes.outputs.attempt }}\n          path: .ci/selection\n',
        '      - uses: actions/download-artifact@d3f86a106a0bac45b974a628896c90dbdf5c8093\n        with:\n          name: ci-baseline-${{ github.event.pull_request.head.sha || github.sha }}-${{ github.run_id }}-${{ needs.baseline.outputs.attempt }}\n          path: .ci/baseline\n',
        '      - uses: actions/download-artifact@d3f86a106a0bac45b974a628896c90dbdf5c8093\n        with:\n          name: ci-compile-${{ github.event.pull_request.head.sha || github.sha }}-${{ github.run_id }}-${{ needs.build.outputs.attempt }}\n          path: .ci/compile\n',
    ):
        if ('\n' + aggregate).count('\n' + fragment) != 1:
            raise AssertionError('Required aggregate identity, dependency or receipt changed: ' + fragment.strip())
    first = aggregate.index('      - name: Retain dependency job outcomes before validating artifacts\n')
    last = aggregate.index('      - name: Require selected jobs and exact-source execution receipts\n')
    downloads = aggregate[first:last]
    for prefix in ('ci-selection-', 'ci-baseline-', 'ci-compile-'):
        if downloads.count('          name: ' + prefix) != 1:
            raise AssertionError('Required aggregate download ordering changed: ' + prefix)
