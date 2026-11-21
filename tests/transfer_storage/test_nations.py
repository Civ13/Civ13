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
from tools.transfer_storage.nations import (NATION_CAPACITY, SECEDE_COOLDOWN, APPLICATION_SECONDS, GOVERNMENTS,  # noqa: E402
                                           GOVERNMENT_COOLDOWN, GOVERNMENT_NOTICE, Nations)
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

    def test_common_currency_by_majority(self):
        nid = self.found()
        self.assertIsNone(self.n.snapshot(T)[nid]['currency'])
        self.assertIn('counted', self.ask('alpha', 'currency', A, issuer=B))
        self.assertEqual(self.n.snapshot(T)[nid]['currency_votes'], {A: B})
        self.assertIn('common money', self.ask('alpha', 'currency', B, issuer=B))
        self.assertEqual(self.n.snapshot(T)[nid]['currency'], B)
        self.assertIn("member faction's coin", self.ask('alpha', 'currency', A, issuer=D))
        self.assertIn('not understood', self.ask('alpha', 'currency', A, issuer='nonsense'))
        # A vote for no faction drops the common money.
        self.ask('alpha', 'currency', A, issuer='')
        self.assertIn('no common money', self.ask('alpha', 'currency', B, issuer=''))
        self.assertIsNone(self.n.snapshot(T)[nid]['currency'])

    def test_currency_follows_rename_and_leaves_with_its_faction(self):
        nid = self.found()
        self.ask('alpha', 'apply', C, nation=nid)
        self.ask('alpha', 'vote', A, applicant=C, yes=True)
        self.ask('alpha', 'vote', B, applicant=C, yes=True)
        self.ask('alpha', 'currency', A, issuer=B)
        self.ask('alpha', 'currency', C, issuer=B)
        self.assertEqual(self.n.currency(nid), B)
        self.ask('alpha', 'rename', B, to='civ:alpha:Bark')
        self.assertEqual(self.n.currency(nid), 'civ:alpha:Bark')
        self.ask('alpha', 'secede', 'civ:alpha:Bark')
        self.assertIsNone(self.n.currency(nid))

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


class GovernmentTests(unittest.TestCase):
    """Nation government types (Val GO 2026-11-21, docs/nation-government.md)."""

    def setUp(self):
        self.db = sqlite3.connect(':memory:', isolation_level=None)
        self.n = Nations(self.db)
        self.assertIn('founded', self.ask('alpha', 'found', A, name='Union', **{'with': [B]}))
        self.nid = self.n.nation_of(A)
        self.ask('alpha', 'apply', C, nation=self.nid)
        self.ask('alpha', 'vote', A, applicant=C, yes=True)
        self.ask('alpha', 'vote', B, applicant=C, yes=True)

    def ask(self, land, op, faction, now=T, actor='leader', **kw):
        return self.n.decide(land, dict(kw, op=op, actor=actor, faction=faction), now)

    def monarchy(self, faction, now=T):
        return self.ask('alpha', 'govern', faction, now=now, type='monarchy', person='val', pname='Queen Val', pfaction=A)

    def crown(self):
        for f in (A, B, C):
            self.ask('alpha', 'era', f, age=1)
        self.monarchy(A)
        self.assertIn('becomes a monarchy', self.monarchy(B))
        self.n.snapshot(T + GOVERNMENT_NOTICE)

    def gov(self, now=T):
        return self.n.snapshot(now)[self.nid]['government']

    def test_default_is_confederation_like_today(self):
        g = self.gov()
        self.assertEqual((g['type'], g['ruler'], g['pending']), ('confederation', None, None))
        self.assertEqual(self.n.capacity(self.nid), NATION_CAPACITY[0])

    def test_change_needs_two_thirds_era_and_notice(self):
        self.assertIn('age it belongs to', self.monarchy(A))
        for f in (A, B):
            self.ask('alpha', 'era', f, age=1)
        self.assertIn('counted', self.monarchy(A))
        self.assertEqual(self.n.snapshot(T)[self.nid]['government_votes'][A][0], 'monarchy')
        self.assertIn('becomes a monarchy', self.monarchy(B))
        self.assertEqual(self.gov()['pending']['type'], 'monarchy')
        self.assertEqual(self.gov(T + GOVERNMENT_NOTICE - 1)['type'], 'confederation')
        g = self.gov(T + GOVERNMENT_NOTICE)
        self.assertEqual((g['type'], g['head_account'], g['head_name']), ('monarchy', 'val', 'Queen Val'))
        self.assertEqual(self.n.snapshot(T + GOVERNMENT_NOTICE)[self.nid]['head'], A)
        self.assertEqual(self.n.capacity(self.nid), NATION_CAPACITY[0] + GOVERNMENTS['monarchy']['bonus'])

    def test_ruler_decides_alone_and_cooldown_holds(self):
        self.crown()
        later = T + GOVERNMENT_NOTICE + 10
        self.assertIn('recently', self.ask('alpha', 'govern', A, now=later, actor='val', type='confederation'))
        later += GOVERNMENT_COOLDOWN
        self.assertIn('Only the Monarch', self.ask('alpha', 'govern', B, now=later, type='confederation'))
        self.assertIn('decree', self.ask('alpha', 'govern', A, now=later, actor='val', type='confederation'))
        self.assertEqual(self.gov(later + GOVERNMENT_NOTICE)['type'], 'confederation')

    def test_ruler_admits_and_sets_money(self):
        self.crown()
        now = T + GOVERNMENT_NOTICE
        self.ask('beta', 'apply', D, nation=self.nid, now=now)
        self.assertIn('Only the Monarch admits', self.ask('alpha', 'vote', B, now=now, applicant=D, yes=True))
        self.assertIn('joins', self.ask('alpha', 'vote', A, now=now, actor='val', applicant=D, yes=True))
        self.assertEqual(self.n.nation_of(D), self.nid)
        self.assertIn('Only the Monarch chooses', self.ask('alpha', 'currency', B, now=now, issuer=B))
        self.ask('alpha', 'currency', A, now=now, actor='val', issuer=B)
        self.assertEqual(self.n.currency(self.nid), B)
        self.assertIn('set by its government', self.ask('alpha', 'head', B, now=now, candidate=B))

    def test_secession_notice_and_stay(self):
        self.crown()
        now = T + GOVERNMENT_NOTICE
        self.assertIn('48 hours', self.ask('alpha', 'secede', C, now=now))
        self.assertIn('already leaving', self.ask('alpha', 'secede', C, now=now + 3600))
        self.assertIn('stays', self.ask('alpha', 'stay', C, now=now + 3600))
        self.ask('alpha', 'secede', C, now=now + 3600)
        self.assertIn(C, self.n.snapshot(now + 3600 + GOVERNMENTS['monarchy']['notice'] - 1)[self.nid]['members'])
        self.assertNotIn(C, self.n.snapshot(now + 3600 + GOVERNMENTS['monarchy']['notice'])[self.nid]['members'])

    def test_ruler_faction_leaving_collapses_the_government(self):
        self.crown()
        now = T + GOVERNMENT_NOTICE
        self.ask('alpha', 'secede', A, now=now)
        g = self.gov(now + GOVERNMENTS['monarchy']['notice'])
        self.assertEqual((g['type'], g['head_account']), ('confederation', None))
        self.assertEqual(self.n.snapshot(now + GOVERNMENTS['monarchy']['notice'])[self.nid]['head'], B)

    def test_proposals_are_validated(self):
        self.assertIn('not understood', self.ask('alpha', 'govern', A, type='empire'))
        self.assertIn('not understood', self.ask('alpha', 'govern', A, type='monarchy'))
        self.assertIn('not understood', self.ask('alpha', 'govern', A, type='theocracy', person='val', pname='Val',
                                                 pfaction=A))
        self.assertIn('not understood', self.ask('alpha', 'govern', A, type='monarchy', person='val', pname='<b>',
                                                 pfaction=A))
        self.assertIn('citizen of a member', self.ask('alpha', 'govern', A, type='theocracy', person='val', pname='Val',
                                                      pfaction=D, religion='Sun'))

    def test_rename_follows_the_proposal(self):
        self.ask('alpha', 'govern', B, type='theocracy', person='val', pname='Val', pfaction=A, religion='Sun')
        self.ask('alpha', 'rename', A, to='civ:alpha:Oak')
        self.assertEqual(self.n.snapshot(T)[self.nid]['government_votes'][B][3], 'civ:alpha:Oak')
        self.ask('alpha', 'govern', 'civ:alpha:Oak', type='theocracy', person='val', pname='Val', pfaction='civ:alpha:Oak',
                 religion='Sun')
        g = self.gov(T + GOVERNMENT_NOTICE)
        self.assertEqual((g['type'], g['religion']), ('theocracy', 'Sun'))
        self.assertEqual(self.n.snapshot(T + GOVERNMENT_NOTICE)[self.nid]['head'], 'civ:alpha:Oak')

    def test_dictatorship_capacity_is_capped(self):
        for tier in (3,):
            self.ask('alpha', 'assembly', A, tier=tier)
        for f in (A, B, C):
            self.ask('alpha', 'era', f, age=1)
        for f in (A, B):
            self.ask('alpha', 'govern', f, type='dictatorship', person='val', pname='Val', pfaction=A)
        self.n.snapshot(T + GOVERNMENT_NOTICE)
        self.assertEqual(self.n.capacity(self.nid), 9)


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

    def test_currency_and_government_requests_pass_the_agent(self):
        self.stores['alpha'].request_nation({'op': 'currency', 'actor': 'val', 'faction': A, 'issuer': ''})
        self.stores['alpha'].request_nation({'op': 'govern', 'actor': 'val', 'faction': A, 'type': 'monarchy',
                                             'person': 'val', 'pname': 'Val', 'pfaction': A})
        self.stores['alpha'].request_nation({'op': 'era', 'actor': 'world', 'faction': A, 'age': 2})
        kinds = [(r['op'], r.get('issuer'), r.get('pname'), r.get('age')) for r in self.stores['alpha'].nations()['pending']]
        self.assertEqual(kinds, [('currency', '', None, None), ('govern', None, 'Val', None), ('era', None, None, 2)])

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
