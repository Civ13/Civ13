"""Archive-bound Linux 516.1688 exclusion parity; historical 1681 runner remains unchanged."""
import argparse
import importlib.util
import json
from pathlib import Path
import sys
import time

ROOT = Path(__file__).resolve().parents[1]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


legacy = load('exclusion_historical_ci', ROOT / 'tests/exclusion_dispatch/run-ci.py')
current = load('exclusion_current_runtime', ROOT / 'tests/world_save/current_runtime.py')
# Keep the admitted historical four-case lane. The target omission control is
# available for offline source inspection and requires separate admission to run.
MODES = legacy.MODES


def validate_result(mode, result, log):
    legacy.validate_result(mode, result, log)
    if (type(result.get('byond_version')) is not int or result['byond_version'] != 516 or
            type(result.get('byond_build')) is not int or result['byond_build'] != 1688):
        raise RuntimeError('Observed fixture runtime is not exactly 516.1688')
    failures = result.get('target_failures')
    # Parent omission breaks inherited target exclusion for exactly the two
    # mob types in probe.dm. It must not weaken any positive/parity assertion.
    expected = {'parity': 0, 'omit': 0, 'parent': 2, 'eager': 0}
    if (mode not in (*expected, 'target-omit') or type(failures) is not int
            or (failures <= 0 if mode == 'target-omit' else failures != expected[mode])):
        raise RuntimeError('Original-target positive or omission control failed')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--byond-archive', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if sys.platform != 'linux': parser.error('Current exclusion CI requires Linux')
    runtime = current.select(args.byond_bin, args.byond_archive)
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    compiler, daemon = runtime.bin_dir / 'DreamMaker', runtime.bin_dir / 'DreamDaemon'
    deadline = time.monotonic() + 180
    summary = dict(status='incomplete', runtime=runtime.identity, native_execution=False,
                   scope='isolated Linux hook parity and mutation controls; no benchmark or deployment', modes={})
    try:
        for mode in MODES:
            packet = output / (mode + '.json')
            command = [sys.executable, str(ROOT / 'tests/exclusion_dispatch/run.py'), '--source-only',
                       '--source-version', '516.1688', '--output', str(packet)]
            if mode != 'parity': command += ['--negative-control', mode]
            legacy.run(command, output, mode + '-prepare', deadline)
            source_receipt = json.loads(packet.read_text(encoding='utf-8'))
            if source_receipt.get('required_version') != '516.1688' or source_receipt.get('native_execution') is not False:
                raise RuntimeError('Source preparation did not preserve current source-only identity')
            work = packet.with_suffix('.sources')
            runtime.before_launch(mode + '-compile', output)
            build = legacy.run([str(compiler), '-max_errors', '0', 'probe.dme'], work, 'compile', deadline)
            runtime.validate_compile(0, build, 'probe.dmb')
            runtime.before_launch(mode + '-daemon', output)
            # A failed owned-run call can occur before or after process creation;
            # its process receipt determines which, so do not assert either here.
            summary['native_execution'] = None
            log = legacy.run([str(daemon), 'probe.dmb', '-ip', '127.0.0.1', '-invisible', '-close',
                              '-trusted', '-log', 'runtime.log'], work, 'daemon', deadline)
            summary['native_execution'] = True
            log += (work / 'runtime.log').read_text(errors='replace')
            result = json.loads((work / 'result.json').read_text(encoding='utf-8'))
            validate_result(mode, result, log)
            summary['modes'][mode] = result
        summary['status'] = 'passed'
    finally:
        (output / 'native-ci-1688.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
    print('PASS: archive-bound 516.1688 exclusion parity and mutation controls; no performance claim')


if __name__ == '__main__': main()
