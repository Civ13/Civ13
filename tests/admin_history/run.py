"""Compile the production admin writer/view in isolated storage, or only prepare sources."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
HELPER = 'code/_helpers/_logging.dm'
VIEW = 'code/modules/admin/secrets/logs.dm'
CONTROLS = {
    'failure-trim': ('\tif (!archived)\n', '\tif (!archived && admin_log.len < 0)\n',
                     'zero write retains every row'),
    'alias': ('\tadmin_log.Cut(1, archive_count + 1)\n',
              '\tadmin_log = admin_log.Copy(archive_count + 1)\n',
              'retirement preserves the original list'),
    'batch': ('var/archive_count = min(ADMIN_HISTORY_ARCHIVE_BATCH, admin_log.len - 1)',
              'var/archive_count = admin_log.len - 1',
              'backlog recovery uses one bounded batch per append'),
}


def replace_once(source, old, new):
    if source.count(old) != 1:
        raise ValueError(f'Missing or ambiguous source anchor: {old!r}')
    return source.replace(old, new)


def prepare(evidence, control=None, root=ROOT):
    original = (root / HELPER).read_text(encoding='utf-8')
    start, end = '#define ADMIN_HISTORY_RECENT_LIMIT ', '/proc/log_discord('
    if original.count(start) != 1 or original.count(end) != 1:
        raise ValueError('Missing or ambiguous production writer boundaries')
    helper = original[original.index(start):original.index(end)]
    helper = replace_once(helper, 'return text2file("\\n[payload]", diary)',
                          'return history_probe_write(payload, diary)')
    helper = replace_once(helper,
                          'world.log << "Admin history archive unavailable; older entries retained in memory. Further attempts and warnings are limited to once per minute."',
                          'history_probe_warning()')
    if control:
        old, new, _ = CONTROLS[control]
        helper = replace_once(helper, old, new)
    view = replace_once((root / VIEW).read_text(encoding='utf-8'),
                        '\tuser << browse(dat, "window=admin_log")',
                        '\thistory_probe_show(user, dat)')
    inputs = {
        'history.dm': helper,
        'view.dm': view,
        'probe.dm': (root / 'tests/admin_history/probe.dm').read_text(encoding='utf-8'),
        'probe.dme': '#define TRUE 1\n#define FALSE 0\n#include "history.dm"\n#include "probe.dm"\n#include "view.dm"\n',
    }
    evidence.mkdir(parents=True, exist_ok=True)
    for name, value in inputs.items():
        (evidence / name).write_text(value, encoding='utf-8')
    metadata = {
        'head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip(),
        'status': subprocess.check_output(['git', 'status', '--porcelain'], cwd=root, text=True),
        'control': control,
        'production_sha256': {path: hashlib.sha256((root / path).read_bytes()).hexdigest()
                              for path in (HELPER, VIEW)},
        'compiled_sha256': {name: hashlib.sha256(value.encode()).hexdigest() for name, value in inputs.items()},
        'adapters': ['one-tile world without production startup/configuration/saves',
                     'write boundary injects zero/throw; success uses a temporary native file',
                     'warning and ordinary logger count calls; cooldown scalars advanced by fixture',
                     'view permission parent stub; browse sink captures the actual rendered HTML string'],
        'limits': 'Row/character retention counts do not measure process RAM, disk crash durability or live gameplay.',
    }
    (evidence / 'sources.json').write_text(json.dumps(metadata, indent=2), encoding='utf-8')
    return metadata


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', type=Path)
    parser.add_argument('--evidence-dir', type=Path, required=True)
    parser.add_argument('--prepare-only', action='store_true')
    parser.add_argument('--negative-control', choices=CONTROLS)
    args = parser.parse_args()
    evidence = args.evidence_dir.resolve()
    if evidence.exists() and any(evidence.iterdir()):
        parser.error('Choose a fresh evidence directory')
    if not args.prepare_only and not args.byond_bin:
        parser.error('--byond-bin is required for native execution')
    prepare(evidence, args.negative_control)
    if args.prepare_only:
        print('PASS source preparation; native compilation and runtime UNRUN')
        return
    binary = args.byond_bin.resolve()
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    compiler = binary / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = binary / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    build = subprocess.run([str(compiler), '-max_errors', '0', 'probe.dme'], cwd=evidence,
                           capture_output=True, text=True, timeout=60, creationflags=flags)
    compilation = build.stdout + build.stderr
    (evidence / 'compile.log').write_text(compilation, encoding='utf-8')
    if build.returncode or '516.1681' not in compilation or '0 errors, 0 warnings' not in compilation:
        raise SystemExit('Pinned compilation failed:\n' + compilation)
    run = subprocess.run([str(daemon), 'probe.dmb', '-invisible', '-close', '-safe', '-log', 'runtime.log'],
                         cwd=evidence, capture_output=True, timeout=60, creationflags=flags)
    (evidence / 'daemon.log').write_bytes(run.stdout + run.stderr)
    log = (evidence / 'runtime.log').read_text(errors='replace')
    combined = log + (run.stdout + run.stderr).decode(errors='replace')
    if run.returncode or re.search(r'runtime error|Bad ref|Bad loc|BUG:|## ERROR:', combined, re.I):
        raise SystemExit('Native diagnostics invalidate evidence:\n' + combined)
    result = json.loads((evidence / 'result.json').read_text())
    if result['checks'] != 27 or 'COMPLETE admin history fixture' not in log:
        raise SystemExit(f'Incomplete fixture: {result}')
    if args.negative_control:
        required = CONTROLS[args.negative_control][2]
        if not result['failures'] or required not in result['failed_labels']:
            raise SystemExit(f'Negative control missed its required contract: {result}')
    elif result['failures']:
        raise SystemExit(f'Production contract failed: {result}')
    print(json.dumps(result, sort_keys=True))
    print('PASS ' + (args.negative_control or 'bounded production admin history'))


if __name__ == '__main__':
    main()
