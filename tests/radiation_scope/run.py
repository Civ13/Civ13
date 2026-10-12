"""Extract production radiation procedures into a bounded offline BYOND fixture."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile


def extract(source, path):
    match = re.search(r'^' + re.escape(path) + r'\([^\n]*\)[^\n]*\n[\s\S]*?(?=^/|\Z)', source, re.M)
    if not match:
        raise RuntimeError(f'Missing production procedure {path}')
    return match.group(0).rstrip()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--byond-bin', required=True, type=Path)
    parser.add_argument('--negative-control', choices=('cross-z', 'normalization'))
    parser.add_argument('--output-dir', type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    evidence = args.output_dir or Path(tempfile.mkdtemp(prefix='civ13-radiation-evidence-'))
    if args.output_dir:
        evidence.mkdir(parents=True, exist_ok=False)
    commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
    source = (root / 'code/modules/1713/radiation.dm').read_text(encoding='utf-8')
    paths = ['/proc/nuke_map', '/proc/radiation_pulse', '/atom/proc/rad_act',
             '/turf/floor/rad_act', '/turf/floor/grass/rad_act',
             '/turf/floor/beach/water/rad_act', '/mob/living/rad_act',
             '/mob/living/human/rad_act', '/mob/living/human/proc/getarmor_rad']
    production = '\n\n'.join(extract(source, path) for path in paths)
    if args.negative_control == 'cross-z':
        if production.count('if (W.z == event_z)') != 2:
            raise RuntimeError('Window/wild control anchors changed')
        production = production.replace('if (W.z == event_z)', 'if (TRUE)')
    elif args.negative_control == 'normalization':
        anchor = '\tepicenter = get_turf(epicenter)\n'
        if production.count(anchor) != 1:
            raise RuntimeError('Normalization control anchor changed')
        production = production.replace(anchor, '', 1)
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    compiler = args.byond_bin / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = args.byond_bin / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    with tempfile.TemporaryDirectory(prefix='civ13-radiation-scope-') as directory:
        work = Path(directory)
        (work / 'production.dm').write_text(production, encoding='utf-8')
        (work / 'fixture.dm').write_text((Path(__file__).parent / 'fixture.dm').read_text(encoding='utf-8'), encoding='utf-8')
        definitions = '#define NORMALIZATION_CONTROL 1\n' if args.negative_control == 'normalization' else ''
        (work / 'probe.dme').write_text(definitions + '#include "fixture.dm"\n#include "production.dm"\n', encoding='utf-8')
        hashes = {}
        for name in ('production.dm', 'fixture.dm', 'probe.dme'):
            contents = (work / name).read_bytes()
            (evidence / name).write_bytes(contents)
            hashes[name] = hashlib.sha256(contents).hexdigest()
        (evidence / 'metadata.json').write_text(json.dumps({'head_sha': commit,
            'negative_control': args.negative_control, 'source_sha256': hashes,
            'production_source_sha256': hashlib.sha256(source.encode()).hexdigest(),
            'scope': 'extracted production direct fallout with isolated effect adapters'}, indent=2), encoding='utf-8')
        build = subprocess.run([str(compiler), '-max_errors', '0', 'probe.dme'], cwd=work,
                               capture_output=True, text=True, timeout=60, creationflags=flags)
        output = build.stdout + build.stderr
        (evidence / 'compile.log').write_text(output, encoding='utf-8')
        print(output, flush=True)
        if build.returncode or not re.search(r'DM compiler version 516\.1681\b', output) or '0 errors, 0 warnings' not in output:
            raise RuntimeError('Pinned fixture compilation failed')
        daemon_args = [str(daemon), 'probe.dmb']
        if os.name == 'nt':
            daemon_args.append('-invisible')
        result = subprocess.run(daemon_args + ['-safe', '-log', 'runtime.log'],
                                cwd=work, capture_output=True, text=True, timeout=30, creationflags=flags)
        stdio = result.stdout + result.stderr
        (evidence / 'daemon-stdio.log').write_text(stdio, encoding='utf-8')
        output = (work / 'runtime.log').read_text(encoding='utf-8', errors='replace')
        (evidence / 'runtime.log').write_text(output, encoding='utf-8')
        print(output, flush=True)
        if result.returncode or re.search(r'runtime error:|Bad ref|DM runtime', output + stdio, re.I):
            raise RuntimeError('Native runtime diagnostics invalidate all fixture modes')
        failures = re.findall(r'^FAIL (.+)$', output, re.M)
        if output.count('DONE radiation scope') != 1:
            raise RuntimeError('Fixture completion missing or duplicated')
        if args.negative_control:
            expected = {'cross-z': ['windows scoped and once', 'other-z plants unchanged',
                                    'second event remains scoped'],
                        'normalization': ['epicenter normalized to turf']}[args.negative_control]
            if failures != expected or 'PASS radiation scope' in output:
                raise RuntimeError(f'Negative control must fail only {expected!r}: {failures}')
            print(f'PASS detected {args.negative_control} control')
        elif failures or output.count('PASS radiation scope') != 1:
            raise RuntimeError('Radiation scope fixture failed')
        (evidence / 'result.json').write_text(json.dumps({'head_sha': commit, 'status': 'passed',
            'negative_control': args.negative_control, 'scope': 'isolated native fixture'}, indent=2), encoding='utf-8')
        print(f'Evidence: {evidence}')


if __name__ == '__main__':
    main()
