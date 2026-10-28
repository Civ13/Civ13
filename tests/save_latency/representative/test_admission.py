"""Actual one-use caller with synthetic files/clocks and no native effects."""
from copy import deepcopy
from datetime import datetime, timedelta, timezone
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch
import uuid

import admission
import execute
import files
from test_execute import allocation


class FakeOperator:
    def __init__(self):
        self.elapsed = 0
        self.wall = 0
        self.now = datetime(2026, 10, 22, tzinfo=timezone.utc)
        self.ident = {'host': 'offline', 'account': 'injected', 'python': '/fake/python', 'python_sha256': 'a' * 64}
        self.after_claim = None
    def clock(self):
        return self.elapsed
    def utcnow(self):
        return self.now + timedelta(seconds=self.wall)
    def identity(self):
        return dict(self.ident)
    def claim(self, path, value):
        admission.Operator.claim(path, value)
        if self.after_claim:
            self.after_claim()


class CallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.repository = self.root / 'repo'
        self.repository.mkdir()
        self.driver = self.root / 'driver'
        self.driver.mkdir()
        for name in ('admission.py', 'execute.py', 'probe.dm'):
            (self.driver / name).write_bytes(('synthetic ' + name).encode())
        self.ledger = self.root / 'shared-reservations'
        self.ledger.mkdir()
        self.resource = allocation(self.root)
        self.resource['allocation_id'] = str(uuid.uuid4())
        self.op = FakeOperator()
        self.packet = {'schema': 1, 'authorized': True, 'attempt_id': self.resource['allocation_id'],
            'executor_thread': 'offline-only-executor', 'resource_owner': 'offline-only-owner',
            'reservation_id': 'externally-reviewed-offline-reservation', 'authority_reference': 'injected test only',
            'repository': str(self.repository), 'ledger_directory': str(self.ledger),
            'identity': self.op.identity(), 'resource_sha256': admission.digest(self.resource),
            'resource_sample': {'measured_utc': self.op.now.isoformat(), 'host': 'offline',
                'cpu_accepted_by_owner': True, 'available_bytes': 100, 'output_volume_free_bytes': 100},
            'driver_sha256': {p.name: files.file_sha(p) for p in self.driver.iterdir()}}
        self.run = Mock(return_value={'injected': True})

    def invoke(self, packet=None, expected=None):
        packet = packet if packet is not None else self.packet
        return admission.invoke(self.repository, self.resource, packet, expected or admission.digest(packet),
                                operator=self.op, driver=self.driver, run=self.run)

    def test_claim_exists_before_effect_and_reuse_never_invokes_twice(self):
        claim = self.ledger / (self.packet['attempt_id'] + '.json')
        def effect(repository, resource, *, caller_deadline):
            self.assertEqual(admission.load(claim)['state'], 'CONSUMED_BEFORE_EXECUTION')
            self.assertEqual(caller_deadline, 10410)
            return {'injected': True}
        self.run.side_effect = effect
        self.assertEqual(self.invoke(), {'injected': True})
        with self.assertRaises(FileExistsError):
            self.invoke()
        self.assertEqual(self.run.call_count, 1)

    def test_digest_and_resource_output_port_binding_reject_before_claim(self):
        for key, value in (('output', str(self.root / 'other')), ('port', 19572), ('maximum_output_bytes', 2)):
            with self.subTest(key=key):
                old = self.resource[key]
                self.resource[key] = value
                with self.assertRaisesRegex(ValueError, 'resource packet changed'):
                    self.invoke()
                self.resource[key] = old
        with self.assertRaisesRegex(ValueError, 'digest differs'):
            self.invoke(expected='0' * 64)
        self.run.assert_not_called()
        self.assertEqual(list(self.ledger.iterdir()), [])

    def test_identity_and_full_driver_mutation_reject_before_claim(self):
        self.op.ident['host'] = 'other'
        with self.assertRaisesRegex(ValueError, 'identity differs'):
            self.invoke()
        self.op.ident['host'] = 'offline'
        (self.driver / 'execute.py').write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, 'driver changed'):
            self.invoke()
        self.run.assert_not_called()
        self.assertEqual(list(self.ledger.iterdir()), [])

    def test_slow_claim_expiry_is_consumed_but_no_effect(self):
        for kind in ('elapsed', 'wall'):
            with self.subTest(kind=kind):
                packet = deepcopy(self.packet)
                packet['attempt_id'] = str(uuid.uuid4())
                self.resource['allocation_id'] = packet['attempt_id']
                packet['resource_sha256'] = admission.digest(self.resource)
                self.op.elapsed = self.op.wall = 0
                self.op.after_claim = lambda: setattr(self.op, kind, 10411)
                with self.assertRaises(TimeoutError):
                    self.invoke(packet)
                self.assertTrue((self.ledger / (packet['attempt_id'] + '.json')).is_file())
        self.run.assert_not_called()

    def test_failure_preserves_claim_no_retry(self):
        self.run.side_effect = RuntimeError('injected effect failure')
        with self.assertRaisesRegex(RuntimeError, 'injected effect failure'):
            self.invoke()
        with self.assertRaises(FileExistsError):
            self.invoke()
        self.assertEqual(self.run.call_count, 1)

    def test_postclaim_source_mutation_refuses_effect(self):
        self.op.after_claim = lambda: (self.driver / 'probe.dm').write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, 'driver changed'):
            self.invoke()
        self.run.assert_not_called()

    def test_final_expiry_refuses_success(self):
        self.run.side_effect = lambda *a, **k: setattr(self.op, 'elapsed', 10411)
        with self.assertRaises(TimeoutError):
            self.invoke()
        self.assertEqual(self.run.call_count, 1)

    def test_claim_tampering_refuses_success(self):
        def effect(*args, **kwargs):
            (self.ledger / (self.packet['attempt_id'] + '.json')).write_text('{}')
            return {'injected': True}
        self.run.side_effect = effect
        with self.assertRaisesRegex(ValueError, 'claim changed during'):
            self.invoke()

    def test_stale_or_unaccepted_resources_never_claim(self):
        for key, value in (('measured_utc', (self.op.now - timedelta(seconds=61)).isoformat()),
                           ('cpu_accepted_by_owner', False),
                           ('output_volume_free_bytes', 0)):
            with self.subTest(key=key):
                old = self.packet['resource_sample'][key]
                self.packet['resource_sample'][key] = value
                with self.assertRaisesRegex(ValueError, 'admission evidence missing or stale'):
                    self.invoke()
                self.packet['resource_sample'][key] = old
        self.run.assert_not_called()
        self.assertEqual(list(self.ledger.iterdir()), [])

    def test_duplicate_and_oversized_json_rejected(self):
        path = self.root / 'packet.json'
        path.write_text('{"authorized":true,"authorized":false}')
        with self.assertRaisesRegex(ValueError, 'Duplicate'):
            admission.load(path)
        path.write_bytes(b' ' * (admission.MAX_PACKET + 1))
        with self.assertRaisesRegex(ValueError, 'bounded'):
            admission.load(path)

    def test_memory_admission_override_preserves_cpu_disk_and_allocated_caps(self):
        del self.packet['resource_sample']['available_bytes']
        self.assertEqual(self.invoke(), {'injected': True})
        self.assertEqual(self.run.call_args.args[1]['maximum_private_bytes'], self.resource['maximum_private_bytes'])

    def test_actual_main_packet_read_cannot_restart_caller_deadline(self):
        now = self.op.now
        class Clock(datetime):
            @staticmethod
            def now(tz):
                return now
        reads = []
        def slow_load(path):
            reads.append(path)
            self.op.elapsed = 11000
            return self.resource if path.name == 'resource.json' else self.packet
        real_invoke = admission.invoke
        def invoke(*args, **kwargs):
            return real_invoke(*args, **kwargs, operator=self.op, driver=self.driver, run=self.run)
        with patch.object(execute, 'CLI_ENTRY', None), patch.object(execute.time, 'monotonic', side_effect=self.op.clock), \
                patch.object(execute, 'datetime', Clock), patch.object(admission, 'load', side_effect=slow_load), \
                patch.object(admission, 'invoke', side_effect=invoke):
            with self.assertRaises(TimeoutError):
                execute.main(['--execute', '--repository', str(self.repository), '--resource-packet', 'resource.json',
                              '--admission', 'admission.json', '--admission-sha256', admission.digest(self.packet)])
        self.assertEqual(len(reads), 2)
        self.run.assert_not_called()
        self.assertEqual(list(self.ledger.iterdir()), [])

    def test_explicit_cli_requires_admission_before_executor(self):
        with patch.object(execute, 'execute', side_effect=AssertionError('no native')) as native:
            with self.assertRaises(SystemExit):
                execute.main(['--execute', '--repository', str(self.root), '--resource-packet', 'unused'])
        native.assert_not_called()


if __name__ == '__main__':
    unittest.main()
