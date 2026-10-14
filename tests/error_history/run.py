"""Compile real runtime logging and viewer bodies in an offline native fixture."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess


def prepare(root, evidence, historical=False):
    evidence.mkdir(parents=True, exist_ok=True)
    viewer = (root / 'code/modules/error_handler/error_viewer.dm').read_text()
    original = viewer
    browse_start = viewer.index('/datum/error_viewer/proc/browse_to(')
    browse_end = viewer.index('/datum/error_viewer/proc/build_header(', browse_start)
    viewer = viewer[:browse_start] + '/datum/error_viewer/proc/browse_to(client/user, html)\n\tlast_html = html\n\n' + viewer[browse_end:]
    if historical:
        start = viewer.index('/datum/error_viewer/error_cache/proc/log_error')
        end = viewer.index('/datum/error_viewer/error_cache/proc/retire_error', start)
        historical_body = (root / 'tests/error_history/historical_log_error.dm').read_text()
        viewer = viewer[:start] + historical_body + '\n' + viewer[end:]
    definitions = (root / 'code/modules/error_handler/_defines.dm').read_text()
    # Only the delayed summary wait is accelerated. Spam thresholds are original.
    assert definitions.count('#define ERROR_SILENCE_TIME 6000') == 1
    definitions = definitions.replace('#define ERROR_SILENCE_TIME 6000', '#define ERROR_SILENCE_TIME 2')
    files = {
        'probe.dm': (root / 'tests/error_history/probe.dm').read_text(),
        'viewer.dm': viewer,
        'handler.dm': (root / 'code/modules/error_handler/error_handler.dm').read_text(),
        'defines.dm': definitions,
        'probe.dme': ('#define HISTORICAL_ERROR_HISTORY\n' if historical else '') +
                     '#include "defines.dm"\n#include "probe.dm"\n#include "viewer.dm"\n#include "handler.dm"\n',
    }
    for name, content in files.items():
        (evidence / name).write_text(content, encoding='utf-8')
    metadata = {
        'head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip(),
        'status': subprocess.check_output(['git', 'status', '--porcelain'], cwd=root, text=True),
        'historical': historical,
        'viewer_sha256': hashlib.sha256(original.encode()).hexdigest(),
        'compiled_viewer_sha256': hashlib.sha256(viewer.encode()).hexdigest(),
        'adapter': 'standalone world, browser/log sinks; silence wait 2 ticks; no production startup/config/storage',
    }
    (evidence / 'metadata.json').write_text(json.dumps(metadata, indent=2))
    (evidence / 'dirty.patch').write_bytes(subprocess.check_output(['git', 'diff', 'HEAD', '--'], cwd=root))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', type=Path)
    parser.add_argument('--evidence-dir', type=Path, required=True)
    parser.add_argument('--historical', action='store_true')
    parser.add_argument('--prepare-only', action='store_true')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    evidence = args.evidence_dir.resolve()
    if evidence.exists() and any(evidence.iterdir()):
        parser.error('Choose a fresh evidence directory')
    if not args.prepare_only and not args.byond_bin:
        parser.error('--byond-bin is required for native execution')
    prepare(root, evidence, args.historical)
    if args.prepare_only:
        print('Prepared source only; native compilation/runtime UNRUN')
        return
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    compiler = args.byond_bin.resolve() / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = args.byond_bin.resolve() / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    build = subprocess.run([str(compiler), '-max_errors', '0', 'probe.dme'], cwd=evidence,
                           capture_output=True, text=True, timeout=60, creationflags=flags)
    compilation = build.stdout + build.stderr
    (evidence / 'compile.log').write_text(compilation)
    print(compilation, flush=True)
    if build.returncode or '516.1681' not in compilation or '0 errors, 0 warnings' not in compilation:
        raise SystemExit('Pinned compilation failed')
    run = subprocess.run([str(daemon), 'probe.dmb', '-invisible', '-close', '-safe', '-log', 'runtime.log'],
                         cwd=evidence, capture_output=True, timeout=30, creationflags=flags)
    (evidence / 'daemon.log').write_bytes(run.stdout + run.stderr)
    log = (evidence / 'runtime.log').read_text(errors='replace')
    combined = log + (run.stdout + run.stderr).decode(errors='replace')
    print(log, flush=True)
    if run.returncode or re.search(r'runtime error|Bad ref|Bad loc|BUG:|## ERROR:|WARNING ', combined, re.I):
        raise SystemExit('Native diagnostics invalidate evidence')
    result = json.loads((evidence / 'result.json').read_text())
    labels = re.findall(r'^FAIL (.*)$', log, re.M)
    expected = [
        'per-source history bounded',
        'retired external holder and native ref invalidated',
        'retirement clears source location and text before native deletion',
        'retired external holder absent from both roots',
        'source FIFO keeps newest details chronologically',
        'expired browser link uses existing missing viewer message',
        'retired entry disappears natively without collection wait',
        'global history bounded across sources',
        'global FIFO retains newest sources in order',
        'native memberships and source backrefs bounded and consistent',
        'old source metadata retains no retired entries',
    ]
    if result['checks'] != (22 if args.historical else 24):
        raise SystemExit(f'Incomplete fixture: {result}')
    if args.historical:
        if labels != expected or result['failures'] != len(expected):
            raise SystemExit(f'Historical control did not fail at its named contracts: {labels}')
    elif labels or result['failures']:
        raise SystemExit('Production fixture failed')
    print('PASS historical retention control' if args.historical else 'PASS bounded production history')


if __name__ == '__main__':
    main()
