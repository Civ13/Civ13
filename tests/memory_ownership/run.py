"""Bounded native fixture, no production world or network effects."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import ctypes
from ctypes import wintypes


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--byond-bin', type=Path, required=True)
    p.add_argument('--case', choices=('callback', 'turf', 'lifecycle', 'pool', 'benchmark', 'memory'))
    p.add_argument('--output', type=Path)
    p.add_argument('--scheduler-candidate', action='store_true')
    a = p.parse_args()
    root = Path(__file__).resolve().parents[2]
    out = a.output or Path(tempfile.mkdtemp(prefix='civ13-memory-ownership-'))
    if out.exists() and any(out.iterdir()):
        raise RuntimeError('Use fresh evidence storage')
    out.mkdir(parents=True, exist_ok=True)
    head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
    (out/'metadata.json').write_text(json.dumps({'head_sha': head, 'case': a.case, 'byond': '516.1681', 'scope': 'isolated production GC/pool/callproc', 'scheduler_candidate': a.scheduler_candidate}))
    (out/'dirty.patch').write_bytes(subprocess.check_output(['git', 'diff', 'HEAD'], cwd=root))
    source = (root/'tests/memory_ownership/probe.dm').read_text().replace('../../code/', root.as_posix()+'/code/')
    if a.scheduler_candidate:
        candidate = root/'tests/memory_ownership/scheduler_candidate.dm'
        source = source.replace(root.as_posix()+'/code/processes/callproc.dm', candidate.as_posix())
    probe = out/'probe.dme'
    probe.write_text(source)
    win = os.name == 'nt'
    flags = subprocess.CREATE_NO_WINDOW if win else 0
    build = subprocess.run([str(a.byond_bin/('dm.exe' if win else 'DreamMaker')), '-max_errors', '0', str(probe)], cwd=out, capture_output=True, text=True, timeout=60, creationflags=flags)
    text = build.stdout + build.stderr
    (out/'compile.log').write_text(text)
    print(text, flush=True)
    if build.returncode or '516.1681' not in text or '0 errors, 0 warnings' not in text:
        raise RuntimeError('Pinned clean compile failed')
    command = [str(a.byond_bin/('dd.exe' if win else 'DreamDaemon')), str(out/'probe.dmb')]
    if win:
        command += ['-invisible', '-close']
    command += ['-safe', '-log', 'runtime.log']
    if a.case:
        command += ['-params', 'case='+a.case]
    with (out/'daemon.log').open('w') as log:
        run = subprocess.Popen(command, cwd=out, stdout=log, stderr=subprocess.STDOUT, creationflags=flags)
        deadline = time.monotonic() + 60
        sample = None
        while run.poll() is None:
            if time.monotonic() > deadline:
                run.kill()
                run.wait()
                raise TimeoutError('Native fixture exceeded 60 seconds')
            if win and (out/'result.txt').exists() and sample is None:
                class Counters(ctypes.Structure):
                    _fields_ = [('cb', wintypes.DWORD), ('PageFaultCount', wintypes.DWORD)] + [(name, ctypes.c_size_t) for name in ('PeakWorkingSetSize', 'WorkingSetSize', 'QuotaPeakPagedPoolUsage', 'QuotaPagedPoolUsage', 'QuotaPeakNonPagedPoolUsage', 'QuotaNonPagedPoolUsage', 'PagefileUsage', 'PeakPagefileUsage', 'PrivateUsage')]
                counters = Counters()
                counters.cb = ctypes.sizeof(counters)
                api = ctypes.WinDLL('psapi', use_last_error=True).GetProcessMemoryInfo
                api.argtypes = [wintypes.HANDLE, ctypes.POINTER(Counters), wintypes.DWORD]
                if not api(wintypes.HANDLE(int(run._handle)), ctypes.byref(counters), counters.cb):
                    raise ctypes.WinError(ctypes.get_last_error())
                sample = {'private_bytes': counters.PrivateUsage, 'rss_bytes': counters.WorkingSetSize}
                (out/'process-memory.json').write_text(json.dumps(sample))
            time.sleep(0.01)
    result = (out/'result.txt').read_text()
    runtime = (out/'runtime.log').read_text(errors='replace')
    print(result.strip())
    if (out/'benchmark.txt').exists():
        print((out/'benchmark.txt').read_text().strip())
    print('Evidence:', out)
    if sample:
        print('Process memory:', sample)
    if run.returncode or not result.startswith('PASS:') or 'runtime error:' in runtime:
        raise RuntimeError('Native assertions failed')


if __name__ == '__main__':
    main()
