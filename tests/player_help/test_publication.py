import ctypes
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import threading
import time
import unittest
from unittest import mock

spec = importlib.util.spec_from_file_location('publication_bridge',
    Path(__file__).resolve().parents[2] / 'scripts/player_help_bridge.py')
bridge = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bridge)


class PublicationTests(unittest.TestCase):
    def setUp(self):
        self.storage = tempfile.TemporaryDirectory()
        self.addCleanup(self.storage.cleanup)
        self.path = Path(self.storage.name) / 'limits.json'
        self.path.write_text('{"old": true}')

    def locked(self, code=32):
        error = PermissionError('test sharing violation')
        error.winerror = code
        return error

    def test_transient_publication_recovers(self):
        real_replace = os.replace
        with mock.patch.object(bridge.os, 'replace', side_effect=[self.locked(), None]) as replace:
            with mock.patch.object(bridge.time, 'sleep') as sleep:
                bridge.atomic_json(self.path, {'new': True})
        self.assertEqual(replace.call_count, 2)
        sleep.assert_called_once_with(.05)
        real_replace(self.path.with_suffix('.json.tmp'), self.path)
        self.assertEqual(json.loads(self.path.read_text()), {'new': True})

    def test_persistent_failure_is_finite_and_preserves_previous_json(self):
        with mock.patch.object(bridge.os, 'replace', side_effect=self.locked()) as replace:
            with mock.patch.object(bridge.time, 'sleep') as sleep:
                with self.assertRaises(PermissionError):
                    bridge.atomic_json(self.path, {'new': True})
        self.assertEqual(replace.call_count, 21)
        self.assertEqual(sleep.call_count, 20)
        self.assertEqual(json.loads(self.path.read_text()), {'old': True})

    def test_other_failures_are_not_retried(self):
        for failure in (self.locked(123), OSError('disk failure')):
            with mock.patch.object(bridge.os, 'replace', side_effect=failure) as replace:
                with mock.patch.object(bridge.time, 'sleep') as sleep:
                    with self.assertRaises(OSError):
                        bridge.atomic_json(self.path, {})
            replace.assert_called_once()
            sleep.assert_not_called()

    @unittest.skipUnless(os.name == 'nt', 'Windows sharing contract')
    def test_real_windows_reader_blocks_baseline_then_retry_recovers(self):
        from ctypes import wintypes
        kernel = ctypes.WinDLL('kernel32', use_last_error=True)
        kernel.CreateFileW.argtypes = (wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD,
            wintypes.LPVOID, wintypes.DWORD, wintypes.DWORD, wintypes.HANDLE)
        kernel.CreateFileW.restype = wintypes.HANDLE
        kernel.CloseHandle.argtypes = (wintypes.HANDLE,)
        handle = kernel.CreateFileW(str(self.path), 0x80000000, 3, None, 3, 0, None)
        self.assertNotIn(handle, (None, ctypes.c_void_p(-1).value))
        thread = None
        try:
            temporary = self.path.with_suffix('.json.tmp')
            temporary.write_text('{}')
            with self.assertRaises(PermissionError):
                os.replace(temporary, self.path)  # Original one-shot control.
            self.assertEqual(json.loads(self.path.read_text()), {'old': True})
            def release():
                time.sleep(.15)
                kernel.CloseHandle(handle)
            thread = threading.Thread(target=release)
            thread.start()
            bridge.atomic_json(self.path, {'new': True})
            self.assertEqual(json.loads(self.path.read_text()), {'new': True})
        finally:
            if thread:
                thread.join()
            else:
                kernel.CloseHandle(handle)

    def test_existing_stop_marker_drains_without_accepting_new_requests(self):
        stop = self.path.parent / 'stop'
        stop.touch()
        instance = mock.Mock(root=self.path.parent, running=True)
        corpus = [{'topic': 'test', 'text': 'test'}]
        with mock.patch('sys.argv', ['bridge', '--game-root', str(self.path.parent),
                '--config', str(self.path), '--stop-file', str(stop)]):
            with mock.patch.multiple(bridge, load_config=mock.Mock(return_value={}),
                    bounded_json=mock.Mock(return_value=corpus),
                    recipe_context=mock.Mock(return_value=[]),
                    gameplay_knowledge=mock.Mock(return_value=[]),
                    Bridge=mock.Mock(return_value=instance)):
                with mock.patch.object(bridge.signal, 'signal'):
                    bridge.main()
        instance.tick.assert_not_called()
        instance.close.assert_called_once()


if __name__ == '__main__':
    unittest.main()
