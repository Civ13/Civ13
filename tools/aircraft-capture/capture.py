"""Native DreamSeeker stills of an aircraft flight on a hosted Windows runner.

Appends capture_probe.dm to a copy of civ13.dme (Gaia), serves it from
DreamDaemon on loopback, connects one DreamSeeker guest and takes a PNG of the
client window whenever the probe asks for one (shot-<name>.req). Windows only.

    python capture.py --byond <byond/bin> --game <checkout> --ffmpeg <ffmpeg.exe> --output <dir>
"""
import argparse
import ctypes
from ctypes import wintypes
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import time

SIZE = (1280, 1000)
TIMEOUT = 1500


def log(message):
    print(f'[{time.strftime("%H:%M:%S")}] {message}', flush=True)


user32 = ctypes.WinDLL('user32', use_last_error=True) if os.name == 'nt' else None


def process_windows(pid):
    found = []
    buf = ctypes.create_unicode_buffer(256)

    @ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
    def visit(hwnd, _):
        owner = wintypes.DWORD()
        user32.GetWindowThreadProcessId(hwnd, ctypes.byref(owner))
        if owner.value == pid and user32.IsWindowVisible(hwnd):
            rect = wintypes.RECT()
            user32.GetWindowRect(hwnd, ctypes.byref(rect))
            user32.GetWindowTextW(hwnd, buf, 256)
            found.append(((rect.right - rect.left) * (rect.bottom - rect.top), hwnd, buf.value))
        return True

    user32.EnumWindows(visit, 0)
    return sorted(found, reverse=True)


def place(hwnd):
    user32.ShowWindow(hwnd, 3)  # SW_MAXIMIZE
    user32.SetForegroundWindow(hwnd)
    time.sleep(1.0)
    rect = wintypes.RECT()
    user32.GetWindowRect(hwnd, ctypes.byref(rect))
    # A maximised window overhangs the desktop by its border; gdigrab refuses that.
    sw, sh = user32.GetSystemMetrics(0), user32.GetSystemMetrics(1)
    x, y = max(rect.left, 0), max(rect.top, 0)
    return dict(x=x, y=y, width=min(rect.right, sw) - x, height=min(rect.bottom, sh) - y)


def stage(game):
    # The runner checkout is disposable: build the probe in place.
    dme = (game / 'civ13.dme').read_text(encoding='utf-8-sig')
    shutil.copy2(Path(__file__).with_name('capture_probe.dm'), game / 'capture_probe.dm')
    (game / 'civ13.dme').write_text(dme + '\n#include "capture_probe.dm"\n', encoding='utf-8')
    return game


def run(byond, game, ffmpeg, output):
    output.mkdir(parents=True, exist_ok=False)
    shots = output / 'shots'
    shots.mkdir()
    result = dict(status='FAILED', shots=[])
    procs = []
    build = game
    try:
        build = stage(game)
        log('compiling')
        with (output / 'compiler.log').open('w') as out:
            rc = subprocess.call([str(byond / 'dm.exe'), '-max_errors', '0', 'civ13.dme'], cwd=build,
                                 stdout=out, stderr=subprocess.STDOUT, timeout=900)
        text = (output / 'compiler.log').read_text(errors='replace')
        if rc != 0 or '0 errors' not in text:
            raise RuntimeError('compile failed:\n' + text[-2000:])
        with socket.socket() as s:
            s.bind(('127.0.0.1', 0))
            port = s.getsockname()[1]
        log(f'starting DreamDaemon on {port}')
        server = subprocess.Popen([str(byond / 'dd.exe'), 'civ13.dmb', str(port), '-ip', '127.0.0.1', '-invisible',
                                   '-trusted', '-params', 'tested_commit=capture'], cwd=build,
                                  stdout=(output / 'server.log').open('w'), stderr=subprocess.STDOUT)
        procs.append(('DreamDaemon', server))
        deadline = time.monotonic() + TIMEOUT
        while not (build / 'cloud-ready.txt').exists():
            if server.poll() is not None:
                raise RuntimeError(f'DreamDaemon exited {server.returncode} before the scene was ready')
            if time.monotonic() > deadline:
                raise RuntimeError('scene never became ready')
            time.sleep(1)
        log('connecting DreamSeeker')
        client = subprocess.Popen([str(byond / 'dreamseeker.exe'), f'byond://127.0.0.1:{port}##guest'], cwd=build,
                                  stdout=(output / 'client.log').open('w'), stderr=subprocess.STDOUT)
        procs.append(('DreamSeeker', client))
        window = None
        while not (build / 'capture-done.txt').exists():
            if time.monotonic() > deadline:
                raise RuntimeError('capture timed out')
            for name, proc in procs:
                if proc.poll() is not None:
                    raise RuntimeError(f'{name} exited {proc.returncode}')
            for req in sorted(build.glob('shot-*.req')):
                name = req.stem[len('shot-'):]
                wins = process_windows(client.pid)
                log(f'windows: {[(w[0], w[2]) for w in wins]}')
                if wins:
                    window = place(wins[0][1])
                target = shots / f'{name}.png'
                args = [str(ffmpeg), '-hide_banner', '-loglevel', 'error', '-y', '-f', 'gdigrab', '-framerate', '5', '-draw_mouse', '0']
                if window:
                    args += ['-offset_x', str(window['x']), '-offset_y', str(window['y']),
                             '-video_size', f'{window["width"] - window["width"] % 2}x{window["height"] - window["height"] % 2}']
                args += ['-i', 'desktop', '-frames:v', '1', str(target)]
                with (output / 'ffmpeg.log').open('a') as flog:
                    flog.write(' '.join(args) + '\n')
                    flog.flush()
                    subprocess.call(args, stdout=flog, stderr=subprocess.STDOUT, timeout=60)
                    if not target.exists():
                        # Whole desktop as a fallback.
                        subprocess.call([str(ffmpeg), '-hide_banner', '-loglevel', 'error', '-y', '-f', 'gdigrab',
                                         '-framerate', '5', '-i', 'desktop', '-frames:v', '1', str(target)],
                                        stdout=flog, stderr=subprocess.STDOUT, timeout=60)
                log(f'shot {name}: {target.exists()} {window}')
                result['shots'].append(dict(name=name, ok=target.exists(), window=window))
                req.unlink()
                (build / f'shot-{name}.done').write_text('done')
            time.sleep(0.3)
        result['status'] = 'CAPTURED'
    except BaseException as error:
        result['error'] = str(error)[:4000]
        log('ERROR: ' + result['error'])
        try:
            subprocess.call([str(ffmpeg), '-hide_banner', '-loglevel', 'error', '-y', '-f', 'gdigrab', '-i', 'desktop',
                             '-frames:v', '1', str(output / 'desktop-on-error.png')], timeout=60)
        except Exception:
            pass
    finally:
        for name, proc in reversed(procs):
            if proc.poll() is None:
                proc.kill()
        for name in ('result.json', 'cloud-ready.txt'):
            if (build / name).exists():
                shutil.copy2(build / name, output / ('probe-' + name))
        for logs in (build / 'data' / 'logs',):
            if logs.exists():
                shutil.copytree(logs, output / 'game-logs', dirs_exist_ok=True)
        (output / 'capture.json').write_text(json.dumps(result, indent=2) + '\n')
    return result


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--byond', type=Path, required=True)
    p.add_argument('--game', type=Path, required=True)
    p.add_argument('--ffmpeg', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    a = p.parse_args()
    r = run(a.byond.resolve(), a.game.resolve(), a.ffmpeg.resolve(), a.output.resolve())
    print(r['status'])
    raise SystemExit(0 if r['status'] == 'CAPTURED' else 1)
