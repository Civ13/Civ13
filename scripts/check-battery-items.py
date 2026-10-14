"""Compile the real game types, but run battery item checks without game startup or maps."""
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
    parser.add_argument("--probe", choices=("batteries", "modern-energy"), default="batteries")
    parser.add_argument("--negative-control", action="store_true")
    args = parser.parse_args()
    if args.negative_control and args.probe != "modern-energy":
        parser.error("The charge-debit negative control requires modern-energy")
    callback = "run_battery_item_checks" if args.probe == "batteries" else "run_modern_energy_checks"
    root = Path(__file__).resolve().parents[1]
    # Assets/includes are resolved relative to the checkout; runtime storage is isolated.
    with tempfile.TemporaryDirectory(prefix=".battery-items-", dir=root) as build, tempfile.TemporaryDirectory(prefix="civ13-battery-items-") as run:
        build, run = Path(build), Path(run)
        source = (root / "code/world.dm").read_text(encoding="utf-8")
        for marker, replacement in [
            ("/datum/global_init/New()\n", "\treturn\n"),
            ("/world/New()\n", f"\tspawn(1)\n\t\t{callback}()\n\treturn\n"),
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
        probe_file = "tests/batteries/items.dm" if args.probe == "batteries" else "tests/modern_energy/probe.dm"
        dme += f'\n#include "{root.as_posix()}/{probe_file}"\n'
        if args.negative_control:
            generator = (root / "code/modules/1713/machinery/modern_generation.dm").read_text(encoding="utf-8")
            generator = replace_once(generator, "\tcharge_power += transfer", "\t// Negative control: omitted charge debit")
            (build / "generation.dm").write_text(generator, encoding="utf-8")
            dme = replace_once(dme, '#include "code\\modules\\1713\\machinery\\modern_generation.dm"', f'#include "{build.as_posix()}/generation.dm"')
        # Preserve resource lookup from original includes.
        dme = dme.replace('#define FILE_DIR .', f'#define FILE_DIR "{root.as_posix()}"')
        dme = re.sub(r'^#include "([^/":][^":]*)"', lambda m: f'#include "{root.as_posix()}/{m[1].replace(chr(92), "/")}"', dme, flags=re.M)
        (build / "recipes.dme").write_text(dme, encoding="utf-8")
        compiled = subprocess.run([args.compiler, "-max_errors", "0", str(build / "recipes.dme")], cwd=root, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=180)
        print(compiled.stdout)
        if compiled.returncode or "0 errors, 0 warnings" not in compiled.stdout or (args.probe == "modern-energy" and "516.1681" not in compiled.stdout):
            return 1
        shutil.copytree(root / "config/crafting", run / "config/crafting")
        shutil.copytree(root / "config/names", run / "config/names")
        for suffix in (".dmb", ".rsc"):
            shutil.copy2(build / ("recipes" + suffix), run)
        with (run / "runtime.log").open("w", encoding="utf-8") as log:
            runtime = subprocess.run([args.runtime, str(run / "recipes.dmb"), "0", "-invisible", "-close", "-trusted"], cwd=run, stdout=log, stderr=subprocess.STDOUT, timeout=90)
        runtime_log = (run / "runtime.log").read_text(encoding="utf-8", errors="replace")
        print(runtime_log)
        report = run / "battery-item-checks.txt"
        if not report.exists():
            print("FAIL: battery item checks did not complete")
            return 1
        output = report.read_text(encoding="utf-8")
        if args.report:
            args.report.write_text(output, encoding="utf-8")
        print(output)
        if runtime.returncode or any(marker in runtime_log.lower() for marker in ("runtime error:", "bug:", "## error:")):
            return 1
        if args.negative_control:
            return 0 if "duplicate charge cannot mint energy" in output and output.rstrip().endswith("FAIL") else 1
        return 0 if output.rstrip().endswith("PASS") else 1

if __name__ == "__main__":
    raise SystemExit(main())

