"""Render the village trailer take on a disposable hosted Windows runner.

Compiles the staged build, serves it from DreamDaemon on loopback, connects
one DreamSeeker guest (the camera) and records its map with ffmpeg's gdigrab
from the moment the scene is armed until the director reports it is done.
Windows only; the scene itself can be checked headless anywhere with
`DreamDaemon civ13.dmb -trusted -params headless=1`.

    python run_trailer.py --byond <byond/bin> --build <staged build> \
        --ffmpeg <ffmpeg.exe> --output <dir>
"""
import argparse
import ctypes
from ctypes import wintypes
import json
import os
from pathlib import Path
import socket
import subprocess
import time

TITLE = 'Civ13 village trailer'
SIZE = (960, 576)
FPS = 20
SCENE_TIMEOUT = 420


def log(message):
    print(f'[{time.strftime("%H:%M:%S")}] {message}', flush=True)


def isolated_env(root):
    env_root = root / 'environment'
    env_root.mkdir(exist_ok=True)
    system = os.environ['SystemRoot']
    keep = {k: os.environ[k] for k in ('SystemRoot', 'WINDIR', 'SystemDrive', 'NUMBER_OF_PROCESSORS',
                                       'PROCESSOR_ARCHITECTURE', 'COMPUTERNAME', 'USERNAME') if k in os.environ}
    keep.update(PATH=os.pathsep.join([str(Path(system) / 'System32'), system]),
                TEMP=str(env_root), TMP=str(env_root), APPDATA=str(env_root / 'AppData'),
                LOCALAPPDATA=str(env_root / 'LocalAppData'), USERPROFILE=str(env_root),
                ProgramData=str(env_root / 'ProgramData'))
    for key in ('APPDATA', 'LOCALAPPDATA', 'ProgramData'):
        Path(keep[key]).mkdir(exist_ok=True)
    return keep


def wait_for(path, timeout, procs=()):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if path.exists():
            return path.read_text(errors='replace').strip()
        for name, proc in procs:
            if proc.poll() is not None:
                raise RuntimeError(f'{name} exited with {proc.returncode} while waiting for {path.name}')
        stop = path.parent / 'trailer-stop.txt'
        if stop.exists():
            raise RuntimeError('scene stopped: ' + stop.read_text(errors='replace')[:400])
        time.sleep(0.1)
    raise RuntimeError(f'timed out waiting for {path.name}')


user32 = ctypes.WinDLL('user32', use_last_error=True) if os.name == 'nt' else None


def find_window(title, timeout=30):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        hwnd = user32.FindWindowW(None, title)
        if hwnd:
            return hwnd
        time.sleep(0.2)
    raise RuntimeError('DreamSeeker window not found')


def place_window(hwnd):
    # Top-left, topmost, then measure where the client (map) area landed.
    HWND_TOPMOST = -1
    user32.ShowWindow(hwnd, 9)  # SW_RESTORE
    user32.SetWindowPos(hwnd, HWND_TOPMOST, 0, 0, 0, 0, 0x0001 | 0x0040)  # NOSIZE | SHOWWINDOW
    user32.SetForegroundWindow(hwnd)
    time.sleep(0.5)
    rect = wintypes.RECT()
    user32.GetClientRect(hwnd, ctypes.byref(rect))
    origin = wintypes.POINT(0, 0)
    user32.ClientToScreen(hwnd, ctypes.byref(origin))
    return dict(x=origin.x, y=origin.y, width=rect.right - rect.left, height=rect.bottom - rect.top)


def screen_size():
    return user32.GetSystemMetrics(0), user32.GetSystemMetrics(1)


def run(byond, build, ffmpeg, output):
    output.mkdir(parents=True, exist_ok=False)
    env = isolated_env(output)
    result = dict(status='FAILED', screen=None, window=None)
    procs = []
    recorder = None
    try:
        log('compiling')
        with (output / 'compiler.log').open('w') as out:
            rc = subprocess.call([str(byond / 'dm.exe'), '-max_errors', '0', 'civ13.dme'], cwd=build,
                                 stdout=out, stderr=subprocess.STDOUT, env=env, timeout=600)
        compiler_log = (output / 'compiler.log').read_text(errors='replace')
        if rc != 0 or '0 errors' not in compiler_log:
            raise RuntimeError('compile failed:\n' + compiler_log[-2000:])
        with socket.socket() as s:
            s.bind(('127.0.0.1', 0))
            port = s.getsockname()[1]
        log(f'starting DreamDaemon on {port}')
        server = subprocess.Popen([str(byond / 'dd.exe'), 'civ13.dmb', str(port), '-ip', '127.0.0.1', '-invisible',
                                   '-trusted', '-nowebclient', '-params', f'intro_port={port}'], cwd=build, env=env,
                                  stdout=(output / 'server.log').open('w'), stderr=subprocess.STDOUT)
        procs.append(('DreamDaemon', server))
        wait_for(build / 'cloud-listening.txt', 180, procs)
        log('connecting the camera client')
        client = subprocess.Popen([str(byond / 'dreamseeker.exe'), f'byond://127.0.0.1:{port}##guest'], cwd=build,
                                  env=env, stdout=(output / 'client.log').open('w'), stderr=subprocess.STDOUT)
        procs.append(('DreamSeeker', client))
        result['client'] = wait_for(build / 'cloud-client.txt', 120, procs)
        hwnd = find_window(TITLE)
        result['screen'] = screen_size()
        wait_for(build / 'trailer-armed.txt', 180, procs)
        window = place_window(hwnd)
        result['window'] = window
        log(f'screen {result["screen"]}, map client area {window}')
        width, height = min(window['width'], SIZE[0]), min(window['height'], SIZE[1])
        width -= width % 2
        height -= height % 2
        log('recording')
        recorder = subprocess.Popen([str(ffmpeg), '-hide_banner', '-loglevel', 'warning', '-y',
                                     '-f', 'gdigrab', '-framerate', str(FPS), '-draw_mouse', '0',
                                     '-offset_x', str(window['x']), '-offset_y', str(window['y']),
                                     '-video_size', f'{width}x{height}', '-i', 'desktop',
                                     '-c:v', 'libx264', '-preset', 'ultrafast', '-crf', '8', '-pix_fmt', 'yuv444p',
                                     str(output / 'take.mkv')],
                                    stdin=subprocess.PIPE, stdout=(output / 'ffmpeg.log').open('w'),
                                    stderr=subprocess.STDOUT)
        time.sleep(1.0)
        if recorder.poll() is not None:
            raise RuntimeError('ffmpeg exited early: ' + (output / 'ffmpeg.log').read_text(errors='replace')[-1500:])
        (build / 'trailer-capturing.txt').write_text('capturing\n')
        started = time.monotonic()
        wait_for(build / 'trailer-done.txt', SCENE_TIMEOUT, procs)
        result['scene_seconds'] = time.monotonic() - started
        time.sleep(1.0)
        result['status'] = 'CAPTURED'
    except BaseException as error:
        result['error'] = str(error)[:4000]
        log('ERROR: ' + result['error'])
        if os.name == 'nt':
            try:
                hwnd = user32.FindWindowW(None, TITLE)
                if hwnd and recorder is None:
                    result['window_on_error'] = place_window(hwnd)
            except Exception:
                pass
    finally:
        if recorder is not None and recorder.poll() is None:
            try:
                recorder.communicate(b'q', timeout=30)
            except Exception:
                recorder.kill()
        for name, proc in reversed(procs):
            if proc.poll() is None:
                proc.kill()
                try:
                    proc.wait(10)
                except Exception:
                    pass
        for name in ('trailer-log.txt', 'trailer-timeline.json', 'trailer-runtimes.txt', 'trailer-stop.txt',
                     'cloud-client.txt'):
            if (build / name).exists():
                (output / name).write_bytes((build / name).read_bytes())
        (output / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
    return result


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--byond', type=Path, required=True)
    p.add_argument('--build', type=Path, required=True)
    p.add_argument('--ffmpeg', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    a = p.parse_args()
    r = run(a.byond.resolve(), a.build.resolve(), a.ffmpeg.resolve(), a.output.resolve())
    print(r['status'])
    raise SystemExit(0 if r['status'] == 'CAPTURED' else 1)
