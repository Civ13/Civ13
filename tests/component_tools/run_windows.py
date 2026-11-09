"""Current-pin Windows component fixture using the existing owned-Job supervisor.

No maps, global startup, game configuration, clients or external effects. Linux
CI uses scripts/check-component-tools.py and its canonical archive verification.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
from native_fixture import Session, no_port_args, run_native


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--negative-control', choices=('armor-consumption', 'armor-research'))
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    build, run = out / 'source', out / 'runtime'
    build.mkdir(); run.mkdir()
    helper = load('component_windows_supervisor', ROOT / 'tests/human_subtile/run-diagonal.py')
    generator = load('component_generator', ROOT / 'scripts/check-component-tools.py')
    head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    session = Session(out / 'supervisor', head, backend_factory=helper.current_backend)
    world = (ROOT / 'code/world.dm').read_text(encoding='utf-8')
    for marker, replacement in [
        ('/datum/global_init/New()\n', '\treturn\n'),
        ('/world/New()\n', '\tworld.OpenPort("none")\n\tspawn(1)\n\t\trun_component_checks()\n\treturn\n')]:
        world = generator.replace_once(world, marker, marker + replacement)
    (build / 'world.dm').write_text(world, encoding='utf-8')
    globals_dm = (ROOT / 'code/controllers/mc/globals.dm').read_text(encoding='utf-8')
    marker = '/datum/controller/global_vars/New()\n'
    (build / 'globals.dm').write_text(generator.replace_once(globals_dm, marker, marker + '\treturn\n'), encoding='utf-8')
    dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
    for relative, generated in [('code/world.dm', 'world.dm'), ('code/controllers/mc/globals.dm', 'globals.dm')]:
        dme = generator.replace_once(dme, '#include "' + relative.replace('/', '\\') + '"', f'#include "{build.as_posix()}/{generated}"')
    if args.negative_control:
        armor = (ROOT / 'code/game/objects/structures/blacksmithing/armor_workbench.dm').read_text(encoding='utf-8')
        if args.negative_control == 'armor-consumption':
            armor = generator.replace_once(armor, '\t\t\tS.use(cost[1])', '\t\t\tS.can_use(cost[1])')
        else:
            armor = generator.replace_once(armor, 'crafting_node_allowed(H, R["node"])', 'TRUE')
        (build / 'armor.dm').write_text(armor, encoding='utf-8')
        dme = generator.replace_once(dme, '#include "code\\game\\objects\\structures\\blacksmithing\\armor_workbench.dm"', f'#include "{build.as_posix()}/armor.dm"')
    dme = re.sub(r'^#include ".*\.(dmf|dmm)"\s*$', '', dme, flags=re.M)
    dme += f'\n#include "{ROOT.as_posix()}/tests/component_tools/checks.dm"\n'
    dme = dme.replace('#define FILE_DIR .', f'#define FILE_DIR "{ROOT.as_posix()}"')
    dme = re.sub(r'^#include "([^/":][^":]*)"', lambda m: f'#include "{ROOT.as_posix()}/{m[1].replace(chr(92), "/")}"', dme, flags=re.M)
    source = build / 'recipes.dme'
    source.write_text(dme, encoding='utf-8')
    paths = [*build.iterdir(), *ROOT.glob('tests/component_tools/*.dm'),
             ROOT / 'code/game/objects/structures/blacksmithing/armor_workbench.dm',
             ROOT / 'code/game/objects/structures/blacksmithing/component_workbench.dm',
             ROOT / 'code/game/objects/structures/blacksmithing/dedicated_workbenches.dm',
             Path(__file__), ROOT / 'civ13.dme']
    manifest = dict(head=head, negative_control=args.negative_control,
                    dirty_diff=subprocess.check_output(['git', 'diff', 'HEAD', '--binary'], cwd=ROOT, text=True),
                    sha256={str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths})
    (out / 'inputs.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    binary = args.byond_bin.resolve()
    compiled = run_native(session, [str(binary / 'dm.exe'), '-max_errors', '0', str(source)], cwd=ROOT,
                          phase='compile', timeout=120, artifacts=[source.with_suffix('.dmb'), source.with_suffix('.rsc')])
    log = compiled.stdout + compiled.stderr
    (out / 'compile.log').write_text(log, encoding='utf-8')
    if compiled.returncode or 'DM compiler version 516.1688' not in log or '0 errors, 0 warnings' not in log:
        print(log); return 1
    for suffix in ('.dmb', '.rsc'):
        shutil.copy2(source.with_suffix(suffix), run)
    for relative in ('config/crafting', 'config/names'):
        shutil.copytree(ROOT / relative, run / relative)
    executed = run_native(session, [str(binary / 'dd.exe'), str(run / 'recipes.dmb'), '-invisible', '-close',
                          *no_port_args(), '-trusted'], cwd=run, phase='runtime', timeout=90, state_directory=run)
    log = executed.stdout + executed.stderr
    (out / 'runtime.log').write_text(log, encoding='utf-8')
    report = (run / 'component-checks.txt').read_text(encoding='utf-8') if (run / 'component-checks.txt').exists() else ''
    print(log); print(report)
    if executed.returncode or any(s in log.lower() for s in ('runtime error:', 'bug:', '## error:')):
        return 1
    if args.negative_control:
        required = 'armor carrier exact costs/excess' if args.negative_control == 'armor-consumption' else 'armor specialist research bypass'
        return 0 if f'FAIL: {required}' in report and report.endswith('FAIL\n') else 1
    return 0 if report.endswith('PASS\n') else 1


if __name__ == '__main__':
    raise SystemExit(main())
