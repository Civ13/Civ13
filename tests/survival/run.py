"""Bounded production disease fixture with normal world startup disabled."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import uuid


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--byond-bin', required=True, type=Path)
    parser.add_argument('--baseline', action='store_true')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    prefix = '.survival_' + uuid.uuid4().hex
    generated = [root / (prefix + suffix) for suffix in
                 ('.dme', '_world.dm', '_disease.dm', '.dmb', '.rsc')]
    logs = Path(tempfile.mkdtemp(prefix='civ13-survival-'))
    print(f'Artifacts: {logs}', flush=True)
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    binary = args.byond_bin.resolve()
    try:
        world = (root / 'code/world.dm').read_text(encoding='utf-8')
        start = world.index('/world/New()')
        parent = world.index('\n\t..()', start)
        world = world[:parent] + world[parent:].replace('\n\t..()', '', 1)
        world = world.replace('/world/New()', '/world/proc/unused_survival_startup()', 1)
        generated[1].write_text(world, encoding='utf-8')
        source = (root / 'civ13.dme').read_text(encoding='utf-8')
        source = source.replace('code\\world.dm', generated[1].name)
        if args.baseline:
            life = subprocess.check_output(['git', 'show', 'e4967a4e0:code/game/mob/living/carbon/human/human_life.dm'], cwd=root, text=True)
            block = life[life.index('// disease stuff'):life.index('\n\t//shitcode to fix the movement bug')]
            generated[2].write_text('/mob/living/human/proc/survival_baseline_step()\n' + block, encoding='utf-8')
            source += f'\n#include "{generated[2].name}"\n#define SURVIVAL_BASELINE\n'
        generated[0].write_text(source + '\n#include "tests/survival/probe.dm"\n', encoding='utf-8')
        commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
        (logs / 'tested.patch').write_text(subprocess.check_output(['git', 'diff'], cwd=root, text=True), encoding='utf-8')
        compiler = binary / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
        daemon = binary / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
        build = subprocess.run([str(compiler), '-max_errors', '0', str(generated[0])], cwd=root,
                               capture_output=True, text=True, timeout=180, creationflags=flags)
        output = build.stdout + build.stderr
        (logs / 'compile.log').write_text(output, encoding='utf-8')
        print(output, flush=True)
        if build.returncode or '516.1681' not in output or '0 errors, 0 warnings' not in output:
            raise RuntimeError('Pinned compilation failed')
        for path in generated[3:]:
            shutil.copy2(path, logs / path.name)
        shutil.copytree(root / 'config', logs / 'config')
        options = ['-invisible', '-close'] if os.name == 'nt' else []
        run = subprocess.run([str(daemon), str(logs / generated[3].name), *options, '-safe',
                              '-params', f'tested_commit={commit}', '-log', 'runtime.log'], cwd=logs,
                             capture_output=True, text=True, timeout=60, creationflags=flags)
        (logs / 'daemon.log').write_text(run.stdout + run.stderr, encoding='utf-8')
        result = (logs / 'survival-result.txt').read_text(encoding='utf-8')
        print(result, flush=True)
        if run.returncode or not result.startswith('PASS:'):
            raise RuntimeError('Survival probe failed')
    finally:
        for path in generated:
            path.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
