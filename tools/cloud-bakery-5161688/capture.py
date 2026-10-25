"""Fail-closed, one-shot actual-screen capture of the retained DreamSeeker.

This module is source-only until separately admitted on the disposable Windows
runner. Importing it is safe on Linux: WinDLL and Windows APIs are deferred.
The production entry point has no injected backend and no permissive fallback.

The caller owns the already admitted process/Job and the scene-ready deadline.
This function neither launches nor closes the process/window, changes desktops,
handles prompts, sends input, resizes windows, nor retries denied operations.
Its sole screenshot primitive is a bounded screen-DC BitBlt of the verified
client rectangle. The temporary compatible DC/DIB only receives those pixels;
it is not a substitute/offscreen application rendering path.

Guard samples cannot atomically exclude a transient overlay between API calls.
Pixel diversity is a blank-frame heuristic, NOT proof of bakery appearance,
correct Civ13 assets, or equivalence to any reference image. Human inspection
of the resulting actual capture remains necessary.
"""
from collections import Counter
from contextlib import contextmanager
import ctypes as c
import hashlib
import ntpath
import os
from pathlib import Path
import struct
import time
import zlib


MAX_DIMENSION = 1024
MAX_PIXELS = 1024 * 1024
MAX_ENUM_WINDOWS = 512
MAX_NATIVE_CALLS = 8192
MAX_SECONDS = 15.0
HIT_GRID = 9
DEFAULT_TITLE = 'Civ13 native bakery cloud'
PNG_SIGNATURE = b'\x89PNG\r\n\x1a\n'


class CaptureError(RuntimeError):
    """No acceptable capture was produced; do not retry a denied operation."""


class PixelHeuristicFailure(CaptureError):
    """Pixel acceptance failed; diagnostic evidence is never a successful frame."""
    def __init__(self, facts):
        super().__init__('Captured RGB failed nonblank/diversity heuristics')
        self.facts = facts
        self.diagnostic = None


class OwnedRectangleMismatch(CaptureError):
    """Bounded numeric metadata only; same rejection, never pixels or titles."""
    def __init__(self, hwnd, pid, tid, actual, expected):
        super().__init__('Owned client must match the exact map-only dimensions')
        self.evidence = None
        if type(actual) not in (tuple, list) or type(expected) not in (tuple, list):
            return
        values = (hwnd, pid, tid, *actual, *expected)
        if (len(actual) != 4 or len(expected) != 4 or
                any(type(n) is not int for n in values) or
                not 0 < hwnd < 2**64 or not 0 < pid < 2**32 or
                not 0 < tid < 2**32 or
                any(not -2**31 <= n < 2**31 for n in (*actual, *expected))):
            return
        self.evidence = dict(schema=1, hwnd=hwnd, pid=pid, thread_id=tid,
                             actual_client_rect=list(actual), expected_client_rect=list(expected),
                             capture_thread_dpi_context='PER_MONITOR_AWARE_V2',
                             process_identity_revalidated=False)


def _size(size):
    if (not isinstance(size, (tuple, list)) or len(size) != 2
            or any(type(n) is not int or n < 1 or n > MAX_DIMENSION for n in size)
            or size[0] * size[1] > MAX_PIXELS):
        raise CaptureError('Expected dimensions exceed the capture bounds')
    return tuple(size)


def _rgb_bytes(rgb, width, height):
    _size((width, height))
    if not isinstance(rgb, bytes) or len(rgb) != width * height * 3:
        raise CaptureError('RGB byte count does not match bounded dimensions')


def pixel_diagnostics(rgb, width, height):
    """Reject blank/nearly blank buffers; return explicitly non-semantic facts."""
    _rgb_bytes(rgb, width, height)
    bins = Counter()
    distinct = set()
    lowest, highest, middle, changes = 255, 0, 0, 0
    previous = None
    nonzero = 0
    for offset in range(0, len(rgb), 3):
        color = rgb[offset:offset + 3]
        red, green, blue = color
        nonzero += int(bool(red or green or blue))
        if len(distinct) < 256:
            distinct.add(color)
        bucket = (red >> 4, green >> 4, blue >> 4)
        bins[bucket] += 1
        lowest = min(lowest, red, green, blue)
        highest = max(highest, red, green, blue)
        if max(color) > 24 and min(color) < 232:
            middle += 1
        if previous is not None and bucket != previous:
            changes += 1
        previous = bucket
    total = width * height
    dominant = max(bins.values()) / total
    facts = dict(pixel_count=total, nonzero_pixel_count=nonzero,
                 channel_min=lowest, channel_max=highest, entirely_black=(nonzero == 0),
                 flat_rgb=(len(distinct) == 1), distinct_rgb_capped_at_256=len(distinct),
                 quantized_color_count=len(bins), channel_range=highest - lowest,
                 middle_pixel_fraction=round(middle / total, 6),
                 dominant_quantized_fraction=round(dominant, 6),
                 adjacent_quantized_changes=changes,
                 semantic_appearance_verified=False)
    if (len(distinct) < 16 or len(bins) < 8 or highest - lowest < 32
            or middle < max(16, total // 100) or dominant > 0.98
            or changes < max(8, total // 200)):
        raise PixelHeuristicFailure(facts)
    return facts


def encode_png(rgb, width, height):
    """Encode already validated RGB bytes as a standards-conformant RGB8 PNG."""
    _rgb_bytes(rgb, width, height)

    def chunk(kind, data):
        return (struct.pack('>I', len(data)) + kind + data
                + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff))

    stride = width * 3
    rows = b''.join(b'\0' + rgb[y * stride:(y + 1) * stride]
                    for y in range(height))
    header = struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)
    return PNG_SIGNATURE + chunk(b'IHDR', header) + chunk(
        b'IDAT', zlib.compress(rows, level=6)) + chunk(b'IEND', b'')


def _bound_identity(adapter, process):
    if adapter.exited(process):
        raise CaptureError('Retained DreamSeeker process has exited')
    identity = dict(adapter.identity(process))
    if (type(identity.get('pid')) is not int or identity['pid'] <= 0
            or type(identity.get('creation_filetime')) is not int
            or identity['creation_filetime'] <= 0
            or not isinstance(identity.get('image'), str) or not identity['image']):
        raise CaptureError('Retained process identity is incomplete')
    return identity


def _assert_live(adapter, process, baseline, native):
    if _bound_identity(adapter, process) != baseline:
        raise CaptureError('Retained process identity changed')
    actual = native.live_identity(process)
    if (actual['pid'] != baseline['pid']
            or actual['creation_filetime'] != baseline['creation_filetime']
            or ntpath.normcase(ntpath.normpath(actual['image']))
            != ntpath.normcase(ntpath.normpath(baseline['image']))):
        raise CaptureError('Native retained-handle identity differs from admission')
    if adapter.exited(process):
        raise CaptureError('Retained DreamSeeker exited during identity validation')


def _write_new(destination, data):
    """Never overwrite a prior artifact, and remove only our incomplete output."""
    created = False
    try:
        with destination.open('xb') as stream:
            created = True
            if stream.write(data) != len(data):
                raise CaptureError('PNG write was incomplete')
            stream.flush()
            os.fsync(stream.fileno())
    except BaseException:
        if created:
            destination.unlink(missing_ok=True)
        raise


def _capture_with_backend(adapter, process, destination, title, expected_size, native):
    """Private orchestration seam for synthetic tests, not native acceptance."""
    timing_start = time.monotonic()
    width, height = _size(expected_size)
    if not isinstance(title, str) or not title or len(title) > 200 or '\0' in title:
        raise CaptureError('A bounded exact expected title is required')
    destination = Path(destination)
    if destination.suffix.lower() != '.png' or not destination.parent.is_dir():
        raise CaptureError('A PNG destination in an existing directory is required')
    if destination.exists() or destination.is_symlink():
        raise CaptureError('Capture output already exists')
    baseline = _bound_identity(adapter, process)
    checkpoints = []
    with native.scope():
        _assert_live(adapter, process, baseline, native)
        desktop = native.desktop(process)
        hwnd = native.select_owned(baseline['pid'], title)
        try:
            initial = native.window_snapshot(hwnd, baseline['pid'], title,
                                             (width, height), require_exposed=False)
        except OwnedRectangleMismatch as error:
            # Do not retain metadata if the admitted process identity went stale.
            _assert_live(adapter, process, baseline, native)
            if not 0 < baseline['creation_filetime'] < 2**64:
                error.evidence = None
            if error.evidence is not None:
                error.evidence['creation_filetime'] = baseline['creation_filetime']
                error.evidence['process_identity_revalidated'] = True
            raise
        _assert_live(adapter, process, baseline, native)
        activation = native.activate_owned(hwnd, baseline['pid'], title)

        def checkpoint(phase):
            _assert_live(adapter, process, baseline, native)
            if native.desktop(process) != desktop:
                raise CaptureError('Interactive desktop/session changed during capture')
            if native.select_owned(baseline['pid'], title) != hwnd:
                raise CaptureError('Owned visible HWND changed during capture')
            observed = native.window_snapshot(hwnd, baseline['pid'], title,
                                               (width, height), require_exposed=True)
            if observed != initial:
                raise CaptureError('Owned HWND identity or geometry changed during capture')
            # Check liveness once more after the sampled window observations.
            _assert_live(adapter, process, baseline, native)
            checkpoints.append(phase)

        rgb = native.capture_rgb(initial['screen_rect'],
                                 lambda: checkpoint('immediately_before_bitblt'),
                                 lambda: checkpoint('immediately_after_bitblt'))
        if checkpoints != ['immediately_before_bitblt', 'immediately_after_bitblt']:
            raise CaptureError('Capture did not execute both ownership checkpoints')
        # This final read occurs after GDI disposal but before DPI restoration.
        _assert_live(adapter, process, baseline, native)
    timing_native_done = time.monotonic()
    # Nothing is written until all native guards AND native cleanup succeeded.
    try:
        diagnostics = pixel_diagnostics(rgb, width, height)
    except PixelHeuristicFailure as error:
        # Reuse only these already-admitted pixels; no recapture or acceptance.
        if (width, height) == (480, 480) and destination.name in ('bakery-before.png', 'bakery-after.png'):
            failed = destination.with_name(destination.stem + '.failed-diagnostic.png')
            png = encode_png(rgb, width, height)
            if len(png) > 1048576:
                raise CaptureError('Failed diagnostic PNG exceeds artifact bound')
            _write_new(failed, png)
            error.diagnostic = dict(status='FAILED_HEURISTIC_DIAGNOSTIC_ONLY', accepted=False,
                filename=failed.name, width=width, height=height, png_bytes=len(png),
                png_sha256=hashlib.sha256(png).hexdigest(), pixel_facts=error.facts,
                pid=baseline['pid'], creation_filetime=baseline['creation_filetime'],
                client_rect=initial['client_rect'], checkpoints=list(checkpoints),
                cleanup='owned GDI/input handles released; thread DPI restored',
                semantic_appearance_verified=False)
        raise
    timing_pixels_done = time.monotonic()
    png = encode_png(rgb, width, height)
    timing_png_done = time.monotonic()
    _write_new(destination, png)
    timing_write_done = time.monotonic()
    return dict(status='captured', method='screen_dc_bitblt_owned_client_rectangle',
                destination=str(destination), width=width, height=height,
                png_bytes=len(png), png_sha256=hashlib.sha256(png).hexdigest(),
                identity=baseline, window=initial, desktop=desktop,
                activation=activation, checkpoints=checkpoints,
                hit_test_grid=[HIT_GRID, HIT_GRID], pixel_diagnostics=diagnostics,
                stage_seconds=dict(native_guards_and_readback=round(timing_native_done-timing_start,6),
                    pixel_diagnostics=round(timing_pixels_done-timing_native_done,6),
                    png_encoding=round(timing_png_done-timing_pixels_done,6),
                    png_write_fsync=round(timing_write_done-timing_png_done,6)),
                native_counters=dict(native.counters),
                limitations=['Sampled guards are not an atomic desktop lock.',
                             'Pixel heuristics do not prove semantic scene appearance.'],
                cleanup='owned GDI/input handles released; thread DPI restored')


def capture_owned(adapter, process, destination, title=DEFAULT_TITLE,
                  expected_size=(480, 480)):
    """Capture only the live, retained, exactly titled owned map client window.

    Raises CaptureError/OSError on failure. The caller must report a denial and
    stop rather than escalating, changing desktops, injecting input, or trying
    another screenshot path. A receipt is JSON-safe and never lists other
    windows' titles. Successful production invocation means actual screen
    pixels passed these guards, not that a native trial has been done beforehand.
    """
    if os.name != 'nt':
        raise CaptureError('Actual-screen capture is Windows-only; no fallback')
    return _capture_with_backend(adapter, process, destination, title,
                                 expected_size, _WindowsScreen())


class _POINT(c.Structure):
    _fields_ = [('x', c.c_int32), ('y', c.c_int32)]


class _RECT(c.Structure):
    _fields_ = [(name, c.c_int32) for name in ('left', 'top', 'right', 'bottom')]


class _BITMAPINFOHEADER(c.Structure):
    _fields_ = [('size', c.c_uint32), ('width', c.c_int32), ('height', c.c_int32),
                ('planes', c.c_uint16), ('bits', c.c_uint16),
                ('compression', c.c_uint32), ('image_size', c.c_uint32),
                ('xppm', c.c_int32), ('yppm', c.c_int32),
                ('colors_used', c.c_uint32), ('important_colors', c.c_uint32)]


class _BITMAPINFO(c.Structure):
    _fields_ = [('header', _BITMAPINFOHEADER), ('unused_color', c.c_uint32)]


class _WindowsScreen:
    """All native imports, handle creation, and screen access live here."""

    def __init__(self):
        if os.name != 'nt':
            raise CaptureError('Windows native backend unavailable')
        self.user = c.WinDLL('user32', use_last_error=True)
        self.gdi = c.WinDLL('gdi32', use_last_error=True)
        self.kernel = c.WinDLL('kernel32', use_last_error=True)
        self.wts = c.WinDLL('wtsapi32', use_last_error=True)
        H, D, B, I, P = c.c_void_p, c.c_uint32, c.c_int32, c.c_int32, c.POINTER
        self.callback_type = c.WINFUNCTYPE(B, H, c.c_ssize_t)
        signatures = {
            self.user: {
                'SetThreadDpiAwarenessContext': ([H], H),
                'GetThreadDpiAwarenessContext': ([], H),
                'AreDpiAwarenessContextsEqual': ([H, H], B),
                'OpenInputDesktop': ([D, B, D], H), 'CloseDesktop': ([H], B),
                'GetThreadDesktop': ([D], H), 'GetProcessWindowStation': ([], H),
                'GetUserObjectInformationW': ([H, I, H, D, P(D)], B),
                'EnumWindows': ([self.callback_type, c.c_ssize_t], B),
                'GetWindowThreadProcessId': ([H, P(D)], D),
                'IsWindow': ([H], B), 'IsWindowVisible': ([H], B),
                'IsWindowEnabled': ([H], B), 'IsIconic': ([H], B),
                'GetWindowTextW': ([H, c.c_wchar_p, I], I),
                'GetAncestor': ([H, D], H), 'GetWindow': ([H, D], H),
                'GetClientRect': ([H, P(_RECT)], B),
                'GetWindowRect': ([H, P(_RECT)], B),
                'ClientToScreen': ([H, P(_POINT)], B),
                'GetSystemMetrics': ([I], I),
                'GetForegroundWindow': ([], H), 'SetForegroundWindow': ([H], B),
                'WindowFromPoint': ([_POINT], H),
                'GetDC': ([H], H), 'ReleaseDC': ([H, H], I)},
            self.kernel: {
                'GetCurrentThreadId': ([], D), 'GetCurrentProcessId': ([], D),
                'GetProcessId': ([H], D), 'ProcessIdToSessionId': ([D, P(D)], B),
                'GetProcessTimes': ([H] + [P(c.c_uint64)] * 4, B),
                'QueryFullProcessImageNameW': ([H, D, c.c_wchar_p, P(D)], B)},
            self.gdi: {
                'CreateCompatibleDC': ([H], H), 'DeleteDC': ([H], B),
                'CreateDIBSection': ([H, P(_BITMAPINFO), D, P(H), H, D], H),
                'SelectObject': ([H, H], H), 'DeleteObject': ([H], B),
                'BitBlt': ([H, I, I, I, I, H, I, I, D], B),
                'GdiFlush': ([], B)},
            self.wts: {
                'WTSQuerySessionInformationW': ([H, D, I, P(H), P(D)], B),
                'WTSFreeMemory': ([H], None)}}
        for library, methods in signatures.items():
            for name, (args, result) in methods.items():
                function = getattr(library, name)
                function.argtypes, function.restype = args, result
        self.started = time.monotonic()
        self.counters = dict(native_calls=0, bitblt=0, activation_attempts=0,
                             input_desktop_opens=0, hit_samples=0)

    def _call(self, library, name, *args, cleanup=False):
        if not cleanup:
            if (self.counters['native_calls'] >= MAX_NATIVE_CALLS
                    or time.monotonic() - self.started > MAX_SECONDS):
                raise CaptureError('Capture operation/time budget exceeded')
        self.counters['native_calls'] += 1
        return getattr(library, name)(*args)

    @staticmethod
    def _require(value, operation):
        if not value:
            raise CaptureError(operation + ' failed (Win32 error '
                               + str(c.get_last_error()) + ')')
        return value

    @contextmanager
    def scope(self):
        old = self._require(self._call(self.user, 'SetThreadDpiAwarenessContext',
                                       c.c_void_p(-4)), 'Set thread DPI context')
        try:
            current = self._call(self.user, 'GetThreadDpiAwarenessContext')
            if not self._call(self.user, 'AreDpiAwarenessContextsEqual', current,
                              c.c_void_p(-4)):
                raise CaptureError('Per-monitor-v2 thread DPI context unverified')
            yield
        finally:
            self._require(self._call(self.user, 'SetThreadDpiAwarenessContext',
                                      old, cleanup=True), 'Restore thread DPI context')
            restored = self._call(self.user, 'GetThreadDpiAwarenessContext', cleanup=True)
            if not self._call(self.user, 'AreDpiAwarenessContextsEqual', restored,
                              old, cleanup=True):
                raise CaptureError('Thread DPI context restoration unverified')

    def live_identity(self, process):
        pid = self._require(self._call(self.kernel, 'GetProcessId', process.process),
                            'Get retained handle PID')
        times = [c.c_uint64() for _ in range(4)]
        self._require(self._call(self.kernel, 'GetProcessTimes', process.process,
                                 *(c.byref(value) for value in times)), 'Read process birth')
        image, size = c.create_unicode_buffer(32768), c.c_uint32(32768)
        self._require(self._call(self.kernel, 'QueryFullProcessImageNameW', process.process,
                                 0, image, c.byref(size)), 'Read retained image identity')
        return dict(pid=pid, creation_filetime=times[0].value, image=image.value)

    def _object_name(self, handle):
        self._require(handle, 'Get borrowed user-object handle')
        name, needed = c.create_unicode_buffer(256), c.c_uint32()
        self._require(self._call(self.user, 'GetUserObjectInformationW', handle,
                                 2, name, c.sizeof(name), c.byref(needed)),
                      'Read bounded user-object name')
        if not name.value or needed.value > c.sizeof(name):
            raise CaptureError('User-object name unavailable or oversized')
        return name.value

    def _session(self, pid):
        session = c.c_uint32()
        self._require(self._call(self.kernel, 'ProcessIdToSessionId', pid,
                                 c.byref(session)), 'Read process session')
        return session.value

    def desktop(self, process):
        current = self._session(self._call(self.kernel, 'GetCurrentProcessId'))
        target = self._session(int(process.pid))
        if not current or current != target:
            raise CaptureError('Capture and retained client require one interactive session')
        state, length = c.c_void_p(), c.c_uint32()
        try:
            self._require(self._call(self.wts, 'WTSQuerySessionInformationW', None,
                                     current, 8, c.byref(state), c.byref(length)),
                          'Read session connection state')
            if not state.value or length.value != c.sizeof(c.c_uint32):
                raise CaptureError('Session connection state unavailable')
            if c.cast(state, c.POINTER(c.c_uint32)).contents.value != 0:
                raise CaptureError('Interactive session is not WTSActive')
        finally:
            if state.value:
                self._call(self.wts, 'WTSFreeMemory', state, cleanup=True)
        station = self._object_name(self._call(self.user, 'GetProcessWindowStation'))
        thread = self._object_name(self._call(self.user, 'GetThreadDesktop',
                                              self._call(self.kernel, 'GetCurrentThreadId')))
        # No retries, fallback rights, desktop switch, or inherited handle.
        self.counters['input_desktop_opens'] += 1
        handle = self._require(self._call(self.user, 'OpenInputDesktop', 0, False, 0x0001),
                               'OpenInputDesktop READOBJECTS only; stop on denial')
        try:
            input_name = self._object_name(handle)
        finally:
            self._require(self._call(self.user, 'CloseDesktop', handle, cleanup=True),
                          'Close owned input-desktop handle')
        # Same current station + desktop-local EnumWindows binds these names.
        if station != 'WinSta0' or thread != 'Default' or input_name != thread:
            raise CaptureError('Expected WinSta0/Default input and thread desktop not verified')
        return dict(session_id=current, window_station=station,
                    thread_desktop=thread, input_desktop=input_name,
                    input_desktop_access='DESKTOP_READOBJECTS', session_state='WTSActive')

    def _owner(self, hwnd):
        pid = c.c_uint32()
        tid = self._require(self._call(self.user, 'GetWindowThreadProcessId', hwnd,
                                       c.byref(pid)), 'Read HWND owner')
        if not pid.value:
            raise CaptureError('HWND owner PID unavailable')
        return pid.value, tid

    def _owned_title(self, hwnd, pid, title):
        if self._owner(hwnd)[0] != pid:
            raise CaptureError('HWND no longer belongs to retained client')
        buffer = c.create_unicode_buffer(256)
        count = self._call(self.user, 'GetWindowTextW', hwnd, buffer, len(buffer))
        # Never expose a mismatching title in an exception or receipt.
        if count != len(title) or buffer.value != title or self._owner(hwnd)[0] != pid:
            raise CaptureError('Owned HWND lacks the exact expected scene title')

    def select_owned(self, pid, title):
        owned, count, failure = [], 0, []

        @self.callback_type
        def visitor(hwnd, unused):
            nonlocal count
            try:
                count += 1
                if count > MAX_ENUM_WINDOWS:
                    raise CaptureError('Window enumeration bound exceeded')
                # Read titles only after PID ownership is established, never for
                # unrelated processes. Extra visible owned windows reject prompts.
                if (self._owner(hwnd)[0] == pid
                        and self._call(self.user, 'IsWindowVisible', hwnd)):
                    owned.append(hwnd)
                    if len(owned) > 1:
                        raise CaptureError('Multiple visible owned windows; no prompt interaction')
                return True
            except Exception as error:
                failure.append(error)
                return False

        result = self._call(self.user, 'EnumWindows', visitor, 0)
        if failure:
            raise failure[0]
        self._require(result, 'Enumerate current thread-desktop windows')
        if len(owned) != 1:
            raise CaptureError('Exactly one visible retained-client window is required')
        self._owned_title(owned[0], pid, title)
        return owned[0]

    def activate_owned(self, hwnd, pid, title):
        self._owned_title(hwnd, pid, title)
        if (not self._call(self.user, 'IsWindowEnabled', hwnd)
                or not self._call(self.user, 'IsWindowVisible', hwnd)
                or self._call(self.user, 'IsIconic', hwnd)):
            raise CaptureError('Owned scene window is disabled, hidden, or minimized')
        requested = self._call(self.user, 'GetForegroundWindow') != hwnd
        if requested:
            self.counters['activation_attempts'] += 1
            self._require(self._call(self.user, 'SetForegroundWindow', hwnd),
                          'Activate owned HWND once; no foreground workaround')
        if self._call(self.user, 'GetForegroundWindow') != hwnd:
            raise CaptureError('Owned HWND did not become foreground; no retry')
        return dict(requested=requested, attempts=self.counters['activation_attempts'])

    def _no_overlap_above(self, hwnd, rect):
        seen = set()
        cursor = self._call(self.user, 'GetWindow', hwnd, 3)  # GW_HWNDPREV
        while cursor:
            if cursor in seen or len(seen) >= MAX_ENUM_WINDOWS:
                raise CaptureError('Above-window traversal bound/repeat encountered')
            seen.add(cursor)
            if self._call(self.user, 'IsWindowVisible', cursor):
                other = _RECT()
                self._require(self._call(self.user, 'GetWindowRect', cursor,
                                         c.byref(other)), 'Read occluder bounds')
                if (other.left < rect[2] and other.right > rect[0]
                        and other.top < rect[3] and other.bottom > rect[1]):
                    raise CaptureError('A visible higher window overlaps the owned client')
            cursor = self._call(self.user, 'GetWindow', cursor, 3)

    def owned_child_geometry(self, hwnd, pid, tid):
        """At most eight direct children, geometry only; no text/class/pixels."""
        rows, seen = [], set()
        origin = _POINT(0, 0)
        self._require(self._call(self.user, 'ClientToScreen', hwnd, c.byref(origin)),
                      'Read owned parent client origin')
        child = self._call(self.user, 'GetWindow', hwnd, 5)  # GW_CHILD
        while child:
            if len(rows) >= 8 or child in seen:
                raise CaptureError('Owned child geometry bound/repeat encountered')
            seen.add(child)
            owner, thread = self._owner(child)
            if owner != pid or self._call(self.user, 'GetAncestor', child, 1) != hwnd:
                raise CaptureError('Child geometry is not directly owned by admitted window')
            rect = _RECT()
            self._require(self._call(self.user, 'GetClientRect', child, c.byref(rect)),
                          'Read owned child client rectangle')
            first, last = _POINT(0, 0), _POINT(rect.right, rect.bottom)
            self._require(self._call(self.user, 'ClientToScreen', child, c.byref(first)),
                          'Read owned child client origin')
            self._require(self._call(self.user, 'ClientToScreen', child, c.byref(last)),
                          'Read owned child client extent')
            visible = bool(self._call(self.user, 'IsWindowVisible', child))
            if self._owner(child) != (owner, thread) or self._call(self.user, 'GetAncestor', child, 1) != hwnd:
                raise CaptureError('Owned child identity changed during geometry read')
            values = (child, owner, thread, rect.left, rect.top, rect.right, rect.bottom,
                      first.x, first.y, last.x, last.y)
            if (any(type(n) is not int for n in values) or not 0 < child < 2**64 or
                    not 0 < owner < 2**32 or not 0 < thread < 2**32 or
                    any(not -2**31 <= n < 2**31 for n in values[3:]) or
                    rect.left != 0 or rect.top != 0 or rect.right < 0 or rect.bottom < 0):
                raise CaptureError('Malformed owned child geometry')
            rows.append(dict(hwnd=child, pid=owner, thread_id=thread, visible=visible,
                             client_rect=[rect.left, rect.top, rect.right, rect.bottom],
                             parent_client_rect=[first.x-origin.x, first.y-origin.y,
                                                 last.x-origin.x, last.y-origin.y]))
            child = self._call(self.user, 'GetWindow', child, 2)  # GW_HWNDNEXT
        if self._owner(hwnd) != (pid, tid):
            raise CaptureError('Owned parent identity changed during child geometry read')
        return rows

    def window_snapshot(self, hwnd, pid, title, size, *, require_exposed):
        if (not self._call(self.user, 'IsWindow', hwnd)
                or not self._call(self.user, 'IsWindowVisible', hwnd)
                or not self._call(self.user, 'IsWindowEnabled', hwnd)
                or self._call(self.user, 'IsIconic', hwnd)
                or self._call(self.user, 'GetAncestor', hwnd, 2) != hwnd):
            raise CaptureError('Owned top-level window is not visible, enabled, and restored')
        self._owned_title(hwnd, pid, title)
        owner, tid = self._owner(hwnd)
        if owner != pid or self._object_name(self._call(self.user, 'GetThreadDesktop', tid)) != 'Default':
            raise CaptureError('Owned window thread/PID desktop mismatch')
        client = _RECT()
        self._require(self._call(self.user, 'GetClientRect', hwnd, c.byref(client)),
                      'Read owned client rectangle')
        if (client.left, client.top, client.right, client.bottom) != (0, 0, *size):
            # Read only the same HWND owner again; no broad/window-content query.
            if self._owner(hwnd) != (owner, tid):
                raise CaptureError('Owned HWND identity changed during rectangle read')
            error = OwnedRectangleMismatch(hwnd, pid, tid,
                (client.left, client.top, client.right, client.bottom), (0, 0, *size))
            if error.evidence is not None:
                try:
                    error.evidence['direct_children'] = self.owned_child_geometry(hwnd, pid, tid)
                    error.evidence['child_geometry_status'] = 'observed'
                except Exception:
                    # Diagnostic failure never permits capture or hides mismatch.
                    error.evidence['child_geometry_status'] = 'unavailable'
            raise error
        first, last = _POINT(0, 0), _POINT(*size)
        self._require(self._call(self.user, 'ClientToScreen', hwnd, c.byref(first)),
                      'Map owned client origin')
        self._require(self._call(self.user, 'ClientToScreen', hwnd, c.byref(last)),
                      'Map owned client extent')
        rect = [first.x, first.y, last.x, last.y]
        if last.x - first.x != size[0] or last.y - first.y != size[1]:
            raise CaptureError('Physical client dimensions are virtualized or changed')
        vx, vy, vw, vh = [self._call(self.user, 'GetSystemMetrics', n) for n in (76, 77, 78, 79)]
        if (vw <= 0 or vh <= 0 or first.x < vx or first.y < vy
                or last.x > vx + vw or last.y > vy + vh):
            raise CaptureError('Owned client rectangle is not wholly on the virtual screen')
        if require_exposed:
            if self._call(self.user, 'GetForegroundWindow') != hwnd:
                raise CaptureError('Foreground changed away from owned HWND')
            self._no_overlap_above(hwnd, rect)
            xs = sorted({first.x + (size[0] - 1) * n // (HIT_GRID - 1) for n in range(HIT_GRID)})
            ys = sorted({first.y + (size[1] - 1) * n // (HIT_GRID - 1) for n in range(HIT_GRID)})
            for y in ys:
                for x in xs:
                    hit = self._call(self.user, 'WindowFromPoint', _POINT(x, y))
                    self.counters['hit_samples'] += 1
                    if (not hit or self._owner(hit)[0] != pid
                            or self._call(self.user, 'GetAncestor', hit, 2) != hwnd):
                        raise CaptureError('Sampled client pixel is not owned/exposed')
            if self._call(self.user, 'GetForegroundWindow') != hwnd:
                raise CaptureError('Foreground changed during hit testing')
        # Recheck basic ownership after geometry/hit-test observations too.
        self._owned_title(hwnd, pid, title)
        return dict(hwnd=int(hwnd), pid=owner, thread_id=tid, expected_title=title,
                    client_rect=[0, 0, *size], screen_rect=rect,
                    virtual_screen=[vx, vy, vx + vw, vy + vh])

    def capture_rgb(self, rect, before, after):
        left, top, right, bottom = rect
        width, height = _size((right - left, bottom - top))
        screen = memory = bitmap = previous = None
        selected = False
        cleanup_errors = []
        try:
            screen = self._require(self._call(self.user, 'GetDC', None), 'Get screen DC')
            memory = self._require(self._call(self.gdi, 'CreateCompatibleDC', screen),
                                   'Create owned capture DC')
            info = _BITMAPINFO()
            info.header = _BITMAPINFOHEADER(c.sizeof(_BITMAPINFOHEADER), width,
                                            -height, 1, 32, 0, width * height * 4,
                                            0, 0, 0, 0)
            bits = c.c_void_p()
            bitmap = self._require(self._call(self.gdi, 'CreateDIBSection', screen,
                                              c.byref(info), 0, c.byref(bits), None, 0),
                                   'Create bounded owned capture DIB')
            self._require(bits.value, 'Get owned DIB storage')
            previous = self._call(self.gdi, 'SelectObject', memory, bitmap)
            if not previous or previous == c.c_void_p(-1).value:
                raise CaptureError('Select owned capture DIB failed')
            selected = True
            before()
            if self.counters['bitblt'] != 0:
                raise CaptureError('Only one screen BitBlt is permitted')
            self.counters['bitblt'] += 1
            # SRCCOPY only. Never request the whole screen, PrintWindow,
            # DrawToBitmap, CAPTUREBLT, input injection, or application redraw.
            self._require(self._call(self.gdi, 'BitBlt', memory, 0, 0, width, height,
                                      screen, left, top, 0x00CC0020),
                          'Copy verified client rectangle from actual screen')
            self._require(self._call(self.gdi, 'GdiFlush'), 'Flush owned capture GDI work')
            after()
            bgra = c.string_at(bits, width * height * 4)
            rgb = bytearray(width * height * 3)
            rgb[0::3], rgb[1::3], rgb[2::3] = bgra[2::4], bgra[1::4], bgra[0::4]
            return bytes(rgb)
        finally:
            # Only objects allocated above are deleted; the borrowed original
            # selected object, process/window, and borrowed desktop are not closed.
            restoration_failed = False
            if selected:
                restored = self._call(self.gdi, 'SelectObject', memory, previous, cleanup=True)
                if not restored or restored == c.c_void_p(-1).value:
                    restoration_failed = True
                    cleanup_errors.append('Restore capture DC selection failed')
            # If deselection failed, dispose our DC first, then our bitmap.
            # Do not try DeleteObject on a still-selected bitmap and retry it.
            if memory and restoration_failed:
                if not self._call(self.gdi, 'DeleteDC', memory, cleanup=True):
                    cleanup_errors.append('Delete owned capture DC failed')
                memory = None
            if bitmap and not self._call(self.gdi, 'DeleteObject', bitmap, cleanup=True):
                cleanup_errors.append('Delete owned capture bitmap failed')
            if memory and not self._call(self.gdi, 'DeleteDC', memory, cleanup=True):
                cleanup_errors.append('Delete owned capture DC failed')
            if screen and self._call(self.user, 'ReleaseDC', None, screen, cleanup=True) != 1:
                cleanup_errors.append('Release screen DC failed')
            if cleanup_errors:
                raise CaptureError('; '.join(cleanup_errors))
