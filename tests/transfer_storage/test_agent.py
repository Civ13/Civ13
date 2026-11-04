"""The loopback agent and coordinator relay, end to end over HTTP."""
import os
import sys
import tempfile
import threading
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, ROOT)
from tools.transfer_storage.agent import make_server  # noqa: E402
from tools.transfer_storage.coordinator import Coordinator, call  # noqa: E402
from tools.transfer_storage.region import IN, OUT, RegionStore  # noqa: E402

TOKEN_A = 'a' * 40
TOKEN_B = 'b' * 40


class AgentTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.stores, self.servers, self.urls = {}, {}, {}
        for name, token in (('alpha', TOKEN_A), ('beta', TOKEN_B)):
            store = RegionStore(os.path.join(self.tmp.name, name + '.sqlite'), name, 'g')
            peer = 'beta' if name == 'alpha' else 'alpha'
            store.enroll(peer, OUT)
            store.enroll(peer, IN)
            store.reconcile_load(name + '-g0', [], 0)
            server = make_server(store, token)
            threading.Thread(target=server.serve_forever, daemon=True).start()
            self.stores[name], self.servers[name] = store, server
            self.urls[name] = 'http://127.0.0.1:%d' % server.server_address[1]
        self.coordinator = Coordinator(os.path.join(self.tmp.name, 'coordinator.sqlite'), 'g')
        self.coordinator.enroll('alpha', self.urls['alpha'], TOKEN_A)
        self.coordinator.enroll('beta', self.urls['beta'], TOKEN_B)

    def tearDown(self):
        for name in self.servers:
            self.servers[name].shutdown()
            self.servers[name].server_close()
            self.stores[name].close()
        self.coordinator.close()
        self.tmp.cleanup()

    def a(self, path, body=None):
        return call(self.urls['alpha'], TOKEN_A, path, body)

    def b(self, path, body=None):
        return call(self.urls['beta'], TOKEN_B, path, body)

    def test_transfer_end_to_end(self):
        escrow = self.a('/escrow', {'peer': 'beta', 'payloads': ['axe', 'bread']})['result']
        self.assertEqual(0, self.coordinator.relay_once())  # nothing leaves before the save
        self.assertEqual(2, self.a('/save', {'generation': 'alpha-g1', 'effects': [escrow['effect_id']],
                                             'ledger_seq': 1})['result']['ledger_seq'])
        for _ in range(3):
            self.coordinator.relay_once()
        due = self.b('/status')['result']['pending_transfers']
        self.assertEqual([escrow['transfer_id']], due)
        imported = self.b('/import', {'transfer_id': escrow['transfer_id']})['result']
        self.assertEqual(['axe', 'bread'], imported['payloads'])
        self.b('/save', {'generation': 'beta-g1', 'effects': [imported['effect_id']], 'ledger_seq': 1})
        for _ in range(3):
            self.coordinator.relay_once()
        for path in (self.a, self.b):
            status = path('/status')['result']
            self.assertEqual([], status['active'])
        self.assertEqual([], self.a('/outbox')['result']['envelopes'])

    def test_bad_token_unknown_path_and_large_body(self):
        self.assertEqual('bad token', call(self.urls['alpha'], TOKEN_B, '/status')['error'])
        self.assertEqual('unknown path', self.a('/drop-tables')['error'])
        import http.client
        conn = http.client.HTTPConnection('127.0.0.1', self.servers['alpha'].server_address[1], timeout=5)
        conn.putrequest('POST', '/escrow')
        conn.putheader('X-Transfer-Token', TOKEN_A)
        conn.putheader('Content-Length', str((1 << 20) + 1))
        conn.endheaders()
        response = conn.getresponse()
        self.assertEqual(413, response.status)
        conn.close()

    def test_refusals_are_reported_not_raised(self):
        answer = self.a('/escrow', {'peer': 'gamma', 'payloads': ['axe']})
        self.assertFalse(answer['ok'])
        answer = self.a('/load', {'generation': 'old', 'effects': [], 'ledger_seq': 0})
        self.assertFalse(answer['ok'])  # the rollback hold is reported...
        self.assertTrue(answer['held'])
        self.assertIn('rollback', answer['error'])
        held = self.a('/escrow', {'peer': 'beta', 'payloads': ['axe']})
        self.assertTrue(held['held'])  # ...and later steps are refused

    def test_short_token_and_remote_coordinator_url_refused(self):
        with self.assertRaises(ValueError):
            make_server(self.stores['alpha'], 'short')
        with self.assertRaises(ValueError):
            self.coordinator.enroll('gamma', 'http://example.com:1', TOKEN_A)


if __name__ == '__main__':
    unittest.main()
