"""Offline runner refusal, deadline, socket and artifact guards; no native calls."""
from datetime import datetime, timedelta, timezone
import copy
import importlib.util
from pathlib import Path
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location('bounded_variable_runner', Path(__file__).with_name('run_variable_probe.py'))
m = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(m)


class Runner(unittest.TestCase):
    def test_missing_grant_refuses_before_outputs_or_used_or_native_imports(self):
        with tempfile.TemporaryDirectory(prefix='collector-native-packet-') as folder:
            root = Path(folder)
            with self.assertRaises(FileNotFoundError):
                m.main(root / 'packet.json')
            self.assertEqual(list(root.iterdir()), [])

    def test_exact_grant_scope_hash_caps_and_full_lease(self):
        now = datetime(2026, 10, 23, tzinfo=timezone.utc)
        packet = dict(scope=m.SCOPE, caps=m.CAPS.copy(), phases=m.PHASES.copy(), baseline=[])
        grant = dict(scope=m.SCOPE, caps=m.CAPS.copy(), packet_sha256='a', runner_sha256='b', single_use=True,
                     starts_utc=now.isoformat(), ends_utc=(now + timedelta(seconds=121)).isoformat())
        self.assertEqual(m.validate_grant(packet, grant, 'a', 'b', now), now + timedelta(seconds=121))
        for field, value in (('scope', 'another task'), ('packet_sha256', 'wrong'), ('runner_sha256', 'wrong'),
                             ('single_use', False), ('ends_utc', (now + timedelta(seconds=119)).isoformat())):
            with self.subTest(field=field), self.assertRaises(RuntimeError):
                m.validate_grant(packet, grant | {field: value}, 'a', 'b', now)
        bad = copy.deepcopy(packet); bad['caps']['process_bytes'] += 1
        with self.assertRaises(RuntimeError):
            m.validate_grant(bad, grant, 'a', 'b', now)

    def test_phase_global_and_wall_deadlines_each_refuse(self):
        tick = [0.0]; wall = [datetime(2026, 10, 23, tzinfo=timezone.utc)]
        budget = m.Budget(wall[0] + timedelta(seconds=120), now=lambda: tick[0], wall=lambda: wall[0])
        with self.assertRaises(RuntimeError):
            with budget.phase('compile', []):
                tick[0] = 20
        tick[0] = 89
        with self.assertRaises(RuntimeError):
            with budget.phase('missing', []):
                tick[0] = 90
        tick[0] = 1; wall[0] += timedelta(seconds=121)
        with self.assertRaises(RuntimeError):
            budget.check()

    def test_only_fixed_preclosure_loopback_listener_is_permitted(self):
        row = dict(protocol='tcp', address='127.0.0.1', port=m.PORT, state='listen')
        m.validate_sockets([row], runtime=True, closed=False)
        m.validate_sockets([], runtime=True, closed=True)
        for rows, runtime, closed in (([row], False, False), ([row], True, True),
                                     ([row | {'port': m.PORT + 1}], True, False),
                                     ([row | {'address': '0.0.0.0'}], True, False),
                                     ([row | {'protocol': 'udp'}], True, False),
                                     ([row | {'state': '5'}], True, False), ([row, row], True, False)):
            with self.subTest(rows=rows), self.assertRaises(RuntimeError):
                m.validate_sockets(rows, runtime=runtime, closed=closed)

    def test_inventory_counts_environment_and_unexpected_outputs(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); (root / 'source.dm').write_text('source')
            packet = dict(files={'source.dm': 'unused'}, generated_files=['outputs/receipt.json'])
            self.assertGreater(m.inventory(root, packet)['total_bytes'], 0)
            (root / 'unlisted.log').write_text('unexpected')
            with self.assertRaises(RuntimeError):
                m.inventory(root, packet)
            (root / 'unlisted.log').unlink()
            env = root / 'outputs/environment'; env.mkdir(parents=True)
            (env / 'unexpected-size.bin').write_bytes(b'x' * (m.CAPS['evidence_bytes'] + 1))
            with self.assertRaises(RuntimeError):
                m.inventory(root, packet)

    def test_obstruction_and_closure_checks_are_present_in_actual_fixture(self):
        source = Path(__file__).with_name('variable_probe.dm').read_text()
        self.assertIn('real file-versus-directory write refusal', source)
        self.assertIn('output obstruction remains a directory', source)
        self.assertLess(source.index('OpenPort("none")'), source.index('text2file("closed", "probe-port-closed.txt")'))
        self.assertLess(source.index('probe-port-closed.ack'), source.index('variable_observability_enabled()'))

    def test_terminal_artifact_failure_keeps_prior_receipt_and_cleanup(self):
        with tempfile.TemporaryDirectory() as folder:
            out = Path(folder)
            (out / 'receipt.json').write_text('previous complete sample')
            (out / 'cleanup.json').write_text('{"all_exited":true}')
            report = dict(packet_sha256='a', runner_sha256='b', samples=[{'pid': 123}], error='artifact growth')
            m.preserve_failure(out, report, RuntimeError('Unexpected generated path'))
            self.assertEqual((out / 'receipt.json').read_text(), 'previous complete sample')
            self.assertTrue((out / 'cleanup.json').exists())
            import json
            failure = json.loads((out / 'failure.json').read_text())
            self.assertFalse(failure['passed'])
            self.assertFalse(failure['native_verified'])
            self.assertEqual(failure['cleanup_sha256'], m.digest(out / 'cleanup.json'))


if __name__ == '__main__':
    unittest.main()
