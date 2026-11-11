"""Recovery authority must not be inferred from a partial replacement roster."""
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from tools.transfer_storage.coordinator import Coordinator


class BootstrapTests(unittest.TestCase):
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
