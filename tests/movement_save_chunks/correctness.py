"""Opt-in isolated native chunk correctness; default is source preparation only."""
import argparse
import importlib.util
import json
import re
from pathlib import Path
import shutil
import sys
import time

HERE = Path(__file__).resolve().parent

def load(name):
    spec = importlib.util.spec_from_file_location('moving_' + name, HERE / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module

SCENARIOS = ('walking', 'reference', 'frontier', 'frontier-delete', 'delete', 'inventory', 'cross-z', 'yield', 'depth')
ROSTER_ANCHOR = '/map_storage/proc/prepare_moving_save_roster()\n'
ORIGIN_ANCHOR = '''\tvar/datum/child = saving_reference_pins[ref]
\tvar/list/moving_root = child ? moving_save_roots["\\ref[child]"] : null
\tif(moving_root && moving_root["ref"] == ref && frame.source != moving_root["origin"])
\t\tif(!isturf(frame.source)) throw EXCEPTION("Moving save root entered a captured container")
\t\treturn // The frozen origin owns this root; roster drain will attach it.
'''

def mutate(packet, control):
    if control == 'roster':
        path = packet / 'code/modules/persistence/saving.dm'
        text = path.read_text()
        if text.count(ROSTER_ANCHOR) != 1: raise ValueError('roster mutation anchor differs')
        path.write_text(text.replace(ROSTER_ANCHOR, ROSTER_ANCHOR + '\treturn // omission control\n', 1))
    elif control == 'origin':
        path = packet / 'code/modules/persistence/functions.dm'
        text = path.read_text()
        if text.count(ORIGIN_ANCHOR) != 1: raise ValueError('origin mutation anchor differs')
        path.write_text(text.replace(ORIGIN_ANCHOR, '', 1))
    elif control != 'positive': raise ValueError('unknown control')

def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run-native', action='store_true')
    parser.add_argument('--byond-bin', type=Path)
    parser.add_argument('--byond-archive', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--job-seconds', type=int, default=240)
    args = parser.parse_args(argv)
    if not 1 <= args.job_seconds <= 1200: parser.error('job-seconds must be 1..1200')
    if args.output.exists(): parser.error('output must be a new directory')
    if args.run_native and (not args.byond_bin or not args.byond_archive):
        parser.error('native execution requires exact installed runtime and archive')
    args.output.mkdir(parents=True)
    prepare = load('prepare')
    for control in ('positive', 'roster', 'origin'):
        packet = args.output / (control + '-source'); packet.mkdir()
        prepare.prepare(packet); mutate(packet, control)
        # Mutations must get their own hashes, not masquerade as positive bytes.
        import hashlib
        hashes = {str(p.relative_to(packet)): hashlib.sha256(p.read_bytes()).hexdigest()
                  for p in packet.rglob('*') if p.is_file() and p.name != 'receipt.json'}
        (packet / 'receipt.json').write_text(json.dumps({'control': control, 'execution': 'not_run', 'sources': hashes}, indent=2))
    if not args.run_native: return 0
    runner = load('benchmark')
    limits = runner.Limits(case_seconds=90, job_seconds=args.job_seconds, rss_mib=1024, sample_ms=20)
    limits.validate()
    deadline = time.monotonic() + args.job_seconds
    results = []
    for control in ('positive', 'roster', 'origin'):
        packet = args.output / (control + '-source')
        identity = runner.verify_runtime(args.byond_bin, args.byond_archive)
        (packet / 'runtime-identity.json').write_text(json.dumps(identity, indent=2))
        build = runner.run_monitored([str(args.byond_bin / 'DreamMaker'), '-max_errors', '0', 'probe.dme'], packet, 'compile', limits, deadline)
        log = (packet / 'compile.log').read_text(errors='replace') if (packet / 'compile.log').exists() else ''
        if not runner.compile_ok(build, log, packet / 'probe.dmb'):
            results.append({'control': control, 'stage': 'compile', 'passed': False, 'summary': build}); continue
        scenarios = SCENARIOS if control == 'positive' else (('frontier',) if control == 'roster' else ('reference',))
        for scenario in scenarios:
            case = args.output / (control + '-' + scenario)
            case.mkdir()
            for name in ('probe.dmb', 'probe.rsc'):
                if (packet / name).exists(): shutil.copy2(packet / name, case / name)
            identity = runner.verify_runtime(args.byond_bin, args.byond_archive)
            (case / 'runtime-identity.json').write_text(json.dumps(identity, indent=2))
            summary = runner.run_monitored([str(args.byond_bin / 'DreamDaemon'), 'probe.dmb', '-trusted', '-ip', '127.0.0.1', '-nowebclient', '-log', 'runtime.log', '-params', 'scenario=' + scenario], case, 'daemon', limits, deadline)
            logs = '\n'.join(path.read_text(errors='replace') for path in (case / 'daemon.log', case / 'runtime.log') if path.exists())
            result = (case / 'result.txt').read_text().strip() if (case / 'result.txt').exists() else None
            diagnostics = bool(re.search(r'runtime error:|run-time error:|\bBUG\b|badref|unhandled[ _-]*exception', logs, re.I))
            errors_path = case / 'errors.txt'
            diagnostics = diagnostics or (errors_path.exists() and bool(errors_path.read_text(errors='replace').strip()))
            clean = summary['status'] == 'exited' and summary.get('returncode') == 0 and not diagnostics
            expected = None if control == 'positive' else ('admitted animal missing or multiply owned' if control == 'roster' else 'Moving save root has conflicting saved owners')
            passed = clean and (result == 'PASS' if not expected else result == 'FAIL' and expected in logs)
            results.append({'control': control, 'scenario': scenario, 'passed': passed, 'expected_control_assertion': expected, 'summary': summary})
            (args.output / 'results.json').write_text(json.dumps(results, indent=2))
    (args.output / 'results.json').write_text(json.dumps(results, indent=2))
    return 0 if results and all(row['passed'] for row in results) else 1

if __name__ == '__main__': raise SystemExit(main())
