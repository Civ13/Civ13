"""Compile production harvesting in a small offline world, with temporary storage."""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'scripts'))
from native_fixture import Session, no_port_args, read_bounded, run_native


def main(argv=None, session=None):
    parser = argparse.ArgumentParser()
    parser.add_argument('--byond-bin', required=True, type=Path)
    parser.add_argument('--evidence-dir', type=Path)
    args = parser.parse_args(argv)
    root = Path(__file__).resolve().parents[2]
    binary = args.byond_bin.resolve()
    compiler = binary / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = binary / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    prefix = '.animal_harvest_ci'
    generated = [root / (prefix + suffix) for suffix in ('.dme', '_world.dm', '.dmb', '.rsc')]
    if any(path.exists() for path in generated):
        raise RuntimeError('Preserve existing probe files')
    storage = root / 'data' / 'animal-harvest-tests'
    storage.mkdir(parents=True, exist_ok=True)
    logs = args.evidence_dir.resolve() if args.evidence_dir else Path(tempfile.mkdtemp(prefix='run-', dir=storage))
    if args.evidence_dir:
        logs.mkdir(parents=True, exist_ok=False)
    print(f'Evidence: {logs}', flush=True)
    commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True, timeout=10).strip()
    if os.name == 'nt' and session is None:
        session = Session(logs/'supervisor', commit)
    try:
        world = (root / 'code/world.dm').read_text(encoding='utf-8')
        start = world.index('/world/New()')
        parent = world.index('\n\t..()', start)
        world = world[:parent] + world[parent:].replace('\n\t..()', '', 1)
        world = world.replace('/world/New()', '/world/proc/unused_harvest_startup()', 1)
        generated[1].write_text(world, encoding='utf-8')
        source = (root / 'civ13.dme').read_text(encoding='utf-8')
        source = source.replace('code\\world.dm', prefix + '_world.dm')
        source = re.sub(r'^#include ".*\.dmm".*$', '', source, flags=re.M)
        generated[0].write_text(source + '\n#include "tests/animal_harvest/probe.dm"\n', encoding='utf-8')
        print(f'Commit: {commit}', flush=True)
        build = run_native(session, [str(compiler), '-max_errors', '0', str(generated[0])],
                           cwd=root, phase='harvest-compile', timeout=120, artifacts=generated[2:])
        output = build.stdout + build.stderr
        (logs / 'compile.log').write_text(output, encoding='utf-8')
        print(output, flush=True)
        if build.returncode or '0 errors, 0 warnings' not in output or '516.1681' not in output:
            raise RuntimeError('Pinned compilation failed')
        shutil.copy2(generated[2], logs / generated[2].name)
        shutil.copy2(generated[3], logs / generated[3].name)
        shutil.copytree(root / 'config/names', logs / 'config/names')
        (logs / 'config/config.txt').write_text('# Offline fixture\n', encoding='utf-8')
        runtime = run_native(session, [str(daemon), str(logs / generated[2].name),
                                  *(['-invisible', '-close'] if os.name == 'nt' else []),
                                  *no_port_args(), '-trusted', '-params', f'tested_commit={commit}', '-log', 'runtime.log'],
                             cwd=logs, phase='harvest-runtime', timeout=60, state_directory=logs)
        (logs / 'daemon.log').write_text(runtime.stdout + runtime.stderr, encoding='utf-8')
        result = read_bounded(logs/'result.txt', 4096).strip()
        print(result, flush=True)
        log = read_bounded(logs/'runtime.log')
        if read_bounded(logs/'port-closed.txt', 16).strip() != 'closed':
            raise RuntimeError('Native no-port assertion did not complete')
        errors = logs / 'errors.txt'
        if runtime.returncode or not result.startswith('PASS:') or 'runtime error:' in log.lower() or (errors.exists() and errors.stat().st_size):
            print(log, flush=True)
            raise RuntimeError('Harvest fixture failed')
    finally:
        if session is None or all(p.get('owned_exit_evidence_complete') for p in session.phases):
            for path in generated:
                path.unlink(missing_ok=True)
        else:
            print('Retaining generated probe files: owned native cleanup is unconfirmed', flush=True)


if __name__ == '__main__':
    main()
