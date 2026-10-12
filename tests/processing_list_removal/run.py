"""Pinned native production removal semantics; immutable baseline and unsafe control."""
import argparse
import hashlib
import json
import os
import platform
from pathlib import Path
import re
import subprocess
import statistics
import tempfile

BASELINE = 'aa675de6dbade0f3740c516dc4b5945c5c9a43c7'
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--byond-bin', required=True, type=Path)
parser.add_argument('--baseline', action='store_true')
parser.add_argument('--negative-control', action='store_true')
parser.add_argument('--guarded-control', action='store_true')
parser.add_argument('--remove-candidate', action='store_true')
parser.add_argument('--benchmark', action='store_true')
parser.add_argument('--evidence-dir', type=Path)
args = parser.parse_args()
if sum((args.baseline, args.negative_control, args.guarded_control, args.benchmark, args.remove_candidate)) > 1:
    parser.error('Choose one mode')
repo = Path(__file__).resolve().parents[2]
paths = ['code/processes/___defines.dm', 'code/processes/obj.dm']
raw = [subprocess.check_output(['git', 'show', BASELINE + ':' + p], cwd=repo, text=True)
       if args.baseline else (repo / p).read_text() for p in paths]
defines, objects = raw
if args.guarded_control:
    defines, count = re.subn(r'^#define PROCESS_LIST_CHECK .+$',
                            '#define PROCESS_LIST_CHECK if (priority != PROCESS_PRIORITY_VERY_HIGH) { if (current_list && current_list.len && current_list[1] == current) { current_list.Cut(1, 2); } else { current_list -= current; } }',
                            defines, flags=re.M)
    assert count == 1
if args.remove_candidate:
    defines, count = re.subn(r'^#define PROCESS_LIST_CHECK .+$',
                            '#define PROCESS_LIST_CHECK if (priority != PROCESS_PRIORITY_VERY_HIGH) current_list.Remove(current)',
                            defines, flags=re.M)
    assert count == 1
if args.negative_control:
    defines, count = re.subn(r'^#define PROCESS_LIST_CHECK .+$',
                            '#define PROCESS_LIST_CHECK if (priority != PROCESS_PRIORITY_VERY_HIGH && current_list && current_list.len) current_list.Cut(1, 2)',
                            defines, flags=re.M)
    assert count == 1
source = '' if args.benchmark else re.search(r'/process/obj/fire\(\)[\s\S]*?(?=/process/obj/statProcess)', objects).group()
probe = Path(__file__).with_name('benchmark.dm' if args.benchmark else 'probe.dm').read_text()
flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
compiler = args.byond_bin / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
daemon = args.byond_bin / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
with tempfile.TemporaryDirectory(prefix='civ13-list-removal-') as temp:
    out = args.evidence_dir or Path(temp)
    if args.evidence_dir and out.exists() and any(out.iterdir()):
        parser.error('Evidence directory must be fresh')
    out.mkdir(parents=True, exist_ok=True)
    (out / 'production.dm').write_text(source)
    (out / 'defines.dm').write_text(defines)
    (out / 'probe.dm').write_text(probe)
    (out / 'probe.dme').write_text('#include "defines.dm"\n#include "probe.dm"\n#include "production.dm"\n')
    head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo, text=True).strip()
    metadata = {'head': head, 'source_commit': BASELINE if args.baseline else head,
                'baseline': args.baseline, 'negative_control': args.negative_control,
                'guarded_control': args.guarded_control,
                'benchmark': args.benchmark,
                'remove_candidate': args.remove_candidate,
                'platform': platform.system() + ' ' + platform.release(),
                'architecture': platform.machine(),
                'checkout_status': subprocess.check_output(['git', 'status', '--porcelain'], cwd=repo, text=True),
                'source_sha256': [hashlib.sha256(x.encode()).hexdigest() for x in raw],
                'compiled_sha256': hashlib.sha256((defines + source).encode()).hexdigest(),
                'probe_sha256': hashlib.sha256(probe.encode()).hexdigest()}
    (out / 'metadata.json').write_text(json.dumps(metadata, indent=2))
    (out / 'dirty.patch').write_bytes(subprocess.check_output(['git', 'diff', 'HEAD'], cwd=repo))
    build = subprocess.run([str(compiler), '-max_errors', '0', 'probe.dme'], cwd=out,
                           capture_output=True, text=True, timeout=60, creationflags=flags)
    log = build.stdout + build.stderr
    (out / 'compile.log').write_text(log)
    if build.returncode or '516.1681' not in log or '0 errors, 0 warnings' not in log:
        raise SystemExit(log)
    run = subprocess.run([str(daemon), 'probe.dmb', '-invisible', '-close', '-safe', '-log', 'runtime.log'],
                         cwd=out, capture_output=True, timeout=120, creationflags=flags)
    log = (out / 'runtime.log').read_text(errors='replace')
    (out / 'daemon.log').write_bytes(run.stdout + run.stderr)
    combined = log + (run.stdout + run.stderr).decode(errors='replace')
    if run.returncode or re.search(r'runtime error|Bad ref|Bad loc|BUG:|## ERROR:|WARNING |Cannot read null|Cannot execute null', combined, re.I):
        raise SystemExit(combined)
    result = json.loads((out / 'result.json').read_text())
    if args.benchmark:
        if (len(result['samples']) != 51 or result['sink'] != 5_440_000 or
                any(not row['complete'] or row['remaining'] or row['operations'] != row['count'] * row['passes'] for row in result['samples'])):
            raise SystemExit('Incomplete benchmark work invalidates throughput evidence')
        for count in (1000, 5000, 10000):
            for mode in dict.fromkeys(row['mode'] for row in result['samples']):
                rows = [row for row in result['samples'] if row['count'] == count and row['mode'] == mode]
                print(f"{count:5} {mode:12} median_ds={statistics.median(row['elapsed_ds'] for row in rows):.5f} complete={all(row['complete'] for row in rows)}")
    elif args.negative_control:
        if result != {'checks': 56, 'failures': 17} or 'FAIL skipped head retained' not in log or 'FAIL already removed current leaves next entry' not in log:
            raise SystemExit('Unsafe front removal was not detected: ' + log)
        print('PASS unsafe front-cut negative control: ' + str(result))
    elif args.guarded_control:
        if result != {'checks': 56, 'failures': 2} or log.count('FAIL value removal matches native subtraction') != 2:
            raise SystemExit('Guarded-cut duplicate/null mismatch changed: ' + log)
        print('PASS guarded-cut duplicate/null negative control: ' + str(result))
    elif result['failures'] or result['checks'] != 56:
        raise SystemExit(log)
    else:
        print('PASS native production removal semantics: ' + str(result))
    if args.evidence_dir:
        print('Retained evidence: ' + str(out))
