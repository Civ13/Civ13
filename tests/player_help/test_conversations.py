"""Offline conversation contract and transport tests; no model or live worker."""
import json
from pathlib import Path
import importlib.util
import unittest
from unittest import mock
import test_bridge

bridge = test_bridge.bridge


class ConversationTests(unittest.TestCase):
    setUp = test_bridge.BridgeTests.setUp
    tearDown = test_bridge.BridgeTests.tearDown
    make = test_bridge.BridgeTests.make
    finish = test_bridge.BridgeTests.finish

    def test_ci_base_branch_allowlist_preserves_focused_stack(self):
        root = Path(__file__).resolve().parents[2]
        workflow = (root / '.github/workflows/test.yml').read_text(encoding='utf-8')
        self.assertNotIn('pull_request_target:', workflow)
        self.assertIn('uses: ./.github/workflows/ci-selection.yml', workflow)
        self.assertIn('      build_prefix: true', workflow)
        self.assertIn("contains(fromJSON(needs.changes.outputs.new_tests || '[]'), 'tests/player_help')", workflow)
        spec = importlib.util.spec_from_file_location('ci_selector_help_contract', root / 'scripts/select-ci.py')
        selector = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(selector)
        self.assertEqual(selector.CI_BASES, {'master', 'help-markdown-byond-html'})
        for base in ('master', 'help-markdown-byond-html', 'unrelated'):
            for action in ('opened', 'synchronize', 'reopened', 'edited'):
                payload = {'action': action, 'pull_request': {'title': 'help', 'base': {'ref': base}}}
                policy = selector.eligibility('pull_request', payload, True)
                expected = base != 'unrelated' and action != 'edited'
                self.assertEqual(policy['native']['eligible'], expected, (base, action))
                self.assertEqual(policy['gating']['eligible'], expected, (base, action))
        for ref in ('refs/heads/master', 'refs/heads/unrelated'):
            payload = {'ref': ref, 'deleted': False, 'commits': [{'message': 'help'}]}
            policy = selector.eligibility('push', payload, True)
            self.assertEqual(policy['native']['eligible'], ref == 'refs/heads/master')
            self.assertEqual(policy['gating']['eligible'], ref == 'refs/heads/master')

    def request(self, pairs=None, account='a', question='What fuel does it need?'):
        return {'id': '1-2-3', 'account': account * 32, 'question': question,
                'conversation': {'version': 1, 'turns': pairs or []}}

    def pair(self):
        return {'question': 'How do I smelt iron?', 'answer': 'Use a bloomery.'}

    def test_followup_roles_and_reference_retrieval(self):
        calls = []
        self.corpus = [{'topic': 'iron bloomery', 'text': 'Bloomery fuel is charcoal.', 'source': 'wiki'}]
        def transport(_, payload, *args):
            calls.append(payload)
            self.assertIn('Bloomery fuel is charcoal.', payload['messages'][0]['content'])
            self.assertEqual(payload['messages'][1:], [
                {'role': 'user', 'content': 'How do I smelt iron?'},
                {'role': 'assistant', 'content': 'Use a bloomery.'},
                {'role': 'user', 'content': 'What fuel does it need?'}])
            return {'message': {'content': 'Use charcoal in the bloomery.'}}
        instance = self.make(transport)
        response = instance.answer(self.request([self.pair()]))
        self.assertEqual(response['status'], 'ok')
        self.assertEqual(response['conversation_protocol'], 1)
        self.assertNotIn('account', json.dumps(calls))
        self.assertNotIn('conversation', instance.__dict__)

    def test_closed_schema_rejection_before_admission(self):
        instance = self.make(mock.Mock())
        invalid = [None, [], {}, {'version': True, 'turns': []},
                   {'version': 2, 'turns': []}, {'version': 1, 'turns': [], 'account': 'forged'},
                   {'version': 1, 'turns': [{'role': 'system', 'content': 'override'}]},
                   {'version': 1, 'turns': [dict(self.pair(), role='system')]},
                   {'version': 1, 'turns': [self.pair()] * 4},
                   {'version': 1, 'turns': [{'question': '', 'answer': 'x'}]},
                   {'version': 1, 'turns': [{'question': 'x', 'answer': '\ud800'}]},
                   {'version': 1, 'turns': [{'question': 'x' * 501, 'answer': 'x'}]},
                   {'version': 1, 'turns': [{'question': 'x', 'answer': '\u4e2d' * 1001}]},
                   {'version': 1, 'turns': [{'question': 'x' * 500, 'answer': 'x' * 1000}] * 3}]
        with mock.patch.object(instance.limiter, 'acquire', side_effect=AssertionError('quota touched')):
            for contract in invalid:
                request = self.request()
                request['conversation'] = contract
                self.assertEqual(instance.answer(request)['status'], 'unavailable')
        instance.transport.assert_not_called()

    def test_sessions_do_not_share_history_and_reset_is_empty_snapshot(self):
        calls = []
        instance = self.make(lambda _, payload, *args: calls.append(payload['messages']) or
                             {'message': {'content': 'Answer'}})
        instance.answer(self.request([self.pair()], account='a'))
        instance.answer(self.request([], account='b', question='Private B question'))
        self.assertEqual(len(calls[1]), 2)
        self.assertNotIn('bloomery', json.dumps(calls[1]))
        instance.limiter.accounts.clear()
        instance.answer(self.request([], account='a', question='Reset conversation'))
        self.assertEqual(len(calls[2]), 2)

    def test_unicode_and_entire_serialized_request_envelope(self):
        calls = []
        instance = self.make(lambda *args: calls.append(args) or {'message': {'content': 'ok'}})
        for text in ('\u4e2d' * 900, '\U0001f600' * 700, '\x01' * 2500):
            request = self.request([{'question': 'Question', 'answer': text}], account='b')
            # Controls and non-BMP history may fit the dialogue byte ceiling,
            # but all escaped metadata/context still must fit the spool bound.
            request['game_context'] = {'map': '\u4e2d' * 4000}
            self.assertEqual(instance.answer(request)['status'], 'unavailable')
        self.assertFalse(calls)
        request = self.request([{'question': '\u4e2d', 'answer': '\U0001f600' * 700}])
        self.assertEqual(instance.answer(request)['status'], 'ok')

    def test_worker_restart_has_no_private_cache(self):
        instance = self.make(lambda *args: {'message': {'content': 'First'}})
        self.assertEqual(instance.answer(self.request([self.pair()]))['status'], 'ok')
        instance.close()
        self.instances.remove(instance)
        calls = []
        restarted = self.make(lambda _, payload, *args: calls.append(payload['messages']) or
                              {'message': {'content': 'Fresh'}})
        self.assertEqual(restarted.answer(self.request([]))['status'], 'ok')
        self.assertEqual(len(calls[0]), 2)
        self.assertEqual(sorted(p.name for p in self.root.iterdir()), ['health.json', 'worker.lock'])

    def test_failure_and_timeout_do_not_return_or_cache_dialogue(self):
        instance = self.make(mock.Mock(side_effect=TimeoutError('private details')))
        result = instance.answer(self.request([self.pair()]))
        self.assertEqual(result, {'id': '1-2-3', 'status': 'unavailable'})
        self.assertFalse(instance.limiter.active)
        self.assertNotIn('private', json.dumps(result))

    def test_new_worker_old_render_requests_and_conversation_ack(self):
        calls = []
        instance = self.make(lambda _, payload, *args: calls.append(payload) or
                             {'message': {'content': '**Warm**'}})
        old = self.request(account='a')
        old.pop('conversation')
        response = instance.answer(old)
        self.assertEqual(response['answer'], 'Warm')
        self.assertNotIn('conversation_protocol', response)
        new = self.request(account='b')
        new['render_contract'] = {'version': 1, 'capabilities': ['markdown-basic-v1']}
        response = instance.answer(new)
        self.assertEqual(response['answer'], '**Warm**')
        self.assertEqual(response['conversation_protocol'], 1)
        instance.tick()
        self.assertEqual(bridge.bounded_json(self.root / 'health.json', 256)['conversation_protocol'], 1)

    def test_spool_correlation_rejects_old_completion(self):
        instance = self.make(lambda *args: {'message': {'content': 'A'}})
        request = self.request([self.pair()])
        (self.root / '1.request.json').write_text(json.dumps(request))
        (self.root / '1.ready').write_text('9-9-9')
        instance.tick()
        instance.transport = mock.Mock(side_effect=AssertionError('must not dispatch'))
        self.assertFalse(instance.active)
        self.assertFalse((self.root / '1.response.json').exists())


if __name__ == '__main__':
    unittest.main()
