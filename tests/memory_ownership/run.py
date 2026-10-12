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
import re
from ctypes import wintypes


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--byond-bin', type=Path, required=True)
    p.add_argument('--case', choices=('callback', 'turf', 'lifecycle', 'pool', 'benchmark', 'memory', 'collector', 'triage'))
    p.add_argument('--output', type=Path)
    p.add_argument('--baseline-scheduler', action='store_true')
    p.add_argument('--negative-control', choices=('cancel-retention','deletion-state','pool-cleanup','pool-cap','pool-global','pool-idle','hard-reference','startup','ref-identity','hard-now','let-live','gc-soft-budget','gc-hard-budget','triage-slots','triage-identity','triage-lists','triage-metadata'))
    a = p.parse_args()
    root = Path(__file__).resolve().parents[2]
    out = a.output or Path(tempfile.mkdtemp(prefix='civ13-memory-ownership-'))
    if out.exists() and any(out.iterdir()):
        raise RuntimeError('Use fresh evidence storage')
    out.mkdir(parents=True, exist_ok=True)
    head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
    (out/'metadata.json').write_text(json.dumps({'head_sha': head, 'case': a.case, 'byond': '516.1681', 'scope': 'isolated production GC/pool/callproc', 'baseline_scheduler': a.baseline_scheduler, 'negative_control': a.negative_control}))
    (out/'dirty.patch').write_bytes(subprocess.check_output(['git', 'diff', 'HEAD'], cwd=root))
    source = (root/'tests/memory_ownership/probe.dm').read_text().replace('../../code/', root.as_posix()+'/code/')
    source += '\n' + (root/'tests/memory_ownership/collector.dm').read_text()
    source += '\n' + (root/'tests/gc_triage/probe.dm').read_text()
    if a.baseline_scheduler:
        if a.negative_control:
            raise RuntimeError('Do not combine historical baseline with mutation controls')
        original = 'f556e39b93fc97f41020b2d8c5f2abed63fab497'
        body = subprocess.check_output(['git','show', original+':code/processes/callproc.dm'], cwd=root, text=True)
        candidate = out/'baseline_scheduler.dm'
        candidate.write_text(body)
        source = source.replace(root.as_posix()+'/code/processes/callproc.dm', candidate.as_posix())
    expected = None
    if a.negative_control:
        controls = {
            'triage-slots': ('code/processes/gc_reference_triage.dm', '#define GC_TRIAGE_REFERENCE_SLOTS 256', '#define GC_TRIAGE_REFERENCE_SLOTS 100000', 'targeted inspection stops at its slot cap'),
            'triage-identity': ('code/processes/gc_reference_triage.dm', 'target.gcDestroyed != destroyed[ref_id]', 'FALSE', 'targeted inspection rejects mismatched queue identity'),
            'triage-lists': ('code/processes/gc_reference_triage.dm', '#define GC_TRIAGE_REFERENCE_LISTS 32', '#define GC_TRIAGE_REFERENCE_LISTS 100000', 'targeted inspection stops at its list cap'),
            'triage-metadata': ('code/processes/gc_outcome_triage.dm', '#define GC_TRIAGE_PENDING_LIMIT 1024', '#define GC_TRIAGE_PENDING_LIMIT 100000', 'pending outcome metadata stops at exact cap'),
            'gc-soft-budget': ('code/processes/garbage.dm', '\t\tvar/refID = destroyed[1]', '\t\tif (remaining_force_dels <= 0)\n\t\t\tbreak\n\t\tvar/refID = destroyed[1]', 'soft records drain after forced budget without exceeding candidate cap'),
            'gc-hard-budget': ('code/processes/garbage.dm', 'if (remaining_force_dels <= 0)', 'if (remaining_force_dels <= -100000)', 'next forced target waits after the hard-delete cap'),
            'cancel-retention': ('code/processes/callproc.dm', 'C.args = null', '// C.args deliberately retained', 'cancel clears helper target and arguments'),
            'deletion-state': ('code/processes/garbage.dm', 'A.gc_destroyed = A.gcDestroyed', 'A.gc_destroyed = 0', 'reentry cleans once and deletion markers agree'),
            'pool-cleanup': ('code/_helpers/datum_pool.dm', 'D.ResetVars()\n\tD.gcDestroyed', 'D.Destroy()\n\tD.ResetVars()\n\tD.gcDestroyed', 'pooled deletion cleans once and remains retired'),
            'pool-cap': ('code/_helpers/datum_pool.dm', '>= ATOM_POOL_COUNT', '> ATOM_POOL_COUNT', 'pool respects exact per-type cap'),
            'pool-global': ('code/_helpers/datum_pool.dm', 'pooled_count >= DATUM_POOL_TOTAL_COUNT', 'pooled_count >= 100000', 'global pool ownership stays capped'),
            'pool-idle': ('code/_helpers/datum_pool.dm', 'if (D)\n\t\tpool_idle -= D', 'if (D)\n\t\t// stale idle ownership retained', 'reuse releases idle bookkeeping and resets state'),
            'hard-reference': ('code/processes/garbage.dm', 'processes.garbage.hard_references["\\ref[A]"] = A', '// missing hard owner', 'hard-delete hint retains its queued target'),
            'startup': ('code/processes/garbage.dm', 'AddTrash(A)', 'qdel(A)', 'startup queue becomes stamped without repeating cleanup'),
            'ref-identity': ('code/processes/garbage.dm', 'A && A.gcDestroyed == GCd_at_time', 'A', 'timestamp guard preserves a live reused identity'),
            'hard-now': ('code/processes/garbage.dm', '\t\tif (QDEL_HINT_HARDDEL_NOW)\n', '\t\tif (999)\n', 'hard-delete-now hint deletes immediately'),
            'let-live': ('code/processes/garbage.dm', '\t\tA.gc_destroyed = 0\n\t\treturn', '\t\tA.gc_destroyed = 1\n\t\treturn', 'let-me-live preserves live state and location'),
        }
        relative, before, after, expected = controls[a.negative_control]
        body = (root/relative).read_text()
        # A generated copy must still resolve includes beside its production source.
        body = re.sub(r'#include "([^"/\\]+\.dm)"',
                      lambda m: '#include "' + (root/relative).parent.joinpath(m[1]).as_posix() + '"', body)
        if before not in body:
            raise RuntimeError('Negative control anchor missing')
        altered = out/'negative.dm'
        altered.write_text(body.replace(before, after, 1))
        source = source.replace((root/relative).as_posix(), altered.as_posix())
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
    params = []
    if a.case:
        params.append('case='+a.case)
    if a.case not in ('callback', 'turf', 'benchmark', 'memory', 'collector', 'triage'):
        params.append('policy_tests=1')
    if params:
        command += ['-params', '&'.join(params)]
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
    if run.returncode or any(marker in (runtime + (out/'daemon.log').read_text(errors='replace')).lower() for marker in ('runtime error:', 'bad ref', 'badref', '## bug:')):
        raise RuntimeError('Native runtime failed')
    if expected:
        if not result.startswith('FAIL: '+expected):
            raise RuntimeError('Negative control did not fail at its intended assertion')
        print('PASS: negative control detected at intended assertion')
    elif not result.startswith('PASS:'):
        raise RuntimeError('Native assertions failed')


if __name__ == '__main__':
    main()
