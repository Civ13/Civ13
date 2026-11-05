"""Cross-region radio: the ephemeral ring, the agent routes and the coordinator fan-out."""
import os
import sys
import tempfile
import threading
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, ROOT)
from tools.transfer_storage.agent import make_server  # noqa: E402
from tools.transfer_storage.coordinator import Coordinator, call  # noqa: E402
from tools.transfer_storage.radio import RING, TTL, RadioError, RadioRelay  # noqa: E402
from tools.transfer_storage.region import RegionStore  # noqa: E402

TOKENS = {'alpha': 'a' * 40, 'beta': 'b' * 40, 'gamma': 'c' * 40}


class Clock:
    def __init__(self):
        self.now = 1000.0

    def __call__(self):
        return self.now


def envelope(**overrides):
    base = {'key': 'village', 'frequency': 150, 'name': 'Ada', 'message': 'hello over there',
            'language': 'Latin', 'verb': 'says', 'relay': 'north mast', 'condition': 80, 'ckey': 'ada'}
    base.update(overrides)
    return base


class RingTests(unittest.TestCase):
    def setUp(self):
        self.clock = Clock()
        self.relay = RadioRelay('alpha', 'g', self.clock)

    def test_send_validates_and_queues(self):
        ident = self.relay.send(envelope())
        out = self.relay.outbox()
        self.assertEqual(1, len(out['envelopes']))
        sent = out['envelopes'][0]
        self.assertEqual(ident, sent['id'])
        self.assertEqual(('g', 'alpha', 'village', 150, 'hello over there'),
                         (sent['group'], sent['source'], sent['key'], sent['frequency'], sent['message']))
        self.assertEqual([], self.relay.outbox()['envelopes'])  # handed out once
        for bad in (envelope(key='Village'), envelope(key=''), envelope(key='x' * 17),
                    envelope(frequency=149), envelope(frequency=150.5), envelope(frequency=True),
                    envelope(message=''), envelope(message='m' * 257), envelope(name=''),
                    envelope(condition=101), envelope(condition='fine'), 'not an object'):
            with self.assertRaises(RadioError):
                self.relay.send(bad)
        self.assertEqual(150, self.relay.send(envelope(frequency=150.0)) and 150)
        self.relay.send(envelope(frequency='Red (private)'))  # named faction channels pass as text

    def test_deliver_filters_duplicates_wrong_group_self_and_stale(self):
        sender = RadioRelay('beta', 'g', self.clock)
        sender.send(envelope())
        batch = sender.outbox()['envelopes']
        self.assertEqual(1, self.relay.deliver(batch))
        self.assertEqual(0, self.relay.deliver(batch))  # same id again
        self.assertEqual(1, len(self.relay.inbox()))
        self.assertEqual([], self.relay.inbox())
        self.assertEqual(0, self.relay.deliver([dict(batch[0], id='other1', group='h')]))
        self.assertEqual(0, self.relay.deliver([dict(batch[0], id='other2', source='alpha')]))
        self.assertEqual(0, self.relay.deliver([dict(batch[0], id='other3', age=TTL + 1)]))
        self.assertEqual(0, self.relay.deliver([dict(batch[0], id='other4', message='')]))
        self.assertEqual(0, self.relay.deliver(['garbage', 7]))
        with self.assertRaises(RadioError):
            self.relay.deliver('not a list')
        self.assertEqual(7, self.relay.status()['dropped'])

    def test_rings_are_bounded_and_expire(self):
        for i in range(RING + 20):
            self.relay.send(envelope(message='line %d' % i))
        out = self.relay.outbox()['envelopes']
        self.assertEqual(RING, len(out))
        self.assertEqual('line 20', out[0]['message'])
        sender = RadioRelay('beta', 'g', self.clock)
        sender.send(envelope())
        self.relay.deliver(sender.outbox()['envelopes'])
        self.clock.now += TTL + 1
        self.assertEqual([], self.relay.inbox())
        self.assertGreaterEqual(self.relay.status()['dropped'], 1)

    def test_heartbeats_show_peer_links_with_age(self):
        self.assertEqual(2, self.relay.heartbeat([{'key': 'village', 'condition': 70},
                                                  {'key': 'village', 'condition': 90}, {'key': 'raiders', 'condition': 5}]))
        beats = self.relay.outbox()['heartbeats']
        self.assertEqual({'village': {'condition': 90, 'age': 0}, 'raiders': {'condition': 5, 'age': 0}}, beats)
        other = RadioRelay('beta', 'g', self.clock)
        other.deliver([], {'alpha': beats, 'beta': {'village': {'condition': 1, 'age': 0}}, 'BAD KEY': {}})
        status = other.status()
        self.assertEqual({'alpha': {'village': {'condition': 90, 'age': 0}, 'raiders': {'condition': 5, 'age': 0}}},
                         status['peers'])
        self.clock.now += 200
        self.assertEqual({'alpha': {}}, other.status()['peers'])  # stale heartbeats stop counting as links
        with self.assertRaises(RadioError):
            self.relay.heartbeat([{'key': 'Bad Key'}])
        with self.assertRaises(RadioError):
            self.relay.heartbeat('x')


class AgentRadioTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.stores, self.servers, self.urls = {}, {}, {}
        for name, token in TOKENS.items():
            store = RegionStore(os.path.join(self.tmp.name, name + '.sqlite'), name, 'g')
            server = make_server(store, token)
            threading.Thread(target=server.serve_forever, daemon=True).start()
            self.stores[name], self.servers[name] = store, server
            self.urls[name] = 'http://127.0.0.1:%d' % server.server_address[1]
        self.coordinator = Coordinator(os.path.join(self.tmp.name, 'coordinator.sqlite'), 'g')
        for name in TOKENS:
            self.coordinator.enroll(name, self.urls[name], TOKENS[name])

    def tearDown(self):
        for name in self.servers:
            self.servers[name].shutdown()
            self.servers[name].server_close()
            self.stores[name].close()
        self.coordinator.close()
        self.tmp.cleanup()

    def post(self, region, path, body=None):
        return call(self.urls[region], TOKENS[region], path, body)

    def test_message_reaches_every_other_region_once(self):
        self.post('alpha', '/radio/heartbeat', {'relays': [{'key': 'village', 'condition': 77}]})
        sent = self.post('alpha', '/radio/send', {'envelope': envelope()})
        self.assertTrue(sent['ok'], sent)
        self.assertEqual(2, self.coordinator.relay_radio_once())
        self.assertEqual(0, self.coordinator.relay_radio_once())
        self.assertEqual([], self.post('alpha', '/radio/inbox')['result']['envelopes'])
        for region in ('beta', 'gamma'):
            got = self.post(region, '/radio/inbox')['result']['envelopes']
            self.assertEqual(1, len(got), region)
            self.assertEqual(('alpha', 'hello over there', 'ada'), (got[0]['source'], got[0]['message'], got[0]['ckey']))
            self.assertNotIn('at', got[0])
            self.assertEqual([], self.post(region, '/radio/inbox')['result']['envelopes'])
            peers = self.post(region, '/radio/status')['result']['peers']
            self.assertEqual(77, peers['alpha']['village']['condition'])
        # Nothing reached the durable ledger.
        for region in TOKENS:
            status = self.post(region, '/status')['result']
            self.assertEqual([], status['active'])
            self.assertEqual([], self.post(region, '/outbox')['result']['envelopes'])

    def test_refusals(self):
        bad = self.post('alpha', '/radio/send', {'envelope': envelope(key='NOPE')})
        self.assertFalse(bad['ok'])
        self.assertIn('key', bad['error'])
        self.assertEqual('bad token', call(self.urls['alpha'], TOKENS['beta'], '/radio/inbox')['error'])
        self.assertEqual(0, self.coordinator.relay_radio_once())

    def test_a_dead_agent_does_not_stop_the_others(self):
        self.post('alpha', '/radio/send', {'envelope': envelope()})
        self.servers['gamma'].shutdown()
        self.servers['gamma'].server_close()
        self.assertEqual(1, self.coordinator.relay_radio_once())
        self.assertEqual(1, len(self.post('beta', '/radio/inbox')['result']['envelopes']))


if __name__ == '__main__':
    unittest.main()
