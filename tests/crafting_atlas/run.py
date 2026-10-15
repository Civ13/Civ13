"""Native bounded atlas renderer probe; no game startup, clients or game objects."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import shutil
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--negative-control', action='store_true')
    parser.add_argument('--full-catalog', action='store_true')
    parser.add_argument('--compile-only', action='store_true')
    parser.add_argument('--navigation-negative-control', choices=('default', 'era', 'processor', 'output'))
    args = parser.parse_args()
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    with tempfile.TemporaryDirectory(prefix='atlas-renderer-') as folder:
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
        build = subprocess.run([str(compiler), '-max_errors', '0', 'probe.dme'], cwd=tmp, text=True, capture_output=True, timeout=120, creationflags=flags)
        if build.returncode or '0 errors, 0 warnings' not in build.stdout + build.stderr:
            raise RuntimeError(build.stdout + build.stderr)
        if args.compile_only:
            print('PASS: Compile only, 0 errors/warnings; no runtime launched')
            return
        run = subprocess.run([str(daemon), 'probe.dmb', *(['-invisible', '-close'] if os.name == 'nt' else []), '-safe', '-log', 'runtime.log'], cwd=tmp, text=True, capture_output=True, timeout=30, creationflags=flags)
        logs = (tmp / 'runtime.log').read_text(errors='replace') if (tmp / 'runtime.log').exists() else ''
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
