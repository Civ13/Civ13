"""Offline fake-backend checks for the dormant one-shot network profile.

No Windows native API, port census, compiler or daemon is invoked.
"""
import importlib.util
import ast
import ctypes
from pathlib import Path
import socket
import struct
import tempfile
from types import SimpleNamespace
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


def backend_rows(*, family=2, protocol='tcp', pid=123, address='127.0.0.1', port=59474):
    """Actual unchanged decoder over synthetic OS tables; no native API/import.

    Unlike a second invented row serializer, this fails when the production
    backend's decoder contract changes. The fixture supplies bytes only.
    """
    source = ROOT / 'tests/human_subtile/native_1688/windows.py'
    tree = ast.parse(source.read_text())
    adapter = next(node for node in tree.body if isinstance(node, ast.ClassDef) and node.name == 'Adapter')
    method = next(node for node in adapter.body if isinstance(node, ast.FunctionDef) and node.name == 'sockets')
    width = (24 if family == 2 else 56) if protocol == 'tcp' else (12 if family == 2 else 28)
    row = bytearray(width)
    af = socket.AF_INET if family == 2 else socket.AF_INET6
    local_offset = (4 if protocol == 'tcp' else 0) if family == 2 else 0
    packed = socket.inet_pton(af, address)
    row[local_offset:local_offset + len(packed)] = packed
    local_port = (8 if protocol == 'tcp' else 4) if family == 2 else 20
    row[local_port:local_port + 2] = struct.pack('!H', port)
    if protocol == 'tcp':
        struct.pack_into('<I', row, 0 if family == 2 else 48, 2)
    struct.pack_into('<I', row, width - 4, pid)
    table = struct.pack('<I', 1) + row
    class Table:
        def __init__(self, kind): self.kind = kind
        def __call__(self, buf, size, ordered, requested_family, table_class, flags):
            raw = table if (requested_family, self.kind) == (family, protocol) else struct.pack('<I', 0)
            size._obj.value = len(raw)
            if buf is None: return 122
            ctypes.memmove(buf, raw, len(raw))
            return 0
    env = dict(c=ctypes, w=SimpleNamespace(DWORD=ctypes.c_uint32, BOOL=ctypes.c_int, ULONG=ctypes.c_uint32),
               struct=struct, socket=socket)
    exec(compile(ast.Module(body=[method], type_ignores=[]), str(source), 'exec'), env)
    facade = SimpleNamespace(exited=lambda child: False,
        ip=SimpleNamespace(GetExtendedTcpTable=Table('tcp'), GetExtendedUdpTable=Table('udp')))
    return env['sockets'](facade, SimpleNamespace(pid=123))


class FakeBackend:
    def __init__(self):
        self.rows = [listener()]
        self.private = 16 * 1024**2
        self.launches = 0
        self.owner = dict(pid=123, creation_filetime=456, image='C:/fixture/dd.exe')
        self.birth = 456
        self.a = self
        self.members = [123]

    def identity(self, child): return dict(self.owner)

    def times(self, child): return self.birth, 0.1

    def launch(self, *args):
        self.launches += 1
        return SimpleNamespace(pid=123)

    def observe(self, child):
        return dict(exited=False, sockets=self.rows, total=1, retained=1, active=1, terminated=0,
                    members=self.members, private=self.private, watcher=16 * 1024**2,
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
        for rows in ([listener(family=23, address='::1', remote_address='::')],
                     [listener(address='0.0.0.0')], [listener(state=5)],
                     [listener(port=1715)], [listener(remote_address='8.8.8.8')],
                     [listener(), listener()]):
            with self.subTest(rows=rows):
                self.backend.rows = rows
                sample = self.profile.observe(self.child)
                self.assertEqual(sample['sockets'], rows)
                with self.assertRaisesRegex(RuntimeError, 'socket observed'):
                    NATIVE.validate_sample(sample, 123)

    def test_actual_textual_decoder_and_numeric_schema_have_same_canonical_endpoint(self):
        numeric = RUNTIME.normalize_socket(listener(), self.backend.owner)
        self.backend.rows = backend_rows()
        self.assertEqual(self.backend.rows, [dict(protocol='tcp', address='127.0.0.1', port=59474,
            remote_address='0.0.0.0', remote_port=0, state='listen')])
        sample = self.profile.observe(self.child)
        NATIVE.validate_sample(sample, 123)
        self.assertEqual(sample['normalized_sockets'], [numeric])
        self.assertEqual(numeric['family'], 4)
        self.assertEqual((numeric['pid'], numeric['creation_filetime']), (123, 456))
        self.assertEqual(self.audit[-1]['observed_sockets'], self.backend.rows)

    def test_actual_udp_and_ipv6_decoder_rows_never_get_the_exception(self):
        for rows in (backend_rows(protocol='udp'), backend_rows(family=23, address='::1')):
            with self.subTest(rows=rows), self.assertRaises(RuntimeError):
                self.backend.rows = rows
                NATIVE.validate_sample(self.profile.observe(self.child), 123)

    def test_missing_family_is_derived_from_address_not_assumed_ipv4(self):
        ipv6 = dict(protocol='tcp', address='::1', port=59474, state='listen', remote_address='::', remote_port=0)
        self.assertEqual(RUNTIME.normalize_socket(ipv6, self.backend.owner)['family'], 6)
        for row in (listener(family=23), dict(ipv6, address='127.0.0.1'), dict(ipv6, address='localhost')):
            with self.subTest(row=row), self.assertRaises(RuntimeError):
                RUNTIME.normalize_socket(row, self.backend.owner)

    def test_unknown_malformed_or_ambiguous_rows_are_rejected_and_raw_is_audited(self):
        for row in (listener(extra=True), listener(pid=999), listener(creation_filetime=999),
                    listener(port=True), listener(port='59474'), listener(state='listen'),
                    listener(family=True), listener(address='127.000.0.1'), listener(protocol='other'),
                    dict(protocol='tcp', address='127.0.0.1', port=59474, state=2, remote_address='0.0.0.0', remote_port=0)):
            with self.subTest(row=row), self.assertRaises(RuntimeError):
                self.backend.rows = [row]
                self.profile.observe(self.child)
            self.assertEqual(self.audit[-1]['observed_sockets'], [row])

    def test_foreign_pid_or_birth_cannot_borrow_the_owner_context(self):
        self.backend.owner['pid'] = 999
        with self.assertRaisesRegex(RuntimeError, 'Foreign owner'):
            self.profile.observe(self.child)
        self.backend.owner['pid'] = 123
        self.backend.birth = 999
        with self.assertRaisesRegex(RuntimeError, 'Foreign owner'):
            self.profile.observe(self.child)
        self.backend.birth = 456
        self.backend.members = [999]
        with self.assertRaisesRegex(RuntimeError, 'Job member'):
            NATIVE.validate_sample(self.profile.observe(self.child), 123)
        self.assertEqual(backend_rows(pid=999), [])  # Real decoder filters foreign table owners.

    def test_observation_latency_cannot_extend_the_five_second_window(self):
        original = self.backend.observe
        def delayed(child):
            self.clock = 5.01
            return original(child)
        self.backend.observe = delayed
        with self.assertRaisesRegex(RuntimeError, 'closure deadline'):
            self.profile.observe(self.child)

    def test_textual_schema_negative_endpoints_and_unknown_rows_are_never_allowed(self):
        row, = backend_rows()
        for changed in (dict(row, address='0.0.0.0'), dict(row, address='127.0.0.2'),
                        dict(row, port=1715), dict(row, state='5'), dict(row, remote_port=80),
                        dict(row, remote_address='8.8.8.8'), dict(row, owner_pid=999),
                        dict(row, remote_address='::'), None, [], dict(row, address='127.1')):
            with self.subTest(row=changed), self.assertRaises(RuntimeError):
                self.backend.rows = [changed]
                NATIVE.validate_sample(self.profile.observe(self.child), 123)

    def test_both_schemas_expire_and_no_socket_renews_the_window(self):
        for rows in ([listener()], backend_rows(), []):
            self.backend.rows = rows
            self.clock = 5.00001
            with self.assertRaisesRegex(RuntimeError, 'closure deadline'):
                self.profile.observe(self.child)
        self.clock = -1
        with self.assertRaisesRegex(RuntimeError, 'closure deadline'):
            self.profile.observe(self.child)

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
