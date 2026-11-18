"""Player view vs ghost view profiler. Windows only.

Builds a temporary copy of civ13.dme with tests/view_lag/probe.dm, starts the
daemon on a loopback port behind the byte-counting proxy from
tests/open_air_view/bandwidth_check.py and connects one Dream Seeker client.
The probe moves the client through roles (ghost, human, human with one
player-only system off, ...) and stages (still, walk, taps, crowd). For each
measure phase this script:

- counts bytes the server sent (network.json);
- holds or taps the arrow keys in the Dream Seeker window, as a player would;
- copies a box at the centre of the map from the screen as fast as it can and
  records how much of it changed each frame (client.json), from which
  report.py works out frame rate, hitches while walking and key-to-picture
  time.

The Dream Seeker window is maximised and must stay in front for the whole run
(about 20 minutes plus Gaia's start-up). Nothing here touches a live server:
its own ports, its own folder, versioned sample config plus
DAYNIGHT_CLIENT_TINT as on live regions. Generated sources are removed
afterwards.
"""
import argparse
import ctypes
import importlib.util
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import threading
import time
import uuid

HERE = Path(__file__).resolve().parent
PROBE_INCLUDE = '\n#include "tests\\view_lag\\probe.dm"\n'
VK_LEFT, VK_RIGHT = 0x25, 0x27
KEYEVENTF_EXTENDEDKEY, KEYEVENTF_KEYUP = 0x1, 0x2
BOX = 240  # physical pixels, centred on the player
SAMPLE_STRIDE = 97


def load_module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


bandwidth = load_module(HERE.parent / 'open_air_view' / 'bandwidth_check.py', 'view_lag_bandwidth')
report = load_module(HERE / 'report.py', 'view_lag_report')


def read_json(path):
    try:
        return json.loads(path.read_text(encoding='utf-8'))
    except (FileNotFoundError, json.JSONDecodeError, PermissionError):
        return None


class Window:
    """The Dream Seeker main window: focus, keys and screen box capture."""

    def __init__(self, pid):
        self.pid = pid
        self.user32 = ctypes.windll.user32
        self.gdi32 = ctypes.windll.gdi32
        for name in ('GetDC', 'GetForegroundWindow'):
            getattr(self.user32, name).restype = ctypes.c_void_p
        for name in ('CreateCompatibleDC', 'CreateCompatibleBitmap', 'SelectObject'):
            getattr(self.gdi32, name).restype = ctypes.c_void_p
        self.hwnd = None
        self.box = None
        self.closing = {}
        self.want_focus = False
        self.active = False
        self.screen = self.memory = self.bitmap = None

    def find(self):
        found = []

        @ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p)
        def visit(hwnd, _):
            owner = ctypes.c_ulong()
            self.user32.GetWindowThreadProcessId(ctypes.c_void_p(hwnd), ctypes.byref(owner))
            if owner.value == self.pid and self.user32.IsWindowVisible(ctypes.c_void_p(hwnd)):
                rect = (ctypes.c_long * 4)()
                self.user32.GetWindowRect(ctypes.c_void_p(hwnd), rect)
                found.append(((rect[2] - rect[0]) * (rect[3] - rect[1]), hwnd))
            return True

        self.user32.EnumWindows(visit, None)
        self.hwnd = max(found)[1] if found else None
        return self.hwnd

    def focus(self):
        """Brings the window to the front; True when it really is in front."""
        if not self.hwnd and not self.find():
            return False
        hwnd = ctypes.c_void_p(self.hwnd)
        if self.user32.GetForegroundWindow() == self.hwnd:
            return True
        self.user32.ShowWindow(hwnd, 3)  # SW_MAXIMIZE
        # Windows refuses SetForegroundWindow from a background process unless
        # it just had input; a bare Alt press counts.
        self.user32.keybd_event(0x12, 0, 0, 0)
        self.user32.SetForegroundWindow(hwnd)
        self.user32.keybd_event(0x12, 0, KEYEVENTF_KEYUP, 0)
        time.sleep(0.3)
        return self.user32.GetForegroundWindow() == self.hwnd

    def dismiss_dialogs(self, log):
        """Closes stray client popups (prompts, the lobby panel) over the map.

        A titled popup gets WM_CLOSE (Cancel), then IDOK if it is still there
        next time; an untitled popup is hidden. Each one is logged.
        """
        found = []

        @ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p)
        def visit(hwnd, _):
            owner = ctypes.c_ulong()
            self.user32.GetWindowThreadProcessId(ctypes.c_void_p(hwnd), ctypes.byref(owner))
            if owner.value == self.pid and hwnd != self.hwnd and self.user32.IsWindowVisible(ctypes.c_void_p(hwnd)):
                found.append(hwnd)
            return True

        self.user32.EnumWindows(visit, None)
        main = (ctypes.c_long * 4)()
        self.user32.GetWindowRect(ctypes.c_void_p(self.hwnd), main)
        main_area = (main[2] - main[0]) * (main[3] - main[1])
        for hwnd in found:
            rect = (ctypes.c_long * 4)()
            self.user32.GetWindowRect(ctypes.c_void_p(hwnd), rect)
            width, height = rect[2] - rect[0], rect[3] - rect[1]
            if width <= 50 or height <= 50 or width * height > main_area / 4:
                continue
            title = ctypes.create_unicode_buffer(256)
            self.user32.GetWindowTextW(ctypes.c_void_p(hwnd), title, 256)
            if title.value:
                tries = self.closing.get(hwnd, 0)
                if tries:
                    self.user32.PostMessageW(ctypes.c_void_p(hwnd), 0x0111, 1, 0)  # WM_COMMAND IDOK
                else:
                    self.user32.PostMessageW(ctypes.c_void_p(hwnd), 0x0010, 0, 0)  # WM_CLOSE
                self.closing[hwnd] = tries + 1
            else:
                self.user32.ShowWindow(ctypes.c_void_p(hwnd), 0)  # SW_HIDE
            log(f'closed client dialog {title.value!r} {width}x{height}')

    def keep(self, log, stop):
        """Background: keeps popups away and the window in front."""
        while not stop.is_set():
            try:
                # Only once the game is running: the connecting window is the
                # client's largest window before that, and must not be touched.
                if self.active and self.find():
                    self.dismiss_dialogs(log)
                    if self.want_focus and self.active:
                        self.focus()
            except OSError:
                pass
            stop.wait(0.5)

    def key(self, vk, down):
        scan = self.user32.MapVirtualKeyW(vk, 0)
        self.user32.keybd_event(vk, scan, KEYEVENTF_EXTENDEDKEY | (0 if down else KEYEVENTF_KEYUP), 0)

    def place_box(self, layout):
        """A BOX-sized square at the centre of the map control, in screen pixels."""
        rect = (ctypes.c_long * 4)()
        self.user32.GetClientRect(ctypes.c_void_p(self.hwnd), rect)
        origin = (ctypes.c_long * 2)(0, 0)
        self.user32.ClientToScreen(ctypes.c_void_p(self.hwnd), origin)
        width, height = rect[2], rect[3]
        share_x, share_y = 0.6, 1.0  # usual split when the layout is unknown

        def size(text):
            try:
                w, h = str(text).split('x')
                return int(w), int(h)
            except (ValueError, AttributeError):
                return None

        window = size((layout or {}).get('window'))
        mapped = size((layout or {}).get('map'))
        if window and mapped and window[0] and window[1]:
            share_x = min(1.0, mapped[0] / window[0])
            share_y = min(1.0, mapped[1] / window[1])
        cx = origin[0] + int(width * share_x / 2)
        cy = origin[1] + int(height * share_y / 2)
        self.box = (cx - BOX // 2, cy - BOX // 2)
        if not self.screen:
            self.screen = self.user32.GetDC(None)
            self.memory = self.gdi32.CreateCompatibleDC(ctypes.c_void_p(self.screen))
            self.bitmap = self.gdi32.CreateCompatibleBitmap(ctypes.c_void_p(self.screen), BOX, BOX)
            self.gdi32.SelectObject(ctypes.c_void_p(self.memory), ctypes.c_void_p(self.bitmap))
            self.header = ctypes.create_string_buffer(struct.pack('<IiiHHIIiiII', 40, BOX, -BOX, 1, 32, 0, 0, 0, 0, 0, 0), 40)
            self.pixels = ctypes.create_string_buffer(BOX * BOX * 4)
        return {'box': self.box, 'client_size': (width, height), 'share': (round(share_x, 3), round(share_y, 3))}

    def grab(self):
        """Sampled bytes of the box as it is on screen now."""
        self.gdi32.BitBlt(ctypes.c_void_p(self.memory), 0, 0, BOX, BOX, ctypes.c_void_p(self.screen), self.box[0], self.box[1], 0x00CC0020)
        self.gdi32.GetDIBits(ctypes.c_void_p(self.memory), ctypes.c_void_p(self.bitmap), 0, BOX, self.pixels, self.header, 0)
        return self.pixels.raw[::SAMPLE_STRIDE]

    def save_png(self, path):
        raw = self.pixels.raw
        rows = bytearray()
        for y in range(BOX):
            row = raw[y * BOX * 4:(y + 1) * BOX * 4]
            rgb = bytearray(BOX * 3)
            rgb[0::3], rgb[1::3], rgb[2::3] = row[2::4], row[1::4], row[0::4]
            rows += b'\x00' + rgb
        import zlib

        def chunk(kind, data):
            body = kind + data
            return struct.pack('>I', len(data)) + body + struct.pack('>I', zlib.crc32(body))

        path.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', BOX, BOX, 8, 2, 0, 0, 0))
                         + chunk(b'IDAT', zlib.compress(bytes(rows), 6)) + chunk(b'IEND', b''))

    def close(self):
        if self.screen:
            self.gdi32.DeleteObject(ctypes.c_void_p(self.bitmap))
            self.gdi32.DeleteDC(ctypes.c_void_p(self.memory))
            self.user32.ReleaseDC(None, ctypes.c_void_p(self.screen))
            self.screen = None


class Stage:
    """One measure phase: capture frames while acting out the probe's action."""

    def __init__(self, window, name, action, layout, shots):
        self.window, self.name, self.action, self.layout, self.shots = window, name, action, layout, shots
        self.frames, self.holds, self.taps = [], [], []
        self.stop = threading.Event()
        self.focus_ok = window.user32.GetForegroundWindow() == window.hwnd
        self.box = window.place_box(layout)
        self.t0 = time.perf_counter()
        self.threads = [threading.Thread(target=self.capture, daemon=True), threading.Thread(target=self.act, daemon=True)]
        for thread in self.threads:
            thread.start()

    def now(self):
        return time.perf_counter() - self.t0

    def capture(self):
        previous = self.window.grab()
        count = len(previous)
        saved = False
        while not self.stop.is_set():
            sample = self.window.grab()
            t = self.now()
            changed = sum(1 for a, b in zip(previous, sample) if a != b)
            self.frames.append((round(t, 4), round(changed / count, 4)))
            previous = sample
            if not saved and t > 2:
                self.window.save_png(self.shots / (self.name + '.png'))
                saved = True

    def act(self):
        if self.action == 'walk':
            vk = VK_RIGHT
            while not self.stop.is_set():
                down = self.now()
                self.window.key(vk, True)
                self.stop.wait(1.5)
                self.window.key(vk, False)
                self.holds.append((round(down, 4), round(self.now(), 4)))
                vk = VK_LEFT if vk == VK_RIGHT else VK_RIGHT
                self.stop.wait(0.25)
        elif self.action == 'taps':
            vk = VK_RIGHT
            self.stop.wait(0.5)
            while not self.stop.is_set():
                self.taps.append(round(self.now(), 4))
                self.window.key(vk, True)
                time.sleep(0.05)
                self.window.key(vk, False)
                vk = VK_LEFT if vk == VK_RIGHT else VK_RIGHT
                self.stop.wait(1.4)

    def finish(self):
        self.stop.set()
        self.focus_ok = self.focus_ok and self.window.user32.GetForegroundWindow() == self.window.hwnd
        for thread in self.threads:
            thread.join(timeout=5)
        for vk in (VK_LEFT, VK_RIGHT):
            self.window.key(vk, False)
        return {'frames': self.frames, 'holds': self.holds, 'taps': self.taps, 'focus_ok': self.focus_ok, 'box': self.box}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--roles', help='comma list (default: every role in probe.dm)')
    parser.add_argument('--config-line', action='append', default=None, help='extra line for the run copy of config/config.txt (default: DAYNIGHT_CLIENT_TINT, as on live)')
    parser.add_argument('--deadline', type=int, default=5400, help='seconds for the whole run')
    args = parser.parse_args()
    if sys.platform != 'win32':
        raise SystemExit('This profiler needs a Windows Dream Seeker client')
    try:
        ctypes.windll.shcore.SetProcessDpiAwareness(2)  # screen pixels, not scaled ones
    except (AttributeError, OSError):
        pass
    config_lines = ['DAYNIGHT_CLIENT_TINT'] if args.config_line is None else args.config_line
    repo = HERE.parents[1]
    output = (args.output or Path(tempfile.gettempdir()) / ('civ13-view-lag-' + uuid.uuid4().hex)).resolve()
    if output.exists() and any(output.iterdir()):
        raise RuntimeError('Output evidence directory must be fresh')
    (output / 'shots').mkdir(parents=True, exist_ok=True)
    port, proxy_port = bandwidth.free_port(), bandwidth.free_port()
    head = subprocess.check_output(['git', '-C', str(repo), 'rev-parse', 'HEAD'], text=True).strip()
    status = subprocess.check_output(['git', '-C', str(repo), 'status', '--porcelain'], text=True)
    source = repo / ('.view_lag_' + uuid.uuid4().hex + '.dme')
    created = [source.with_suffix(suffix) for suffix in ('.dme', '.dmb', '.rsc', '.int', '.lk')]
    daemon = client = proxy = window = stage = None
    keeper_stop = None
    client_data = {}
    try:
        dme = (repo / 'civ13.dme').read_text(encoding='utf-8-sig')
        source.write_text(dme + PROBE_INCLUDE, encoding='utf-8')
        build = subprocess.run([str(args.byond_bin / 'dm.exe'), '-max_errors', '0', source.name], cwd=repo, capture_output=True, text=True, timeout=1200)
        log = build.stdout + build.stderr
        (output / 'compile.log').write_text(log, encoding='utf-8')
        if build.returncode or '0 errors, 0 warnings' not in log:
            raise RuntimeError('Probe compilation failed; see compile.log')
        source.with_suffix('.dmb').replace(output / 'probe.dmb')
        source.with_suffix('.rsc').replace(output / 'probe.rsc')
        for path in subprocess.check_output(['git', '-C', str(repo), 'ls-files', '--', 'config', 'maps/heights'], text=True).splitlines():
            target = output / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes((repo / path).read_bytes())
        if config_lines:
            with (output / 'config' / 'config.txt').open('a', encoding='utf-8') as extra:
                extra.write('\n' + '\n'.join(config_lines) + '\n')
        (output / 'manifest.json').write_text(json.dumps({
            'tested_commit': head, 'working_tree_status': status, 'port': port, 'proxy_port': proxy_port, 'config_lines': config_lines,
            'roles': args.roles, 'adapters': ['probe appended to a temporary civ13.dme', 'webhooks/ToRban off', 'round started via admin_started',
                                              'staged bodies fed and held warm', 'player-only systems switched by probe overrides',
                                              'client connects through a counting proxy', 'arrow keys sent to the Dream Seeker window']}, indent=2), encoding='utf-8')
        params = 'tested_commit=' + head + ('&roles=' + args.roles if args.roles else '')
        with (output / 'daemon-output.log').open('w') as out:
            daemon = subprocess.Popen([str(args.byond_bin / 'dd.exe'), 'probe.dmb', str(port), '-trusted', '-ip', '127.0.0.1',
                                       '-params', params, '-log', 'startup.log'], cwd=output, stdout=out, stderr=subprocess.STDOUT)
        proxy = bandwidth.CountingProxy(proxy_port, port)
        print(f'Daemon PID {daemon.pid} on 127.0.0.1:{port}, proxy on {proxy_port}; evidence in {output}', flush=True)
        started = time.monotonic()
        last_phase = None
        while not (output / 'result.json').exists():
            if time.monotonic() - started > args.deadline:
                raise RuntimeError(f'Whole-run {args.deadline}-second deadline')
            if daemon.poll() is not None:
                break
            info = read_json(output / 'phase.json') or {}
            phase = info.get('phase')
            if phase and phase != last_phase:
                proxy.phase = phase
                if stage:
                    client_data[stage.name] = stage.finish()
                    stage = None
                print(f'[{round(time.monotonic() - started)} s] {phase} {info.get("action")}', flush=True)
                if phase.startswith('switch_') and window:
                    window.active = True
                if phase.startswith('measure_') and window:
                    stage = Stage(window, phase[len('measure_'):], info.get('action'), info.get('map'), output / 'shots')
                last_phase = phase
            if phase == 'waiting_for_client' and client is None:
                client = subprocess.Popen([str(args.byond_bin / 'dreamseeker.exe'), f'byond://127.0.0.1:{proxy_port}'])
                window = Window(client.pid)
                window.want_focus = True
                keeper_stop = threading.Event()
                threading.Thread(target=window.keep, args=(lambda text: print(f'[{round(time.monotonic() - started)} s] {text} during {last_phase}', flush=True), keeper_stop), daemon=True).start()
            time.sleep(0.05)
        if stage:
            client_data[stage.name] = stage.finish()
        time.sleep(3)
        network = {}
        for phase, down in proxy.down.items():
            if phase.startswith('measure_'):
                network[phase[len('measure_'):]] = {'down': down, 'up': proxy.up.get(phase, 0)}
        (output / 'network.json').write_text(json.dumps(network, indent=2), encoding='utf-8')
        (output / 'client.json').write_text(json.dumps(client_data), encoding='utf-8')
        if not (output / 'result.json').exists():
            raise RuntimeError(f'No result.json (daemon exit {daemon.poll()}); see {output}')
        summary = report.build(output)
        print((output / 'report.md').read_text(encoding='utf-8'))
        unfocused = [name for name, data in client_data.items() if not data.get('focus_ok')]
        if unfocused:
            print('WARNING: Dream Seeker was not in front for: ' + ', '.join(unfocused), flush=True)
        if not summary['passed']:
            raise SystemExit(1)
    finally:
        if keeper_stop:
            keeper_stop.set()
        if stage:
            stage.finish()
        if window:
            window.close()
        for process in (client, daemon):
            if process and process.poll() is None:
                process.kill()
                process.wait(timeout=15)
        if proxy:
            proxy.close()
        for path in created:
            if path.exists():
                path.unlink()


if __name__ == '__main__':
    main()
