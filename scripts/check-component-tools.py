"""Run production component assembly and save/load without game startup/maps."""
import argparse
from contextlib import contextmanager
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def load_runtime(byond_bin, archive):
    spec = importlib.util.spec_from_file_location('component_current_runtime', ROOT / 'tests/world_save/current_runtime.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    runtime = module.select(byond_bin, archive)
    if runtime is None:
        raise ValueError('Canonical Linux archive identity is required')
    return runtime


@contextmanager
def evidence_workspace(output):
    output.mkdir(parents=True, exist_ok=False)
    build, run = output / 'source', output / 'runtime'
    build.mkdir(); run.mkdir()
    try:
        yield build, run
    except BaseException as error:
        try:
            (output / 'failure.json').write_text(json.dumps({'error': str(error)[:4096]}), encoding='utf-8')
        except OSError:
            pass  # Preserve the original failure if secondary retention fails.
        raise


def compile_fixture(runtime, byond_bin, source, output, root):
    runtime.before_launch('compiler', output)
    try:
        compiled = subprocess.run([str(byond_bin / 'DreamMaker'), '-max_errors', '0', str(source)], cwd=root,
                                  stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=180)
    except subprocess.TimeoutExpired as error:
        log = error.stdout or b''
        (output / 'compile.log').write_text(log.decode(errors='replace') if isinstance(log, bytes) else log, encoding='utf-8')
        raise
    (output / 'compile.log').write_text(compiled.stdout, encoding='utf-8')
    runtime.validate_compile(compiled.returncode, compiled.stdout, 'recipes.dmb')
    print(compiled.stdout)


def replace_once(source, old, new):
    if source.count(old) != 1:
        raise RuntimeError(f"Isolation include changed: {old}")
    return source.replace(old, new)

def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", type=Path)
    parser.add_argument("--byond-bin", type=Path, required=True)
    parser.add_argument("--byond-archive", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--negative-control", choices=("consumption", "runtime-save"))
    args = parser.parse_args(argv)
    args.output = args.output.absolute()
    root = ROOT
    byond_bin = args.byond_bin.absolute()
    # Assets/includes are resolved relative to the checkout; runtime storage is isolated.
    with evidence_workspace(args.output) as (build, run):
        inputs = ('scripts/check-component-tools.py', 'code/world.dm', 'code/controllers/mc/globals.dm',
                  'code/game/objects/structures/blacksmithing/component_workbench.dm', 'civ13.dme',
                  'tests/component_tools/checks.dm', 'tests/component_tools/workbench.dm', 'tests/world_save/current_runtime.py',
                  'scripts/byond_runtime.py', 'scripts/byond_toolchain.py', 'tools/byond/version.json',
                  'tests/new_z_budget/z_budget_evidence.py')
        (args.output / 'inputs.json').write_text(json.dumps({
            'negative_control': args.negative_control,
            'inputs_sha256': {p: hashlib.sha256((root / p).read_bytes()).hexdigest() for p in inputs}}, indent=2), encoding='utf-8')
        runtime = load_runtime(byond_bin, args.byond_archive)
        source = (root / "code/world.dm").read_text(encoding="utf-8")
        for marker, replacement in [
            ("/datum/global_init/New()\n", "\treturn\n"),
            ("/world/New()\n", "\tspawn(1)\n\t\trun_component_checks()\n\treturn\n"),
        ]:
            if source.count(marker) != 1:
                raise RuntimeError(f"Startup isolation marker changed: {marker!r}")
            source = source.replace(marker, marker + replacement)
        (build / "world.dm").write_text(source, encoding="utf-8")
        globals_source = (root / "code/controllers/mc/globals.dm").read_text(encoding="utf-8")
        marker = "/datum/controller/global_vars/New()\n"
        if globals_source.count(marker) != 1:
            raise RuntimeError("Global-controller isolation marker changed")
        (build / "globals.dm").write_text(globals_source.replace(marker, marker + "\treturn\n"), encoding="utf-8")
        dme = (root / "civ13.dme").read_text(encoding="utf-8")
        if args.negative_control:
            bench = (root / "code/game/objects/structures/blacksmithing/component_workbench.dm").read_text(encoding="utf-8")
            if args.negative_control == "consumption":
                bench = replace_once(bench, "\tqdel(P)\n\tqdel(B)\n", "\t// Deliberately leave both paid components alive.\n")
            else:
                bench = replace_once(bench, '(key in list("busy", "cancelled", "assembler", "assembly_time"))', '(key in list("cancelled", "assembler", "assembly_time"))')
            (build / "bench.dm").write_text(bench, encoding="utf-8")
            dme = replace_once(dme, '#include "code\\game\\objects\\structures\\blacksmithing\\component_workbench.dm"', f'#include "{build.as_posix()}/bench.dm"')
        dme = replace_once(dme, '#include "code\\controllers\\mc\\globals.dm"', f'#include "{build.as_posix()}/globals.dm"')
        dme = re.sub(r'^#include ".*\.dmf"\s*$', '', dme, flags=re.M)
        dme = replace_once(dme, '#include "code\\world.dm"', f'#include "{build.as_posix()}/world.dm"')
        dme, maps = re.subn(r'^#include ".*\.dmm"\s*$', '', dme, flags=re.M)
        if not maps:
            raise RuntimeError("Expected to remove game maps")
        dme += f'\n#include "{root.as_posix()}/tests/component_tools/checks.dm"\n'
        # Preserve resource lookup from original includes.
        dme = dme.replace('#define FILE_DIR .', f'#define FILE_DIR "{root.as_posix()}"')
        dme = re.sub(r'^#include "([^/":][^":]*)"', lambda m: f'#include "{root.as_posix()}/{m[1].replace(chr(92), "/")}"', dme, flags=re.M)
        (build / "recipes.dme").write_text(dme, encoding="utf-8")
        (args.output / 'generated-source.json').write_text(json.dumps({
            p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in build.iterdir()
            if p.suffix in ('.dm', '.dme')}, indent=2), encoding='utf-8')
        compile_fixture(runtime, byond_bin, build / 'recipes.dme', args.output, root)
        shutil.copytree(root / "config/crafting", run / "config/crafting")
        shutil.copytree(root / "config/names", run / "config/names")
        for suffix in (".dmb", ".rsc"):
            shutil.copy2(build / ("recipes" + suffix), run)
        runtime.before_launch('daemon', args.output)
        with (run / "runtime.log").open("w", encoding="utf-8") as log:
            executed = subprocess.run([str(byond_bin / 'DreamDaemon'), str(run / "recipes.dmb"), "0", "-invisible", "-close", "-trusted"], cwd=run, stdout=log, stderr=subprocess.STDOUT, timeout=90)
        runtime_log = (run / "runtime.log").read_text(encoding="utf-8", errors="replace")
        print(runtime_log)
        report = run / "component-checks.txt"
        if not report.exists():
            print("FAIL: recipe checks did not complete")
            return 1
        output = report.read_text(encoding="utf-8")
        if args.report:
            args.report.write_text(output, encoding="utf-8")
        print(output)
        if executed.returncode or any(marker in runtime_log.lower() for marker in ("runtime error:", "bug:", "## error:")):
            return 1
        expected = "FAIL" if args.negative_control else "PASS"
        return 0 if output.rstrip().endswith(expected) else 1

if __name__ == "__main__":
    raise SystemExit(main())
