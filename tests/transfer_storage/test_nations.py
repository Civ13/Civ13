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
        self.ask('alpha', 'present', A, now=later + 3 * 86400, actor='val')
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

    def test_rename_keeps_era_and_notice(self):
        self.ask('alpha', 'era', C, age=2)
        self.crown()
        self.ask('alpha', 'secede', C, now=T + GOVERNMENT_NOTICE)
        self.ask('alpha', 'rename', C, to='civ:alpha:Cork', now=T + GOVERNMENT_NOTICE)
        snap = self.n.snapshot(T + GOVERNMENT_NOTICE)[self.nid]
        self.assertEqual(snap['eras']['civ:alpha:Cork'], 1)
        self.assertIn('civ:alpha:Cork', snap['leaving'])

    def test_absent_monarch_passes_to_heir_or_leaves_throne_empty(self):
        self.crown()
        now = T + GOVERNMENT_NOTICE
        self.assertIn('Only the Monarch names', self.ask('alpha', 'heir', B, now=now, person='bob', pname='Bob',
                                                         pfaction=B))
        self.assertIn('named heir', self.ask('alpha', 'heir', A, now=now, actor='val', person='bob', pname='Bob',
                                             pfaction=B))
        self.assertEqual(self.gov(now)['successor']['account'], 'bob')
        self.ask('alpha', 'present', A, now=now + 5 * 86400, actor='val')
        self.assertEqual(self.gov(now + 11 * 86400)['head_account'], 'val')
        g = self.gov(now + 12 * 86400 + 1)
        self.assertEqual((g['head_account'], g['successor']), ('bob', None))
        self.assertEqual(self.n.snapshot(now + 12 * 86400 + 1)[self.nid]['head'], B)
        # Bob vanishes too: with no heir the throne stands empty.
        g = self.gov(now + 20 * 86400)
        self.assertEqual((g['type'], g['head_account']), ('monarchy', None))
        # The member factions decide while it is empty, and anyone may claim it.
        self.ask('beta', 'apply', D, nation=self.nid, now=now + 20 * 86400)
        self.assertIn('counted', self.ask('alpha', 'vote', A, now=now + 20 * 86400, applicant=D, yes=True))
        self.assertIn('take the empty throne', self.ask('alpha', 'claim', C, now=now + 20 * 86400, actor='cat',
                                                       role='citizen', pname='Cat'))
        self.assertIn('not empty', self.ask('alpha', 'claim', B, now=now + 20 * 86400, actor='bob', role='citizen',
                                            pname='Bob'))
        self.assertEqual(self.gov(now + 20 * 86400)['head_account'], 'cat')

    def test_absent_dictator_collapses_and_faith_leads_theocracy(self):
        for f in (A, B, C):
            self.ask('alpha', 'era', f, age=1)
        for f in (A, B):
            self.ask('alpha', 'govern', f, type='dictatorship', person='val', pname='Val', pfaction=A)
        now = T + GOVERNMENT_NOTICE
        self.assertEqual(self.gov(now)['type'], 'dictatorship')
        self.assertEqual(self.gov(now + 3 * 86400 + 1)['type'], 'confederation')
        now += 3 * 86400 + 1 + GOVERNMENT_COOLDOWN
        for f in (A, B):
            self.ask('alpha', 'govern', f, now=now, type='theocracy', person='val', pname='Val', pfaction=A,
                     religion='Sun')
        now += GOVERNMENT_NOTICE
        self.ask('alpha', 'faith', B, now=now, actor='bob', role='citizen', pname='Bob', religion='Moon')
        self.assertEqual(self.gov(now)['head_account'], 'val')
        self.ask('alpha', 'faith', B, now=now, actor='bob', role='citizen', pname='Bob', religion='Sun')
        self.assertEqual(self.gov(now)['head_account'], 'bob')

    def test_dictatorship_capacity_is_capped(self):
        for tier in (3,):
            self.ask('alpha', 'assembly', A, tier=tier)
        for f in (A, B, C):
            self.ask('alpha', 'era', f, age=1)
        for f in (A, B):
            self.ask('alpha', 'govern', f, type='dictatorship', person='val', pname='Val', pfaction=A)
        self.n.snapshot(T + GOVERNMENT_NOTICE)
        self.assertEqual(self.n.capacity(self.nid), 9)


class ElectiveTests(unittest.TestCase):
    """Motions and elections of republics, democracies and leagues
    (tools/transfer_storage/nation_motions.py)."""

    def setUp(self):
        self.db = sqlite3.connect(':memory:', isolation_level=None)
        self.n = Nations(self.db)
        self.ask('alpha', 'found', A, name='Union', **{'with': [B]})
        self.nid = self.n.nation_of(A)
        self.ask('alpha', 'apply', C, nation=self.nid)
        self.ask('alpha', 'vote', A, applicant=C, yes=True)
        self.ask('alpha', 'vote', B, applicant=C, yes=True)
        for f, citizens, wealth in ((A, 6, 1000), (B, 2, 10), (C, 2, 10)):
            self.ask('alpha', 'era', f, age=2)
            self.ask('alpha', 'census', f, citizens=citizens, wealth=wealth)

    def ask(self, land, op, faction, now=T, actor='leader', **kw):
        return self.n.decide(land, dict(kw, op=op, actor=actor, faction=faction), now)

    def become(self, kind):
        for f in (A, B, C):
            self.ask('alpha', 'govern', f, type=kind, person='val', pname='Val', pfaction=A)
        self.now = T + GOVERNMENT_NOTICE
        self.assertEqual(self.snap()['government']['type'], kind)

    def snap(self, now=None):
        return self.n.snapshot(self.now if now is None and hasattr(self, 'now') else (now or T))[self.nid]

    def motion(self, kind):
        return [m for m in self.snap()['motions'] if m['kind'] == kind]

    def test_senate_weights_by_citizens_and_closes_early(self):
        self.become('republic')
        self.assertEqual(self.snap()['term_ends'], self.now + 14 * 86400)
        self.ask('beta', 'apply', D, nation=self.nid, now=self.now)
        [m] = self.motion('admit')
        # A alone holds 6 of 10 citizens: its yes carries at once.
        self.assertIn('counted', self.ask('alpha', 'vote', A, now=self.now, applicant=D, yes=True))
        self.assertEqual(self.n.nation_of(D), self.nid)
        self.assertEqual(self.motion('admit'), [])

    def test_senate_leader_only_and_ballot_change(self):
        self.become('republic')
        self.assertIn("leader can bring", self.ask('alpha', 'currency', B, now=self.now, role='citizen', issuer=B))
        self.assertIn('open', self.ask('alpha', 'currency', B, now=self.now, issuer=B))
        [m] = self.motion('currency')
        self.assertIn('no vote', self.ask('alpha', 'ballot', C, now=self.now, role='citizen', motion=m['id'], choice='yes'))
        self.ask('alpha', 'ballot', A, now=self.now, motion=m['id'], choice='no')
        self.assertEqual(self.motion('currency'), [])  # 6 of 10 against: it cannot pass
        self.assertIsNone(self.n.currency(self.nid))

    def test_referendum_needs_quorum(self):
        self.become('democracy')
        self.assertIn('open', self.ask('alpha', 'currency', A, now=self.now, actor='ann', role='citizen', issuer=B))
        [m] = self.motion('currency')
        self.assertEqual(m['possible'], 10)
        self.n.snapshot(self.now + 86400)
        self.assertIsNone(self.n.currency(self.nid))  # 1 of 10 voted: under a third
        self.ask('alpha', 'currency', A, now=self.now, actor='ann', role='citizen', issuer=B)
        [m] = self.motion('currency')
        for who in ('bob', 'cat', 'dan'):
            self.ask('alpha', 'ballot', B, now=self.now, actor=who, role='citizen', motion=m['id'], choice='yes')
        self.ask('alpha', 'ballot', B, now=self.now, actor='bob', role='citizen', motion=m['id'], choice='yes')
        self.assertEqual(self.motion('currency')[0]['yes'], 4)  # one ballot per account
        self.n.snapshot(self.now + 2 * 86400)
        self.assertEqual(self.n.currency(self.nid), B)

    def test_change_of_government_needs_two_thirds_and_half_turnout(self):
        self.become('democracy')
        self.now += GOVERNMENT_COOLDOWN
        self.ask('alpha', 'govern', A, now=self.now, actor='ann', role='citizen', type='confederation')
        [m] = self.motion('government')
        for who in ('bob', 'cat', 'dan'):
            self.ask('alpha', 'ballot', A, now=self.now, actor=who, role='citizen', motion=m['id'], choice='yes')
        self.n.snapshot(self.now + 86400)
        self.assertIsNone(self.snap(self.now + 86400)['government']['pending'])  # 4 of 10: under half
        self.ask('alpha', 'govern', A, now=self.now + 86400, actor='ann', role='citizen', type='confederation')
        [m] = self.motion('government')
        for who in ('bob', 'cat', 'dan', 'eve'):
            self.ask('alpha', 'ballot', A, now=self.now + 86400, actor=who, role='citizen', motion=m['id'], choice='yes')
        self.ask('alpha', 'ballot', A, now=self.now + 86400, actor='fay', role='citizen', motion=m['id'], choice='no')
        g = self.snap(self.now + 2 * 86400)['government']
        self.assertEqual(g['pending']['type'], 'confederation')

    def test_election_at_term_end(self):
        self.become('democracy')
        end = self.snap()['term_ends']
        self.assertEqual(self.motion('election'), [])
        self.now = end
        [m] = self.motion('election')
        self.assertIn('stand', self.ask('alpha', 'stand', B, now=end, actor='bob', role='citizen', pname='Bob'))
        self.ask('alpha', 'stand', C, now=end, actor='cat', role='citizen', pname='Cat')
        self.ask('alpha', 'ballot', A, now=end, actor='ann', role='citizen', motion=m['id'], choice='cat')
        self.assertIn('not standing', self.ask('alpha', 'ballot', A, now=end, actor='ann', role='citizen',
                                               motion=m['id'], choice='zed'))
        self.now = end + 86400
        g = self.snap()['government']
        self.assertEqual((g['head_account'], g['head_name']), ('cat', 'Cat'))
        self.assertEqual(self.snap()['head'], C)
        self.assertEqual(self.snap()['term_ends'], end + 86400 + 7 * 86400)

    def test_league_council_weighs_strongboxes_with_a_cap(self):
        self.become('league')
        self.assertEqual(self.n.weights(self.nid), {A: 0.4 * 1020, B: 10, C: 10})
        self.ask('alpha', 'currency', A, now=self.now, issuer=A)
        self.assertEqual(self.n.currency(self.nid), A)  # 408 of 428 at once

    def test_absent_consul_hands_to_deputy_and_election_opens(self):
        self.become('republic')
        self.ask('alpha', 'deputy', A, now=self.now, actor='val', person='bob', pname='Bob', pfaction=B)
        self.now += 3 * 86400 + 1
        snap = self.snap()
        self.assertEqual(snap['government']['head_account'], 'bob')
        self.assertEqual([m['kind'] for m in snap['motions']], ['election'])

    def test_rename_and_dissolve_follow_motions(self):
        self.become('republic')
        self.ask('alpha', 'currency', B, now=self.now, issuer=B)
        self.ask('alpha', 'rename', B, to='civ:alpha:Bark', now=self.now)
        [m] = self.motion('currency')
        self.assertEqual(m['subject'], 'civ:alpha:Bark')
        self.assertEqual(m['ballots'], {'civ:alpha:Bark': 'yes'})
        self.ask('alpha', 'secede', C, now=self.now)
        self.ask('alpha', 'secede', 'civ:alpha:Bark', now=self.now)
        self.n.snapshot(self.now + 3 * 86400)
        self.assertEqual(self.db.execute('SELECT COUNT(*) FROM nation_motion').fetchone()[0], 0)


class RevoltTests(ElectiveTests.__base__):
    """Revolt petitions and the assembly hold (tools/transfer_storage/nation_revolt.py)."""

    setUp = ElectiveTests.setUp
    ask = ElectiveTests.ask
    become = ElectiveTests.become
    snap = ElectiveTests.snap

    def petition(self, who='ann', now=None, **kw):
        kw.setdefault('type', 'confederation')
        return self.ask('alpha', 'revolt', B, now=self.now if now is None else now, actor=who, role='citizen',
                        sname=who.title(), **kw)

    def sign(self, who, faction=B, now=None):
        return self.ask('alpha', 'sign', faction, now=self.now if now is None else now, actor=who, role='citizen',
                        sname=who.title())

    def test_petition_fills_waits_and_overthrows(self):
        self.become('monarchy')
        self.assertIn('own rule', self.petition('val'))
        self.assertIn('open a revolt petition', self.petition())
        self.assertIn('already open', self.petition('bob'))
        r = self.snap()['revolt']
        self.assertEqual((r['type'], r['needed'], [s['account'] for s in r['signers']]), ('confederation', 5, ['ann']))
        self.assertIn('own rule', self.sign('val', A))
        for who in ('bob', 'cat', 'dan'):
            self.assertIn('You sign', self.sign(who))
        self.assertIn('has its signatures', self.sign('eve', C))
        self.assertIn('already has', self.sign('fay'))
        ripe = self.now
        self.assertEqual(self.snap()['revolt']['hold_from'], ripe + 86400)
        self.assertIn('wait a day', self.ask('alpha', 'overthrow', B, now=ripe + 10, actor='ann', role='citizen'))
        self.assertIn('Only a signer', self.ask('alpha', 'overthrow', B, now=ripe + 86400, actor='fay', role='citizen'))
        self.assertIn('falls', self.ask('alpha', 'overthrow', B, now=ripe + 86400, actor='eve', role='citizen'))
        self.now = ripe + 86400
        snap = self.snap()
        self.assertEqual(snap['government']['type'], 'confederation')
        self.assertEqual(snap['revolt'], {'cooldown': ripe + 86400 + 7 * 86400})
        self.assertIn('recently', self.petition('bob', type='monarchy', person='bob', pname='Bob', pfaction=B))

    def test_unfilled_petition_bars_only_its_opener(self):
        self.become('monarchy')
        self.petition()
        self.now += 2 * 86400 + 1
        self.assertIsNone(self.snap()['revolt']['cooldown'])
        self.assertIn('too few signers', self.petition())
        self.assertIn('open a revolt petition', self.petition('bob'))

    def test_hold_window_closes(self):
        self.become('dictatorship')
        self.petition(type='monarchy', person='cat', pname='Cat', pfaction=C)
        self.sign('bob')
        self.sign('cat', C)
        self.assertIn('has its signatures', self.sign('dan'))  # a third of 10, rounded up
        ripe = self.now
        late = ripe + 4 * 86400 + 1
        self.ask('alpha', 'present', A, now=ripe + 2 * 86400, actor='val', role='citizen')  # the dictator stays
        self.assertIn('passed', self.n.overthrow(self.nid, {'actor': 'ann'}, late))
        self.n.snapshot(late)
        self.assertEqual(self.snap(late)['revolt']['cooldown'], late + 7 * 86400)
        self.assertEqual(self.snap(late)['government']['type'], 'dictatorship')

    def test_rename_follows_signatures_and_candidate(self):
        self.become('monarchy')
        self.petition(type='monarchy', person='bob', pname='Bob', pfaction=B)
        self.ask('alpha', 'rename', B, to='civ:alpha:Bark', now=self.now)
        r = self.snap()['revolt']
        self.assertEqual((r['pfaction'], r['signers'][0]['faction']), ('civ:alpha:Bark', 'civ:alpha:Bark'))

    def test_request_needs_signer_name(self):
        from tools.transfer_storage.nations import nation_request_valid
        base = {'op': 'sign', 'actor': 'ann', 'faction': B, 'role': 'citizen'}
        self.assertFalse(nation_request_valid(base))
        self.assertTrue(nation_request_valid(dict(base, sname='Ann')))
        self.assertTrue(nation_request_valid(dict(base, op='revolt', sname='Ann', type='confederation')))
        self.assertFalse(nation_request_valid(dict(base, op='revolt', sname='Ann', type='monarchy')))


class StaffTests(ElectiveTests.__base__):
    """Staff tools (tools/transfer_storage/nation_staff.py)."""

    setUp = ElectiveTests.setUp
    ask = ElectiveTests.ask
    become = ElectiveTests.become
    snap = ElectiveTests.snap

    def staff(self, act, land='beta', now=None, **kw):
        return self.ask(land, 'staff', A, now=self.now if now is None else now, actor='mod', act=act,
                        reason='test', **kw)

    def test_freeze_blocks_changes_and_absence(self):
        self.become('monarchy')
        self.assertIn('frozen', self.staff('freeze'))  # from another land
        self.assertIn('already', self.staff('freeze'))
        self.assertIn('paused', self.ask('alpha', 'revolt', B, now=self.now, actor='ann', role='citizen', sname='Ann',
                                         type='confederation'))
        self.now += 30 * 86400
        self.assertEqual(self.snap()['government']['head_account'], 'val')  # absence did not count
        self.assertTrue(self.snap()['frozen'])
        self.assertIn('thawed', self.staff('thaw'))
        self.now += 86400
        self.assertEqual(self.snap()['government']['head_account'], 'val')
        log = self.snap()['staff_log']
        self.assertEqual([e['act'] for e in log], ['thaw', 'freeze'])
        self.assertEqual(log[0]['actor'], 'mod')

    def test_void_motion_revolt_and_set(self):
        self.become('republic')
        self.ask('alpha', 'currency', B, now=self.now, issuer=B)
        [m] = self.snap()['motions']
        self.assertIn('no such', self.staff('void_motion', motion=m['id'] + 99))
        self.assertIn('void', self.staff('void_motion', motion=m['id']))
        self.assertEqual(self.snap()['motions'], [])
        self.ask('alpha', 'revolt', B, now=self.now, actor='ann', role='citizen', sname='Ann', type='confederation')
        self.assertIn('void', self.staff('void_revolt'))
        self.assertEqual(self.snap()['revolt'], {'cooldown': None})
        self.assertIn('must be a citizen', self.staff('set', type='monarchy', person='zed', pname='Zed', pfaction=D))
        self.assertIn('set', self.staff('set', type='monarchy', person='bob', pname='Bob', pfaction=B))
        g = self.snap()['government']
        self.assertEqual((g['type'], g['head_account']), ('monarchy', 'bob'))
        self.assertIn('Bob', self.snap()['staff_log'][0]['detail'])

    def test_staff_request_needs_reason_and_crosses_lands(self):
        from tools.transfer_storage.nations import nation_request_valid
        base = {'op': 'staff', 'actor': 'mod', 'faction': A, 'act': 'freeze'}
        self.assertFalse(nation_request_valid(base))
        self.assertTrue(nation_request_valid(dict(base, reason='spam')))
        self.assertFalse(nation_request_valid(dict(base, reason='x', act='void_motion')))
        self.assertIn('not part', self.ask('beta', 'staff', D, actor='mod', act='freeze', reason='x'))


class OfficeTests(ElectiveTests.__base__):
    """Offices of state (tools/transfer_storage/nation_offices.py)."""

    setUp = ElectiveTests.setUp
    ask = ElectiveTests.ask
    become = ElectiveTests.become
    snap = ElectiveTests.snap

    def appoint(self, office, person, faction=B, actor='val', **kw):
        return self.ask('alpha', 'appoint', A, now=kw.pop('now', self.now), actor=actor, role='citizen',
                        office=office, person=person, pname=person.title(), pfaction=faction, **kw)

    def test_ruler_appoints_and_officers_act(self):
        self.become('monarchy')
        self.assertIn('Only the Monarch', self.appoint('treasurer', 'bob', actor='ann'))
        self.assertIn('yourself', self.appoint('treasurer', 'val', faction=A))
        self.assertIn('appointed Treasurer', self.appoint('treasurer', 'bob'))
        self.assertIn('already holds', self.appoint('chancellor', 'bob'))
        self.assertIn('appointed Chancellor', self.appoint('chancellor', 'cat', faction=C))
        self.assertEqual(set(self.snap()['offices']), {'treasurer', 'chancellor'})
        # The treasurer picks the money in the monarch's place.
        self.assertIn('new common money', self.ask('alpha', 'currency', B, now=self.now, actor='bob', role='citizen',
                                                   issuer=B))
        self.assertEqual(self.n.currency(self.nid), B)
        # The chancellor admits in the monarch's place; nobody else may.
        self.ask('beta', 'apply', D, nation=self.nid, now=self.now)
        self.assertIn('Only a member', self.ask('alpha', 'vote', C, now=self.now, actor='dan', role='citizen',
                                                applicant=D, yes=True))
        self.assertIn('joins', self.ask('alpha', 'vote', C, now=self.now, actor='cat', role='citizen',
                                        applicant=D, yes=True))
        self.assertEqual(self.n.nation_of(D), self.nid)

    def test_dismiss_resign_and_lapse(self):
        self.become('monarchy')
        self.appoint('marshal', 'bob')
        self.appoint('treasurer', 'cat', faction=C)
        self.assertIn('Only the head', self.ask('alpha', 'dismiss', B, now=self.now, actor='ann', office='marshal'))
        self.assertIn('resign', self.ask('alpha', 'dismiss', B, now=self.now, actor='bob', office='marshal'))
        self.assertIn('dismissed', self.ask('alpha', 'dismiss', A, now=self.now, actor='val', office='treasurer'))
        self.assertEqual(self.snap()['offices'], {})
        self.appoint('marshal', 'bob')
        self.ask('alpha', 'secede', B, now=self.now)
        self.now += 2 * 86400 + 1
        self.ask('alpha', 'present', A, now=self.now, actor='val', role='citizen')
        self.assertEqual(self.snap()['offices'], {})  # the faction left

    def test_elective_body_confirms_and_new_government_clears(self):
        self.become('republic')
        self.assertIn('senate must confirm', self.appoint('chancellor', 'cat', faction=C))
        [m] = [m for m in self.snap()['motions'] if m['kind'] == 'office']
        self.assertEqual(self.snap()['offices'], {})
        self.ask('alpha', 'ballot', A, now=self.now, motion=m['id'], choice='yes')  # 6 of 10 senators
        self.assertEqual(self.snap()['offices']['chancellor']['account'], 'cat')
        self.ask('alpha', 'rename', C, to='civ:alpha:Cork', now=self.now)
        self.assertEqual(self.snap()['offices']['chancellor']['faction'], 'civ:alpha:Cork')
        self.n.staff(self.nid, {'act': 'set', 'actor': 'mod', 'reason': 'x', 'type': 'monarchy', 'person': 'val',
                                'pname': 'Val', 'pfaction': A}, '["monarchy", "val", "Val", "%s", ""]' % A, self.now)
        self.assertEqual(self.snap()['offices'], {})

    def test_confederation_has_no_officers(self):
        self.assertIn('no head', self.ask('alpha', 'appoint', A, office='marshal', person='bob', pname='Bob',
                                          pfaction=B))


class TreatyTests(unittest.TestCase):
    """Treaties between nations (tools/transfer_storage/nation_treaties.py)."""

    def setUp(self):
        self.db = sqlite3.connect(':memory:', isolation_level=None)
        self.n = Nations(self.db)
        self.ask('alpha', 'found', A, name='Union', **{'with': [B]})
        self.ask('beta', 'found', D, name='League', **{'with': [E]})
        self.u, self.l = self.n.nation_of(A), self.n.nation_of(D)

    def ask(self, land, op, faction, now=T, actor='leader', **kw):
        return self.n.decide(land, dict(kw, op=op, actor=actor, faction=faction), now)

    def treaty(self, land, faction, other, kind, act='agree', now=T, **kw):
        return self.ask(land, 'treaty', faction, now=now, other=other, treaty=kind, act=act, **kw)

    def kinds(self, nid, now=T):
        return sorted(t['kind'] for t in self.n.snapshot(now)[nid]['treaties']['in_force'])

    def test_both_confederations_agree_by_majority(self):
        self.assertIn('more than half', self.treaty('alpha', A, self.l, 'alliance'))
        self.assertIn('offers an alliance', self.treaty('alpha', B, self.l, 'alliance'))
        self.assertEqual(self.n.snapshot(T)[self.l]['treaties']['offers']['received'][0]['kind'], 'alliance')
        self.treaty('beta', D, self.u, 'alliance')
        self.assertIn('in force', self.treaty('beta', E, self.u, 'alliance'))
        self.assertEqual(self.kinds(self.u), ['alliance'])
        self.assertIn('already', self.treaty('alpha', A, self.l, 'alliance'))
        # War is declared alone and ends the alliance; peace needs both.
        self.treaty('beta', D, self.u, 'war')
        self.assertIn('declares war', self.treaty('beta', E, self.u, 'war'))
        self.assertEqual(self.kinds(self.l), ['war'])
        self.assertIn('make peace first', self.treaty('alpha', A, self.l, 'trade'))
        self.treaty('alpha', A, self.l, 'peace')
        self.treaty('alpha', B, self.l, 'peace')
        self.treaty('beta', D, self.u, 'peace')
        self.assertIn('war is over', self.treaty('beta', E, self.u, 'peace'))
        self.assertEqual(self.kinds(self.u), [])

    def test_offers_lapse_renounce_and_dissolve(self):
        for f in (A, B):
            self.treaty('alpha', f, self.l, 'trade')
        self.n.snapshot(T + 7 * 86400 + 1)
        self.assertEqual(self.n.snapshot(T + 7 * 86400 + 1)[self.u]['treaties']['offers']['made'], [])
        for land, fs, other in (('alpha', (A, B), self.l), ('beta', (D, E), self.u)):
            for f in fs:
                self.treaty(land, f, other, 'trade', now=T + 8 * 86400)
        self.assertEqual(self.kinds(self.u, T + 8 * 86400), ['trade'])
        self.assertIn('no such treaty', self.treaty('alpha', A, self.l, 'pact', act='renounce', now=T + 8 * 86400))
        self.treaty('alpha', A, self.l, 'trade', act='renounce', now=T + 8 * 86400)
        self.assertIn('renounces', self.treaty('alpha', B, self.l, 'trade', act='renounce', now=T + 8 * 86400))
        self.treaty('alpha', A, self.l, 'war', now=T + 8 * 86400)
        self.treaty('alpha', B, self.l, 'war', now=T + 8 * 86400)
        self.ask('beta', 'secede', E, now=T + 8 * 86400)
        self.n.snapshot(T + 8 * 86400)
        self.assertEqual(self.db.execute('SELECT COUNT(*) FROM nation_treaty').fetchone()[0], 0)

    def test_ruler_decides_alone(self):
        for f in (A, B):
            self.ask('alpha', 'era', f, age=1)
        for f in (A, B):
            self.ask('alpha', 'govern', f, type='monarchy', person='val', pname='Val', pfaction=A)
        now = T + 86400
        self.assertIn('Only the Monarch', self.treaty('alpha', A, self.l, 'war', now=now))
        self.assertIn('declares war', self.treaty('alpha', A, self.l, 'war', now=now, actor='val', role='citizen'))
        self.assertIn('no such nation', self.treaty('alpha', A, 'n99', 'pact', now=now, actor='val', role='citizen'))

    def test_senate_decides_by_motion(self):
        for f, c in ((A, 3), (B, 1)):
            self.ask('alpha', 'era', f, age=1)
            self.ask('alpha', 'census', f, citizens=c, wealth=0)
        for f in (A, B):
            self.ask('alpha', 'govern', f, type='republic', person='val', pname='Val', pfaction=A)
        now = T + 86400
        self.assertIn('decided at once', self.treaty('alpha', A, self.l, 'pact', now=now))  # 3 of 4 senators
        self.assertEqual(self.n.snapshot(now)[self.u]['treaties']['offers']['made'][0]['kind'], 'pact')


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
