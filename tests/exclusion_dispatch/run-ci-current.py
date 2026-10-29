"""Explicit 516.1688 Linux parity lane; the historical 1681 gate is unchanged."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import re
import sys
import time

from preparation import git

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
VERSION = '516.1688'
EXTRA_DIAGNOSTIC = re.compile(r'unexpected runtime|\bOOM\b|out of memory|access violation|\bCRASH(?:ED)?\b|invalid file', re.I)


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


def source_identity():
    return dict(head=git(ROOT, 'rev-parse', 'HEAD').strip(),
                tree=git(ROOT, 'rev-parse', 'HEAD^{tree}').strip(),
                tracked_dirty=bool(git(ROOT, 'status', '--porcelain', '--untracked-files=no').strip()))


def validate_build(log, diagnostics):
    lines = log.splitlines()
    banners = [line for line in lines if re.search(r'DM compiler version', line, re.I)]
    results = [line for line in lines if re.search(r'\berrors?\b|\bwarnings?\b', line, re.I)]
    summary = (r'probe\.dmb - 0 errors, 0 warnings '
               r'\(\d{1,2}/\d{1,2}/\d{2,4} \d{1,2}:\d{2}(?::\d{2})? (?:am|pm)\)')
    if (len(log.encode('utf-8')) > 1024 * 1024 or banners != ['DM compiler version ' + VERSION]
            or len(results) != 1 or not re.fullmatch(summary, results[0])
            or lines.index(banners[0]) >= lines.index(results[0])
            or re.search(r'invalid file|file not found|cannot open', log, re.I)
            or diagnostics.search(log) or EXTRA_DIAGNOSTIC.search(log)):
        raise RuntimeError('Exact 516.1688 clean compilation required')


def validate_observed_result(result):
    if (type(result.get('byond_version')) is not int or result['byond_version'] != 516 or
            type(result.get('byond_build')) is not int or result['byond_build'] != 1688):
        raise RuntimeError('Observed fixture runtime is not exactly 516.1688')
    if type(result.get('target_failures')) is not int or result['target_failures'] != 0:
        raise RuntimeError('Original-target positive assertion failed')


def execute(args, *, ci=None, runtime=None):
    if sys.platform != 'linux':
        raise ValueError('Current exclusion fixture supports Linux only')
    ci = ci or module('historical_exclusion_ci', HERE / 'run-ci.py')
    runtime = runtime or module('current_exclusion_runtime', ROOT / 'scripts/byond_runtime.py')
    identity = ci.identities(ROOT, args.base, args.head,
        event_path=os.environ.get('GITHUB_EVENT_PATH'), event_name=os.environ.get('GITHUB_EVENT_NAME'),
        github_actions=os.environ.get('GITHUB_ACTIONS') == 'true')
    source = source_identity()
    if source['tracked_dirty'] or source['head'] != identity['head']:
        raise ValueError('Current exclusion fixture requires unchanged checked-out head')
    environment = os.environ.copy()
    if environment.get('LD_PRELOAD') or environment.get('LD_AUDIT'):
        raise ValueError('Loader injection is incompatible with pinned exclusion execution')
    byond, archive, output = args.byond_bin.absolute(), args.byond_archive.absolute(), args.output.absolute()
    if output.exists() or output.is_symlink():
        raise ValueError('Preserve prior exclusion evidence; use a fresh output directory')
    selected = runtime.verify_linux(byond, archive)
    if selected['version'] != VERSION:
        raise ValueError('Current exclusion fixture requires the reviewed ' + VERSION + ' pin')
    environment.update(LD_LIBRARY_PATH=str(byond), BYOND_SYSTEM=str(byond.parent))
    output.mkdir(parents=True)
    deadline = time.monotonic() + 180
    summary = dict(status='incomplete', identity=identity, source=source, runtime_identity=selected,
        native_execution=False, native_execution_attempted=False, runtime_checks=['admission'], modes={},
        scope='isolated Linux hook parity and controls; no benchmark, pixels, lifecycle or deployment',
        source_preparation='legacy source-only generator; its historical runtime gate is not used for admission')

    def verify(phase):
        if runtime.verify_linux(byond, archive) != selected:
            raise RuntimeError('Runtime identity changed: ' + phase)
        if source_identity() != source:
            raise RuntimeError('Checked-out source changed: ' + phase)
        summary['runtime_checks'].append(phase)

    try:
        for mode in ci.MODES:
            packet = output / (mode + '.json')
            command = [sys.executable, str(HERE / 'run.py'), '--source-only', '--output', str(packet),
                       '--base', identity['base'], '--head', identity['head']]
            if mode != 'parity':
                command += ['--negative-control', mode]
            ci.run(command, output, mode + '-prepare', deadline, environment=environment)
            work = packet.with_suffix('.sources')
            verify(mode + ':before-compiler')
            summary['native_execution_attempted'] = True
            build = ci.run([str(byond / 'DreamMaker'), '-max_errors', '0', 'probe.dme'],
                           work, 'compile', deadline, environment=environment)
            summary['native_execution'] = True
            validate_build(build, ci.DIAGNOSTIC)
            verify(mode + ':before-daemon')
            log = ci.run([str(byond / 'DreamDaemon'), 'probe.dmb', '-ip', '127.0.0.1', '-invisible',
                          '-close', '-trusted', '-log', 'runtime.log'], work, 'daemon', deadline,
                         environment=environment)
            log += (work / 'runtime.log').read_text(errors='replace')
            if not re.search(r'(?<![\d.])516\.1688(?![\d.])', log):
                raise RuntimeError('Exact 516.1688 native runtime banner required')
            verify(mode + ':after-daemon')
            result = json.loads((work / 'result.json').read_text())
            ci.validate_result(mode, result, log)
            validate_observed_result(result)
            summary['modes'][mode] = result
        summary['status'] = 'passed'
    except BaseException as error:
        summary.update(status='failed', error=str(error), exception_type=type(error).__name__)
        raise
    finally:
        (output / 'native-ci.json').write_text(json.dumps(summary, indent=2) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--byond-archive', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--base', default=os.environ.get('CI_BASE'))
    parser.add_argument('--head', default=os.environ.get('CI_HEAD'))
    execute(parser.parse_args())


if __name__ == '__main__':
    main()
