"""Compile the real game types, but run recipe checks without game startup or maps."""
import argparse
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


def replace_once(source, old, new):
    if source.count(old) != 1:
        raise RuntimeError(f"Isolation include changed: {old}")
    return source.replace(old, new)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", type=Path)
    parser.add_argument("--compiler", default="DreamMaker")
    parser.add_argument("--runtime", default="DreamDaemon")
    parser.add_argument("--food-bootstrap-negative-control", action="store_true")
    parser.add_argument("--camera-prototype-negative-control", action="store_true")
    args = parser.parse_args()
    if args.food_bootstrap_negative_control and args.camera_prototype_negative_control:
        parser.error("Run one negative control at a time")
    root = Path(__file__).resolve().parents[1]
    # Assets/includes are resolved relative to the checkout; runtime storage is isolated.
    with tempfile.TemporaryDirectory(prefix=".recipe-ci-", dir=root) as build, tempfile.TemporaryDirectory(prefix="civ13-recipes-") as run:
        build, run = Path(build), Path(run)
        source = (root / "code/world.dm").read_text(encoding="utf-8")
        for marker, replacement in [
            ("/datum/global_init/New()\n", "\treturn\n"),
            ("/world/New()\n", "\tspawn(1)\n\t\trun_recipe_checks()\n\treturn\n"),
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
        dme = replace_once(dme, '#include "code\\controllers\\mc\\globals.dm"', f'#include "{build.as_posix()}/globals.dm"')
        dme = re.sub(r'^#include ".*\.dmf"\s*$', '', dme, flags=re.M)
        dme = replace_once(dme, '#include "code\\world.dm"', f'#include "{build.as_posix()}/world.dm"')
        dme, maps = re.subn(r'^#include ".*\.dmm"\s*$', '', dme, flags=re.M)
        if not maps:
            raise RuntimeError("Expected to remove game maps")
        if args.food_bootstrap_negative_control:
            nodes = (root / "code/modules/research_tree/research_node.dm").read_text(encoding="utf-8")
            marker = '"/obj/item/weapon/plough" = "basic_agriculture"'
            nodes = replace_once(nodes, marker, '"/obj/item/weapon/plough" = "basic_tools"')
            (build / "research_node.dm").write_text(nodes, encoding="utf-8")
            dme = replace_once(dme, r'#include "code\modules\research_tree\research_node.dm"', f'#include "{build.as_posix()}/research_node.dm"')
        dme += f'\n#include "{root.as_posix()}/tests/crafting/checks.dm"\n#include "{root.as_posix()}/tests/crafting/camera_progression.dm"\n#include "{root.as_posix()}/tests/crafting/exercise_progression.dm"\n#include "{root.as_posix()}/tests/crafting/telecom_progression.dm"\n'
        dme += f'\n#include "{root.as_posix()}/tests/crafting/energy_progression.dm"\n'
        # Preserve resource lookup from original includes.
        dme = dme.replace('#define FILE_DIR .', f'#define FILE_DIR "{root.as_posix()}"')
        dme = re.sub(r'^#include "([^/":][^":]*)"', lambda m: f'#include "{root.as_posix()}/{m[1].replace(chr(92), "/")}"', dme, flags=re.M)
        (build / "recipes.dme").write_text(dme, encoding="utf-8")
        compiled = subprocess.run([args.compiler, "-max_errors", "0", str(build / "recipes.dme")], cwd=root, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=180)
        print(compiled.stdout)
        if compiled.returncode or "0 errors, 0 warnings" not in compiled.stdout:
            return 1
        shutil.copytree(root / "config/crafting", run / "config/crafting")
        shutil.copytree(root / "config/names", run / "config/names")
        if args.camera_prototype_negative_control:
            recipes = run / "config/crafting/material_recipes_global.txt"
            fixed = "RECIPE: /material/electronics/,early color camera,/obj/item/camera/coldwar,7,150,1,1,none,160,0,0,8,null"
            recipes.write_text(replace_once(recipes.read_text(), fixed, fixed.replace(",0,0,8,null", ",0,0,7,null")), encoding="utf-8")
        for suffix in (".dmb", ".rsc"):
            shutil.copy2(build / ("recipes" + suffix), run)
        with (run / "runtime.log").open("w", encoding="utf-8") as log:
            runtime = subprocess.run([args.runtime, str(run / "recipes.dmb"), "0", "-invisible", "-close", "-trusted"], cwd=run, stdout=log, stderr=subprocess.STDOUT, timeout=90)
        runtime_log = (run / "runtime.log").read_text(encoding="utf-8", errors="replace")
        print(runtime_log)
        report = run / "recipe-checks.txt"
        if not report.exists():
            print("FAIL: recipe checks did not complete")
            return 1
        output = report.read_text(encoding="utf-8")
        if args.report:
            args.report.write_text(output, encoding="utf-8")
        print(output)
        if runtime.returncode or any(marker in runtime_log.lower() for marker in ("runtime error:", "bug:", "## error:")):
            return 1
        if args.food_bootstrap_negative_control:
            expected = [
                "FAIL food bootstrap: plough stays locked before Basic Agriculture",
                "FAIL food bootstrap: incomplete study keeps the plough locked",
            ]
            if output.rstrip().splitlines()[1:-1] == expected and output.rstrip().endswith("FAIL"):
                print("PASS: food bootstrap research-gate omission detected")
                return 0
            print("FAIL: food bootstrap control did not produce only the expected gate failures")
            return 1
        if args.camera_prototype_negative_control:
            expected = ["FAIL camera progression: lagging faction retains paid matching prototype after another faction advances the world"]
            if output.rstrip().splitlines()[1:-1] == expected and output.rstrip().endswith("FAIL"):
                print("PASS: obsolete camera prototype recipe detected")
                return 0
            print("FAIL: camera control did not produce only the expected availability failure")
            return 1
        return 0 if output.rstrip().endswith("PASS") else 1

if __name__ == "__main__":
    raise SystemExit(main())
