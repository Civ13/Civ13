"""Offline fake-backend checks for the dormant one-shot network profile.

No Windows native API, port census, compiler or daemon is invoked.
"""
import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('frozen_throw_runtime', Path(__file__).with_name('runtime_once.py'))
RUNTIME = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RUNTIME)
NATIVE_SPEC = importlib.util.spec_from_file_location('throw_native_guard', ROOT / 'scripts/native_fixture.py')
import sys
NATIVE = importlib.util.module_from_spec(NATIVE_SPEC)
sys.modules[NATIVE_SPEC.name] = NATIVE
NATIVE_SPEC.loader.exec_module(NATIVE)


def listener(**changes):
    return dict(dict(protocol='tcp', family=2, address='127.0.0.1', port=59474,
                     state=2, remote_address='0.0.0.0', remote_port=0), **changes)


class FakeBackend:
    def __init__(self):
        self.rows = [listener()]
        self.private = 16 * 1024**2
        self.launches = 0

    def launch(self, *args):
        self.launches += 1
        return object()

    def observe(self, child):
        return dict(sockets=self.rows, total=1, retained=1, active=1, terminated=0,
                    members=[123], private=self.private, watcher=16 * 1024**2,
                    free=8 * 1024**3, cpu=0.1)


class RuntimeProfileTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.marker = Path(self.temp.name) / 'port-closed.txt'
        self.clock = 0.0
        self.backend = FakeBackend()
        self.audit = []
        self.profile = RUNTIME.StartupLoopback(self.backend, self.marker, self.audit.append, lambda: self.clock)
        self.child = self.profile.launch([], None, None, 'throw-launch')

    def test_only_exact_listener_is_filtered_and_original_rows_are_retained(self):
        sample = self.profile.observe(self.child)
        self.assertEqual(sample['sockets'], [])
        self.assertEqual(sample['observed_sockets'], [listener()])
        self.assertEqual(self.audit[-1]['observed_sockets'], [listener()])
        NATIVE.validate_sample(sample, 123)

    def test_udp_ipv6_external_connected_wrong_port_and_multiple_rows_are_rejected(self):
        for rows in ([listener(protocol='udp')], [listener(family=23)],
                     [listener(address='0.0.0.0')], [listener(state=5)],
                     [listener(port=1715)], [listener(remote_address='8.8.8.8')],
                     [listener(), listener()]):
            with self.subTest(rows=rows):
                self.backend.rows = rows
                sample = self.profile.observe(self.child)
                self.assertEqual(sample['sockets'], rows)
                with self.assertRaisesRegex(RuntimeError, 'socket observed'):
                    NATIVE.validate_sample(sample, 123)

    def test_closure_ends_exception_permanently_even_if_marker_disappears(self):
        self.marker.write_bytes(b'closed\r\n')
        sample = self.profile.observe(self.child)
        self.assertTrue(sample['closure_seen'])
        with self.assertRaises(RuntimeError): NATIVE.validate_sample(sample, 123)
        self.marker.unlink()
        with self.assertRaises(RuntimeError): NATIVE.validate_sample(self.profile.observe(self.child), 123)
        self.backend.rows = []
        self.clock = 80
        NATIVE.validate_sample(self.profile.observe(self.child), 123)

    def test_late_or_missing_marker_fails_even_without_sockets(self):
        self.backend.rows = []
        self.clock = 6
        with self.assertRaisesRegex(RuntimeError, 'closure deadline'):
            self.profile.observe(self.child)
        self.marker.write_bytes(b'closed\r\n')
        with self.assertRaisesRegex(RuntimeError, 'closure deadline'):
            self.profile.observe(self.child)

    def test_malformed_or_oversized_marker_fails(self):
        for content in (b'closed\n', b'closed\r\nextra', b'x' * 33):
            self.marker.write_bytes(content)
            with self.assertRaisesRegex(RuntimeError, 'Malformed'):
                self.profile.observe(self.child)

    def test_second_launch_and_preexisting_marker_are_refused(self):
        with self.assertRaisesRegex(RuntimeError, 'Exactly one'):
            self.profile.launch([], None, None, 'throw-launch')
        self.marker.write_bytes(b'closed\r\n')
        other = RUNTIME.StartupLoopback(self.backend, self.marker, self.audit.append)
        with self.assertRaisesRegex(RuntimeError, 'pre-exist'):
            other.launch([], None, None, 'throw-launch')
        self.assertEqual(self.backend.launches, 1)

    def test_startup_exception_does_not_relax_resource_or_membership_guards(self):
        self.backend.private = NATIVE.CHILD_CAP + 1
        with self.assertRaisesRegex(RuntimeError, 'memory budget'):
            NATIVE.validate_sample(self.profile.observe(self.child), 123)
        self.backend.private = 0
        sample = self.profile.observe(self.child)
        sample['members'] = [123, 456]
        with self.assertRaisesRegex(RuntimeError, 'Job member'):
            NATIVE.validate_sample(sample, 123)

    def test_execute_without_prior_permission_flag_stops_before_read_or_launch(self):
        with self.assertRaisesRegex(RuntimeError, 'Root must establish'):
            RUNTIME.execute('does-not-exist.json', 'does-not-exist', False)


if __name__ == '__main__':
    unittest.main(verbosity=2)
