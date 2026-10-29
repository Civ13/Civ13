"""1688 migration controls: files, synthetic pixels and injected Win32 only."""
import hashlib
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch
from PIL import Image
import run


class Migration(unittest.TestCase):
    def test_exact_reference_pins_and_fresh_local_hold(self):
        vendor = json.loads((run.ROOT / 'vendor.json').read_text())
        self.assertEqual(vendor['version'], '516.1688')
        self.assertEqual(vendor['bytes'], 8602470)
        self.assertEqual(vendor['sha256'], '9079f29b0747719233715dfeff223641e6fb69bd16b8ba9676d5cd42cfcd0148')
        self.assertEqual(vendor['binaries']['dreamseeker.exe'], 'dde2893d7d6721eb8cb73d9e6b9f8cb28d86d1e432b42edaad10b066800a97e4')
        self.assertEqual(vendor['provenance']['reference_runs'], [40223669267, 40228533562])
        self.assertIsNone(run.INSTALLED_MANIFEST_SHA256)
        self.assertIsNone(run.INSTALLED_MANIFEST_SHAPE)
        self.assertEqual(run.LOCAL_RUNTIME_DLLS, ('mfc140u.dll', 'msvcp140.dll', 'vcruntime140.dll'))

    def test_guest_and_viewport_are_native_and_exact(self):
        fixture = (run.ROOT / 'fixture.dm').read_text()
        for anchor in ('byond_version != 516 || byond_build != 1688',
                       'copytext(key, 1, 7) == "Guest-"', 'address != "127.0.0.1"',
                       'eye = mob', 'perspective = MOB_PERSPECTIVE', 'view = 3'):
            self.assertIn(anchor, fixture)
        dmf = (run.ROOT / 'fixture.dmf').read_text()
        for anchor in ('statusbar = false', 'zoom = 1', 'zoom-mode = normal', 'size = 224x224'):
            self.assertIn(anchor, dmf)

    def test_exact_pixels_reject_count_preserving_damage_and_transparency(self):
        image = Image.new('RGB', (224, 224), 'red')
        image.paste((0, 255, 0), (96, 96, 128, 128))
        self.assertTrue(run.pixel_contract(image, 'red'))
        image.putpixel((0, 0), (0, 255, 0))
        image.putpixel((96, 96), (255, 0, 0))
        self.assertFalse(run.pixel_contract(image, 'red'))
        self.assertFalse(run.pixel_contract(image.resize((448, 448)), 'red'))
        self.assertFalse(run.pixel_contract(image, 'unknown'))
        transparent = Image.new('RGBA', (224, 224), (255, 0, 0, 0))
        transparent.paste((0, 255, 0, 0), (96, 96, 128, 128))
        self.assertFalse(run.pixel_contract(transparent, 'red'))

    def test_directx_reads_exact_system_files_without_install_or_fallback(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary); system = root / 'SysWOW64'; system.mkdir()
            pins = {}
            for name in run.DIRECTX:
                data = name.encode(); (system / name).write_bytes(data)
                pins[name] = (len(data), hashlib.sha256(data).hexdigest())
            with patch.object(run, 'windows_directory', return_value=root), \
                    patch.object(run, 'DIRECTX', pins), \
                    patch.object(run.subprocess, 'Popen', side_effect=AssertionError('native forbidden')):
                self.assertEqual(set(run.graphics_prerequisites()), set(pins))
                target = system / next(iter(pins)); target.write_bytes(b'changed')
                with self.assertRaisesRegex(RuntimeError, 'missing or changed'):
                    run.graphics_prerequisites()
                target.unlink()
                with self.assertRaisesRegex(RuntimeError, 'missing or changed'):
                    run.graphics_prerequisites()

    def test_acquisition_redirect_is_rejected_before_archive_write(self):
        response = Mock(url='https://unexpected.invalid/vendor.zip')
        opener = Mock()
        opener.open.return_value.__enter__ = Mock(return_value=response)
        opener.open.return_value.__exit__ = Mock(return_value=False)
        with tempfile.TemporaryDirectory() as temporary, \
                patch.object(run.urllib.request, 'build_opener', return_value=opener) as factory:
            with self.assertRaisesRegex(RuntimeError, 'redirect'):
                run.install(Path(temporary))
            self.assertEqual(list(Path(temporary).iterdir()), [])
            handler = factory.call_args.args[0]
            with self.assertRaisesRegex(RuntimeError, 'redirect'):
                handler.redirect_request(None, None, None, None, None, None)


class OwnedCapture(unittest.TestCase):
    def setUp(self):
        self.u = Mock()
        self.u.EnumWindows.side_effect = lambda visit, _: visit(1, 0)
        self.u.GetWindowThreadProcessId.side_effect = lambda _, p: setattr(p._obj, 'value', 42)
        self.u.IsWindowVisible.return_value = True
        self.u.IsIconic.return_value = False
        self.u.GetWindowTextLengthW.return_value = 30
        self.u.GetWindowTextW.side_effect = lambda _, b, n: setattr(b, 'value', 'Civ13 DreamSeeker smoke')
        self.u.GetForegroundWindow.return_value = 1
        self.u.GetDpiForWindow.return_value = 96
        def rectangle(_, r):
            r._obj.right = r._obj.bottom = 224
            return 1
        self.u.GetClientRect.side_effect = rectangle
        self.u.ClientToScreen.side_effect = lambda _, p: (setattr(p._obj, 'x', 80) or setattr(p._obj, 'y', 80) or 1)
        self.u.GetSystemMetrics.side_effect = {76: 0, 77: 0, 78: 1920, 79: 1080}.get
        self.u.WindowFromPoint.return_value = 2
        self.u.GetAncestor.return_value = 1
        self.adapter = Mock()
        self.adapter.exited.return_value = False
        self.adapter.identity.return_value = dict(pid=42, creation_filetime=123, image='owned.exe')
        self.process = SimpleNamespace(pid=42)
        self.enterContext(patch.object(run.c, 'WinDLL', return_value=self.u, create=True))
        self.enterContext(patch.object(run.c, 'WINFUNCTYPE', side_effect=lambda *args: lambda f: f, create=True))
        self.grab = self.enterContext(patch.object(run.ImageGrab, 'grab', return_value=Image.new('RGB', (224, 224))))

    def test_exact_owned_rectangle_and_identity_are_rechecked(self):
        self.assertEqual(run.desktop_capture(self.adapter, self.process).size, (224, 224))
        self.grab.assert_called_once_with((80, 80, 304, 304))
        self.assertEqual(self.adapter.identity.call_count, 2)
        self.assertEqual(self.u.WindowFromPoint.call_count, 162)

    def test_obscured_or_scaled_window_never_captures(self):
        self.u.GetAncestor.return_value = 9
        with self.assertRaisesRegex(RuntimeError, 'obscured'):
            run.desktop_capture(self.adapter, self.process)
        self.grab.assert_not_called()
        self.u.GetAncestor.return_value = 1
        self.u.GetDpiForWindow.return_value = 144
        with self.assertRaisesRegex(RuntimeError, '96DPI'):
            run.desktop_capture(self.adapter, self.process)
        self.grab.assert_not_called()

    def test_wrong_retained_identity_never_captures(self):
        self.adapter.identity.return_value = dict(pid=43, creation_filetime=123, image='other.exe')
        with self.assertRaisesRegex(RuntimeError, 'identity mismatch'):
            run.desktop_capture(self.adapter, self.process)
        self.grab.assert_not_called()

    def test_exit_during_capture_rejects_pixels(self):
        self.adapter.exited.side_effect = (False, True)
        with self.assertRaisesRegex(RuntimeError, 'changed during capture'):
            run.desktop_capture(self.adapter, self.process)

    def test_offscreen_and_minimized_window_never_capture(self):
        self.u.IsIconic.return_value = True
        with self.assertRaisesRegex(RuntimeError, 'visible foreground'):
            run.desktop_capture(self.adapter, self.process)
        self.u.IsIconic.return_value = False
        self.u.GetSystemMetrics.side_effect = {76: 0, 77: 0, 78: 200, 79: 200}.get
        with self.assertRaisesRegex(RuntimeError, 'offscreen'):
            run.desktop_capture(self.adapter, self.process)
        self.grab.assert_not_called()

    def test_post_capture_window_change_rejects_pixels(self):
        def changed(_):
            self.u.GetForegroundWindow.return_value = 2
            return Image.new('RGB', (224, 224))
        self.grab.side_effect = changed
        with self.assertRaisesRegex(RuntimeError, 'foreground'):
            run.desktop_capture(self.adapter, self.process)
