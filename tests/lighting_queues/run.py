"""Native queue benchmark using unchanged production process bodies, offline."""
import argparse, json, os, subprocess, tempfile, time
from pathlib import Path

BASELINE = '4e6211fe1a50519f91104fa32da32990baf0f4d4'
def main():
    p = argparse.ArgumentParser()
    p.add_argument('--byond-bin', type=Path, required=True)
    p.add_argument('--baseline', action='store_true')
    p.add_argument('--size', type=int, default=20000)
    p.add_argument('--output', type=Path, required=True)
    a = p.parse_args()
    root = Path(__file__).resolve().parents[2]
    with tempfile.TemporaryDirectory(prefix='civ13-lighting-') as tmp:
        out = Path(tmp)
        for name in ('overlays', 'sources'):
            rel = f'code/processes/lighting/{name}.dm'
            text = subprocess.check_output(['git', 'show', f'{BASELINE}:{rel}'], cwd=root, text=True) if a.baseline else (root/rel).read_text()
            (out/f'{name}.dm').write_text(text)
        (out/'probe.dm').write_text((root/'tests/lighting_queues/probe.dm').read_text())
        (out/'probe.dme').write_text('#include "probe.dm"\n#include "overlays.dm"\n#include "sources.dm"\n')
        flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
        dm = a.byond_bin/('dm.exe' if os.name == 'nt' else 'DreamMaker')
        dd = a.byond_bin/('dd.exe' if os.name == 'nt' else 'DreamDaemon')
        build = subprocess.run([str(dm), 'probe.dme'], cwd=out, capture_output=True, text=True, creationflags=flags)
        print(build.stdout)
        if build.returncode or '0 errors, 0 warnings' not in build.stdout: raise RuntimeError('Compilation failed')
        with (out/'daemon.log').open('w') as log:
            proc = subprocess.Popen([str(dd), 'probe.dmb', '-invisible', '-close', '-safe', '-params', f'size={a.size}', '-log', 'runtime.log'], cwd=out, stdout=log, stderr=log, creationflags=flags)
            peak = 0
            samples = []
            try:
                import ctypes
                class Counters(ctypes.Structure):
                    _fields_ = [('cb',ctypes.c_ulong),('faults',ctypes.c_ulong),('peakws',ctypes.c_size_t),('ws',ctypes.c_size_t),('ppp',ctypes.c_size_t),('pp',ctypes.c_size_t),('pnp',ctypes.c_size_t),('np',ctypes.c_size_t),('page',ctypes.c_size_t),('peakpage',ctypes.c_size_t),('private',ctypes.c_size_t)]
                ctypes.windll.kernel32.OpenProcess.restype = ctypes.c_void_p
                handle = ctypes.windll.kernel32.OpenProcess(0x410,False,proc.pid)
                deadline = time.monotonic()+120
                while proc.poll() is None:
                    if time.monotonic()>deadline: raise RuntimeError('Daemon timeout')
                    c = Counters(); c.cb=ctypes.sizeof(c)
                    ctypes.windll.psapi.GetProcessMemoryInfo(ctypes.c_void_p(handle),ctypes.byref(c),c.cb)
                    samples.append(c.private); peak=max(peak,c.private)
                    time.sleep(.02)
                ctypes.windll.kernel32.CloseHandle(ctypes.c_void_p(handle))
            finally:
                if proc.poll() is None: proc.kill(); proc.wait()
        log = (out/'runtime.log').read_text(errors='replace')
        if proc.returncode or 'PASS' not in log or any(s in log for s in ('runtime error','Runtime in','Bad ref')): raise RuntimeError(log)
        rows = [json.loads(x) for x in (out/'results.jsonl').read_text().splitlines()]
        report = dict(head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(), baseline=BASELINE if a.baseline else None, size=a.size, rows=rows, peak_private_bytes=peak, final_private_bytes=samples[-1] if samples else None, runtime=log)
        a.output.parent.mkdir(parents=True,exist_ok=True); a.output.write_text(json.dumps(report,indent=2))
        print(json.dumps(report,indent=2))
if __name__ == '__main__': main()
