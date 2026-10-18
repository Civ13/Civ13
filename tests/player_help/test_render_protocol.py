"""Offline display negotiation, projection and disk-boundary regressions."""
import json
import threading
import unittest
from unittest import mock
import test_bridge

bridge = test_bridge.bridge


class RenderProtocolTests(unittest.TestCase):
    setUp = test_bridge.BridgeTests.setUp
    tearDown = test_bridge.BridgeTests.tearDown
    make = test_bridge.BridgeTests.make
    finish = test_bridge.BridgeTests.finish
    def request_value(self, contract=None, include=True, account='a'):
        value = {'id': '1-2-3', 'account': account * 32, 'question': 'How do I bandage?'}
        if include:
            value['render_contract'] = contract
        return value

    def test_contract_rejection_precedes_quota_and_transport(self):
        instance = self.make(mock.Mock())
        invalid = [None, [], {}, {'version': True, 'capabilities': []},
                   {'version': 2, 'capabilities': []}, {'version': 1, 'capabilities': None},
                   {'version': 1, 'capabilities': ['unknown']},
                   {'version': 1, 'capabilities': ['markdown-basic-v1'] * 2},
                   {'version': 1, 'capabilities': [], 'guess': True}]
        with mock.patch.object(instance.limiter, 'acquire', side_effect=AssertionError('quota touched')):
            for contract in invalid:
                self.assertEqual(instance.answer(self.request_value(contract))['status'], 'unavailable')
        instance.transport.assert_not_called()

    def test_old_new_and_rollback(self):
        raw = '# Winter\r\n**Warm** and *dry*. [Guide](https://example.org/a(b)?x=1&y=2)'
        instance = self.make(lambda *args: {'message': {'content': raw}})
        for request, expected, account in [
                (None, 'plain-v1', 'a'), ({'version': 1, 'capabilities': []}, 'plain-v1', 'b'),
                ({'version': 1, 'capabilities': ['markdown-basic-v1']}, 'markdown-basic-v1', 'c'),
                (None, 'plain-v1', 'd')]:
            response = instance.answer(self.request_value(request, request is not None, account))
            self.assertEqual(response['answer_format'], expected)
            self.assertEqual(response['render_protocol'], 1)
            self.assertEqual(response['answer'], raw if expected.startswith('markdown') else
                             'Winter\nWarm and dry. Guide (https://example.org/a(b)?x=1&y=2)')
            self.assertNotIn('raw_answer', response)

    def test_selection_is_snapshotted_before_async_dispatch(self):
        instance = self.make(lambda *args: {'message': {'content': '**Warm**'}})
        request = self.request_value({'version': 1, 'capabilities': ['markdown-basic-v1']})
        path = self.root / '1.request.json'
        path.write_text(json.dumps(request))
        (self.root / '1.ready').write_text(request['id'])
        captured = []
        original = instance.executor.submit
        def submit(callback, value, selected):
            captured.append(selected)
            value['render_contract']['capabilities'].clear()
            path.write_text(json.dumps(value))
            return original(callback, value, selected)
        with mock.patch.object(instance.executor, 'submit', side_effect=submit):
            response = self.finish(instance)
        self.assertEqual(captured, ['markdown-basic-v1'])
        self.assertEqual(response['answer'], '**Warm**')
        self.assertEqual(response['answer_format'], 'markdown-basic-v1')

    def test_serialized_bound_includes_metadata_id_and_unicode(self):
        for text, expected in [('a' * 4000, 'ok'), ('\u4e2d' * 3900, 'ok'),
                               ('\u4e2d' * 4000, 'unavailable'), ('\U0001f600' * 4000, 'unavailable'),
                               ('\ud800', 'unavailable'), ('"\\\n' * 1333, 'ok')]:
            with self.subTest(text=text[:8]):
                instance = self.make(lambda *args: {'message': {'content': text}})
                request = self.request_value({'version': 1, 'capabilities': ['markdown-basic-v1']})
                request['id'] = '9' * 100
                result = instance.answer(request)
                self.assertEqual(result['status'], expected)
                bridge.atomic_json(self.root / 'bounded.json', result)
                self.assertLessEqual((self.root / 'bounded.json').stat().st_size, 24000)
                instance.close()

    def test_old_and_new_inflight_requests_keep_independent_formats(self):
        self.config['workers'] = 2
        release, entered = threading.Event(), threading.Barrier(3)
        def transport(*args):
            entered.wait(timeout=3)
            if not release.wait(timeout=3):
                raise TimeoutError('test gate')
            return {'message': {'content': '**Warm**'}}
        instance = self.make(transport)
        for slot, contract in [(1, None), (2, {'version': 1, 'capabilities': ['markdown-basic-v1']})]:
            request = self.request_value(contract, contract is not None, 'a' if slot == 1 else 'b')
            request['id'] = f'1-2-{slot}'
            (self.root / f'{slot}.request.json').write_text(json.dumps(request))
            (self.root / f'{slot}.ready').write_text(request['id'])
        try:
            instance.tick()
            entered.wait(timeout=3)
            release.set()
            old, new = self.finish(instance, 1), self.finish(instance, 2)
            self.assertEqual((old['answer_format'], old['answer']), ('plain-v1', 'Warm'))
            self.assertEqual((new['answer_format'], new['answer']), ('markdown-basic-v1', '**Warm**'))
        finally:
            release.set()

    def test_projection_preserves_literals_urls_code_and_unmatched(self):
        cases = {
            r'\*literal\* **bold** snake_case <b>text</b>': '*literal* bold snake_case <b>text</b>',
            '```dm\r\n**code** <x>\r\n```': '**code** <x>',
            '`**literal**` and ~~unsupported~~': '**literal** and ~~unsupported~~',
            '**unmatched and [bad](javascript:x)': '**unmatched and [bad](javascript:x)',
            '## Heading\n- **one**\n1. *two*': 'Heading\n- one\n1. two',
            '[A](https://host/a(b)?x=1&y=2)': 'A (https://host/a(b)?x=1&y=2)',
            '```unclosed\ntext': '```unclosed\ntext',
            r'*a\*': r'*a*',
            '``a`b``': 'a`b',
        }
        for value, expected in cases.items():
            self.assertEqual(bridge.plain_answer(value), expected)

    def test_empty_projection_is_unavailable(self):
        for raw in ('# ', '```\n```'):
            instance = self.make(lambda *args: {'message': {'content': raw}})
            self.assertEqual(instance.answer(self.request_value(include=False)),
                             {'id': '1-2-3', 'status': 'unavailable'})
            instance.close()

