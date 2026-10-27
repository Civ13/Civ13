"""Prepare/compile the exact-Git NPC fixture. Deliberately no runtime launch mode.

NPC runtime admission and real-client rendering require separate scope review.
Reuses the existing 516.1688 compiler allowlist, owned Job and zero-socket guard.
"""
import argparse
import importlib.util
import json
from pathlib import Path
import os

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
spec = importlib.util.spec_from_file_location('npc_current', HERE / 'run-diagonal.py')
current = importlib.util.module_from_spec(spec)
spec.loader.exec_module(current)


def prepare(out):
    manifest = current.legacy.prepare(ROOT, out, 'human')
    current.adapt(out, manifest, 'tests/human_subtile/probe.dm',
                  '\t\t\thuman_subtile_fixture_headless()', '\t\t\tnpc_subtile_fixture()')
    current.adapt(out, manifest, 'tests/human_subtile/probe.dm',
                  '"checks" = human_subtile_fixture_checks,',
                  '"checks" = human_subtile_fixture_checks, "npc_checks" = npc_subtile_checks, "npc_rows" = npc_subtile_rows,')
    dme = out / manifest['dme']
    with dme.open('a', encoding='utf-8') as stream:
        stream.write('\n#include "tests\\human_subtile\\npc.dm"\n')
    manifest['npc_scope'] = 'unowned vendor AI; no client authority adapter'
    manifest['runtime_executed'] = False
    (out / 'npc-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    return manifest


def validate_npc_receipt(row, head):
    """Future native oracle; never treat compile output or counts alone as PASS."""
    current.require(row.get('head') == head and row.get('error') is None and
                    row.get('port') == 0 and (row.get('byond_version'), row.get('byond_build')) == (516, 1688),
                    'Wrong NPC source/engine or failed native fixture')
    current.require(row.get('npc_checks') == 46, 'Incomplete NPC native assertions')
    rows = row.get('npc_rows')
    current.require(isinstance(rows, list) and [r.get('direction') for r in rows] == [1, 2, 4, 8, 5, 9, 6, 10], 'Missing NPC directions')
    for scene in rows:
        direction = scene['direction']
        dx = 1 if direction & 4 else -1 if direction & 8 else 0
        dy = 1 if direction & 1 else -1 if direction & 2 else 0
        pulses = scene.get('pulses')
        current.require(isinstance(pulses, list) and len(pulses) == 16 and
                        scene.get('deadline') == scene.get('started') + 4, 'Wrong NPC pulse count/deadline')
        for index, pulse in enumerate(pulses, 1):
            # Coordinates are authoritative; native Move return truthiness is not.
            current.require((pulse['x'] - 5) * 32 + pulse['sx'] == index * 2 * dx and
                            (pulse['y'] - 5) * 32 + pulse['sy'] == index * 2 * dy,
                            'Wrong physical NPC displacement')
            due = scene['started'] + (index - 1) * 4 / 16
            current.require(due <= pulse['at'] <= due + .5, 'NPC pulse cadence outside one server tick')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--prepare-only', action='store_true')
    mode.add_argument('--compile-only', action='store_true')
    parser.add_argument('--byond-bin', type=Path)
    args = parser.parse_args()
    current.require(args.prepare_only or args.byond_bin, 'Compile requires pinned BYOND directory')
    out = args.output.resolve()
    manifest = prepare(out)
    if args.prepare_only:
        print('Prepared NPC exact Git ' + manifest['head'] + '; no native execution')
        return
    dme = out / manifest['dme']
    binary = args.byond_bin.resolve() / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    session = current.Session(out / 'supervisor', manifest['head'], backend_factory=current.current_backend) if os.name == 'nt' else None
    built = current.run_phase(session, [str(binary), '-max_errors', '0', str(dme)],
                              cwd=out / 'stage', phase='compile', timeout=120,
                              artifacts=[dme.with_suffix('.dmb'), dme.with_suffix('.rsc')])
    log = built.stdout + built.stderr
    (out / 'compile.log').write_text(log)
    current.require(built.returncode == 0, 'NPC fixture compiler exit failed')
    current.legacy.validate_compile(log, dme.with_suffix('.dmb').name)
    receipt = dict(head=manifest['head'], engine='516.1688', compile_passed=True,
                   runtime_executed=False, native_client=False)
    (out / 'compile-accepted.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(receipt))


if __name__ == '__main__':
    main()
