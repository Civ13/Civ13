"""Bounded, guest-only native renderer feasibility; never composition acceptance."""
import argparse
import ctypes as c
from ctypes import wintypes as w
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import time
import urllib.request
import zipfile
from PIL import Image, ImageGrab
from guard_config import VENDOR, LIMITS, digest

ROOT = Path(__file__).resolve().parent


def server_arguments(port):
    return ['fixture.dmb', str(port), '-ip', '127.0.0.1', '-invisible', '-trusted', '-nowebclient']


def pixel_contract(image, phase):
    counts = image.convert('RGB').getcolors(image.width * image.height)
    counts = {rgb: count for count, rgb in counts}
    wanted = (255, 0, 0) if phase == 'red' else (0, 0, 255)
    other = (0, 0, 255) if phase == 'red' else (255, 0, 0)
    return counts.get(wanted, 0) >= 4096 and counts.get((0, 255, 0), 0) >= 256 and counts.get(other, 0) == 0


def socket_contract(rows, server=False, port=None):
    for row in rows:
        if row['protocol'] != 'tcp' or row['address'] != '127.0.0.1':
            raise RuntimeError('Unexpected owned socket: ' + str(row))
        if row['remote'] not in ('0.0.0.0', '127.0.0.1'):
            raise RuntimeError('Non-loopback peer: ' + str(row))
        if row['state'] == 'listen' and (not server or row['port'] != port):
            raise RuntimeError('Unexpected owned listener: ' + str(row))


def install(destination):
    archive = destination / 'vendor.zip'
    # Exact bytes pinned from the official vendor archive, not a mirror.
    with urllib.request.urlopen(VENDOR['url'], timeout=30) as response:
        if not response.url.startswith('https://www.byond.com/'):
            raise RuntimeError('Unexpected vendor redirect')
        data = response.read(16 * 1024**2 + 1)
    if len(data) > 16 * 1024**2:
        raise RuntimeError('Vendor archive exceeds bound')
    archive.write_bytes(data)
    if digest(archive) != VENDOR['sha256']:
        raise RuntimeError('Vendor archive hash mismatch')
    with zipfile.ZipFile(archive) as z:
        for entry in z.infolist():
            target = (destination / entry.filename).resolve()
            if not target.is_relative_to(destination.resolve()):
                raise RuntimeError('Unsafe vendor archive path')
        z.extractall(destination)
    binary = destination / 'byond' / 'bin'
    for name, expected in VENDOR['binaries'].items():
        if digest(binary / name) != expected:
            raise RuntimeError('Vendor binary hash mismatch: ' + name)
    return binary


def desktop_capture(pid):
    u = c.WinDLL('user32', use_last_error=True)
    u.GetForegroundWindow.restype = w.HWND
    u.GetWindowThreadProcessId.argtypes = [w.HWND, c.POINTER(w.DWORD)]
    u.IsWindowVisible.argtypes = [w.HWND]
    u.GetWindowTextLengthW.argtypes = [w.HWND]
    u.GetWindowTextW.argtypes = [w.HWND, w.LPWSTR, c.c_int]
    u.SetForegroundWindow.argtypes = [w.HWND]
    u.GetClientRect.argtypes = [w.HWND, c.POINTER(w.RECT)]
    u.ClientToScreen.argtypes = [w.HWND, c.POINTER(w.POINT)]
    callback_type = c.WINFUNCTYPE(w.BOOL, w.HWND, w.LPARAM)
    u.EnumWindows.argtypes = [callback_type, w.LPARAM]
    owned = []
    @callback_type
    def visit(hwnd, _):
        owner = w.DWORD()
        u.GetWindowThreadProcessId(hwnd, c.byref(owner))
        if owner.value == pid and u.IsWindowVisible(hwnd):
            title = c.create_unicode_buffer(u.GetWindowTextLengthW(hwnd) + 1)
            u.GetWindowTextW(hwnd, title, len(title))
            owned.append((hwnd, title.value))
        return True
    u.EnumWindows(visit, 0)
    if not owned:
        return None
    if len(owned) != 1 or 'Civ13 DreamSeeker smoke' not in owned[0][1]:
        raise RuntimeError('Unexpected client window/prompt; no interaction attempted: ' + repr(owned))
    hwnd = owned[0][0]
    u.SetForegroundWindow(hwnd)
    if u.GetForegroundWindow() != hwnd:
        raise RuntimeError('Owned window cannot acquire foreground on this runner')
    rect, point = w.RECT(), w.POINT()
    if not u.GetClientRect(hwnd, c.byref(rect)) or not u.ClientToScreen(hwnd, c.byref(point)):
        raise RuntimeError('Owned client geometry unavailable')
    width, height = rect.right, rect.bottom
    if not (128 <= width <= 1024 and 128 <= height <= 1024):
        raise RuntimeError('Unexpected client dimensions')
    return ImageGrab.grab((point.x, point.y, point.x + width, point.y + height))


def run(output):
    if os.name != 'nt' or os.environ.get('GITHUB_ACTIONS') != 'true':
        raise RuntimeError('This smoke runner is restricted to disposable Windows GitHub CI')
    from windows import Adapter
    output.mkdir(parents=True, exist_ok=False)
    work = output.parent / (output.name + '-private-work')
    work.mkdir(exist_ok=False)
    evidence = {'scope': 'DreamSeeker feasibility only; no production composition acceptance',
                'head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
                'source_sha256': {p.name: digest(p) for p in ROOT.iterdir() if p.is_file()},
                'vendor': VENDOR, 'captures': {}, 'cleanup': []}
    adapters = []
    deadline = time.monotonic() + 150
    try:
        binary = install(work)
        fixture = work / 'fixture'
        fixture.mkdir()
        for name in ('fixture.dme', 'fixture.dm', 'fixture.dmf'):
            shutil.copyfile(ROOT / name, fixture / name)
        # An input sprite, not a screenshot or an acceptance reference.
        Image.new('RGBA', (32, 32), (255, 255, 255, 255)).save(fixture / 'tile.png')
        evidence['input_sprite_sha256'] = digest(fixture / 'tile.png')

        def launch(name, args, phase, visible=False):
            adapter = Adapter()
            adapter.preflight(LIMITS)
            adapter.open()
            adapters.append((adapter, None, phase))
            process = adapter.launch([str(binary / name)] + args, fixture, output, phase, visible)
            adapters[-1] = (adapter, process, phase)
            return adapter, process

        def watch():
            if time.monotonic() > deadline:
                raise RuntimeError('Total smoke deadline exceeded')
            for adapter, process, phase in adapters:
                if process is None or adapter.exited(process):
                    continue
                if adapter.memory(process.process) > LIMITS['process_private_bytes']:
                    raise RuntimeError('Owned process memory bound exceeded')
                if adapter.times(process)[1] > 60:
                    raise RuntimeError('Owned process CPU bound exceeded')
                if adapter.accounting().total != 1:
                    raise RuntimeError('Unexpected child process')
                socket_contract(adapter.sockets(process), phase == 'server', port if phase == 'server' else None)
            for path in output.glob('*.log'):
                if path.stat().st_size > 1024**2:
                    raise RuntimeError('Log bound exceeded')
            time.sleep(.1)

        port = None
        compiler, compiled = launch('dreammaker.exe', ['-max_errors', '0', 'fixture.dme'], 'compile')
        while not compiler.exited(compiled):
            watch()
        logs = ''.join(p.read_text(errors='replace') for p in output.glob('compile.*.log'))
        if compiler.finish(compiled)['exit_code'] != 0 or '0 errors, 0 warnings' not in logs or not (fixture/'fixture.dmb').is_file():
            raise RuntimeError('Fixture compilation failed')
        with socket.socket() as probe:
            probe.bind(('127.0.0.1', 0))
            port = probe.getsockname()[1]
        server, serving = launch('dreamdaemon.exe', server_arguments(port), 'server')
        while not (fixture/'ready.txt').exists():
            if server.exited(serving):
                raise RuntimeError('Server exited before readiness')
            watch()
        rows = server.sockets(serving)
        socket_contract(rows, True, port)
        if not any(r['state'] == 'listen' and r['port'] == port for r in rows):
            raise RuntimeError('Loopback-only server listener not proven')
        evidence['server_listener'] = rows
        client, playing = launch('dreamseeker.exe', [f'byond://127.0.0.1:{port}##guest'], 'client', True)
        for phase in ('red', 'blue'):
            previous = None
            while True:
                watch()
                if client.exited(playing) or server.exited(serving):
                    raise RuntimeError('Client/server exited before capture')
                image = desktop_capture(playing.pid)
                if not (fixture/'client.txt').exists():
                    continue
                receipt = (fixture/'client.txt').read_text().strip()
                if receipt != 'guest=1;version=516;build=1681':
                    raise RuntimeError('Non-guest or wrong-build client')
                if not (fixture/'phase.txt').exists() or (fixture/'phase.txt').read_text().strip() != phase:
                    continue
                if image is None or not pixel_contract(image, phase):
                    continue
                pixels = image.tobytes()
                if pixels == previous:
                    target = output / (phase + '.png')
                    image.save(target)
                    evidence['captures'][phase] = {'sha256': digest(target), 'size': image.size}
                    (fixture/(phase+'-captured.txt')).write_text('captured')
                    break
                previous = pixels
        evidence['client'] = receipt
        evidence['result'] = 'PASS native guest renderer smoke, composition UNTESTED'
    except Exception as error:
        evidence['error'] = str(error)
        raise
    finally:
        for adapter, process, phase in reversed(adapters):
            evidence['cleanup'].append({'phase': phase, **adapter.cleanup(process, 5)})
        (output/'receipt.json').write_text(json.dumps(evidence, indent=2))
        if any(not row['all_exited'] for row in evidence['cleanup']):
            raise RuntimeError('Owned process cleanup not confirmed')
    print(evidence['result'])


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    run(parser.parse_args().output.resolve())
