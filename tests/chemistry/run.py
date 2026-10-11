"""Bounded chemistry probe for the pinned Windows and Linux BYOND toolchains."""
import argparse
import os
from pathlib import Path
import subprocess
import shutil
import tempfile
import json


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--byond-bin', required=True, type=Path)
    parser.add_argument('--negative-control', action='store_true')
    parser.add_argument('--probe', choices=('polyethylene', 'fuel', 'processing'), default='polyethylene')
    parser.add_argument('--visual', action='store_true')
    parser.add_argument('--port', type=int, default=18329)
    args = parser.parse_args()
    if args.visual and (args.probe == 'processing' or args.negative_control or not 1024 <= args.port <= 65535):
        parser.error('Visual mode requires a valid local port and no negative control')
    root = Path(__file__).resolve().parents[2]
    binary = args.byond_bin.resolve()
    compiler = binary / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = binary / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    prefix = '.chemistry_ci_' + args.probe
    generated = [root / (prefix + suffix) for suffix in
                 ('.dme', '_world.dm', '_recipes.dm', '.dmb', '.rsc', '_login.dm', '_compounds.dm')]
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
        if args.visual:
            generated[5].write_text('/mob/new_player\n\tvar/client/my_client\n/mob/new_player/Login()\n\tchemistry_fixture_login()\n', encoding='utf-8')
            source = source.replace('code\\game\\mob\\new_player\\login.dm', prefix + '_login.dm')
        if args.negative_control and args.probe in ('fuel', 'processing'):
            # Restore the registration defect in a generated source copy.
            compounds = (root / 'code/modules/reagents/Chemistry-Reagents/Chemistry-Reagents-Compounds.dm').read_text(encoding='utf-8')
            reagent = 'octane' if args.probe == 'fuel' else 'n_methylmorpholine_n_oxide'
            target = f'\tid = "{reagent}"'
            if compounds.count(target) != 1:
                raise RuntimeError(f'{reagent} mutation target missing or ambiguous')
            generated[6].write_text(compounds.replace(target, f'\tid = "{reagent}_removed"', 1), encoding='utf-8')
            source = source.replace('code\\modules\\reagents\\Chemistry-Reagents\\Chemistry-Reagents-Compounds.dm', prefix + '_compounds.dm')
        elif args.negative_control:
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
        generated[0].write_text(source + f'\n#include "tests/chemistry/{args.probe}.dm"\n#include "tests/chemistry/visual.dm"\n#include "tests/chemistry/fuel_visual.dm"\n', encoding='utf-8')
        commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
        print(f'Commit: {commit}; probe={args.probe}; negative_control={args.negative_control}', flush=True)
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
        if args.probe == 'processing':
            (logs / 'config/crafting').mkdir(parents=True)
            shutil.copy2(root / 'config/crafting/material_recipes_global.txt',
                         logs / 'config/crafting/material_recipes_global.txt')
        if args.visual:
            daemon_output = (logs / 'daemon.log').open('w', encoding='utf-8')
            visual = subprocess.Popen([str(daemon), str(logs / generated[3].name), str(args.port),
                                       '-invisible', '-safe', '-params', f'tested_commit={commit}&visual=1&probe={args.probe}',
                                       '-log', 'runtime.log'], cwd=logs, stdout=daemon_output,
                                      stderr=subprocess.STDOUT, creationflags=flags)
            daemon_output.close()
            (logs / 'process.json').write_text(json.dumps({'pid': visual.pid, 'commit': commit,
                'port': args.port, 'url': f'byond://127.0.0.1:{args.port}', 'runtime': str(logs)}), encoding='utf-8')
            print(f'Visual process {visual.pid}; byond://127.0.0.1:{args.port}; 15 minute watchdog', flush=True)
            return
        # Run entirely from temporary storage, with no server configuration or
        # normal world startup. The probe calls production holders/reactions.
        platform_flags = ['-invisible', '-close'] if os.name == 'nt' else []
        runtime = subprocess.run([str(daemon), str(logs / generated[3].name), *platform_flags,
                                  '-safe', '-params', f'tested_commit={commit}',
                                  '-log', 'runtime.log'], cwd=logs,
                                 capture_output=True, text=True, timeout=45,
                                 creationflags=flags)
        (logs / 'daemon.log').write_text(runtime.stdout + runtime.stderr, encoding='utf-8')
        print(runtime.stdout + runtime.stderr, flush=True)
        if not (logs / 'chemistry_result.txt').exists():
            runtime_log = logs / 'runtime.log'
            if runtime_log.exists():
                print(runtime_log.read_text(encoding='utf-8', errors='replace'), flush=True)
            raise RuntimeError(f'Chemistry result missing; daemon exit={runtime.returncode}')
        result = (logs / 'chemistry_result.txt').read_text(encoding='utf-8').strip()
        print(result, flush=True)
        failures = {'fuel': 'FAIL: Product missing: octane',
                    'processing': 'FAIL: Bench synthesis unavailable: n_methylmorpholine_n_oxide',
                    'polyethylene': 'FAIL: Polymerization unavailable with catalysts'}
        failure = failures[args.probe]
        expected = (failure
                    if args.negative_control else 'PASS:')
        if runtime.returncode or not result.startswith(expected):
            raise RuntimeError('Chemistry result did not match expected outcome')
        if args.negative_control:
            print(f'PASS: {args.probe} mutation detected', flush=True)
    finally:
        for path in generated:
            path.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
