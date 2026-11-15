"""Records glide_rate.dme in a real Dream Seeker client. Windows only.
py -3 run_glide_rate.py --byond-bin <bin> --ffmpeg <ffmpeg.exe> --output <new folder>
"""
import argparse, ctypes, shutil, socket, subprocess, sys, time
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from client_check import client_window, window_title, free_port  # noqa: E402

def main():
    p = argparse.ArgumentParser()
    p.add_argument('--byond-bin', type=Path, required=True)
    p.add_argument('--ffmpeg', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--seconds', type=int, default=48)
    a = p.parse_args()
    try:
        ctypes.windll.shcore.SetProcessDpiAwareness(2)
    except (AttributeError, OSError):
        pass
    here = Path(__file__).resolve().parent
    out = a.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    for name in ('glide_rate.dm', 'glide_rate.dme', 'glidetest.dmi'):
        shutil.copy(here / name, out / name)
    b = subprocess.run([str(a.byond_bin / 'dm.exe'), 'glide_rate.dme'], cwd=out, capture_output=True, text=True)
    (out / 'compile.log').write_text(b.stdout + b.stderr)
    if '0 errors' not in b.stdout + b.stderr:
        raise SystemExit('compile failed')
    port = free_port()
    dd = subprocess.Popen([str(a.byond_bin / 'dd.exe'), 'glide_rate.dmb', str(port), '-trusted', '-ip', '127.0.0.1', '-log', 'dd.log'], cwd=out)
    time.sleep(4)
    ds = subprocess.Popen([str(a.byond_bin / 'dreamseeker.exe'), f'byond://127.0.0.1:{port}'])
    try:
        hwnd = None
        for _ in range(60):
            time.sleep(1)
            hwnd, rect = client_window(ds.pid)
            if hwnd:
                break
        user32 = ctypes.windll.user32
        user32.ShowWindow(ctypes.c_void_p(hwnd), 9)
        user32.MoveWindow(ctypes.c_void_p(hwnd), 40, 40, 1200, 520, True)
        user32.SetForegroundWindow(ctypes.c_void_p(hwnd))
        time.sleep(1)
        rec = subprocess.run([str(a.ffmpeg), '-y', '-loglevel', 'error', '-f', 'gdigrab', '-framerate', '50', '-draw_mouse', '0',
                              '-i', 'title=' + window_title(hwnd), '-t', str(a.seconds), '-vf', 'crop=trunc(iw/2)*2:trunc(ih/2)*2',
                              '-c:v', 'libx264', '-crf', '18', '-preset', 'ultrafast', '-pix_fmt', 'yuv420p', str(out / 'glide_rate.mp4')],
                             capture_output=True, text=True)
        (out / 'ffmpeg.log').write_text(rec.stderr)
    finally:
        for proc in (ds, dd):
            if proc.poll() is None:
                proc.kill()
    print('recorded', out / 'glide_rate.mp4')

if __name__ == '__main__':
    main()
