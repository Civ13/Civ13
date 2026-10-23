"""Native bounded atlas renderer probe; no game startup, clients or game objects."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import shutil
import tempfile
import sys
from contextlib import nullcontext

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'scripts'))
from native_fixture import Session, no_port_args, read_bounded, run_native


def main(argv=None, session=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--negative-control', action='store_true')
    parser.add_argument('--full-catalog', action='store_true')
    parser.add_argument('--compile-only', action='store_true')
    parser.add_argument('--navigation-negative-control', choices=('default', 'era', 'processor', 'output'))
    parser.add_argument('--evidence-dir', type=Path)
    args = parser.parse_args(argv)
    storage = ROOT/'data/atlas-renderer-tests'
    storage.mkdir(parents=True, exist_ok=True)
    evidence = args.evidence_dir.resolve() if args.evidence_dir else Path(tempfile.mkdtemp(prefix='run-', dir=storage))
    if args.evidence_dir:
        evidence.mkdir(parents=True, exist_ok=False)
    print(f'Evidence retained: {evidence}', flush=True)
    if os.name == 'nt' and session is None:
        commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True, timeout=10).strip()
        session = Session(evidence/'supervisor', commit)
    with nullcontext(evidence) as folder:
        tmp = Path(folder)
        records = [{'name': f'Recipe {i}', 'kind': 'Fixture',
                    'inputs': [{'id': 'fixture', 'name': 'Needle' if i == 13 else '<script>alert</script>', 'quantity': '1'}],
                    'outputs': [], 'conditions': 'Fixture only'} for i in range(1, 14)]
        records[0]['inputs'].append({'id':'variant','name':'Paper variant','quantity':'1'})
        catalog = {'recipes': records, 'resources': {'fixture': {'type': '/missing/type'},'variant':{'type':'/obj/item/weapon/paper','state':'paper'}}}
        if args.full_catalog:
            catalog=json.loads((ROOT/'UI/crafting-atlas.json').read_text())
        (tmp / 'catalog.json').write_text(json.dumps(catalog), encoding='utf-8')
        source = (ROOT / 'code/game/mob/crafting_atlas.dm').read_text(encoding='utf-8')
        source = source.replace("'UI/crafting-atlas.json'", "'catalog.json'")
        if args.negative_control:
            assert 'shown >= 12' in source
            source = source.replace('shown >= 12', 'shown >= 13')
        controls = {
            'default': ('legacy ? page_html', 'TRUE ? page_html', 'navigation default is dependency atlas'),
            'era': ('!(text2num(era) in eras)', 'FALSE', 'navigation era membership filter'),
            'processor': ('processor && recipe["processor"] != processor', 'FALSE', 'navigation processor filter'),
            'output': ('jointext(outputs, "")', '""', 'navigation output quantity rendered'),
        }
        if args.navigation_negative_control:
            before, after, expected = controls[args.navigation_negative_control]
            assert before in source
            source = source.replace(before, after)
        (tmp / 'atlas.dm').write_text(source, encoding='utf-8')
        shutil.copy2(ROOT / 'icons/obj/bureaucracy.dmi', tmp / 'paper.dmi')
        probe=(ROOT / 'tests/crafting_atlas/probe.dm').read_text(encoding='utf-8')
        if args.full_catalog:
            probe=probe.split('/world/New()')[0]+(ROOT/'tests/crafting_atlas/full_probe.dm').read_text()
        fixture = "#define PAPER_ICON 'paper.dmi'\n#define ATLAS_EXPECTED_RECIPES "+str(len(catalog['recipes']))+"\n#include \"atlas.dm\"\n" + probe + (ROOT/'tests/crafting_atlas/navigation.dm').read_text()
        (tmp / 'probe.dme').write_text(fixture, encoding='utf-8')
        compiler = args.byond_bin / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
        daemon = args.byond_bin / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
        build = run_native(session, [str(compiler), '-max_errors', '0', 'probe.dme'], cwd=tmp,
                           phase='atlas-compile', timeout=120, artifacts=[tmp/'probe.dmb', tmp/'probe.rsc'])
        if build.returncode or '0 errors, 0 warnings' not in build.stdout + build.stderr:
            raise RuntimeError(build.stdout + build.stderr)
        if args.compile_only:
            print('PASS: Compile only, 0 errors/warnings; no runtime launched')
            return
        run = run_native(session, [str(daemon), 'probe.dmb', *(['-invisible', '-close'] if os.name == 'nt' else []),
                                  *no_port_args(), '-trusted', '-log', 'runtime.log'],
                         cwd=tmp, phase='atlas-runtime', timeout=30, state_directory=tmp)
        logs = read_bounded(tmp/'runtime.log') if (tmp/'runtime.log').exists() else ''
        if read_bounded(tmp/'port-closed.txt', 16).strip() != 'closed':
            raise RuntimeError('Native no-port assertion did not complete')
        if run.returncode or any(marker in logs.lower() for marker in ('runtime error:', '## error:', 'bug:')):
            raise RuntimeError(str(run.returncode) + logs + run.stdout + run.stderr)
        failed = (tmp / 'failed.txt').exists()
        if args.navigation_negative_control:
            if not failed or (tmp/'passed.txt').exists() or expected not in logs:
                raise RuntimeError('Navigation negative control not detected: '+args.navigation_negative_control+'\n'+logs)
            print('PASS: Navigation negative control detected: '+args.navigation_negative_control)
        elif args.negative_control:
            if not failed or (tmp / 'passed.txt').exists():
                raise RuntimeError('Pagination negative control was not detected')
            print('PASS: Pagination negative control detected')
        elif failed or not (tmp / 'passed.txt').exists():
            raise RuntimeError(logs + 'Atlas renderer did not complete')
        else:
            print('PASS: Native atlas pagination, search, escaping, sprites and no item constructors (0 errors/warnings)')


if __name__ == '__main__':
    main()
