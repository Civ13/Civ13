"""Offline scope, review gate and retained-evidence controls."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import stat
import tempfile
from types import SimpleNamespace
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('sleep_hosted_job', ROOT / 'hosted_job.py')
h = importlib.util.module_from_spec(spec); spec.loader.exec_module(h)

class Tests(unittest.TestCase):
    def test_scope_is_exact_and_changed_input_fails(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d); (root / 'source').write_bytes(b'fixture')
            manifest = root / 'scope.json'
            raw = json.dumps({'schema': 1, 'files': {'source': hashlib.sha256(b'fixture').hexdigest()}}).encode()
            manifest.write_bytes(raw); expected = hashlib.sha256(raw).hexdigest()
            self.assertEqual(h.verify_scope(root, manifest, expected)['schema'], 1)
            (root / 'source').write_bytes(b'changed')
            with self.assertRaises(ValueError): h.verify_scope(root, manifest, expected)
            with self.assertRaises(ValueError): h.verify_scope(root, manifest, '0' * 64)
    def test_scope_refuses_parent_traversal(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d); raw = json.dumps({'schema': 1, 'files': {'../outside': '0' * 64}}).encode()
            manifest = root / 'scope.json'; manifest.write_bytes(raw)
            with self.assertRaises(ValueError): h.verify_scope(root, manifest, hashlib.sha256(raw).hexdigest())
    def test_execute_rejects_missing_or_changed_reviewed_host_before_launch(self):
        receipt = {'python_sha256': 'a' * 64, 'docker_sha256': 'b' * 64, 'mode': 'execute', 'native_executed': False}
        for python, docker in (('', ''), ('c' * 64, 'b' * 64), ('a' * 64, 'c' * 64)):
            args = SimpleNamespace(expected_python=python, expected_docker=docker)
            with mock.patch.object(h.subprocess, 'run') as run, self.assertRaises(ValueError): h.execute(args, receipt)
            run.assert_not_called()
    def test_unknown_cleanup_only_reads_host_controlled_roots(self):
        self.assertEqual(h.evidence_roots(False), ('main', 'watch'))
        self.assertEqual(h.evidence_roots(None), ('main', 'watch'))
        self.assertIn('tmp', h.evidence_roots(True))
    def test_bounded_fd_copy_rejects_concurrent_growth_and_total_overflow(self):
        info = SimpleNamespace(st_mode=stat.S_IFREG, st_size=1, st_dev=1, st_ino=2, st_mtime_ns=3, st_ctime_ns=4)
        with tempfile.TemporaryDirectory() as d:
            with mock.patch.object(h.os, 'fstat', return_value=info), mock.patch.object(h.os, 'read', side_effect=[b'x', b'y', b'']):
                with self.assertRaises(ValueError): h.bounded_fd_copy(7, Path(d) / 'changed', {'bytes': 0})
            with mock.patch.object(h.os, 'fstat', return_value=info), mock.patch.object(h.os, 'read', side_effect=[b'x', b'']):
                with self.assertRaises(ValueError): h.bounded_fd_copy(7, Path(d) / 'overflow', {'bytes': 512 * 1024**2})
    def test_evidence_copy_preserves_regular_bytes_and_rejects_links(self):
        if not (hasattr(os, 'O_NOFOLLOW') and hasattr(os, 'O_DIRECTORY') and os.scandir in os.supports_fd and os.open in os.supports_dir_fd):
            self.skipTest('descriptor-bound traversal is Linux-specific')
        with tempfile.TemporaryDirectory() as d:
            root = Path(d); src = root / 'src'; src.mkdir(); (src / 'main').mkdir(); (src / 'main' / 'receipt').write_bytes(b'raw receipt\n')
            h.copy_evidence(src, root / 'copy', ('main',)); self.assertEqual((root / 'copy' / 'main' / 'receipt').read_bytes(), b'raw receipt\n')
            try: (src / 'main' / 'link').symlink_to(src / 'main' / 'receipt')
            except OSError: return
            with self.assertRaises(ValueError): h.copy_evidence(src, root / 'copy2', ('main',))
    def test_image_inspect_accepts_valid_list_and_retains_raw_bytes(self):
        class Binding:
            ENDPOINT='unix:///var/run/docker.sock'; IMAGE_ID='image'
            def same_daemon(self, *args): pass
        class Contract:
            def validate_image(self, row, image): self.row=row
        binding=Binding(); contract=Contract(); raw=b'[{"Id":"image","Os":"linux","Architecture":"386"}]'
        with tempfile.TemporaryDirectory() as d:
            def load(name, path): return binding if name == 'sleep_binding_check' else contract
            with mock.patch.object(h, 'load_module', side_effect=load), mock.patch.object(h, 'capture', return_value=raw):
                self.assertEqual(h.image_inspect('/docker', Path(d), {}, Path(d))['id'], 'image')
            self.assertEqual((Path(d) / 'image-inspect.json').read_bytes(), raw)
            self.assertEqual(contract.row['Architecture'], '386')
    def test_watchdog_pidfd_rejects_reparent_or_replacement(self):
        class Poll:
            def register(self, fd, event): pass
            def poll(self, timeout): return []
        ready = json.dumps({'owner_pid': 10, 'watchdog_pid': 20}).encode()
        for second in ((11, 55), (10, 56)):
            with mock.patch.object(h, 'read_host_receipt', return_value=ready), \
                 mock.patch.object(h, 'proc_identity', side_effect=[(10, 55), second]), \
                 mock.patch.object(h.os, 'pidfd_open', return_value=77, create=True), \
                 mock.patch.object(h.os, 'close') as close, \
                 mock.patch.object(h.select, 'poll', return_value=Poll(), create=True), \
                 mock.patch.object(h.select, 'POLLIN', 1, create=True):
                with self.assertRaises(ValueError): h.bind_watchdog(Path('ready'), 10)
                close.assert_called_once_with(77)
    def test_watchdog_pidfd_accepts_only_stable_parent_and_identity(self):
        class Poll:
            def register(self, fd, event): pass
            def poll(self, timeout): return []
        poll = Poll(); ready = json.dumps({'owner_pid': 10, 'watchdog_pid': 20}).encode()
        with mock.patch.object(h, 'read_host_receipt', return_value=ready), \
             mock.patch.object(h, 'proc_identity', return_value=(10, 55)), \
             mock.patch.object(h.os, 'pidfd_open', return_value=77, create=True), \
             mock.patch.object(h.os, 'close') as close, \
             mock.patch.object(h.select, 'poll', return_value=poll, create=True), \
             mock.patch.object(h.select, 'POLLIN', 1, create=True):
            self.assertEqual(h.bind_watchdog(Path('ready'), 10), (77, poll))
            close.assert_not_called()
    def test_watchdog_pidfd_requires_readable_event_on_exact_descriptor(self):
        self.assertEqual(h.classify_watchdog_events([(77, 1)], 77, 1), 'pidfd_exit_observed')
        self.assertEqual(h.classify_watchdog_events([(77, 8)], 77, 1), 'pidfd_unexpected_event')
        self.assertEqual(h.classify_watchdog_events([(78, 1)], 77, 1), 'pidfd_unexpected_event')
        self.assertEqual(h.classify_watchdog_events([], 77, 1), 'not_observed_before_deadline')

if __name__ == '__main__': unittest.main()
