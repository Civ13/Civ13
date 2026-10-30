"""Offline injected status packets; no listener or game process."""
from datetime import datetime, timedelta, timezone
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests/nomads_lifecycle'))
import test_variable_observability as variables_fixture
spec = importlib.util.spec_from_file_location('runtime_bridge', ROOT / 'tools/mcp/runtime_bridge.py')
bridge = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bridge)


class RuntimeBridgeTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        (self.root / 'config').mkdir()
        (self.root / 'config/lifecycle-token.txt').write_text('a' * 32)
        (self.root / 'supervisor.json').write_text(json.dumps({'port': 1714, 'config_directory': str(self.root / 'config')}))
        self.config = dict(root=str(self.root), revision='b' * 40, session='c' * 32, round='abc-DE12')
        self.calls = []

    def recovery_status(self, seconds=0):
        utc = (datetime.now(timezone.utc) - timedelta(seconds=seconds)).strftime('%Y-%m-%d %H:%M:%S')
        return dict(ok=1, revision=self.config['revision'], session=self.config['session'],
            ready=0, busy=1, restart_hold=1, restart_import_complete=0, restart_intent=1,
            error='Missing captured zone row z=2 y=3 private-path', maxz=3, maxy=5,
            debug=dict(schema=1, tick=10, observed_utc=utc,
                progress=dict(active=1, kind='load', phase='preflight', transaction_phase='restore',
                    saving_z=None, loading_z=2, backend_started=0, contents_started=0,
                    mutation_started=0, restoring_players=0, percent_available=0),
                runtime=dict(total=0, skipped=0, cache_available=1, source_total=0, prefix_limit=8,
                    sources=[], stack_available=0, proc_available=0)))

    def exchange(self, status):
        def transport(values):
            self.calls.append(values)
            self.assertEqual(set(values), {'nomads_lifecycle', 'token', 'action'})
            self.assertEqual(values['action'], 'status')
            return status
        return transport

    def test_recovery_is_one_request_identity_bound_fresh_and_redacted(self):
        status = self.recovery_status()
        result = bridge.run('recovery', self.config, transport=self.exchange(status))
        self.assertTrue(result['ok'])
        self.assertEqual(result['captured_zone_row'], {'z': 2, 'y': 3})
        self.assertEqual(result['progress']['transaction_phase'], 'restore')
        self.assertEqual(len(self.calls), 1)
        for forbidden in ('a' * 32, self.config['session'], 'private-path', str(self.root)):
            self.assertNotIn(forbidden, json.dumps(result))
        status['session'] = 'd' * 32
        self.assertEqual(bridge.run('recovery', self.config, transport=self.exchange(status))['error_code'], 'correlation_mismatch')
        self.assertEqual(bridge.run('recovery', self.config, transport=self.exchange(self.recovery_status(62)))['error_code'], 'stale_snapshot')
        old = self.recovery_status(); old['debug'].pop('observed_utc')
        self.assertEqual(bridge.run('recovery', self.config, transport=self.exchange(old))['error_code'], 'freshness_unavailable')
        old_header = self.recovery_status()
        old_header['debug']['variables'] = variables_fixture.status()
        old_header['debug']['variables']['utc'] = (datetime.now(timezone.utc) - timedelta(seconds=62)).strftime('%Y-%m-%d %H:%M:%S')
        self.assertEqual(bridge.run('recovery', self.config, transport=self.exchange(old_header))['error_code'], 'stale_snapshot')

    def test_variables_preserves_correlation_freshness_and_discards_object_details(self):
        status = dict(ok=1, revision=self.config['revision'], session=self.config['session'],
                      debug={'variables': variables_fixture.status()})
        result = bridge.run('variables', self.config, transport=self.exchange(status), now=variables_fixture.NOW)
        self.assertTrue(result['ok'])
        self.assertEqual(result['last_operation']['id'], 'operation-1')
        self.assertEqual(result['failure']['kind'], 'cross_level_object')
        self.assertEqual(len(self.calls), 1)
        for forbidden in ('[0x1]', '/obj/', self.config['session'], 'a' * 32, str(self.root)):
            self.assertNotIn(forbidden, json.dumps(result))
        stale = bridge.run('variables', self.config, transport=self.exchange(status),
                           now=variables_fixture.NOW + timedelta(seconds=61))
        self.assertEqual(stale['error_code'], 'stale_snapshot')
        wrong = dict(self.config, round='wrong')
        self.assertEqual(bridge.run('variables', wrong, transport=self.exchange(status), now=variables_fixture.NOW)['error_code'], 'correlation_mismatch')
        status['debug']['variables']['failure']['utc'] = '2026-10-23 03:58:00'
        retained = bridge.run('variables', self.config, transport=self.exchange(status), now=variables_fixture.NOW)
        self.assertTrue(retained['ok'])
        self.assertEqual(retained['failure_error'], 'stale_snapshot')
        self.assertIsNone(retained['failure'])
        status['debug']['variables']['enabled'] = False
        self.assertEqual(bridge.run('variables', self.config, transport=self.exchange(status), now=variables_fixture.NOW)['error_code'], 'disabled')

    def test_invalid_configuration_never_queries(self):
        for key, value in (('root', 'relative'), ('revision', 'bad'), ('session', 'bad'), ('round', '../bad')):
            result = bridge.run('recovery', dict(self.config, **{key: value}),
                                transport=lambda _: self.fail('unexpected request'))
            self.assertEqual(result['error_code'], 'invalid_configuration')


if __name__ == '__main__':
    unittest.main()
