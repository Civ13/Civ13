"""Recovery authority must not be inferred from a partial replacement roster."""
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from tools.transfer_storage.coordinator import Coordinator


class CoordinatorFixture(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.path = str(Path(self.tmp.name) / 'c.db')
        self.c = Coordinator(self.path, 'earth')
        self.answers = {}
        self.sent = []
        def call(url, token, path, body=None, **kw):
            if path == '/accounts':
                if url not in self.answers:
                    raise OSError('offline')
                return {'ok': True, 'result': self.answers[url]}
            self.sent.append((url, body))
            return {'ok': True}
        self.mock = patch('tools.transfer_storage.coordinator.call', call)
        self.mock.start()

    def tearDown(self):
        self.mock.stop(); self.c.close(); self.tmp.cleanup()

    def enroll(self, name, port):
        url = 'http://127.0.0.1:%d' % port
        self.c.enroll(name, url, 'test-token')
        self.answers[url] = {'store': name, 'epoch': '', 'requests': [], 'rev': 0}
        return url

    def reopen(self, bootstrap=False):
        self.c.close()
        self.c = Coordinator(self.path, 'earth', bootstrap_new_group=bootstrap)


class BootstrapTests(CoordinatorFixture):
    def test_partial_replacement_cannot_claim_offline_peers_account(self):
        url = self.enroll('gamma', 3)
        self.answers[url]['requests'] = [{'id': 1, 'ckey': 'alice', 'op': 'claim', 'region': 'gamma'}]
        self.assertEqual(0, self.c.homes_once())
        self.assertIsNone(self.c.home('alice'))
        self.assertEqual([], self.sent)  # no epoch reset to any agent
        self.reopen()
        self.assertEqual(0, self.c.homes_once())

    def test_explicit_clean_bootstrap_is_durable(self):
        self.enroll('alpha', 1); self.enroll('beta', 2)
        self.reopen(True); self.c.homes_once()
        self.assertEqual('ready', self.c.recovery_status()['state'])
        self.assertEqual(['alpha', 'beta'], self.c.recovery_status()['roster'])
        self.reopen()
        self.assertEqual('ready', self.c.recovery_status()['state'])

    def test_explicit_bootstrap_rejects_previous_epoch(self):
        url = self.enroll('alpha', 1)
        self.answers[url]['epoch'] = 'old-authority'
        self.reopen(True); self.c.homes_once()
        self.assertEqual('quarantined', self.c.recovery_status()['state'])
        self.assertEqual([], self.sent)

    def test_new_peer_waits_for_full_durable_roster(self):
        old = self.enroll('alpha', 1)
        self.reopen(True); self.c.homes_once()
        self.enroll('beta', 2)
        del self.answers[old]
        self.assertEqual(0, self.c.homes_once())
        self.assertEqual('unreconciled', self.c.recovery_status()['state'])
        self.assertEqual(['alpha', 'beta'], self.c.recovery_status()['roster'])
        self.reopen()
        self.assertEqual(0, self.c.homes_once())

    def test_legacy_established_database_retains_directory(self):
        self.enroll('alpha', 1)
        self.c.db.execute("UPDATE ledger SET value='ready' WHERE key='recovery'")
        self.c.db.execute("DELETE FROM ledger WHERE key IN ('roster','bootstrap')")
        self.reopen()
        self.assertEqual(['alpha'], self.c.recovery_status()['roster'])

    def test_legacy_database_without_decisions_retains_directory(self):
        # A pre-recovery database that never decided a home (rev 0) is still
        # the original authority: it adopts its directory and becomes ready.
        self.enroll('alpha', 1); self.enroll('beta', 2)
        self.c.db.execute("DELETE FROM ledger WHERE key IN ('recovery','roster','bootstrap')")
        self.reopen()
        self.assertEqual(['alpha', 'beta'], self.c.recovery_status()['roster'])
        self.c.homes_once()
        self.assertEqual('ready', self.c.recovery_status()['state'])

    def test_directory_loss_with_existing_roster_quarantines(self):
        self.enroll('alpha', 1); self.enroll('beta', 2)
        self.reopen(True); self.c.homes_once()
        self.c.db.execute("DELETE FROM region WHERE region='beta'")
        self.assertEqual(0, self.c.homes_once())
        self.assertEqual('quarantined', self.c.recovery_status()['state'])

    def test_bootstrap_failure_rolls_back_roster_and_readiness_together(self):
        self.enroll('alpha', 1)
        self.reopen(True)
        self.c.db.execute("""CREATE TRIGGER fail_ready BEFORE UPDATE ON ledger
            WHEN NEW.key='recovery' AND NEW.value='ready'
            BEGIN SELECT RAISE(ABORT, 'simulated interruption'); END""")
        with self.assertRaises(Exception):
            self.c.homes_once()
        self.assertEqual([], self.c.recovery_status()['roster'])
        self.assertEqual('unreconciled', self.c.recovery_status()['state'])
        self.c.db.execute('DROP TRIGGER fail_ready')
        self.reopen()
        url = self.enroll('beta', 2)
        self.answers[url]['epoch'] = 'prior-authority'
        self.c.homes_once()
        self.assertEqual('quarantined', self.c.recovery_status()['state'])


class QuarantineRecoveryTests(CoordinatorFixture):
    """A live group was held for a day: setup enrolled the Tutorial region while
    the coordinator was mid-pass, the pass compared its old directory with the
    new roster and quarantined, and no join that needed a decision could finish."""

    def ready_group(self):
        a = self.enroll('alpha', 1); b = self.enroll('beta', 2)
        self.reopen(True); self.c.homes_once()
        self.assertEqual('ready', self.c.recovery_status()['state'])
        epoch = self.c._ledger('epoch')
        for url in (a, b):
            self.answers[url]['epoch'] = epoch
        return a, b, epoch

    def test_enrolment_during_a_pass_does_not_quarantine(self):
        a, b, epoch = self.ready_group()
        late = {}
        real_answers = self.answers
        test = self
        class Racing(dict):
            def __contains__(self, url):
                if url == b and not late:
                    # setup enrols gamma while this pass talks to the agents
                    late['url'] = 'http://127.0.0.1:3'
                    test.c.enroll('gamma', late['url'], 'test-token')
                return dict.__contains__(self, url)
        self.answers = Racing(real_answers)
        self.c.homes_once()
        self.assertNotEqual('quarantined', self.c.recovery_status()['state'])
        self.assertEqual(['alpha', 'beta', 'gamma'], self.c.recovery_status()['roster'])
        self.answers[late['url']] = {'store': 'gamma', 'epoch': '', 'requests': [], 'rev': 0}
        self.c.homes_once()
        self.assertEqual('ready', self.c.recovery_status()['state'])

    def test_quarantine_lifts_when_every_agent_holds_this_epoch(self):
        a, b, epoch = self.decided_group()
        g = self.enroll('gamma', 3)  # new region: no ledger yet
        self.c.db.execute("UPDATE ledger SET value='quarantined' WHERE key='recovery'")
        self.answers[a]['requests'] = [{'id': 5, 'ckey': 'breadguy', 'op': 'claim', 'region': 'alpha'}]
        self.assertEqual(1, self.c.homes_once())
        self.assertEqual('ready', self.c.recovery_status()['state'])
        self.assertEqual('alpha', self.c.home('breadguy'))

    def decided_group(self):
        a, b, epoch = self.ready_group()
        self.answers[a]['requests'] = [{'id': 1, 'ckey': 'alice', 'op': 'claim', 'region': 'alpha'}]
        self.c.homes_once()
        self.answers[a]['requests'] = []
        rev = int(self.c._ledger('rev'))
        self.assertEqual(1, rev)
        for url in (a, b):
            self.answers[url]['rev'] = rev
        return a, b, epoch

    def test_hold_lifts_with_stopped_regions_offline(self):
        # Stopped regions run no agent; the live group had 8 of 10 stopped.
        a, b, epoch = self.decided_group()
        g = self.enroll('gamma', 3)
        del self.answers[b]; del self.answers[g]
        self.c.db.execute("UPDATE ledger SET value='quarantined' WHERE key='recovery'")
        self.answers[a]['requests'] = [{'id': 2, 'ckey': 'breadguy', 'op': 'claim', 'region': 'alpha'}]
        self.assertEqual(1, self.c.homes_once())
        self.assertEqual('ready', self.c.recovery_status()['state'])
        self.assertEqual('alpha', self.c.home('breadguy'))
        self.assertEqual('alpha', self.c.home('alice'))

    def test_unreconciled_new_member_lifts_with_it_offline(self):
        a, b, epoch = self.decided_group()
        self.enroll('gamma', 3)
        del self.answers['http://127.0.0.1:3']
        self.assertEqual('unreconciled', self.c.recovery_status()['state'])
        self.c.homes_once()
        self.assertEqual('ready', self.c.recovery_status()['state'])

    def test_quarantine_holds_while_no_answering_agent_proves_the_epoch(self):
        a, b, epoch = self.decided_group()
        self.c.db.execute("UPDATE ledger SET value='quarantined' WHERE key='recovery'")
        del self.answers[a]; del self.answers[b]
        self.assertEqual(0, self.c.homes_once())
        self.assertEqual('quarantined', self.c.recovery_status()['state'])

    def test_undecided_database_still_needs_every_member(self):
        a, b, epoch = self.ready_group()  # rev 0: nothing proves authority
        self.c.db.execute("UPDATE ledger SET value='quarantined' WHERE key='recovery'")
        del self.answers[b]
        self.assertEqual(0, self.c.homes_once())
        self.assertEqual('quarantined', self.c.recovery_status()['state'])

    def test_quarantine_holds_for_a_foreign_epoch_or_newer_ledger(self):
        a, b, epoch = self.decided_group()
        self.c.db.execute("UPDATE ledger SET value='quarantined' WHERE key='recovery'")
        self.answers[b]['epoch'] = 'other-authority'
        self.assertEqual(0, self.c.homes_once())
        self.assertEqual('quarantined', self.c.recovery_status()['state'])
        self.answers[b]['epoch'] = epoch
        self.answers[b]['rev'] = 99
        self.assertEqual(0, self.c.homes_once())
        self.assertEqual('quarantined', self.c.recovery_status()['state'])

    def test_quarantine_holds_when_a_member_left_the_directory(self):
        a, b, epoch = self.ready_group()
        self.c.db.execute("DELETE FROM region WHERE region='beta'")
        self.assertEqual(0, self.c.homes_once())
        self.assertEqual('quarantined', self.c.recovery_status()['state'])
