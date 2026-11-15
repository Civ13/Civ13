"""Native fixture for spilled-water puddles: run the production
/obj/effect/flooding body and check its water never strands on the turf."""
import argparse
import json
import os
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PINNED_BYOND = json.loads((ROOT / 'tools/byond/version.json').read_text(encoding='utf-8'))['version']
SOURCE = ROOT / 'code/game/objects/map_metadata/voyage.dm'
EXPECTED_CHECKS = 16


def block(source, signature):
    start = source.index(signature)
    body = source.index('\n', start) + 1
    end = re.search(r'^\S', source[body:], re.M)
    stop = body + end.start() if end else len(source)
    return source[start:stop].rstrip() + '\n'


def prepare(output, control=None):
    source = SOURCE.read_text(encoding='utf-8')
    puddle = block(source, '/obj/effect/flooding\n')
    # The bucket-scooping verb needs the item tree; the fixture drops it.
    puddle = puddle[:puddle.index('\tattackby(')].rstrip() + '\n'
    assert 'T.overlays' not in puddle, 'puddle must not draw on its turf'
    bodies = puddle
    bodies += block(source, '/proc/flooding_edge_toward(')
    bodies += block(source, '/proc/flooding_refresh_neighbors(')
    if control == 'turf':
        # The old behaviour: water drawn onto the turf and never removed.
        bodies = bodies.replace('\t\toverlays.Cut()\n\t\tvar/turf/T = get_turf(src)\n',
                                '\t\tvar/turf/T = get_turf(src)\n\t\tT.overlays.Cut()\n', 1)
        bodies = bodies.replace('\t\toverlays += water_img', '\t\tT.overlays += water_img', 1)
    output.mkdir(parents=True)
    (output / 'icons/turf').mkdir(parents=True)
    shutil.copy(ROOT / 'icons/turf/beach.dmi', output / 'icons/turf/beach.dmi')
    (output / 'production.dm').write_text(bodies, encoding='utf-8')
    (output / 'probe.dm').write_bytes((ROOT / 'tests/spilled_water/probe.dm').read_bytes())
    (output / 'probe.dme').write_text(
        '#define TRUE 1\n#define FALSE 0\n'
        '#define QDELETED(X) (!X || X.gc_destroyed)\n'
        '#include "probe.dm"\n#include "production.dm"\n', encoding='utf-8')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--byond-bin', type=Path)
    parser.add_argument('--prepare-only', action='store_true')
    parser.add_argument('--control', choices=['turf'])
    args = parser.parse_args()
    output = args.output.resolve()
    prepare(output, args.control)
    if args.prepare_only:
        print('PASS source preparation; native runtime not run')
        return
    if not args.byond_bin:
        parser.error('--byond-bin required for native execution')
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    compiler = args.byond_bin / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = args.byond_bin / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    built = subprocess.run([str(compiler), '-max_errors', '0', 'probe.dme'], cwd=output,
                           capture_output=True, text=True, timeout=60, creationflags=flags)
    log = built.stdout + built.stderr
    (output / 'compile.log').write_text(log)
    if built.returncode or PINNED_BYOND not in log or '0 errors, 0 warnings' not in log:
        raise SystemExit(log)
    ran = subprocess.run([str(daemon), 'probe.dmb', '-invisible', '-close', '-trusted', '-ip', '127.0.0.1', '-log', 'runtime.log'],
                         cwd=output, capture_output=True, text=True, timeout=60, creationflags=flags)
    combined = (output / 'runtime.log').read_text() if (output / 'runtime.log').exists() else ''
    combined += ran.stdout + ran.stderr
    if re.search(r'runtime error|Bad ref|BUG:', combined, re.I):
        raise SystemExit(combined)
    result = json.loads((output / 'result.json').read_text())
    if result['checks'] != EXPECTED_CHECKS:
        raise SystemExit(f'Incomplete: {result}')
    if args.control:
        assert 'dry dirt shows no water' in result['failed_labels'], result
    else:
        assert not result['failed_labels'], result
    print(json.dumps(result))
    print('PASS ' + (args.control or 'spilled water puddles'))


if __name__ == '__main__':
    main()
