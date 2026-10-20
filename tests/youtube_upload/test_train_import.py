"""Exact original train recording and explicitly owner-attested rebased source."""
import copy
import json
from pathlib import Path
import unittest

from test_import import h, pilot
from test_upload import u, fixtures

FIXTURES = Path(__file__).parent / 'fixtures'


def train():
    _, old, gh = pilot()
    m = h.select_material(h.specification('pr3032-trains-public'),
        {'id': 10, 'run_attempt': 1, 'workflow_id': 77, 'head_sha': 'b' * 40}, 789)
    p = h.policy(m)
    m['artifact'] = dict(old['artifact'], name='gameplay-video-pr3032-trains-public')
    source = gh.objects.pop('/actions/runs/38127733413')
    source.update(id=m['source']['run_id'], head_sha=m['source']['commit'],
        head_branch=m['source']['head_branch'], event='pull_request', pull_requests=[])
    gh.objects[f'/actions/runs/{source["id"]}'] = source
    relation = m['import']['source_relation']
    regression = relation['regression_run']
    gh.objects[f'/actions/runs/{regression["id"]}'] = dict(source,
        id=regression['id'], workflow_id=regression['workflow_id'], path=regression['workflow_path'])
    pr = gh.objects.pop('/pulls/3031')
    pr.update(number=3032, merged=True, merge_commit_sha=relation['merge_commit'])
    pr['head']['sha'] = relation['final_head']
    gh.objects['/pulls/3032'] = pr
    for name in ('owner', 'equivalence'):
        comment = json.loads((FIXTURES / f'pr3032-{name}-attestation.json').read_text(encoding='utf-8-sig'))
        gh.objects[f'/issues/comments/{comment["id"]}'] = comment
    gh.objects['/issues/comments/789'] = {
        'user': {'type': 'User', 'login': 'valzargaming'},
        'issue_url': 'https://api.github.com/repos/Civ13/Civ13/issues/3032',
        'body': u.approval_text(m), 'created_at': '2026-10-20T18:00:00Z',
        'updated_at': '2026-10-20T18:00:00Z'}
    gh.objects.update(json.loads((FIXTURES / 'pr3032-scoped-trees.json').read_text()))
    gh.objects['/actions/artifacts/2']['name'] = m['artifact']['name']
    gh.objects['/actions/runs/10/artifacts?per_page=10']['artifacts'][0]['name'] = m['artifact']['name']
    return p, m, gh


class ExactTrainImportTests(unittest.TestCase):
    def test_original_short_clip_and_explicit_rebased_relation_resolve(self):
        p, m, gh = train()
        u.validate_manifest(m, p)
        u.validate_provenance(gh, m, p)
        self.assertEqual(u.approval_hash(m), u.TRAIN_APPROVAL_DIGEST)
        self.assertEqual(m['clip']['duration_seconds'], 11.4)
        self.assertEqual(len(m['import']['source_relation']['dependencies']), 22)
        self.assertEqual(h.resolve_pilot(gh, 10, 'b' * 40,
            'pr3032-trains-public', 789), (p, m))
        evidence = u.expected_evidence(m)
        self.assertEqual(evidence['tested_commit'], 'ad0c9ce9847dbad62fe0d636134250310cf5c95b')
        self.assertNotEqual(evidence['tested_commit'], m['import']['source_relation']['final_head'])
        self.assertIn('CI did not record', evidence['capture_provenance'])

    def test_short_exception_cannot_be_selected_by_pr_number_or_unpinned_material(self):
        for section, field, value in [('clip', 'duration_seconds', 11.5),
                ('clip', 'duration_seconds', 20), ('clip', 'sha256', 'c' * 64),
                ('clip', 'bytes', 404425), ('metadata', 'title', 'Changed train publication title'),
                ('source', 'commit', 'c' * 40), ('source', 'pr', 3081),
                ('review', 'known_limits', 'Claims full production crash acceptance')]:
            p, m, gh = train()
            m[section][field] = value
            with self.subTest(section=section, field=field), self.assertRaises(u.Refused):
                u.validate_manifest(m, p)
        for duration in (0, 11.4, 14.99, 180.01, float('nan')):
            p, m, *_ = fixtures()
            m['clip']['duration_seconds'] = duration
            with self.subTest(generic_duration=duration), self.assertRaises(u.Refused):
                u.validate_manifest(m, p)
        for duration in (15, 180):
            p, m, *_ = fixtures()
            m['clip']['duration_seconds'] = duration
            u.validate_manifest(m, p)

    def test_wrong_source_and_regression_identity_never_use_train_exception(self):
        for target, field, value in [('source', 'head_sha', 'c' * 40),
                ('source', 'run_attempt', 2), ('source', 'workflow_id', 999),
                ('source', 'event', 'push'), ('source', 'head_branch', 'other-branch'),
                ('source', 'head_repository', {'id': 999}),
                ('source', 'pull_requests', [{'number': 3228}]),
                ('regression', 'head_sha', 'c' * 40), ('regression', 'conclusion', 'failure'),
                ('regression', 'workflow_id', 999), ('regression', 'run_attempt', 2),
                ('regression', 'pull_requests', [{'number': 3228}]),
                ('pr', 'merged', False), ('pr', 'merge_commit_sha', 'c' * 40)]:
            p, m, gh = train()
            obj = {'source': gh.objects['/actions/runs/38128091280'],
                'regression': gh.objects['/actions/runs/38128091416'],
                'pr': gh.objects['/pulls/3032']}[target]
            obj[field] = value
            with self.subTest(target=target, field=field), self.assertRaises(u.Refused):
                u.validate_provenance(gh, m, p)
        p, m, gh = train()
        gh.objects['/pulls/3032']['head']['sha'] = 'c' * 40
        with self.assertRaises(u.Refused):
            u.validate_provenance(gh, m, p)

    def test_both_owner_attestations_and_publication_comment_require_exact_humans(self):
        for comment_id in (6107678670, 6107755107):
            for field, value in [('body', 'Changed or revoked historical evidence'),
                    ('user', {'type': 'User', 'login': 'valzargaming', 'id': 999}),
                    ('updated_at', '2026-10-20T18:00:00Z'),
                    ('issue_url', 'https://api.github.com/repos/Civ13/Civ13/issues/3081')]:
                p, m, gh = train()
                gh.objects[f'/issues/comments/{comment_id}'][field] = value
                with self.subTest(comment=comment_id, field=field), self.assertRaises(u.Refused):
                    u.validate_provenance(gh, m, p)
        for field, value in [('body', 'I approve'),
                ('user', {'type': 'Bot', 'login': 'valzargaming'}),
                ('issue_url', 'https://api.github.com/repos/Civ13/Civ13/issues/3081'),
                ('updated_at', '2026-10-20T18:00:01Z')]:
            p, m, gh = train()
            gh.objects['/issues/comments/789'][field] = value
            with self.subTest(publication=field), self.assertRaises(u.Refused):
                u.validate_provenance(gh, m, p)

    def test_runtime_tree_metadata_cannot_replace_any_of_the_22_source_entries(self):
        p, m, baseline = train()
        for entry in m['import']['source_relation']['dependencies']:
            gh = copy.deepcopy(baseline)
            # Find the corresponding fixed node response and mutate its actual identity.
            target = next(row for key, tree in gh.objects.items() if key.startswith('/git/trees/')
                for row in tree['tree'] if row['sha'] == entry['captured_sha'])
            target['sha'] = 'c' * 40
            with self.subTest(path=entry['path']), self.assertRaises(u.Refused):
                u.validate_provenance(gh, m, p)
        for field, value in [('truncated', True), ('tree', []),
                ('tree', [{'path': 'x', 'sha': 'a' * 40}] * 5001)]:
            gh = copy.deepcopy(baseline)
            gh.objects['/git/trees/' + m['source']['commit']][field] = value
            with self.subTest(tree_field=field), self.assertRaises(u.Refused):
                u.validate_provenance(gh, m, p)

    def test_same_original_receipt_and_rolling_cap_are_preserved(self):
        p, m, gh = train()
        gh.ledger['records'] = {'a' * 64: {'state': 'uncertain', 'channel_id': u.CHANNEL,
            'clip_sha256': 'a' * 64, 'commit': 'a' * 40, 'reserved_at': 99999},
            'b' * 64: {'state': 'verified', 'channel_id': u.CHANNEL,
            'clip_sha256': 'b' * 64, 'commit': 'b' * 40, 'reserved_at': 99999}}
        with self.assertRaises(u.Refused):
            u.Ledger(gh).reserve(m, 100000)
        gh.ledger['records'] = {}
        ledger = u.Ledger(gh)
        record = ledger.reserve(m, 100000)
        record.update(state='uploaded', video_id='abcdefghijk')
        ledger.save()
        gh.objects = {'': gh.objects['']}
        self.assertEqual(h.resolve_pilot_receipt(gh, 10, 'pr3032-trains-public', 789), (p, m))
        with self.assertRaises(u.Refused):
            u.Ledger(gh).reserve(m, 100001)


if __name__ == '__main__':
    unittest.main()
