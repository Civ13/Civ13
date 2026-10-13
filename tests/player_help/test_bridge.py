import importlib.util
import json
from pathlib import Path
import tempfile
import threading
import time
import unittest
from unittest import mock
import subprocess

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('bridge', ROOT / 'scripts/player_help_bridge.py')
bridge = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bridge)


class BridgeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.config = {'enabled': True, 'model': 'test', 'endpoint': 'http://localhost/api/chat', 'workers': 1, 'timeout_seconds': 1}
        self.corpus = [{'topic': 'bandage', 'text': 'Bandages do not replace lost blood.'}]
        self.instances = []

    def tearDown(self):
        for instance in self.instances:
            instance.close()
        self.temp.cleanup()

    def make(self, transport):
        instance = bridge.Bridge(self.root, self.config, self.corpus, transport)
        self.instances.append(instance)
        return instance

    def request(self, request_id='1-2-3', slot=1, question='How do I bandage?'):
        (self.root / f'{slot}.request.json').write_text(json.dumps({'id': request_id, 'question': question}))
        (self.root / f'{slot}.ready').write_text(request_id)

    def finish(self, instance, slot=1):
        for _ in range(100):
            instance.tick()
            if (self.root / f'{slot}.response.json').exists():
                return bridge.bounded_json(self.root / f'{slot}.response.json', 24000)
            time.sleep(.002)
        self.fail('Response not committed')

    def test_grounding_protocol_and_no_identifiers(self):
        calls = []
        def transport(endpoint, payload, headers, timeout):
            calls.append((endpoint, payload, headers, timeout))
            return {'message': {'content': '<script>hello</script>'}}
        instance = self.make(transport)
        self.request()
        response = self.finish(instance)
        self.assertEqual(response['status'], 'ok')
        self.assertIn('lost blood', calls[0][1]['messages'][0]['content'])
        self.assertFalse(calls[0][1]['stream'])
        self.assertNotIn('tools', calls[0][1])
        self.assertEqual(set(calls[0][1]), {'model', 'stream', 'messages', 'options'})
        self.assertEqual(len(calls), 1)
        for _ in range(4):
            instance.tick()
        self.assertEqual(len(calls), 1)

    def test_failures_do_not_expose_secrets(self):
        def failing(*args):
            raise TimeoutError('secret-token endpoint-details')
        instance = self.make(failing)
        self.request()
        result = self.finish(instance)
        self.assertEqual(result, {'id': '1-2-3', 'status': 'unavailable'})

    def test_bounded_output(self):
        instance = self.make(lambda *args: {'message': {'content': 'x' * 9000}})
        self.request()
        self.assertEqual(len(self.finish(instance)['answer']), 4000)

    def test_disconnected_reused_slot_drops_old_answer(self):
        started, release = threading.Event(), threading.Event()
        def transport(*args):
            started.set()
            release.wait(2)
            return {'message': {'content': args[1]['messages'][1]['content']}}
        instance = self.make(transport)
        self.request(question='old question')
        instance.tick()
        self.assertTrue(started.wait(1))
        self.request(request_id='4-5-6', question='new question')
        release.set()
        result = self.finish(instance)
        self.assertEqual(result['id'], '4-5-6')
        self.assertEqual(result['answer'], 'new question')

    def test_stale_response_cannot_block_reused_slot(self):
        instance = self.make(lambda *args: {'message': {'content': 'new'}})
        self.request('4-5-6')
        bridge.atomic_json(self.root / '1.response.json', {'id': '1-2-3', 'status': 'ok', 'answer': 'old'})
        self.assertEqual(self.finish(instance)['id'], '4-5-6')

    def test_disabled_never_calls_transport_and_health_off_on_close(self):
        self.config['enabled'] = False
        instance = self.make(lambda *args: self.fail('Network called'))
        self.request()
        instance.tick()
        self.assertFalse(bridge.bounded_json(self.root / 'health.json', 256)['enabled'])
        instance.close()
        self.assertFalse(bridge.bounded_json(self.root / 'health.json', 256)['enabled'])

    def test_invalid_and_oversized_requests_do_not_call(self):
        instance = self.make(lambda *args: self.fail('Network called'))
        self.request('../bad')
        instance.tick()
        self.assertFalse(instance.active)
        self.request(question='x' * 501)
        instance.tick()
        self.assertFalse(instance.active)

    def test_config_destination_and_bounds(self):
        path = self.root / 'config.json'
        config = {'enabled': True, 'ollama_url': 'https://example.test/api/chat', 'model': 'test'}
        path.write_text(json.dumps(config))
        self.assertEqual(bridge.load_config(path)['endpoint'], config['ollama_url'])
        for url in ['ftp://example.test', 'https://user:pass@example.test', 'https://example.test/admin', 'https://example.test?token=secret']:
            config['ollama_url'] = url
            path.write_text(json.dumps(config))
            with self.assertRaises(ValueError):
                bridge.load_config(path)

    def test_second_worker_rejected(self):
        self.make(lambda *args: None)
        with self.assertRaises(FileExistsError):
            bridge.Bridge(self.root, self.config, self.corpus, lambda *args: None)

    def test_transport_has_total_deadline(self):
        with mock.patch.object(bridge.subprocess, 'run', side_effect=subprocess.TimeoutExpired('child', 1)) as run:
            with self.assertRaises(subprocess.TimeoutExpired):
                bridge.network('http://localhost/api/chat', {}, {}, 1)
            self.assertEqual(run.call_args.kwargs['timeout'], 1)
            self.assertNotIn('http://localhost', ' '.join(run.call_args.args[0]))

    def test_atlas_projection_excludes_source_and_bounds(self):
        path = self.root / 'atlas.json'
        path.write_text(json.dumps({'recipes': [{'name': 'axe', 'kind': 'bench', 'inputs': [{'name': 'twine', 'quantity': 2}], 'outputs': [{'name': 'axe', 'quantity': 1}], 'conditions': 'research required', 'file': 'SECRET PATH', 'source': 'SECRET SOURCE', 'sprite': 'SECRET IMAGE'}]}))
        projected = bridge.recipe_context(path)
        self.assertIn('2 x twine', projected[0]['text'])
        self.assertIn('research required', projected[0]['text'])
        self.assertNotIn('SECRET', json.dumps(projected))


if __name__ == '__main__':
    unittest.main()
