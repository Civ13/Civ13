"""Offline native production area-turf parity and bounded candidate-list benchmark."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time
import uuid

BASELINE = 'e3c8d02f31f1a23c1320eaec949fb4af56e964f3'
HELPER = 'code/_helpers/areas.dm'

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--byond-bin', type=Path, required=True)
    p.add_argument('--output', type=Path, default=Path(tempfile.gettempdir()) / ('civ13-season-filter-' + uuid.uuid4().hex + '.json'))
    p.add_argument('--size', choices=['small', 'largest'], default='small')
    p.add_argument('--large', action='store_true')
    p.add_argument('--negative-control', action='store_true')
    a = p.parse_args()
    repo = Path(__file__).resolve().parents[2]
    baseline = subprocess.check_output(['git', 'show', BASELINE + ':' + HELPER], cwd=repo, text=True)
    current = (repo / HELPER).read_text()
    def body(s):
        return re.search(r'^/proc/get_area_turfs\([\s\S]*?(?=^/proc/pick_area_turf)', s, re.M).group()
    candidate = body(current)
    assert 'turf_type' in candidate, 'Missing production filter'
    if a.negative_control:
        candidate, count = re.subn(r'\t{4}if \(turf_type && !istype\(T, turf_type\)\)\n\t{5}continue\n', '', candidate)
        assert count == 1, 'Negative control must remove exactly one filter'
    seasonal = (repo / 'code/game/objects/map_metadata/_map_metadata.dm').read_text()
    seasonal = seasonal[seasonal.index('/obj/map_metadata/proc/seasons('):seasonal.index('//loads faction-specific recipes')]
    calls = re.findall(r'for\s*\(var/(turf[^ ]+)/(\w+) in get_area_turfs\(([^\n]+)\)\)', seasonal)
    assert len(calls) == 27, 'Missing seasonal passes'
    for turf, _, args in calls:
        assert args.endswith(', null, /' + turf), 'Unfiltered or mismatched seasonal pass: ' + turf
    old_seasonal = subprocess.check_output(['git', 'show', BASELINE + ':code/game/objects/map_metadata/_map_metadata.dm'], cwd=repo, text=True)
    old_seasonal = old_seasonal[old_seasonal.index('/obj/map_metadata/proc/seasons('):old_seasonal.index('//loads faction-specific recipes')]
    normalized = re.sub(r'(get_area_turfs\([^\n]+?), null, /turf[^)]+\)', r'\1)', seasonal)
    assert normalized == old_seasonal, 'Season behavior changed beyond candidate filtering'
    dimensions = (660, 550) if a.large or a.size == 'largest' else (64, 48)
    source = body(baseline).replace('get_area_turfs(', 'baseline_area_turfs(') + candidate
    source += (repo / 'code/_helpers/functional.dm').read_text()
    probe = Path(__file__).with_name('probe.dm').read_text()
    patch = subprocess.check_output(['git', 'diff', 'HEAD'], cwd=repo)
    a.output.parent.mkdir(parents=True, exist_ok=True)
    if a.output.exists(): p.error('Output must be fresh')
    logs = a.output.with_suffix('.logs')
    logs.mkdir(exist_ok=False)
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    with tempfile.TemporaryDirectory(prefix='civ13-season-filter-') as temp:
        root = Path(temp)
        (root / 'probe.dm').write_text(probe)
        (root / 'production.dm').write_text(source)
        (root / 'probe.dme').write_text(f'#define TRUE 1\n#define FALSE 0\n#define WIDTH {dimensions[0]}\n#define HEIGHT {dimensions[1]}\n#define CRASH(message) throw new /exception(message)\n#include "probe.dm"\n#include "production.dm"\n')
        for generated in ('probe.dm', 'production.dm', 'probe.dme'):
            (logs / generated).write_bytes((root / generated).read_bytes())
        dm = a.byond_bin / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
        dd = a.byond_bin / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
        build = subprocess.run([str(dm), '-max_errors', '0', 'probe.dme'], cwd=root, capture_output=True, text=True, timeout=60, creationflags=flags)
        log = build.stdout + build.stderr
        (logs / 'compile.log').write_text(log)
        if build.returncode or '516.1681' not in log or '0 errors, 0 warnings' not in log: raise SystemExit(log)
        start = time.monotonic()
        if os.name != 'nt':
            import resource
            cpu_start = resource.getrusage(resource.RUSAGE_CHILDREN)
        command = [str(dd), 'probe.dmb'] + (['-invisible', '-close'] if os.name == 'nt' else []) + ['-safe', '-log', 'runtime.log']
        process = subprocess.Popen(command, cwd=root, stdout=subprocess.PIPE, stderr=subprocess.PIPE, creationflags=flags)
        try:
            stdout, stderr = process.communicate(timeout=180)
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()
        cpu_seconds = None
        if os.name == 'nt':
            import ctypes
            times = (ctypes.c_ulonglong * 4)()
            if ctypes.windll.kernel32.GetProcessTimes(ctypes.c_void_p(int(process._handle)), ctypes.byref(times, 0), ctypes.byref(times, 8), ctypes.byref(times, 16), ctypes.byref(times, 24)):
                cpu_seconds = (times[2] + times[3]) / 10000000
        else:
            cpu_end = resource.getrusage(resource.RUSAGE_CHILDREN)
            cpu_seconds = cpu_end.ru_utime + cpu_end.ru_stime - cpu_start.ru_utime - cpu_start.ru_stime
        elapsed = time.monotonic() - start
        log = (root / 'runtime.log').read_text(errors='replace') + (stdout + stderr).decode(errors='replace')
        (logs / 'runtime.log').write_text(log)
        if process.returncode or re.search(r'runtime error|Runtime in|Bad ref|Bad loc|Cannot read null|Cannot execute null|PORT_OPEN', log, re.I): raise SystemExit(log)
        result = json.loads((root / 'result.json').read_text())
    result.update(head_sha=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo, text=True).strip(), baseline_sha=BASELINE, dirty_patch_sha256=hashlib.sha256(patch).hexdigest(), helper_sha256=hashlib.sha256(current.encode()).hexdigest(), compiled_sha256=hashlib.sha256(source.encode()).hexdigest(), probe_sha256=hashlib.sha256(probe.encode()).hexdigest(), dimensions=[*dimensions, 1], byond='516.1681', platform=os.name, negative_control=a.negative_control, daemon_elapsed_seconds=elapsed, process_cpu_seconds=cpu_seconds, seasonal_type_guards=len(calls))
    (logs / 'dirty.patch').write_bytes(patch)
    a.output.write_text(json.dumps(result, indent=2))
    assert result['cycles'] == 16 and len(result['samples']) == 24 and result['comparisons'] >= 50, 'Incomplete fixture'
    if a.negative_control:
        assert result['bound_failures'] and not result['parity_failures'], 'Negative control missed bound or failed wrong contract'
    else:
        assert not result['bound_failures'] and not result['parity_failures'], 'Fixture parity/bound failure'
    for mode in ('sparse', 'dominant', 'unfiltered'):
        samples = [x for x in result['samples'] if x['mode'] == mode]
        assert len({x['visits'] for x in samples}) == 1, 'Benchmark skipped visits'
    print(json.dumps({k: result[k] for k in ('cycles', 'comparisons', 'parity_failures', 'bound_failures', 'baseline_slots', 'candidate_slots', 'daemon_elapsed_seconds', 'negative_control')}))

if __name__ == '__main__': main()


