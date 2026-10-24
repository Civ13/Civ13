"""Four serial Windows native phases, only when explicitly invoked after review.

No grant/lease format is invented here. --expected-commit pins reviewed source;
it does not authorize execution. This driver is not run by ordinary CI.
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'scripts'))
from native_fixture import Session, require

INPUTS = ['scripts/native_fixture.py', 'tests/animal_harvest/validate_tanning.py',
          'tests/animal_harvest/run.py', 'tests/animal_harvest/probe.dm',
          'tests/animal_harvest/tanning_probe.dm', 'tests/crafting_atlas/run.py',
          'tests/crafting_atlas/probe.dm', 'tests/crafting_atlas/full_probe.dm',
          'tests/crafting_atlas/navigation.dm', 'code/game/mob/crafting_atlas.dm',
          'UI/crafting-atlas.json', 'tests/floor_decal_tracking/windows.py',
          'tests/floor_decal_tracking/guard_config.py', 'tests/floor_decal_tracking/owned_job.py']


def load(relative, name):
    spec = importlib.util.spec_from_file_location(name, ROOT/relative)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--expected-commit', required=True)
    parser.add_argument('--byond-bin', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    require(os.name == 'nt', 'This four-phase supervisor is Windows-only; Linux uses existing hosted CI')
    head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True, timeout=10).strip()
    require(args.expected_commit == head and len(head) == 40, 'Reviewed source head mismatch')
    subprocess.run(['git', 'diff', '--quiet', 'HEAD', '--'], cwd=ROOT, check=True, timeout=10)
    session = Session(args.output, head)
    payload = {'head': head, 'inputs': {p: hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in INPUTS},
               'native_phase_order': ['atlas-compile', 'atlas-runtime', 'harvest-compile', 'harvest-runtime'],
               'toolchain': {n: hashlib.sha256((args.byond_bin/n).read_bytes()).hexdigest() for n in ('dm.exe', 'dd.exe')}}
    (session.evidence/'inputs.json').write_text(json.dumps(payload, indent=2)+'\n', encoding='utf-8')
    try:
        atlas = load('tests/crafting_atlas/run.py', 'tanning_atlas_runner')
        atlas.main(['--byond-bin', str(args.byond_bin), '--full-catalog',
                    '--evidence-dir', str(session.evidence/'atlas')], session=session)
        harvest = load('tests/animal_harvest/run.py', 'tanning_harvest_runner')
        harvest.main(['--byond-bin', str(args.byond_bin),
                      '--evidence-dir', str(session.evidence/'harvest')], session=session)
        require([p['phase'] for p in session.phases] == payload['native_phase_order'] and
                all(p['accepted'] for p in session.phases) and not session.failed,
                'Incomplete four-phase acceptance')
        (session.evidence/'accepted.txt').write_text('PASS: four reviewed native phases\n', encoding='utf-8')
    except BaseException:
        session.failed = True
        raise
    finally:
        session.persist()


if __name__ == '__main__':
    main()
