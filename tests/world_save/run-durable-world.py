"""Run production world/metadata persistence on a tiny isolated native world."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import uuid


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', type=Path)
    parser.add_argument('--prepare-only', action='store_true')
    parser.add_argument('--dimension-bootstrap', action='store_true',
                        help='Run fresh expanded round-v2 writer and compiled-size reader processes')
    parser.add_argument('--startup-only', action='store_true',
                        help='Diagnose production initialization without running any persistence assertions')
    parser.add_argument('--profile', choices=('gaia', 'europe'), default='gaia')
    parser.add_argument('--negative-control', choices=('season', 'preflight', 'reachability', 'callback', 'timer-restore'))
    args = parser.parse_args()
    if args.dimension_bootstrap and (args.startup_only or args.negative_control):
        parser.error('Expanded fresh-process checks run separately from existing mutation/startup cases')
    if args.startup_only and args.negative_control:
        parser.error('Startup diagnostics cannot run persistence mutation controls')
    if not args.prepare_only and not args.byond_bin:
        parser.error('--byond-bin is required for native execution')
    root = Path(__file__).resolve().parents[2]
    output = Path(tempfile.mkdtemp(prefix='civ13-durable-world-'))
    prefix = '.durable_world_' + uuid.uuid4().hex
    dme = root / (prefix + '.dme')
    generated = []
    receipt = {'profile': args.profile, 'negative_control': args.negative_control,
               'dimension_bootstrap': args.dimension_bootstrap,
               'prepared_only': args.prepare_only, 'startup_only': args.startup_only,
               'production_hashes': {}}
    print(f'Retained evidence: {output}', flush=True)
    try:
        source = (root / 'civ13.dme').read_text(encoding='utf-8')
        source = re.sub(r'^#include ".*\.dmm"\s*$', '', source, flags=re.M)
        replacements = {}
        for relative in ('code/world.dm', 'code/controllers/mc/globals.dm'):
            text = (root / relative).read_text(encoding='utf-8')
            if relative == 'code/world.dm':
                start = text.index('/world/New()')
                parent = text.index('\n\t..()', start)
                text = text[:parent] + text[parent:].replace('\n\t..()', '', 1)
                text = text.replace('/world/New()', '/world/proc/unused_durable_startup()', 1)
                marker = '/datum/global_init/New()\n'
            else:
                marker = '/datum/controller/global_vars/New()\n'
            if text.count(marker) != 1:
                raise RuntimeError('Startup isolation anchor changed')
            replacements[relative] = text.replace(marker, marker + '\treturn\n', 1)
        mutations = {
            'season': ('code/modules/persistence/durable_world.dm', '\tseason = E["season"]', '\tseason = "SPRING"'),
            'preflight': ('code/modules/persistence/durable_world.dm', '\tvar/list/fields = state["fields"]', '\tif(islist(state["fields"])) return TRUE\n\tvar/list/fields = state["fields"]'),
            'reachability': ('code/modules/persistence/durable_world.dm', '\tvalidate_durable_reachability(G)', '\tif(FALSE) validate_durable_reachability(G)'),
            'callback': ('code/modules/persistence/durable_timers.dm', '\t\tif(!owner || revision != expected_revision || pending[key] != row) return', '\t\tif(!owner) return'),
            'timer-restore': ('code/modules/persistence/durable_world.dm', '\tmap.durable_timer_queue().restore(timers)', '\t// Negative control: omit restoring persisted callbacks.'),
        }
        if args.negative_control:
            relative, before, after = mutations[args.negative_control]
            text = (root / relative).read_text(encoding='utf-8')
            if text.count(before) != 1:
                raise RuntimeError('Negative-control anchor changed')
            replacements[relative] = text.replace(before, after, 1)
        for index, (relative, text) in enumerate(replacements.items()):
            generated_path = root / (prefix + f'_{index}.dm')
            generated_path.write_text(text, encoding='utf-8', newline='\n')
            generated.append(generated_path)
            original_include = relative.replace('/', chr(92))
            if source.count(original_include) != 1:
                raise RuntimeError('Production include anchor changed')
            source = source.replace(original_include, generated_path.name)
            (output / generated_path.name).write_text(text, encoding='utf-8', newline='\n')
        probe = (root / 'tests/world_save/durable_world_probe.dm').read_text(encoding='utf-8')
        if args.dimension_bootstrap:
            probe = probe[:probe.index('/world/New()')] + (root / 'tests/world_save/durable_dimension_probe.dm').read_text(encoding='utf-8')
        if args.startup_only:
            marker = '/world/New()\n'
            if probe.count(marker) != 1:
                raise RuntimeError('Startup diagnostic probe anchor changed')
            probe = probe[:probe.index(marker)] + marker + (
                '\ttext2file("startup-only world-New entered", "probe-progress.log")\n'
                '\tworld.OpenPort(0)\n'
                '\ttext2file(json_encode(list("startup_only" = TRUE)), "startup-result.json")\n'
                '\tdel(world)\n')
        probe_path = root / (prefix + '_probe.dm')
        probe_path.write_text(probe, encoding='utf-8', newline='\n')
        generated.append(probe_path)
        (output / probe_path.name).write_text(probe, encoding='utf-8', newline='\n')
        source += '\n#include "' + probe_path.name + '"\n'
        dme.write_text(source, encoding='utf-8', newline='\n')
        for path in (root / 'code/modules/persistence').glob('*.dm'):
            receipt['production_hashes'][path.relative_to(root).as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
        receipt['probe_hash'] = hashlib.sha256((root / 'tests/world_save/durable_world_probe.dm').read_bytes()).hexdigest()
        receipt['generated_probe_hash'] = hashlib.sha256(probe_path.read_bytes()).hexdigest()
        receipt['base_commit'] = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
        (output / 'tested.patch').write_bytes(subprocess.check_output(['git', 'diff'], cwd=root))
        (output / 'probe.dme').write_text(source, encoding='utf-8')
        (output / 'receipt.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
        if args.prepare_only:
            return
        byond = args.byond_bin.resolve(strict=True)
        compiler = byond / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
        daemon = byond / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
        flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
        build = subprocess.run([str(compiler), '-max_errors', '0', dme.name], cwd=root,
                               capture_output=True, text=True, timeout=180, creationflags=flags)
        build_log = build.stdout + build.stderr
        (output / 'compile.log').write_text(build_log, encoding='utf-8')
        if build.returncode or '0 errors, 0 warnings' not in build_log or '516.1681' not in build_log:
            raise RuntimeError('Pinned native compilation failed; see compile.log')
        for suffix in ('.dmb', '.rsc'):
            shutil.copy2(dme.with_suffix(suffix), output / dme.with_suffix(suffix).name)
        (output / 'config').mkdir()
        shutil.copy2(root / 'config/tips.txt', output / 'config/tips.txt')
        shutil.copytree(root / 'config/names', output / 'config/names')
        platform_flags = ['-invisible', '-close'] if os.name == 'nt' else []
        if args.dimension_bootstrap:
            # Both use the identical compiled two-level DMB. Only disk files
            # survive from the writer to the fresh reader process.
            for mode, minimum_checks in (('write', 3), ('read', 12)):
                run = subprocess.run([str(daemon), dme.with_suffix('.dmb').name, *platform_flags, '-safe',
                    '-params', f'profile={args.profile};dimension_mode={mode}', '-log', f'{mode}-runtime.log'],
                    cwd=output, capture_output=True, text=True, timeout=120, creationflags=flags)
                (output / f'{mode}-daemon.log').write_text(run.stdout + run.stderr, encoding='utf-8')
                log = (output / f'{mode}-runtime.log').read_text(encoding='utf-8', errors='replace')
                diagnostics = log + run.stdout + run.stderr
                if run.returncode or re.search(r'##\s*error\s*:|unexpected runtime|bad ref|runtime error:|infinite loop|fatal error|segmentation|assertion failed', diagnostics, re.I):
                    raise RuntimeError(f'Expanded {mode} native diagnostics invalidated evidence')
                result = json.loads((output / 'metadata-result.json').read_text(encoding='utf-8'))
                (output / f'{mode}-result.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
                receipt[mode] = result
                (output / 'receipt.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
                if not result.get('done') or result.get('checks', 0) < minimum_checks:
                    raise RuntimeError(f'Expanded {mode} assertions incomplete: {result}')
                # A reader must write its own completion record.
                (output / 'metadata-result.json').unlink()
            print(json.dumps(receipt, indent=2))
            return
        run = subprocess.run([str(daemon), dme.with_suffix('.dmb').name, *platform_flags, '-safe',
                              '-params', 'profile=' + args.profile, '-log', 'runtime.log'], cwd=output,
                             capture_output=True, text=True, timeout=90, creationflags=flags)
        (output / 'daemon.log').write_text(run.stdout + run.stderr, encoding='utf-8')
        (output / 'daemon-exit.json').write_text(json.dumps({'exit_code': run.returncode}), encoding='utf-8')
        if run.returncode:
            raise RuntimeError(f'Native daemon exited with {run.returncode}; see daemon-exit.json')
        log = (output / 'runtime.log').read_text(encoding='utf-8', errors='replace')
        diagnostics = (log + run.stdout + run.stderr).lower()
        if (re.search(r'##\s*error\s*:', diagnostics) or
                any(word in diagnostics for word in ('unexpected runtime', 'bad ref', 'runtime error:', 'infinite loop', 'fatal error', 'segmentation', 'assertion failed'))):
            raise RuntimeError('Native engine diagnostic invalidated fixture')
        if args.startup_only:
            startup = json.loads((output / 'startup-result.json').read_text(encoding='utf-8'))
            if startup != {'startup_only': 1}:
                raise RuntimeError('Startup diagnostic did not complete')
            receipt['startup_result'] = startup
            (output / 'receipt.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
            print('Startup diagnostic completed; no persistence assertions ran.')
            return
        result_path = output / 'metadata-result.json'
        if not result_path.is_file():
            raise RuntimeError('Native daemon exited without a result; see daemon-exit.json and probe-progress.log')
        result = json.loads(result_path.read_text(encoding='utf-8'))
        expected = {'season': 'environment phase reset', 'preflight': 'malformed artillery sentinel mutated world',
                    'reachability': 'orphan metadata reference accepted', 'callback': 'restored callback duplicated',
                    'timer-restore': 'persisted callback was not restored'}
        if args.negative_control:
            if result.get('done') or result.get('error') != expected[args.negative_control]:
                raise RuntimeError('Negative control failed outside its intended assertion: ' + str(result))
            if args.negative_control == 'preflight' and result.get('checks') != 7:
                raise RuntimeError('Preflight control did not reach its first malformed-wire assertion')
        elif not result.get('done') or result.get('checks', 0) < 19:
            raise RuntimeError('Native integration fixture incomplete: ' + str(result))
        receipt['result'] = result
        receipt['expected_failure_caught'] = bool(args.negative_control)
        (output / 'receipt.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
        print(json.dumps(receipt, indent=2))
    finally:
        for path in [dme, dme.with_suffix('.dmb'), dme.with_suffix('.rsc'), *generated]:
            path.unlink(missing_ok=True)


if __name__ == '__main__':
    main()
