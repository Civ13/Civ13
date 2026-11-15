"""Real-client check for Look into Distance and tree-top sight. Windows only.

Builds a temporary copy of civ13.dme with tests/look_distance/client_probe.dm,
starts the daemon on a loopback port from a fresh evidence directory, connects
one Dream Seeker client and saves a picture of that client's window each time
the probe asks for one. Each picture gets a black-band measure: the share of
pure black pixels in each tenth of the window, top to bottom and left to right.

Nothing here touches a live server: its own port, its own folder, versioned
sample config only. Generated sources are removed afterwards.
"""
import argparse
import ctypes
import json
from pathlib import Path
import socket
import struct
import subprocess
import sys
import tempfile
import time
import uuid
import zlib

REQUIRED_CHECKS = ('stages_recorded',)
REQUIRED_SHOTS = ('1_standing', '2_look_north', '3_look_east', '4_tree_top', '5_tree_look_north', '7_final')
PROBE_INCLUDE = '\n#include "tests\\look_distance\\client_probe.dm"\n'


def png(width, height, bgra):
    """Encodes top-down 32-bit BGRA rows as an RGB PNG with the standard library."""
    rows = bytearray()
    stride = width * 4
    for y in range(height):
        row = bgra[y * stride:(y + 1) * stride]
        rgb = bytearray(width * 3)
        rgb[0::3] = row[2::4]
        rgb[1::3] = row[1::4]
        rgb[2::3] = row[0::4]
        rows += b'\x00' + rgb

    def chunk(kind, data):
        body = kind + data
        return struct.pack('>I', len(data)) + body + struct.pack('>I', zlib.crc32(body))

    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(bytes(rows), 6)) + chunk(b'IEND', b''))


def black_bands(width, height, bgra, parts=10):
    """Share of pure black pixels in each tenth of the picture, by rows and by columns."""
    rows = [[0, 0] for _ in range(parts)]
    cols = [[0, 0] for _ in range(parts)]
    for y in range(0, height, 4):
        ry = rows[min(parts - 1, y * parts // height)]
        base = y * width * 4
        for x in range(0, width, 4):
            i = base + x * 4
            black = bgra[i] < 6 and bgra[i + 1] < 6 and bgra[i + 2] < 6
            cx = cols[min(parts - 1, x * parts // width)]
            ry[0] += black
            ry[1] += 1
            cx[0] += black
            cx[1] += 1
    return [round(a / b, 3) if b else 0 for a, b in rows], [round(a / b, 3) if b else 0 for a, b in cols]


def free_port():
    with socket.socket() as probe:
        probe.bind(('127.0.0.1', 0))
        return probe.getsockname()[1]


def client_window(pid):
    """The largest visible top-level window of the client process."""
    user32 = ctypes.windll.user32
    found = []

    @ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p)
    def visit(hwnd, _):
        owner = ctypes.c_ulong()
        user32.GetWindowThreadProcessId(ctypes.c_void_p(hwnd), ctypes.byref(owner))
        if owner.value == pid and user32.IsWindowVisible(ctypes.c_void_p(hwnd)):
            rect = (ctypes.c_long * 4)()
            user32.GetWindowRect(ctypes.c_void_p(hwnd), rect)
            found.append(((rect[2] - rect[0]) * (rect[3] - rect[1]), hwnd, tuple(rect)))
        return True

    user32.EnumWindows(visit, None)
    return max(found)[1:] if found else (None, None)


def capture(pid, path):
    """Copies the client window's screen area (what the player sees) to a PNG."""
    user32, gdi32 = ctypes.windll.user32, ctypes.windll.gdi32
    for name in ('GetDC', 'ReleaseDC'):
        getattr(user32, name).restype = ctypes.c_void_p
    for name in ('CreateCompatibleDC', 'CreateCompatibleBitmap', 'SelectObject'):
        getattr(gdi32, name).restype = ctypes.c_void_p
    hwnd, _ = client_window(pid)
    if not hwnd:
        raise RuntimeError('The Dream Seeker window was not found')
    user32.ShowWindow(ctypes.c_void_p(hwnd), 3)  # SW_MAXIMIZE
    user32.SetForegroundWindow(ctypes.c_void_p(hwnd))
    time.sleep(1.5)
    hwnd, rect = client_window(pid)
    width, height = rect[2] - rect[0], rect[3] - rect[1]
    if width < 200 or height < 200:
        raise RuntimeError(f'Client window is too small to capture: {rect}')
    # The window draws itself into the bitmap, so other windows covering it (or a
    # refused SetForegroundWindow) cannot end up in the picture.
    screen = user32.GetDC(None)
    memory = gdi32.CreateCompatibleDC(ctypes.c_void_p(screen))
    bitmap = gdi32.CreateCompatibleBitmap(ctypes.c_void_p(screen), width, height)
    previous = gdi32.SelectObject(ctypes.c_void_p(memory), ctypes.c_void_p(bitmap))
    try:
        if not user32.PrintWindow(ctypes.c_void_p(hwnd), ctypes.c_void_p(memory), 2):  # PW_RENDERFULLCONTENT
            raise RuntimeError('PrintWindow failed')
        header = struct.pack('<IiiHHIIiiII', 40, width, -height, 1, 32, 0, 0, 0, 0, 0, 0)
        info = ctypes.create_string_buffer(header, 40)
        pixels = ctypes.create_string_buffer(width * height * 4)
        gdi32.SelectObject(ctypes.c_void_p(memory), ctypes.c_void_p(previous))
        if gdi32.GetDIBits(ctypes.c_void_p(memory), ctypes.c_void_p(bitmap), 0, height, pixels, info, 0) != height:
            raise RuntimeError('GetDIBits failed')
    finally:
        gdi32.DeleteObject(ctypes.c_void_p(bitmap))
        gdi32.DeleteDC(ctypes.c_void_p(memory))
        user32.ReleaseDC(None, ctypes.c_void_p(screen))
    raw = pixels.raw
    if len(set(raw[0:len(raw):4097])) < 4:
        raise RuntimeError('Captured picture is blank')
    bands = black_bands(width, height, raw)
    temporary = path.with_suffix('.tmp')
    temporary.write_bytes(png(width, height, raw))
    temporary.replace(path)  # The probe waits for the finished file.
    return {'width': width, 'height': height, 'black_share_rows': bands[0], 'black_share_columns': bands[1]}


def read_json(path):
    try:
        return json.loads(path.read_text(encoding='utf-8'))
    except (FileNotFoundError, json.JSONDecodeError, PermissionError):
        return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--port', type=int, default=0)
    parser.add_argument('--map', default='nomads_gaia.dmm', help='map file under maps/nomads to compile in place of Gaia')
    parser.add_argument('--deadline', type=int, default=5400, help='seconds for the whole run')
    args = parser.parse_args()
    if sys.platform != 'win32':
        raise SystemExit('This check needs a Windows Dream Seeker client')
    try:
        ctypes.windll.shcore.SetProcessDpiAwareness(2)  # Window rectangles in real pixels.
    except (AttributeError, OSError):
        pass
    repo = Path(__file__).resolve().parents[2]
    output = (args.output or Path(tempfile.gettempdir()) / ('civ13-look-client-' + uuid.uuid4().hex)).resolve()
    if output.exists() and any(output.iterdir()):
        raise RuntimeError('Output evidence directory must be fresh')
    (output / 'shots').mkdir(parents=True)
    port = args.port or free_port()
    head = subprocess.check_output(['git', '-C', str(repo), 'rev-parse', 'HEAD'], text=True).strip()
    status = subprocess.check_output(['git', '-C', str(repo), 'status', '--porcelain'], text=True)
    source = repo / ('.look_client_' + uuid.uuid4().hex + '.dme')
    created = [source.with_suffix(suffix) for suffix in ('.dme', '.dmb', '.rsc', '.int', '.lk')]
    daemon = client = None
    captured = {}
    try:
        dme = (repo / 'civ13.dme').read_text(encoding='utf-8-sig')
        if args.map != 'nomads_gaia.dmm':
            if '#include "maps\\nomads\\nomads_gaia.dmm"' not in dme or not (repo / 'maps' / 'nomads' / args.map).exists():
                raise RuntimeError('Cannot swap the map include for ' + args.map)
            dme = dme.replace('#include "maps\\nomads\\nomads_gaia.dmm"', '#include "maps\\nomads\\' + args.map + '"')
        source.write_text(dme + PROBE_INCLUDE, encoding='utf-8')
        build = subprocess.run([str(args.byond_bin / 'dm.exe'), '-max_errors', '0', source.name], cwd=repo, capture_output=True, text=True, timeout=1200)
        log = build.stdout + build.stderr
        (output / 'compile.log').write_text(log, encoding='utf-8')
        if build.returncode or '0 errors, 0 warnings' not in log:
            raise RuntimeError('Probe compilation failed; see compile.log')
        source.with_suffix('.dmb').replace(output / 'probe.dmb')
        source.with_suffix('.rsc').replace(output / 'probe.rsc')
        # Hill heights are read at run time from maps/heights.
        for path in subprocess.check_output(['git', '-C', str(repo), 'ls-files', '--', 'config', 'maps/heights'], text=True).splitlines():
            target = output / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes((repo / path).read_bytes())
        (output / 'manifest.json').write_text(json.dumps({
            'tested_commit': head, 'working_tree_status': status, 'port': port,
            'adapters': ['probe appended to a temporary civ13.dme', 'webhooks/ToRban off', 'round started via admin_started',
                         'weather worker paused', 'staged body fed and held warm', 'look and climb through the production procs']}, indent=2), encoding='utf-8')
        with (output / 'daemon-output.log').open('w') as out:
            daemon = subprocess.Popen([str(args.byond_bin / 'dd.exe'), 'probe.dmb', str(port), '-trusted', '-ip', '127.0.0.1',
                                       '-params', 'tested_commit=' + head, '-log', 'startup.log'], cwd=output, stdout=out, stderr=subprocess.STDOUT)
        print(f'Daemon PID {daemon.pid} on 127.0.0.1:{port}; evidence in {output}', flush=True)
        started = time.monotonic()
        last_phase = None
        while not (output / 'result.json').exists():
            if time.monotonic() - started > args.deadline:
                raise RuntimeError(f'Whole-run {args.deadline}-second deadline')
            if daemon.poll() is not None:
                break
            phase = (read_json(output / 'phase.json') or {}).get('phase')
            if phase != last_phase:
                print(f'[{round(time.monotonic() - started)} s] {phase}', flush=True)
                last_phase = phase
            if phase == 'waiting_for_client' and client is None:
                client = subprocess.Popen([str(args.byond_bin / 'dreamseeker.exe'), f'byond://127.0.0.1:{port}'])
            request = output / 'shot-request.txt'
            if client and request.exists():
                try:
                    name = request.read_text().strip()
                except PermissionError:
                    name = ''
                if name and name not in captured:
                    captured[name] = capture(client.pid, output / 'shots' / (name + '.png'))
            time.sleep(0.5)
        time.sleep(3)
        result = read_json(output / 'result.json')
        if not result:
            raise RuntimeError(f'No result.json (daemon exit {daemon.poll()}); see {output}')
        passed = [row['check'] for row in result.get('checks', []) if row.get('passed')]
        missing = [name for name in REQUIRED_CHECKS if name not in passed]
        missing_shots = [name for name in REQUIRED_SHOTS if not (output / 'shots' / (name + '.png')).exists()]
        summary = {'passed': bool(result.get('passed')) and not missing and not missing_shots, 'failure': result.get('failure'),
                   'failed_phase': result.get('failed_phase'), 'missing_checks': missing, 'missing_shots': missing_shots,
                   'shots': captured, 'tested_commit': head, 'output': str(output),
                   'stages': result.get('stages')}
        (output / 'summary.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
        print(json.dumps(summary, indent=2))
        if not summary['passed']:
            raise SystemExit(1)
    finally:
        for process in (client, daemon):
            if process and process.poll() is None:
                process.kill()
                process.wait(timeout=15)
        for path in created:
            if path.exists():
                path.unlink()


if __name__ == '__main__':
    main()
