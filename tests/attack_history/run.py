"""Isolated production attack-history contract; --prepare-only never runs BYOND."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

from check_writers import check

ROOT = Path(__file__).resolve().parents[2]
HELPER = 'code/modules/admin/admin_attack_log.dm'
GHOST = 'code/game/mob/observer/ghost/ghost.dm'
CONTROLS = {
    'failure-trim': ('\tif (!archived)\n', '\tif (!archived && attack_log.len < 0)\n',
                     'zero return retains the entire shared history'),
    'alias': ('\tattack_log.Cut(1, archive_count + 1)\n',
              '\tattack_log = attack_log.Copy(archive_count + 1)\n',
              'retirement preserves body and ghost list identity'),
    'batch': ('var/archive_count = min(ATTACK_HISTORY_ARCHIVE_BATCH, attack_log.len - 1)',
              'var/archive_count = attack_log.len - 1',
              'legacy catchup writes at most one 64-row batch per append'),
}


def replace_once(source, old, new):
    if source.count(old) != 1:
        raise ValueError(f'Missing or ambiguous source anchor: {old!r}')
    return source.replace(old, new)


def prepare(evidence, control=None, root=ROOT):
    writers, files = check(root)
    original = (root / HELPER).read_text(encoding='utf-8')
    anchor = 'proc/log_and_message_admins('
    if original.count(anchor) != 1:
        raise ValueError('Missing or ambiguous helper boundary')
    helper = original[:original.index(anchor)]
    helper = replace_once(helper, 'return text2file("\\n[payload]", global.attack_log)',
                          'return history_probe_write(payload, global.attack_log)')
    helper = replace_once(helper,
                          'world.log << "Attack history archive unavailable; older entries retained in memory. Further attempts and warnings are limited to once per minute."',
                          'history_probe_warning("Synthetic history archive warning")')
    if control:
        old, new, _ = CONTROLS[control]
        helper = replace_once(helper, old, new)
    ghost_source = (root / GHOST).read_text(encoding='utf-8')
    assignments = re.findall(r'^\t\tattack_log = body\.attack_log\t[^\n]*$', ghost_source, re.M)
    if len(assignments) != 1:
        raise ValueError('Missing or ambiguous shared ghost assignment')
    ghost = '/mob/observer/ghost/New(mob/body)\n\t..()\n' + assignments[0][1:] + '\n'
    evidence.mkdir(parents=True, exist_ok=True)
    inputs = {
        'probe.dm': (root / 'tests/attack_history/probe.dm').read_text(encoding='utf-8'),
        'history.dm': helper,
        'ghost.dm': ghost,
        'probe.dme': '#define TRUE 1\n#define FALSE 0\n#include "history.dm"\n#include "probe.dm"\n#include "ghost.dm"\n',
    }
    for name, value in inputs.items():
        (evidence / name).write_text(value, encoding='utf-8')
    metadata = {
        'head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip(),
        'status': subprocess.check_output(['git', 'status', '--porcelain'], cwd=root, text=True),
        'control': control,
        'writer_count': writers,
        'writer_files': files,
        'production_sha256': {path: hashlib.sha256((root / path).read_bytes()).hexdigest()
                              for path in (HELPER, GHOST, 'tests/attack_history/writer-migration.json')},
        'compiled_sha256': {name: hashlib.sha256(value.encode()).hexdigest()
                            for name, value in inputs.items()},
        'adapters': ['standalone one-tile world, no production startup/config/saves',
                     'production text2file call injected for success/zero/throw; success writes a temporary real file',
                     'warning sink counts calls; cooldown scalars advanced by fixture',
                     'real shared ghost assignment in a minimal constructor'],
        'limits': 'History row/character counts are not process RAM, disk durability, gameplay latency or live leak attribution.',
    }
    (evidence / 'metadata.json').write_text(json.dumps(metadata, indent=2) + '\n', encoding='utf-8')
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
    if result['checks'] != 28 or 'COMPLETE attack history fixture' not in log:
        raise SystemExit(f'Incomplete fixture: {result}')
    if args.negative_control:
        required = CONTROLS[args.negative_control][2]
        if not result['failures'] or required not in result['failed_labels']:
            raise SystemExit(f'Negative control missed its required contract: {result}')
    elif result['failures']:
        raise SystemExit(f'Production contract failed: {result}')
    print(json.dumps(result, sort_keys=True))
    print('PASS ' + (args.negative_control or 'bounded production attack history'))


if __name__ == '__main__':
    main()
