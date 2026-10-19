"""Native text2file byte protocol with an injected, offline model transport."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('spool_bridge', ROOT / 'scripts/player_help_bridge.py')
bridge = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(bridge)

NATIVE_ID = '8.45621e+09-932939-1'


class SpoolProtocolTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.calls = []
        config = {'enabled': True, 'model': 'offline', 'endpoint': 'http://localhost/api/chat',
                  'workers': 1, 'timeout_seconds': 1}
        def transport(*args):
            self.calls.append(args)
            return {'message': {'content': 'Offline sawmill answer'}}
        self.bridge = bridge.Bridge(self.root, config, [], transport)

    def tearDown(self):
        self.bridge.close()
        self.temp.cleanup()

    def write(self, request_id=NATIVE_ID, marker=None):
        request = {'id': request_id, 'account': 'a' * 32, 'question': 'How do I build a sawmill?'}
        (self.root / '1.request.json').write_text(json.dumps(request), encoding='utf-8')
        (self.root / '1.ready').write_bytes(
            (request_id + '\r\n').encode('ascii') if marker is None else marker)

    def complete(self):
        self.bridge.tick()
        self.assertEqual(len(self.bridge.active), 1, 'Native request must be admitted')
        self.bridge.active[1][1].result(timeout=2)
        self.bridge.tick(admit=False)

    def test_native_scientific_id_crlf_admission_and_completion(self):
        self.write()
        self.complete()
        self.assertTrue((self.root / '1.response.json').exists(), 'Native completion must publish a response')
        response = bridge.bounded_json(self.root / '1.response.json', 24000)
        self.assertEqual(response, {'id': NATIVE_ID, 'status': 'ok', 'answer': 'Offline sawmill answer', 'render_protocol': 1, 'answer_format': 'plain-v1'})
        self.assertEqual(len(self.calls), 1)
        payload = json.dumps(self.calls[0][1])
        self.assertNotIn(NATIVE_ID, payload)
        self.assertNotIn('a' * 32, payload)
        for _ in range(3):
            self.bridge.tick()
        self.assertEqual(len(self.calls), 1, 'Completed native marker must not dispatch again')

    def test_native_marker_line_endings_and_maximum_id(self):
        for request_id in ('1-2-3', NATIVE_ID, '8.45621E+09-932939-1',
                           '8.5e-09-1-1', '8456210000.5-1-1', '1' * 96 + '-1-1'):
            for ending in (b'', b'\n', b'\r\n'):
                with self.subTest(request_id=request_id, ending=ending):
                    (self.root / 'marker').write_bytes(request_id.encode('ascii') + ending)
                    self.assertEqual(bridge.read_ready_id(self.root / 'marker'), request_id)

    def test_malformed_ids_and_markers_never_admit_or_call(self):
        invalid = ('', '../1-2-3', '1/2/3', '1-2-3;exec', '1e+09-1-1/..',
                   '1e+-09-1-1', '1e-1', '1..2-3-4', '-1-2-3', '1-2',
                   '1-2-3-4', '1-2-3\n', '1-2\n-3', '1' * 97 + '-1-1')
        for request_id in invalid:
            with self.subTest(request_id=request_id):
                self.write(request_id)
                self.bridge.tick()
                self.assertFalse(self.bridge.active)
        for marker in (b' ' + NATIVE_ID.encode(), NATIVE_ID.encode() + b' ',
                       NATIVE_ID.encode() + b'\r', NATIVE_ID.encode() + b'\n\n',
                       NATIVE_ID.encode() + b'\r\n\r\n', b'1-2\n-3\r\n',
                       b'1-2-3\x00\r\n', b'\xff\r\n', b'1' * 100000):
            with self.subTest(marker_hash=hashlib.sha256(marker).hexdigest()):
                self.write(marker=marker)
                self.bridge.tick()
                self.assertFalse(self.bridge.active)
        self.assertFalse(self.calls)
        self.assertFalse((self.root / '1.response.json').exists())

    def test_missing_or_stale_marker_never_admits(self):
        self.write(marker=b'1-2-3\r\n')
        self.bridge.tick()
        self.assertFalse(self.bridge.active)
        (self.root / '1.ready').unlink()
        self.bridge.tick()
        self.assertFalse(self.bridge.active)
        self.assertFalse(self.calls)

    def test_changed_completion_marker_cannot_receive_old_answer(self):
        self.write()
        self.bridge.tick()
        self.bridge.active[1][1].result(timeout=2)
        for marker in (b'1-2-3\r\n', NATIVE_ID.encode() + b'\r\n\r\n'):
            with self.subTest(marker=marker):
                # Keep the already completed future; no new model call or request.
                future = next(iter(self.bridge.active.values()))[1]
                (self.root / '1.ready').write_bytes(marker)
                self.bridge.tick(admit=False)
                self.assertFalse((self.root / '1.response.json').exists())
                self.bridge.active[1] = (NATIVE_ID, future)
        (self.root / '1.ready').unlink()
        self.bridge.tick(admit=False)
        self.assertFalse((self.root / '1.response.json').exists())
        self.assertEqual(len(self.calls), 1)

    def test_native_stale_response_replaced_without_duplicate_dispatch(self):
        self.write()
        bridge.atomic_json(self.root / '1.response.json', {'id': '1-2-3', 'status': 'ok', 'answer': 'old'})
        self.complete()
        self.assertEqual(bridge.bounded_json(self.root / '1.response.json', 24000)['id'], NATIVE_ID)
        self.assertEqual(len(self.calls), 1)


if __name__ == '__main__':
    unittest.main()
