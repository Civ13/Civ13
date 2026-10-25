"""Offline synthetic tests only: no Windows APIs, clients, or native acceptance."""
from contextlib import contextmanager
import importlib.util
import json
import os
from pathlib import Path
import struct
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch
import zlib


MODULE = Path(__file__).resolve().parents[1] / 'capture.py'
sys.path.insert(0, str(MODULE.parent))
spec = importlib.util.spec_from_file_location('bakery_capture_under_test', MODULE)
capture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(capture)


def gradient(width=48, height=48):
    return bytes(component for y in range(height) for x in range(width)
                 for component in ((x * 9) % 256, (y * 7) % 256, (x * 5 + y * 3) % 256))


class Adapter:
    def __init__(self):
        self.binding = dict(pid=123, creation_filetime=123456,
                            image=r'C:\isolated\byond\bin\dreamseeker.exe')
        self.dead = False
        self.calls = 0

    def identity(self, process):
        return dict(self.binding)

    def exited(self, process):
        self.calls += 1
        return self.dead


class SyntheticScreen:
    def __init__(self, adapter):
        self.adapter = adapter
        self.actual_identity = dict(adapter.binding)
        self.counters = dict(bitblt=0, activation_attempts=0)
        self.desktops = 0
        self.selected = 0
        self.snapshots = 0
        self.cleaned = False
        self.cleanup_error = False
        self.desktop_error = False
        self.selection_error = False
        self.foreground_error = False
        self.post_capture = lambda: None
        self.rectangle = [30, 40, 78, 88]
        self.result = gradient()
        self.exposed_flags = []

    @contextmanager
    def scope(self):
        try:
            yield
        finally:
            self.cleaned = True
            if self.cleanup_error:
                raise capture.CaptureError('Synthetic cleanup failure')

    def live_identity(self, process):
        return dict(self.actual_identity)

    def desktop(self, process):
        self.desktops += 1
        if self.desktop_error:
            raise capture.CaptureError('Synthetic OpenInputDesktop denial')
        return dict(session_id=2, window_station='WinSta0', input_desktop='Default',
                    thread_desktop='Default', session_state='WTSActive')

    def select_owned(self, pid, title):
        self.selected += 1
        if self.selection_error:
            raise capture.CaptureError('Synthetic ambiguous owned windows')
        return 567

    def window_snapshot(self, hwnd, pid, title, size, *, require_exposed):
        self.snapshots += 1
        self.exposed_flags.append(require_exposed)
        if require_exposed and self.foreground_error:
            raise capture.CaptureError('Synthetic ownership/foreground failure')
        return dict(hwnd=hwnd, pid=pid, thread_id=124, expected_title=title,
                    client_rect=[0, 0, *size], screen_rect=list(self.rectangle),
                    virtual_screen=[0, 0, 1024, 768])

    def activate_owned(self, hwnd, pid, title):
        self.counters['activation_attempts'] += 1
        return dict(requested=True, attempts=1)

    def capture_rgb(self, rect, before, after):
        before()
        self.counters['bitblt'] += 1
        self.post_capture()
        after()
        return self.result


class PNGTests(unittest.TestCase):
    def test_rgb_png_round_trip_and_crc(self):
        rgb = gradient()
        png = capture.encode_png(rgb, 48, 48)
        self.assertEqual(png[:8], capture.PNG_SIGNATURE)
        cursor, chunks = 8, []
        while cursor < len(png):
            length = struct.unpack_from('>I', png, cursor)[0]
            kind = png[cursor + 4:cursor + 8]
            data = png[cursor + 8:cursor + 8 + length]
            crc = struct.unpack_from('>I', png, cursor + 8 + length)[0]
            self.assertEqual(crc, zlib.crc32(kind + data) & 0xffffffff)
            chunks.append((kind, data))
            cursor += 12 + length
        self.assertEqual(cursor, len(png))
        self.assertEqual([kind for kind, _ in chunks], [b'IHDR', b'IDAT', b'IEND'])
        self.assertEqual(struct.unpack('>IIBBBBB', chunks[0][1]), (48, 48, 8, 2, 0, 0, 0))
        raw = zlib.decompress(chunks[1][1])
        self.assertEqual(len(raw), 48 * (1 + 48 * 3))
        for row in range(48):
            offset = row * 145
            self.assertEqual(raw[offset], 0)
            self.assertEqual(raw[offset + 1:offset + 145], rgb[row * 144:(row + 1) * 144])

    def test_dimensions_and_byte_bounds(self):
        for size in ((0, 1), (1, -1), (1025, 1), (1, True), (1.0, 1), (1,), (1, 1, 1)):
            with self.subTest(size=size), self.assertRaises(capture.CaptureError):
                capture._size(size)
        for data in (b'', bytes(48 * 48 * 3 - 1), bytearray(48 * 48 * 3)):
            with self.assertRaises(capture.CaptureError):
                capture.encode_png(data, 48, 48)

    def test_blank_solid_and_almost_blank_rejected(self):
        for color in (b'\0\0\0', b'\xff\xff\xff', b'\xff\0\0', b'\x80\x80\x80'):
            with self.assertRaises(capture.CaptureError):
                capture.pixel_diagnostics(color * (48 * 48), 48, 48)
        sparse = bytearray(48 * 48 * 3)
        sparse[:48] = gradient(16, 1)
        with self.assertRaises(capture.CaptureError):
            capture.pixel_diagnostics(bytes(sparse), 48, 48)

    def test_diversity_is_explicitly_not_semantic_acceptance(self):
        facts = capture.pixel_diagnostics(gradient(), 48, 48)
        self.assertFalse(facts['semantic_appearance_verified'])
        self.assertGreaterEqual(facts['distinct_rgb_capped_at_256'], 16)
        self.assertGreaterEqual(facts['quantized_color_count'], 8)
        json.dumps(facts)


class OrchestrationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.path = Path(self.tmp.name) / 'frame.png'
        self.adapter = Adapter()
        self.process = SimpleNamespace(pid=123, process=111, thread=222)
        self.native = SyntheticScreen(self.adapter)

    def run_capture(self):
        return capture._capture_with_backend(self.adapter, self.process, self.path,
                                              capture.DEFAULT_TITLE, (48, 48), self.native)

    def assert_no_output(self, mutation):
        mutation()
        with self.assertRaises(capture.CaptureError):
            self.run_capture()
        self.assertFalse(self.path.exists())

    def test_success_is_json_safe_and_one_capture(self):
        receipt = self.run_capture()
        json.dumps(receipt)
        self.assertEqual(set(receipt['stage_seconds']), {'native_guards_and_readback', 'pixel_diagnostics', 'png_encoding', 'png_write_fsync'})
        self.assertTrue(all(type(v) is float and v >= 0 for v in receipt['stage_seconds'].values()))
        self.assertTrue(self.path.read_bytes().startswith(capture.PNG_SIGNATURE))
        self.assertEqual(receipt['png_bytes'], self.path.stat().st_size)
        self.assertEqual(self.native.counters['bitblt'], 1)
        self.assertEqual(self.native.desktops, 3)
        self.assertEqual(self.native.exposed_flags, [False, True, True])
        self.assertTrue(self.native.cleaned)
        self.assertEqual(receipt['checkpoints'], ['immediately_before_bitblt',
                                                  'immediately_after_bitblt'])

    def test_exited_retained_handle_stops_before_native_scope(self):
        self.assert_no_output(lambda: setattr(self.adapter, 'dead', True))
        self.assertEqual(self.native.desktops, 0)
        self.assertEqual(self.native.counters['bitblt'], 0)

    def test_changed_native_pid_birth_or_image_stops_before_activation(self):
        for key, value in (('pid', 999), ('creation_filetime', 333), ('image', r'C:\other.exe')):
            with self.subTest(key=key):
                self.native.actual_identity = dict(self.adapter.binding, **{key: value})
                with self.assertRaises(capture.CaptureError):
                    self.run_capture()
                self.assertEqual(self.native.counters['activation_attempts'], 0)
                self.assertFalse(self.path.exists())

    def test_input_desktop_denial_is_not_retried(self):
        self.assert_no_output(lambda: setattr(self.native, 'desktop_error', True))
        self.assertEqual(self.native.desktops, 1)
        self.assertEqual(self.native.counters['bitblt'], 0)
        self.assertTrue(self.native.cleaned)

    def test_extra_owned_window_stops_without_activation(self):
        self.assert_no_output(lambda: setattr(self.native, 'selection_error', True))
        self.assertEqual(self.native.counters['activation_attempts'], 0)

    def test_foreground_or_hit_guard_failure_stops_before_pixels(self):
        self.assert_no_output(lambda: setattr(self.native, 'foreground_error', True))
        self.assertEqual(self.native.counters['bitblt'], 0)

    def test_exit_between_pixel_copy_and_post_guard_discards_pixels(self):
        self.assert_no_output(lambda: setattr(self.native, 'post_capture',
                                               lambda: setattr(self.adapter, 'dead', True)))
        self.assertEqual(self.native.counters['bitblt'], 1)
        self.assertTrue(self.native.cleaned)

    def test_binding_change_after_copy_discards_pixels(self):
        self.assert_no_output(lambda: setattr(self.native, 'post_capture',
                                               lambda: self.adapter.binding.update(pid=124)))
        self.assertTrue(self.native.cleaned)

    def test_geometry_change_after_copy_discards_pixels(self):
        self.assert_no_output(lambda: setattr(self.native, 'post_capture',
                                               lambda: setattr(self.native, 'rectangle', [31, 40, 79, 88])))
        self.assertEqual(self.native.counters['bitblt'], 1)

    def test_cleanup_failure_prevents_artifact(self):
        self.assert_no_output(lambda: setattr(self.native, 'cleanup_error', True))
        self.assertEqual(self.native.counters['bitblt'], 1)

    def test_blank_pixels_prevent_artifact(self):
        self.assert_no_output(lambda: setattr(self.native, 'result', bytes(48 * 48 * 3)))
        self.assertTrue(self.native.cleaned)

    def test_missing_post_capture_guard_cannot_produce_receipt(self):
        def broken_capture(rect, before, after):
            before()
            return gradient()
        self.assert_no_output(lambda: setattr(self.native, 'capture_rgb', broken_capture))

    def test_prior_output_never_overwritten(self):
        self.path.write_bytes(b'prior artifact')
        with self.assertRaises(capture.CaptureError):
            self.run_capture()
        self.assertEqual(self.path.read_bytes(), b'prior artifact')
        self.assertEqual(self.native.desktops, 0)

    def test_public_function_has_no_linux_fallback(self):
        with patch.object(capture.os, 'name', 'posix'):
            with self.assertRaises(capture.CaptureError):
                capture.capture_owned(self.adapter, self.process, self.path)
        self.assertFalse(self.path.exists())

    def test_import_does_not_load_windows_libraries(self):
        with patch.object(capture.c, 'WinDLL', create=True, side_effect=AssertionError('native load')):
            fresh = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(fresh)


class NativeGuardInjectionTests(unittest.TestCase):
    """Exercise selected native guard logic with mocked APIs, never call Win32."""
    def setUp(self):
        self.backend = object.__new__(capture._WindowsScreen)
        self.backend.user = object()
        self.backend.counters = dict(activation_attempts=0)
        self.backend._call = Mock()
        self.backend._owner = Mock(return_value=(123, 124))

    def test_no_foreign_window_title_is_read(self):
        self.backend._owner.return_value = (999, 124)
        with self.assertRaises(capture.CaptureError):
            self.backend._owned_title(567, 123, capture.DEFAULT_TITLE)
        self.backend._call.assert_not_called()

    def test_title_read_owner_race_is_rejected(self):
        self.backend._owner.side_effect = [(123, 124), (999, 124)]
        def exact_title(lib, name, hwnd, buffer, length):
            self.assertEqual(name, 'GetWindowTextW')
            buffer.value = capture.DEFAULT_TITLE
            return len(capture.DEFAULT_TITLE)
        self.backend._call.side_effect = exact_title
        with self.assertRaises(capture.CaptureError):
            self.backend._owned_title(567, 123, capture.DEFAULT_TITLE)

    def test_mismatch_does_not_disclose_actual_title(self):
        secret = 'Unrelated private prompt title'
        def wrong_title(lib, name, hwnd, buffer, length):
            buffer.value = secret
            return len(secret)
        self.backend._call.side_effect = wrong_title
        with self.assertRaises(capture.CaptureError) as caught:
            self.backend._owned_title(567, 123, capture.DEFAULT_TITLE)
        self.assertNotIn(secret, str(caught.exception))

    def test_foreground_denial_only_attempted_once(self):
        self.backend._owned_title = Mock()
        names = []
        def response(lib, name, *args, **kwargs):
            names.append(name)
            return {'IsWindowEnabled': 1, 'IsWindowVisible': 1, 'IsIconic': 0,
                    'GetForegroundWindow': 999, 'SetForegroundWindow': 0}[name]
        self.backend._call.side_effect = response
        with patch.object(capture.c, 'get_last_error', return_value=5, create=True):
            with self.assertRaises(capture.CaptureError):
                self.backend.activate_owned(567, 123, capture.DEFAULT_TITLE)
        self.assertEqual(names.count('SetForegroundWindow'), 1)
        self.assertEqual(self.backend.counters['activation_attempts'], 1)
        self.assertNotIn('SendInput', names)

    def test_existing_foreground_needs_no_activation_call(self):
        self.backend._owned_title = Mock()
        self.backend._call.side_effect = lambda lib, name, *args: {
            'IsWindowEnabled': 1, 'IsWindowVisible': 1, 'IsIconic': 0,
            'GetForegroundWindow': 567}[name]
        result = self.backend.activate_owned(567, 123, capture.DEFAULT_TITLE)
        self.assertFalse(result['requested'])
        self.assertEqual(result['attempts'], 0)


class NativeCaptureInjectionTests(unittest.TestCase):
    def setUp(self):
        self.backend = object.__new__(capture._WindowsScreen)
        self.backend.user, self.backend.gdi = object(), object()
        self.backend.counters = dict(bitblt=0)
        self.calls = []
        self.selection_calls = 0
        self.restore_failure = False
        rgb = gradient()
        bgra = bytearray(48 * 48 * 4)
        bgra[0::4], bgra[1::4], bgra[2::4] = rgb[2::3], rgb[1::3], rgb[0::3]
        self.storage = capture.c.create_string_buffer(bytes(bgra))
        self.backend._call = self.api

    def api(self, library, name, *args, **kwargs):
        self.calls.append((name, args, kwargs))
        if name == 'GetDC':
            self.assertEqual(args, (None,))
            return 10
        if name == 'CreateCompatibleDC':
            return 20
        if name == 'CreateDIBSection':
            info = capture.c.cast(args[1], capture.c.POINTER(capture._BITMAPINFO)).contents
            self.assertEqual((info.header.width, info.header.height, info.header.bits), (48, -48, 32))
            capture.c.cast(args[3], capture.c.POINTER(capture.c.c_void_p)).contents.value = capture.c.addressof(self.storage)
            return 30
        if name == 'SelectObject':
            self.selection_calls += 1
            return 40 if self.selection_calls == 1 else (0 if self.restore_failure else 30)
        return 1

    def test_one_bitblt_exact_crop_and_bgra_conversion(self):
        phases = []
        rgb = self.backend.capture_rgb([30, 40, 78, 88], lambda: phases.append('before'),
                                        lambda: phases.append('after'))
        self.assertEqual(rgb, gradient())
        self.assertEqual(phases, ['before', 'after'])
        blits = [args for name, args, _ in self.calls if name == 'BitBlt']
        self.assertEqual(blits, [(20, 0, 0, 48, 48, 10, 30, 40, 0x00CC0020)])
        self.assertEqual(self.backend.counters['bitblt'], 1)
        self.assertEqual([name for name, _, _ in self.calls][-4:],
                         ['SelectObject', 'DeleteObject', 'DeleteDC', 'ReleaseDC'])
        self.assertNotIn('PrintWindow', [name for name, _, _ in self.calls])

    def test_pre_guard_failure_never_blits_and_disposes_owned_objects(self):
        def denied():
            raise capture.CaptureError('Synthetic pre-capture denial')
        with self.assertRaises(capture.CaptureError):
            self.backend.capture_rgb([30, 40, 78, 88], denied, lambda: None)
        self.assertEqual(self.backend.counters['bitblt'], 0)
        self.assertEqual([name for name, _, _ in self.calls][-4:],
                         ['SelectObject', 'DeleteObject', 'DeleteDC', 'ReleaseDC'])

    def test_failed_deselection_deletes_dc_before_bitmap_without_retry(self):
        self.restore_failure = True
        with self.assertRaises(capture.CaptureError):
            self.backend.capture_rgb([30, 40, 78, 88], lambda: None, lambda: None)
        names = [name for name, _, _ in self.calls]
        self.assertEqual(names[-4:], ['SelectObject', 'DeleteDC', 'DeleteObject', 'ReleaseDC'])
        self.assertEqual(names.count('DeleteObject'), 1)
        self.assertEqual(names.count('DeleteDC'), 1)


class NativeDesktopInjectionTests(unittest.TestCase):
    def setUp(self):
        self.backend = object.__new__(capture._WindowsScreen)
        self.backend.user, self.backend.kernel, self.backend.wts = object(), object(), object()
        self.backend.counters = dict(input_desktop_opens=0)
        self.calls = []
        self.denied = False
        self.session_state = capture.c.c_uint32(0)
        self.backend._object_name = lambda handle: {11: 'WinSta0', 22: 'Default', 33: 'Default'}[handle]
        self.backend._call = self.api

    def api(self, library, name, *args, **kwargs):
        self.calls.append((name, args))
        if name == 'GetCurrentProcessId':
            return 999
        if name == 'ProcessIdToSessionId':
            capture.c.cast(args[1], capture.c.POINTER(capture.c.c_uint32)).contents.value = 2
            return 1
        if name == 'WTSQuerySessionInformationW':
            self.assertEqual(args[:3], (None, 2, 8))
            capture.c.cast(args[3], capture.c.POINTER(capture.c.c_void_p)).contents.value = capture.c.addressof(self.session_state)
            capture.c.cast(args[4], capture.c.POINTER(capture.c.c_uint32)).contents.value = 4
            return 1
        if name == 'GetProcessWindowStation':
            return 11
        if name == 'GetCurrentThreadId':
            return 1001
        if name == 'GetThreadDesktop':
            return 22
        if name == 'OpenInputDesktop':
            self.assertEqual(args, (0, False, 1))
            return 0 if self.denied else 33
        if name == 'CloseDesktop':
            self.assertEqual(args, (33,))
        return 1

    def test_readobjects_only_and_only_owned_desktop_closed(self):
        result = self.backend.desktop(SimpleNamespace(pid=123))
        self.assertEqual(result['input_desktop_access'], 'DESKTOP_READOBJECTS')
        self.assertEqual(result['session_id'], 2)
        names = [name for name, _ in self.calls]
        self.assertEqual(names.count('OpenInputDesktop'), 1)
        self.assertEqual(names.count('CloseDesktop'), 1)
        self.assertNotIn('CloseHandle', names)
        self.assertNotIn('SwitchDesktop', names)

    def test_denied_input_desktop_stops_with_no_retry_or_close(self):
        self.denied = True
        with patch.object(capture.c, 'get_last_error', return_value=5, create=True):
            with self.assertRaises(capture.CaptureError):
                self.backend.desktop(SimpleNamespace(pid=123))
        names = [name for name, _ in self.calls]
        self.assertEqual(names.count('OpenInputDesktop'), 1)
        self.assertNotIn('CloseDesktop', names)
        self.assertNotIn('SwitchDesktop', names)

    def test_disconnected_session_stops_before_desktop_open(self):
        self.session_state.value = 4
        with self.assertRaises(capture.CaptureError):
            self.backend.desktop(SimpleNamespace(pid=123))
        self.assertNotIn('OpenInputDesktop', [name for name, _ in self.calls])


if __name__ == '__main__':
    unittest.main()
