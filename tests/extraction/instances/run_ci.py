"""Standalone exact-commit instance probe. Native execution is CI Linux only."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[3]
SOURCE = 'code/modules/1713/extraction/instances.dm'
PROBE = 'tests/extraction/instances/probe.dm'
INCLUDE = '#include "../../../code/modules/1713/extraction/instances.dm"'
CONTROLS = {
    'overlap': ('if (origin[3] <= other["top"] && top >= other["bottom"]) return null',
                'if (FALSE) return null', 'XY-separated homes cannot share z interval'),
    'generation': ('generation == scope_generation', 'TRUE', 'wrong scope acquire rejected'),
}
DIAGNOSTIC = re.compile(r'runtime error|bad ref|unhandled|traceback|segmentation|fatal|error:|warning:'
                        r'|BUG:|access violation|out of memory', re.I)


def require(value, message):
    if not value:
        raise ValueError(message)


def committed(head, relative):
    require(re.fullmatch('[0-9a-f]{40}', head), 'Expected full commit SHA')
    return subprocess.run(['git', 'show', head + ':' + relative], cwd=ROOT,
                          check=True, capture_output=True, timeout=10).stdout


def mutation(source, control):
    if control == 'baseline':
        return source
    original, replacement, _ = CONTROLS[control]
    require(source.count(original) == 1, 'Mutation anchor changed: ' + control)
    return source.replace(original, replacement)


def labels(probe):
    result = re.findall(r'^\tcheck\(.+, "([^"\n]+)"\)\s*$', probe, re.M)
    require(len(result) == 35 and len(set(result)) == 35, 'Expected 35 unique authored assertions')
    return set(result)


def verdict(log, expected, control):
    require(not DIAGNOSTIC.search(log), 'Runtime/engine diagnostic invalidates evidence')
    rows = re.findall(r'^(PASS|FAIL): ([^\r\n]+)$', log, re.M)
    require(len(rows) == 35 and {label for _, label in rows} == expected,
            'Missing, duplicated or unexpected assertion result')
    failures = [label for status, label in rows if status == 'FAIL']
    if control == 'baseline':
        require(not failures and log.count('INSTANCE PROBE COMPLETE') == 1
                and 'INSTANCE PROBE FAILED' not in log, 'Positive probe failed')
    else:
        require(CONTROLS[control][2] in failures, 'Control missed its exact assertion')
        require(log.count('INSTANCE PROBE FAILED: ' + str(len(failures))) == 1
                and 'INSTANCE PROBE COMPLETE' not in log, 'Invalid control terminator')
    target = CONTROLS[control][2] if control != 'baseline' else None
    return {'assertions': len(rows), 'failures': failures, 'expected_control': control,
            'expected_target': target, 'collateral_failure_labels': [label for label in failures if label != target],
            'oracle': 'baseline all pass' if control == 'baseline' else 'named target required; collateral reported'}


def compiler_verdict(log):
    require(not DIAGNOSTIC.search(log), 'Compiler diagnostic invalidates evidence')
    require('DM compiler version 516.1681' in log and '- 0 errors, 0 warnings' in log,
            'Compiler banner/result mismatch')


def prepare(head, output):
    source, probe = committed(head, SOURCE), committed(head, PROBE)
    text = probe.decode('utf-8')
    require(text.count(INCLUDE) == 1, 'Production include changed')
    require(re.findall(r'^#include .+$', text, re.M) == [INCLUDE], 'Unexpected fixture dependency')
    expected = labels(text)
    output.mkdir(parents=True, exist_ok=False)
    for control in ('baseline', *CONTROLS):
        case = output / control
        case.mkdir()
        (case / 'instances.dm').write_bytes(mutation(source.decode('utf-8'), control).encode('utf-8'))
        (case / 'probe.dme').write_bytes(text.replace(INCLUDE, '#include "instances.dm"').encode('utf-8'))
    manifest = {'head_sha': head, 'source_sha256': hashlib.sha256(source).hexdigest(),
                'probe_sha256': hashlib.sha256(probe).hexdigest(), 'native_executed': False,
                'scope': 'standalone logical identity/lease assertions; no full game, map or disk saves',
                'cases': ['baseline', *CONTROLS], 'expected_assertions_per_case': 35}
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    return manifest, expected


def native_gate(output, byond):
    require(sys.platform == 'linux' and os.environ.get('GITHUB_ACTIONS') == 'true'
            and os.environ.get('RUNNER_OS') == 'Linux', 'Native execution requires ephemeral Linux CI')
    temporary = Path(os.environ['RUNNER_TEMP']).resolve(strict=True)
    workspace = Path(os.environ['GITHUB_WORKSPACE']).resolve(strict=True)
    require(output.resolve().is_relative_to(temporary) and output.resolve() != temporary,
            'Evidence must be a new child of RUNNER_TEMP')
    require(byond.resolve(strict=True) == workspace / 'BYOND/byond/bin', 'Use pinned CI BYOND installation')
    require(os.environ.get('BYOND_MAJOR') == '516' and os.environ.get('BYOND_MINOR') == '1681',
            'Pinned BYOND version changed')


def run_bounded(command, folder, name, wall, cpu, memory, global_deadline):
    import resource
    def limits():
        resource.setrlimit(resource.RLIMIT_AS, (memory, memory))
        resource.setrlimit(resource.RLIMIT_CPU, (cpu, cpu))
        resource.setrlimit(resource.RLIMIT_FSIZE, (16 * 1024 * 1024,) * 2)
        resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    started = time.monotonic()
    with (folder / name).open('xb') as log:
        process = subprocess.Popen(command, cwd=folder, stdin=subprocess.DEVNULL,
            stdout=log, stderr=subprocess.STDOUT, start_new_session=True, preexec_fn=limits)
        try:
            deadline = min(started + wall, global_deadline)
            # Keep the exited leader unreaped until group cleanup. Its reserved
            # PID prevents killpg from targeting a subsequently reused group ID.
            while os.waitid(os.P_PID, process.pid, os.WEXITED | os.WNOHANG | os.WNOWAIT) is None:
                require(time.monotonic() < deadline, 'Native wall deadline exceeded')
                time.sleep(.1)
        finally:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait(timeout=5)
        require(process.returncode == 0, 'Native process failed')
    return {'wall_seconds': time.monotonic() - started, 'wall_limit': wall,
            'cpu_limit_seconds': cpu, 'address_space_limit_bytes': memory}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--head', required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--prepare-only', action='store_true')
    parser.add_argument('--byond-bin', type=Path)
    args = parser.parse_args()
    if not args.prepare_only:
        require(args.byond_bin is not None, 'Missing pinned BYOND path')
        native_gate(args.output, args.byond_bin)
    manifest, expected = prepare(args.head, args.output)
    if args.prepare_only:
        print(json.dumps(manifest, indent=2))
        return
    binaries = {name: hashlib.sha256((args.byond_bin / name).read_bytes()).hexdigest()
                for name in ('DreamMaker', 'DreamDaemon')}
    result = {'head_sha': args.head, 'native_executed': True, 'binary_sha256': binaries,
              'cases': {}, 'success': False}
    deadline = time.monotonic() + 300
    try:
        for control in manifest['cases']:
            case = args.output / control
            compilation = run_bounded([str(args.byond_bin / 'DreamMaker'), '-max_errors', '0', 'probe.dme'],
                case, 'compile.log', 60, 30, 1024 ** 3, deadline)
            log = (case / 'compile.log').read_text(errors='replace')
            compiler_verdict(log)
            runtime = run_bounded([str(args.byond_bin / 'DreamDaemon'), 'probe.dmb', '-invisible', '-safe',
                '-close', '-log', 'runtime.log'], case, 'console.log', 30, 15, 128 * 1024 ** 2, deadline)
            require(not DIAGNOSTIC.search((case / 'console.log').read_text(errors='replace')),
                    'Runtime console diagnostic invalidates evidence')
            outcome = verdict((case / 'runtime.log').read_text(errors='replace'), expected, control)
            result['cases'][control] = dict(outcome, compile=compilation, runtime=runtime)
        result['success'] = True
    finally:
        (args.output / 'result.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
