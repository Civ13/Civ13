"""Actual key-release/rotation callbacks; offline preparation or isolated native CI."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

BASELINE = 'cc03b199128f8afed58713912c551ad7556e6bc4'
MOVEMENT = 'code/game/mob/mob_movement.dm'
WHEELS = 'code/modules/1713/machinery/modular_vehicles/wheels.dm'
RELEASES = ('stopmovingright', 'stopmovingleft')
ADDITION = '\t\tfor(var/obj/item/turret_controls/C in mob)\n\t\t\tC.stop_rotation()\n'

# Exact reviewed whole-file states, decoded as UTF-8 with universal newlines.
# The second is pinned3228 movement plus ONLY the two turret release additions.
# Every Move/SelfMove admission/context/dispatch byte remains covered.
APPROVED_MOVEMENT_REFERENCES = {
    'd53614ecf3aa04ca53a1788528959c46d7878f1189674cbec04d6b2bef8a3a62': BASELINE,
    '62f2c263f16a46558147060ddada9954e701cb95f4208c718dd035b60408f19b': '4b77eab58979ca718faf1aebe9a879a631dcdedf',
}


def movement_reference(source):
    digest = hashlib.sha256(source.encode()).hexdigest()
    reference = APPROVED_MOVEMENT_REFERENCES.get(digest)
    if reference is None:
        raise ValueError('Movement does not match either exact reviewed release-port state')
    return reference


def proc(source, header):
    lines = source.splitlines(keepends=True)
    starts = [i for i, line in enumerate(lines) if line.rstrip('\n') == header]
    if len(starts) != 1:
        raise ValueError('Expected exactly one production procedure: ' + header)
    start = starts[0]
    end = next((i for i in range(start + 1, len(lines))
                if lines[i].startswith('/') and not lines[i].startswith('//')), len(lines))
    return ''.join(lines[start:end]).rstrip() + '\n'


def generate(repo, negative_control=False):
    movement = (repo / MOVEMENT).read_text(encoding='utf-8')
    wheels = (repo / WHEELS).read_text(encoding='utf-8')
    baseline = subprocess.check_output(['git', 'show', BASELINE + ':' + MOVEMENT],
                                       cwd=repo, encoding='utf-8')
    reference_sha = movement_reference(movement)
    source = baseline if negative_control else movement
    generated = ''
    for name in RELEASES:
        body = proc(source, '/client/verb/' + name + '()')
        generated += body.replace('/client/verb/', '/datum/movement_client/verb/', 1) + '\n'
    callbacks = ''
    for name, args in [('stop_rotation', ''), ('start_rotation', 'var/direction'), ('rotate', '')]:
        callbacks += proc(wheels, '/obj/item/turret_controls/proc/' + name + '(' + args + ')') + '\n'
    generated += callbacks
    return generated, {'baseline_sha': BASELINE, 'negative_control': negative_control,
        'movement_reference_sha': reference_sha,
        'movement_sha256': hashlib.sha256(movement.encode()).hexdigest(),
        'wheel_callbacks_sha256': hashlib.sha256(callbacks.encode()).hexdigest(),
        'compiled_source_sha256': hashlib.sha256(generated.encode()).hexdigest(),
        'unchanged_movement_outside_release': True}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--negative-control', action='store_true')
    parser.add_argument('--prepare-only', action='store_true')
    args = parser.parse_args()
    if not args.prepare_only and not args.byond_bin:
        parser.error('Native execution requires explicit --byond-bin')
    if args.output.exists():
        parser.error('Output directory must be fresh')
    repo = Path(__file__).resolve().parents[2]
    generated, evidence = generate(repo, args.negative_control)
    evidence['head_sha'] = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo, encoding='ascii').strip()
    fixture = Path(__file__).with_name('fixture.dm').read_text(encoding='utf-8')
    evidence['fixture_sha256'] = hashlib.sha256(fixture.encode()).hexdigest()
    args.output.mkdir(parents=True)
    (args.output / 'production.dm').write_text(generated, encoding='utf-8')
    (args.output / 'fixture.dm').write_text(fixture, encoding='utf-8')
    evidence['native_executed'] = False
    if not args.prepare_only:
        flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
        with tempfile.TemporaryDirectory(prefix='civ13-turret-release-') as temporary:
            root = Path(temporary)
            (root / 'fixture.dm').write_text(fixture, encoding='utf-8')
            (root / 'production.dm').write_text(generated, encoding='utf-8')
            (root / 'probe.dme').write_text('#include "fixture.dm"\n#include "production.dm"\n', encoding='utf-8')
            compiler = args.byond_bin / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
            daemon = args.byond_bin / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
            build = subprocess.run([str(compiler), '-max_errors', '0', 'probe.dme'], cwd=root,
                capture_output=True, text=True, timeout=60, creationflags=flags)
            log = build.stdout + build.stderr
            (args.output / 'compile.log').write_text(log, encoding='utf-8')
            if build.returncode or '516.1681' not in log or '0 errors, 0 warnings' not in log:
                raise SystemExit('Fixture compilation failed; inspect compile.log')
            run = subprocess.run([str(daemon), 'probe.dmb', '-trusted', '-invisible', '-close', '-log', 'runtime.log'],
                cwd=root, capture_output=True, timeout=45, creationflags=flags)
            log = (root / 'runtime.log').read_text(errors='replace') + (run.stdout + run.stderr).decode(errors='replace')
            (args.output / 'runtime.log').write_text(log, encoding='utf-8')
            if run.returncode or re.search(r'runtime error|Bad ref|Bad loc|Cannot read null|Cannot execute null', log, re.I):
                raise SystemExit('Fixture runtime failed; inspect runtime.log')
            result = json.loads((root / 'result.json').read_text())
            (args.output / 'result.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
            if result.get('scenarios') != 7 or result.get('checks', 0) < 25:
                raise SystemExit('Incomplete runtime scenario coverage')
            failures = result.get('failures')
            if args.negative_control:
                if not failures or 'east release stops scheduled rotation' not in failures:
                    raise SystemExit('Original key-release defect was not detected')
            elif failures:
                raise SystemExit('Key-release regression: ' + str(failures))
            evidence.update(native_executed=True, byond='516.1681', result=result)
    (args.output / 'evidence.json').write_text(json.dumps(evidence, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(evidence))


if __name__ == '__main__':
    main()
