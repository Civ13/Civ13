"""Bounded chemistry probe for the pinned Windows and Linux BYOND toolchains."""
import argparse
import os
from pathlib import Path
import subprocess
import shutil
import tempfile


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--byond-bin', required=True, type=Path)
    parser.add_argument('--negative-control', action='store_true')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    binary = args.byond_bin.resolve()
    compiler = binary / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = binary / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    prefix = '.chemistry_ci'
    generated = [root / (prefix + suffix) for suffix in
                 ('.dme', '_world.dm', '_recipes.dm', '.dmb', '.rsc')]
    if any(path.exists() for path in generated):
        raise RuntimeError('Existing chemistry probe files must be preserved')
    logs = Path(tempfile.mkdtemp(prefix='civ13-chemistry-ci-'))
    print(f'Isolated runtime and logs: {logs}', flush=True)
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    try:
        world = (root / 'code/world.dm').read_text(encoding='utf-8')
        start = world.index('/world/New()')
        parent = world.index('\n\t..()', start)
        world = world[:parent] + world[parent:].replace('\n\t..()', '', 1)
        world = world.replace('/world/New()', '/world/proc/unused_chemistry_startup()', 1)
        generated[1].write_text(world, encoding='utf-8')
        source = (root / 'civ13.dme').read_text(encoding='utf-8')
        source = source.replace('code\\world.dm', prefix + '_world.dm')
        if args.negative_control:
            # Reintroduce the original wrong feedstock only in a generated copy.
            recipes = (root / 'code/modules/reagents/Chemistry-Recipes.dm').read_text(encoding='utf-8')
            target = recipes.index('/datum/chemical_reaction/polyethylene\n')
            tail = recipes[target:]
            if 'required_reagents = list("ethylene" = 2)' not in tail:
                raise RuntimeError('Polyethylene mutation target missing')
            recipes = recipes[:target] + tail.replace(
                'required_reagents = list("ethylene" = 2)',
                'required_reagents = list("propylene" = 2)', 1)
            generated[2].write_text(recipes, encoding='utf-8')
            source = source.replace('code\\modules\\reagents\\Chemistry-Recipes.dm',
                                    prefix + '_recipes.dm')
        generated[0].write_text(source + '\n#include "tests/chemistry/polyethylene.dm"\n', encoding='utf-8')
        commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
        print(f'Commit: {commit}; negative_control={args.negative_control}', flush=True)
        build = subprocess.run([str(compiler), '-max_errors', '0', str(generated[0])],
                               cwd=root, capture_output=True, text=True, timeout=120,
                               creationflags=flags)
        output = build.stdout + build.stderr
        (logs / 'compile.log').write_text(output, encoding='utf-8')
        print(output, flush=True)
        if build.returncode or '0 errors, 0 warnings' not in output:
            raise RuntimeError('Chemistry compilation failed')
        shutil.copy2(generated[3], logs / generated[3].name)
        shutil.copy2(generated[4], logs / generated[4].name)
        # Run entirely from temporary storage, with no server configuration or
        # normal world startup. The probe calls production holders/reactions.
        runtime = subprocess.run([str(daemon), str(logs / generated[3].name), '-invisible',
                                  '-safe', '-close', '-params', f'tested_commit={commit}',
                                  '-log', str(logs / 'runtime.log')], cwd=logs,
                                 capture_output=True, text=True, timeout=45,
                                 creationflags=flags)
        (logs / 'daemon.log').write_text(runtime.stdout + runtime.stderr, encoding='utf-8')
        result = (logs / 'chemistry_result.txt').read_text(encoding='utf-8').strip()
        print(result, flush=True)
        expected = ('FAIL: Polymerization unavailable with catalysts'
                    if args.negative_control else 'PASS:')
        if runtime.returncode or not result.startswith(expected):
            raise RuntimeError('Chemistry result did not match expected outcome')
        if args.negative_control:
            print('PASS: wrong-feedstock mutation detected', flush=True)
    finally:
        for path in generated:
            path.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
