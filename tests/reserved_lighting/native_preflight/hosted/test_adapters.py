"""Offline causal controls. All HTTPS, mount, clock and filesystem effects injected."""
import copy
import importlib.util
import io
import json
import os
from pathlib import Path
import ssl
import struct
import subprocess
import sys
import types
import unittest
import warnings
from unittest import mock
import zipfile

spec = importlib.util.spec_from_file_location('hosted', Path(__file__).with_name('adapters.py'))
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)


def elf():
    ident = b'\x7fELF\x01\x01\x01'+b'\0'*9
    strings = b'libc.so.6\0'
    size, base = 160+len(strings), 0x8048000
    header = struct.pack('<16sHHIIIIIHHHHHH', ident, 2, 3, 1, 0, 52, 0, 0, 52, 32, 2, 0, 0, 0)
    load = struct.pack('<IIIIIIII', 1, 0, base, 0, size, size, 5, 4096)
    dynamic = struct.pack('<IIIIIIII', 2, 116, base+116, 0, 32, 32, 4, 4)
    tags = struct.pack('<IIIIIIII', 5, base+160, 10, len(strings), 1, 0, 0, 0)
    return (header+load+dynamic+tags).ljust(160, b'\0')+strings


def archive(extra=(), binaries=True):
    output = io.BytesIO()
    with zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_DEFLATED) as z:
        if binaries:
            z.writestr('byond/bin/DreamMaker', elf())
            z.writestr('byond/bin/DreamDaemon', elf())
        for name, value in extra:
            with warnings.catch_warnings():
                warnings.filterwarnings('ignore', message='Duplicate name:', category=UserWarning)
                z.writestr(name, value)
    return output.getvalue()


class Clock:
    now = 1000.0
    def __call__(self): return self.now


class Buffer(io.BytesIO):
    def close(self): self.value = self.getvalue()  # retained injected filesystem


class Scratch:
    def __init__(self, *args): self.files, self.clean = {}, 0
    def create(self, name):
        if name in self.files: raise FileExistsError(name)
        self.files[name] = Buffer(); return self.files[name]
    def capacity(self, budget): return {'errno': 28, 'hard_bytes': m.LIMITS['scratch_bytes']}
    def bytes(self): return self.files['archive.zip'].getvalue()
    def cleanup(self): self.clean += 1; self.files.clear(); return {'owned_files_removed': True}


class Transport:
    def __init__(self, data): self.data, self.offset, self.closed = data, 0, 0
    def open(self, budget): return {'url': m.URL, 'peer_ip': '8.8.8.8', 'certificate_sha256': 'b'*64, 'bytes': len(self.data)}
    def read(self, budget):
        budget.check(); result = self.data[self.offset:self.offset+128]; self.offset += len(result); return result
    def close(self): self.closed += 1; return []


def admission():
    request = {'scope': m.SCOPE, 'url': m.URL, 'limits': dict(m.LIMITS), 'head': 'a'*40, 'owner': 'c'*32,
               'executor': 'test-injected-only', 'peer_ip': '8.8.8.8', 'image_count': 0, 'compile_count': 0,
               'daemon_count': 0, 'package_install_count': 0}
    grant = {'scope': m.SCOPE, 'granted': True, 'request_sha256': m.sha(m.canonical(request)), 'head': request['head'],
             'executor': request['executor'], 'starts': 999.0, 'ends': 1120.0, 'external_controls_reviewed': True}
    return request, grant


class Contracts(unittest.TestCase):
    def test_cli_host_identity_rejects_desktop_wrong_head_and_retry(self):
        request, _ = admission()
        environment = {'GITHUB_ACTIONS': 'true', 'GITHUB_EVENT_NAME': 'workflow_dispatch', 'GITHUB_REPOSITORY': 'Civ13/Civ13',
                       'GITHUB_REPOSITORY_ID': '141349998', 'GITHUB_SHA': request['head'], 'RUNNER_ENVIRONMENT': 'github-hosted',
                       'RUNNER_OS': 'Linux', 'GITHUB_RUN_ATTEMPT': '1'}
        with mock.patch.object(m.sys, 'platform', 'linux'):
            m.hosted_identity(request, environment)
            for field, value in [('GITHUB_SHA', 'b'*40), ('GITHUB_EVENT_NAME', 'push'), ('GITHUB_RUN_ATTEMPT', '2'),
                                 ('RUNNER_ENVIRONMENT', 'self-hosted'), ('GITHUB_REPOSITORY', 'private/elsewhere')]:
                with self.assertRaises(ValueError): m.hosted_identity(request, dict(environment, **{field: value}))
    def test_default_cli_inert_and_no_grant_never_creates_or_connects(self):
        result = subprocess.run([sys.executable, '-B', str(Path(m.__file__))], capture_output=True, check=True, text=True)
        self.assertEqual(json.loads(result.stdout)['status'], 'INERT_NO_CAPTURE')
        request, grant = admission(); grant['granted'] = False
        transport, factory = mock.Mock(), mock.Mock()
        with self.assertRaisesRegex(ValueError, 'grant'):
            m.capture(request, grant, transport, factory, Clock(), Clock())
        factory.assert_not_called(); transport.open.assert_not_called()

    def test_capture_actual_orchestration_inventory_and_owned_cleanup(self):
        request, grant = admission(); transport = Transport(archive()); scratch = Scratch()
        result = m.capture(request, grant, transport, lambda *a: scratch, Clock(), Clock())
        self.assertTrue(result['complete'], result)
        self.assertEqual(result['status'], 'CANDIDATE_IDENTITIES_ONLY_REQUIRES_REVIEW')
        self.assertEqual(result['archive_sha256'], m.sha(archive()))
        self.assertEqual([x['elf_needed'] for x in result['members']], [['libc.so.6'], ['libc.so.6']])
        self.assertEqual(scratch.clean, 1); self.assertEqual(transport.closed, 1)

    def test_transport_drift_short_stream_and_corrupt_zip_are_incomplete(self):
        for fault in ('peer', 'length', 'corrupt'):
            request, grant = admission(); transport = Transport(b'bad' if fault == 'corrupt' else archive())
            original = transport.open
            def opened(budget):
                value = original(budget)
                if fault == 'peer': value['peer_ip'] = '1.1.1.1'
                if fault == 'length': value['bytes'] += 1
                return value
            transport.open = opened; scratch = Scratch()
            result = m.capture(request, grant, transport, lambda *a: scratch, Clock(), Clock())
            self.assertFalse(result['complete'], fault); self.assertEqual(scratch.clean, 1)
            self.assertEqual(transport.closed, 1)

    def test_late_hash_utc_cleanup_and_request_drift_cannot_pass(self):
        for phase in ('inventory', 'utc', 'cleanup', 'request'):
            request, grant = admission(); mono, utc = Clock(), Clock(); scratch = Scratch()
            original = m.inventory
            def inspected(data, budget):
                value = original(data, budget)
                if phase == 'inventory': mono.now += 106
                if phase == 'utc': utc.now += 121
                if phase == 'request': request['executor'] = 'changed'
                return value
            old_cleanup = scratch.cleanup
            def cleaned():
                value = old_cleanup()
                if phase == 'cleanup': mono.now += 121
                return value
            scratch.cleanup = cleaned
            with mock.patch.object(m, 'inventory', inspected):
                result = m.capture(request, grant, Transport(archive()), lambda *a: scratch, mono, utc)
            self.assertFalse(result['complete'], phase)

    def test_cleanup_failure_keeps_original_download_error_and_no_retry(self):
        request, grant = admission(); transport, scratch = Transport(archive()), Scratch()
        transport.read = mock.Mock(side_effect=ValueError('original read failure'))
        transport.close = mock.Mock(side_effect=OSError('close failure'))
        scratch.cleanup = mock.Mock(side_effect=ValueError('unowned drift'))
        result = m.capture(request, grant, transport, lambda *a: scratch, Clock(), Clock())
        self.assertIn('original read failure', result['error']); self.assertIn('unowned drift', result['cleanup_error'])
        self.assertFalse(result['complete']); transport.read.assert_called_once()

    def test_zip_traversal_alias_links_metadata_and_expansion_bounds(self):
        budget = m.Budget(1120, Clock(), Clock())
        cases = [archive([('../escape', b'x')]), archive([('byond//bad', b'x')]),
                 archive([('byond/bin/DreamMaker', elf())]), archive(binaries=False)]
        output = io.BytesIO()
        with zipfile.ZipFile(output, 'w') as z:
            link = zipfile.ZipInfo('link'); link.external_attr = 0o120777 << 16; z.writestr(link, b'target')
        cases.append(output.getvalue())
        for data in cases:
            with self.assertRaises((ValueError, zipfile.BadZipFile)): m.inventory(data, budget)
        with mock.patch.dict(m.LIMITS, expanded_bytes=4):
            with self.assertRaisesRegex(ValueError, 'expansion'): m.inventory(archive(), budget)
        with mock.patch.dict(m.LIMITS, members=1):
            with self.assertRaisesRegex(ValueError, 'directory'): m.inventory(archive(), budget)

    def test_static_elf_needed_and_malformed_string_segment_rejected(self):
        self.assertEqual(m.elf_dependencies(elf()), ['libc.so.6'])
        self.assertIsNone(m.elf_dependencies(b'ordinary data'))
        for offset, value in ((4, 2), (5, 2), (18, 62)):
            data = bytearray(elf()); data[offset] = value
            with self.assertRaises(ValueError): m.elf_dependencies(data)
        data = bytearray(elf()); struct.pack_into('<I', data, 120, 0xffffffff)
        with self.assertRaises(ValueError): m.elf_dependencies(data)

    def test_https_uses_one_numeric_peer_verified_hostname_and_no_redirect(self):
        for peer in ('127.0.0.1', '10.0.0.1', '169.254.169.254', '::1'):
            with self.assertRaisesRegex(ValueError, 'Public'): m.HTTPS(peer)
        context = mock.Mock(check_hostname=False, verify_mode=ssl.CERT_REQUIRED)
        with self.assertRaisesRegex(ValueError, 'Verified'): m.HTTPS('8.8.8.8', context=context)
        for status, headers in ((302, {'Location': 'https://elsewhere'}), (200, {'Content-Length': '99999999'}),
                                (200, {'Content-Length': '1', 'Transfer-Encoding': 'chunked'})):
            context = mock.Mock(check_hostname=True, verify_mode=ssl.CERT_REQUIRED)
            raw, tls = mock.Mock(), mock.Mock(); tls.getpeername.return_value = ('8.8.8.8', 443)
            context.wrap_socket.return_value = tls
            response = mock.Mock(status=status, headers=headers)
            # Real headers API preserves duplicate length fields.
            response.headers = __import__('email.message', fromlist=['Message']).Message()
            for k, v in headers.items(): response.headers[k] = v
            connector = mock.Mock(return_value=raw)
            transport = m.HTTPS('8.8.8.8', connector=connector, context=context)
            with mock.patch.object(m.http.client, 'HTTPResponse', return_value=response):
                with self.assertRaises(ValueError): transport.open(m.Budget(1120, Clock(), Clock()))
            connector.assert_called_once(); context.wrap_socket.assert_called_once_with(raw, server_hostname=m.HOST)
            self.assertIn(b'Host: www.byond.com', tls.sendall.call_args.args[0])
            self.assertNotIn(b'Authorization:', tls.sendall.call_args.args[0])

    def test_capacity_probe_collision_preserves_unowned_bytes(self):
        scratch = object.__new__(m.Scratch); scratch.files = {}; scratch.mount_id = 'injected'
        scratch.create = mock.Mock(side_effect=FileExistsError('preexisting'))
        scratch.remove = mock.Mock()
        with self.assertRaises(FileExistsError): scratch.capacity(m.Budget(1120, Clock(), Clock()))
        scratch.remove.assert_not_called()

    def test_capacity_control_requires_actual_linux_enospc_and_owned_cleanup(self):
        for code, passes in ((28, True), (13, False), (5, False)):
            scratch = object.__new__(m.Scratch); scratch.mount_id = 'injected'
            handle = mock.MagicMock()
            handle.write.side_effect = [65536, OSError(code, 'injected')]
            scratch.create = mock.Mock(return_value=handle); scratch.remove = mock.Mock()
            if passes:
                self.assertEqual(scratch.capacity(m.Budget(1120, Clock(), Clock()))['errno'], 28)
            else:
                with self.assertRaises(ValueError): scratch.capacity(m.Budget(1120, Clock(), Clock()))
            scratch.remove.assert_called_once_with('capacity.bin')

    def test_actual_stream_close_failure_preserves_primary_and_cleanup_only_is_fatal(self):
        for initial in (True, False):
            request, grant = admission(); transport, scratch = Transport(archive()), Scratch()
            handle = Buffer()
            original_close = handle.close
            def failed_close():
                original_close()
                raise OSError('owned archive close failure')
            handle.close = failed_close
            scratch.create = lambda name: handle
            scratch.bytes = lambda: handle.getvalue()
            if initial: transport.read = mock.Mock(side_effect=ValueError('original stream failure'))
            try: result = m.capture(request, grant, transport, lambda *a: scratch, Clock(), Clock())
            finally: handle.close = original_close
            self.assertFalse(result['complete'])
            if initial:
                self.assertEqual(result['error'], 'original stream failure')
                self.assertIn('owned archive close failure', result['error_notes'][0])
                transport.read.assert_called_once()
            else: self.assertEqual(result['error'], 'owned archive close failure')
            self.assertEqual(scratch.clean, 1)

    def test_actual_capacity_write_or_deadline_close_remove_preserve_primary(self):
        for failure in ('write', 'deadline', 'cleanup_only'):
            scratch = object.__new__(m.Scratch); scratch.mount_id = 'injected'
            handle = mock.MagicMock(); handle.__enter__.return_value = handle
            if failure == 'write': handle.write.side_effect = ValueError('original capacity write')
            else: handle.write.side_effect = OSError(28, 'full')
            handle.close.side_effect = OSError('additional capacity close')
            scratch.create = mock.Mock(return_value=handle)
            scratch.remove = mock.Mock(side_effect=OSError('additional capacity remove'))
            budget = m.Budget(1120, Clock(), Clock())
            if failure == 'deadline': budget.check = mock.Mock(side_effect=ValueError('original capacity deadline'))
            with self.assertRaises((ValueError, OSError)) as raised: scratch.capacity(budget)
            if failure in ('write', 'deadline'):
                self.assertEqual(str(raised.exception), 'original capacity '+failure)
                notes = raised.exception.__notes__
                self.assertIn('additional capacity close', notes[0]); self.assertIn('additional capacity remove', notes[1])
            else:
                self.assertEqual(str(raised.exception), 'additional capacity close')
                self.assertIn('additional capacity remove', raised.exception.__notes__[0])
            scratch.remove.assert_called_once_with('capacity.bin')

    def test_cleanup_changed_inode_never_unlinks_unowned_file(self):
        scratch = object.__new__(m.Scratch); scratch.fd = 42; scratch.files = {'archive.zip': (1, 2)}
        identity = types.SimpleNamespace(st_dev=1, st_ino=3, st_mode=0o100600)
        with mock.patch.object(m.os, 'stat', return_value=identity), mock.patch.object(m.os, 'unlink') as unlink:
            with self.assertRaisesRegex(ValueError, 'identity'): scratch.remove('archive.zip')
            unlink.assert_not_called()


if __name__ == '__main__': unittest.main()
