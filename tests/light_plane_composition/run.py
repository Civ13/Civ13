"""Actual production plane modes; screenshots remain separate native evidence."""
import argparse
import importlib.util
import os
from pathlib import Path
import re
import shutil
import tempfile

ROOT = Path(__file__).resolve().parents[2]
PLANE = "code/_onclick/hud/plane_master.dm"


def production_proc(path, signature):
    source = (ROOT / path).read_text()
    matches = re.findall(r"^" + re.escape(signature) + r"[\s\S]*?(?=^/(?!/)|\Z)", source, re.M)
    assert len(matches) == 1, "Production proc anchor changed: " + signature
    return matches[0]


def prepare(control=None, enabled=True):
    source = (ROOT / PLANE).read_text()
    if control in ("bypass", "ordinary"):
        anchor = "mymob && mymob.see_invisible >= INVISIBILITY_LEVEL_TWO"
        assert source.count(anchor) == 1
        source = source.replace(anchor, "FALSE" if control == "bypass" else "TRUE")
    coverage = (ROOT / "code/modules/lighting/lighting_composition.dm").read_text()
    if control == "coverage":
        coverage = coverage.replace("\tif(needed && !retained)\n\t\tnew", "\tif(FALSE && !retained)\n\t\tnew")
    area_change = production_proc("code/game/area/areas.dm", "/turf/var/tmp/list/area_change_owner")
    area_change += production_proc("code/game/area/areas.dm", "/proc/ChangeArea(")
    if control == "area-change":
        anchor = "\t\tT.change_area(old_area, A)\n"
        assert area_change.count(anchor) == 1
        area_change = area_change.replace(anchor, "\t\treturn\n")
    if control == "area-owner":
        anchor = "if(!T || T.area_change_owner != request)"
        assert area_change.count(anchor) == 1
        area_change = area_change.replace(anchor, "if(!T)")
    area_change += production_proc("code/modules/lighting/lighting_area.dm", "/atom/proc/change_area(")
    area_change += production_proc("code/modules/lighting/lighting_turf.dm", "/turf/change_area(")
    if control in ("area-policy", "area-policy-dynamic"):
        anchor = "\twindow_coeff_dirty = TRUE\n\tif (new_area.dynamic_lighting)"
        assert area_change.count(anchor) == 1
        condition = "old_area && new_area.dynamic_lighting == old_area.dynamic_lighting" if control == "area-policy" else "old_area && new_area.dynamic_lighting && old_area.dynamic_lighting"
        area_change = area_change.replace(anchor, "\twindow_coeff_dirty = TRUE\n\tif (" + condition + ")\n\t\treturn\n\tif (new_area.dynamic_lighting)")
    return {"production.dm": source, "coverage.dm": coverage,
            "area_change.dm": area_change,
            "build_overlay.dm": production_proc("code/modules/lighting/lighting_turf.dm", "/turf/proc/lighting_build_overlay("),
            "area_probe.dm": (Path(__file__).parent / "area_probe.dm").read_text(),
            "probe.dm": (Path(__file__).parent / "probe.dm").read_text(),
            "probe.dme": '#define LIGHTING_COMPOSITION_V2 ' + str(int(enabled)) + '\n#include "probe.dm"\n#include "production.dm"\n#include "coverage.dm"\n#include "area_change.dm"\n#include "build_overlay.dm"\n#include "area_probe.dm"\n'}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--byond-bin", type=Path, required=True)
    parser.add_argument("--negative-control", choices=("bypass", "ordinary", "coverage", "area-change", "area-owner", "area-policy", "area-policy-dynamic"))
    parser.add_argument("--disabled", action="store_true")
    args = parser.parse_args()
    spec = importlib.util.spec_from_file_location("startup_runner", ROOT / "tests/lighting_startup/run.py")
    runner = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(runner)
    # Reuse the existing bounded compiler/runtime subprocess seam.
    with tempfile.TemporaryDirectory(prefix="civ13-light-plane-") as tmp:
        out = Path(tmp)
        for name, text in prepare(args.negative_control, not args.disabled).items():
            (out / name).write_text(text)
        resource = out / "icons/effects/icon.png"
        resource.parent.mkdir(parents=True)
        shutil.copyfile(ROOT / "icons/effects/icon.png", resource)
        compiler = args.byond_bin / ("dm.exe" if os.name == "nt" else "DreamMaker")
        daemon = args.byond_bin / ("dd.exe" if os.name == "nt" else "DreamDaemon")
        flags = 0x8 if os.name == "nt" else 0
        result = runner.run_logged([str(compiler), "probe.dme"], out, "compile.log", 60, flags)
        print(result.stdout, result.stderr)
        if result.stdout.count("DM compiler version 516.1681") != 1 or re.search(r"invalid file|file not found|cannot open", result.stdout, re.I) or result.returncode or not re.search(r"^probe.dmb - 0 errors, 0 warnings \(.+\)$", result.stdout, re.M):
            raise RuntimeError("Plane fixture compilation failed")
        cmd = [str(daemon), "probe.dmb", "-trusted", "-close", "-log", "runtime.log"]
        result = runner.run_logged(cmd, out, "daemon.log", 20, flags)
        logs = result.stdout + result.stderr + (out / "runtime.log").read_text(errors="replace")
        print(logs)
        if result.returncode or re.search(r"runtime error|Runtime in|BUG:|CRASH|Infinite loop|Cannot read null", logs, re.I):
            raise RuntimeError("Unexpected native diagnostic")
        if args.negative_control:
            expected = {"bypass": "vision 45 coefficient 1", "ordinary": "vision 0 coefficient 1", "coverage": "explicit fullbright coverage", "area-change": "ChangeArea dispatches turf hook", "area-owner": "superseded away-and-back skips outer hook", "area-policy": "superseding same-fullbright policy clears actual overlay", "area-policy-dynamic": "superseding same-dynamic policy builds missing overlay"}[args.negative_control]
            if "FAIL checks=" not in logs or expected not in logs or "PASS checks=" in logs:
                raise RuntimeError("Wrong negative-control outcome")
            print("PASS: expected " + args.negative_control + " control caught")
        elif not re.search(r"^PASS checks=" + str(8 if args.disabled else 287) + r" area_change_checks=64\s*$", logs, re.M) or "FAIL checks=" in logs:
            raise RuntimeError("Plane fixture assertions failed")


if __name__ == "__main__":
    main()
