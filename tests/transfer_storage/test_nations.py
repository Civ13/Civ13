"""Nations: unions of factions decided by the coordinator for the whole group."""
import os
import sqlite3
import sys
import tempfile
import threading
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, ROOT)
from tools.transfer_storage.agent import make_server  # noqa: E402
from tools.transfer_storage.coordinator import Coordinator, call  # noqa: E402
from tools.transfer_storage.nations import NATION_CAPACITY, SECEDE_COOLDOWN, APPLICATION_SECONDS, Nations  # noqa: E402
from tools.transfer_storage.region import RegionStore, TransferError  # noqa: E402

A, B, C, D, E = ('civ:alpha:Ash', 'civ:alpha:Birch', 'civ:alpha:Cedar', 'civ:beta:Dune', 'civ:beta:Elm')
T = 1_000_000


class RegistryTests(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(':memory:', isolation_level=None)
        self.n = Nations(self.db)

    def ask(self, land, op, faction, now=T, **kw):
        return self.n.decide(land, dict(kw, op=op, actor='leader', faction=faction), now)

    def found(self):
        self.assertIn('founded', self.ask('alpha', 'found', A, name='Union', **{'with': [B]}))
        return self.n.nation_of(A)

    def test_found_needs_own_land_and_free_factions(self):
        self.assertIn('same land', self.ask('alpha', 'found', A, name='Union', **{'with': [D]}))
        self.assertIn('own land', self.ask('beta', 'found', A, name='Union', **{'with': [B]}))
        nid = self.found()
        self.assertEqual(self.n.members(nid), [A, B])
        self.assertEqual(self.n.snapshot(T)[nid]['head'], A)
        self.assertIn('already belongs', self.ask('alpha', 'found', B, name='Other', **{'with': [C]}))
        self.assertIn('already exists', self.ask('alpha', 'found', C, name='union', **{'with': ['civ:alpha:Fir']}))

    def test_found_limited_to_base_capacity(self):
        self.assertIn('not understood', self.ask('alpha', 'found', A, name='Union', **{'with': [B, C, 'civ:alpha:Fir']}))

    def test_join_by_majority_from_other_land(self):
        nid = self.found()
        self.assertIn('applied', self.ask('beta', 'apply', D, nation=nid))
        self.assertIn('counted', self.ask('alpha', 'vote', A, applicant=D, yes=True))
        self.assertEqual(self.n.snapshot(T)[nid]['applications'][0]['votes'], {A: 'yes'})
        self.assertIn('passed', self.ask('alpha', 'vote', B, applicant=D, yes=True))
        self.assertEqual(self.n.nation_of(D), nid)
        self.assertEqual(self.n.snapshot(T)[nid]['applications'], [])

    def test_refusal_and_expiry(self):
        nid = self.found()
        self.ask('beta', 'apply', D, nation=nid)
        self.assertIn('refused', self.ask('alpha', 'vote', A, applicant=D, yes=False))
        self.assertIsNone(self.n.nation_of(D))
        self.ask('beta', 'apply', D, nation=nid)
        self.assertEqual(self.n.snapshot(T + APPLICATION_SECONDS + 1)[nid]['applications'], [])

    def test_vote_only_by_members(self):
        nid = self.found()
        self.ask('beta', 'apply', D, nation=nid)
        self.assertIn('not part of a nation', self.ask('beta', 'vote', E, applicant=D, yes=True))

    def test_capacity_rises_with_assembly(self):
        nid = self.found()
        self.ask('alpha', 'apply', C, nation=nid)
        self.ask('alpha', 'vote', A, applicant=C, yes=True)
        self.ask('alpha', 'vote', B, applicant=C, yes=True)
        self.assertEqual(len(self.n.members(nid)), NATION_CAPACITY[0])
        self.assertIn('as many factions', self.ask('beta', 'apply', D, nation=nid))
        self.assertIsNone(self.ask('alpha', 'assembly', B, tier=1))
        self.assertEqual(self.n.capacity(nid), NATION_CAPACITY[1])
        self.assertIn('applied', self.ask('beta', 'apply', D, nation=nid))
        # An assembly that burns takes its tier with it.
        self.ask('alpha', 'assembly', B, tier=0)
        self.assertEqual(self.n.capacity(nid), NATION_CAPACITY[0])

    def test_head_by_majority(self):
        nid = self.found()
        self.assertIn('counted', self.ask('alpha', 'head', A, candidate=B))
        self.assertIn('majority', self.ask('alpha', 'head', B, candidate=B))
        self.assertEqual(self.n.snapshot(T)[nid]['head'], B)
        self.assertIn('Only a member', self.ask('alpha', 'head', A, candidate=D))

    def test_secede_cooldown_and_dissolve(self):
        nid = self.found()
        self.ask('alpha', 'apply', C, nation=nid)
        self.ask('alpha', 'vote', A, applicant=C, yes=True)
        self.ask('alpha', 'vote', B, applicant=C, yes=True)
        self.assertIn('seceded from', self.ask('alpha', 'secede', A))
        self.assertEqual(self.n.snapshot(T)[nid]['head'], B)  # longest-standing member
        self.assertIn('recently', self.ask('alpha', 'apply', A, nation=nid, now=T + 10))
        self.assertIn('applied', self.ask('alpha', 'apply', A, nation=nid, now=T + SECEDE_COOLDOWN + 10))
        self.assertIn('dissolved', self.ask('alpha', 'secede', B, now=T + SECEDE_COOLDOWN + 20))
        self.assertEqual(self.n.snapshot(T + SECEDE_COOLDOWN + 20), {})
        self.assertIsNone(self.n.nation_of(C))

    def test_rename_keeps_place(self):
        nid = self.found()
        self.ask('alpha', 'head', B, candidate=A)
        self.assertIsNone(self.ask('alpha', 'rename', A, to='civ:alpha:Oak'))
        snap = self.n.snapshot(T)[nid]
        self.assertIn('civ:alpha:Oak', snap['members'])
        self.assertNotIn(A, snap['members'])
        self.assertEqual(snap['head'], 'civ:alpha:Oak')
        self.assertEqual(snap['head_votes'], {B: 'civ:alpha:Oak'})
        self.assertIn('not understood', self.ask('alpha', 'rename', B, to='civ:beta:Birch'))


class AgentRoundTripTests(unittest.TestCase):
    TOKENS = {'alpha': 'a' * 40, 'beta': 'b' * 40}

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.stores, self.servers, self.urls = {}, {}, {}
        for name in self.TOKENS:
            store = RegionStore(os.path.join(self.tmp.name, name + '.sqlite'), name, 'g')
            server = make_server(store, self.TOKENS[name])
            threading.Thread(target=server.serve_forever, daemon=True).start()
            self.stores[name], self.servers[name] = store, server
            self.urls[name] = 'http://127.0.0.1:%d' % server.server_address[1]
        self.coordinator = Coordinator(os.path.join(self.tmp.name, 'c.sqlite'), 'g', 'alpha', bootstrap_new_group=True)
        for name in self.stores:
            self.coordinator.enroll(name, self.urls[name], self.TOKENS[name])
        self.coordinator.homes_once()

    def tearDown(self):
        for name in list(self.servers):
            self.servers[name].shutdown()
            self.servers[name].server_close()
            self.stores[name].close()
        self.coordinator.close()
        self.tmp.cleanup()

    def agent(self, land, path, body):
        return call(self.urls[land], self.TOKENS[land], path, body)

    def test_request_decided_and_told_once(self):
        answer = self.agent('alpha', '/nation/request', {'op': 'found', 'actor': 'val', 'faction': A, 'name': 'Union',
                                                         'with': [B]})
        self.assertTrue(answer['ok'])
        self.assertEqual(len(self.agent('alpha', '/nations', {})['result']['pending']), 1)
        self.coordinator.homes_once()
        for land in ('alpha', 'beta'):
            nations = self.agent(land, '/nations', {})['result']
            self.assertEqual([n['name'] for n in nations['nations'].values()], ['Union'])
        result = self.agent('alpha', '/nations', {})['result']
        self.assertEqual(result['pending'], [])
        self.assertEqual([(r['actor'], r['faction']) for r in result['results']], [('val', A)])
        self.assertIn('founded', result['results'][0]['text'])
        # Deciding again changes nothing; the told outcome goes away.
        self.coordinator.homes_once()
        self.assertEqual(len(self.agent('alpha', '/nations', {})['result']['results']), 1)
        self.agent('alpha', '/nation/seen', {'ids': [result['results'][0]['id']]})
        self.assertEqual(self.agent('alpha', '/nations', {})['result']['results'], [])

    def test_world_speaks_only_for_its_factions(self):
        with self.assertRaises(TransferError):
            self.stores['beta'].request_nation({'op': 'secede', 'actor': 'val', 'faction': A})
        with self.assertRaises(TransferError):
            self.stores['alpha'].request_nation({'op': 'found', 'actor': 'val', 'faction': A, 'name': '<b>', 'with': [B]})

    def test_lost_answer_is_not_decided_twice(self):
        self.stores['beta'].request_nation({'op': 'found', 'actor': 'val', 'faction': D, 'name': 'Shore', 'with': [E]})
        url, token = self.coordinator.regions()['beta']
        self.coordinator.db.execute("UPDATE region SET token = 'x' WHERE region = 'beta'")
        self.coordinator.homes_once()  # beta cannot be read: nothing decided
        self.coordinator.db.execute('UPDATE region SET token = ? WHERE region = ?', (token, 'beta'))
        self.coordinator.homes_once()
        self.coordinator.homes_once()
        texts = [r['text'] for r in self.stores['beta'].nations()['results']]
        self.assertEqual(len(texts), 1)
        self.assertIn('founded', texts[0])


if __name__ == '__main__':
    unittest.main()
