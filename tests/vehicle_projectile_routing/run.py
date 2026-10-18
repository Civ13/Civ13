"""Production vehicle projectile routing fixture; local native runs require allocation.

The probe closes the native port in world.New(), not OS network isolation.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import uuid

ROOT = Path(__file__).resolve().parents[2]
CORE = "code/modules/projectiles/projectile.dm"
BASE = "cc03b199128f8afed58713912c551ad7556e6bc4"

def baseline():
    return subprocess.check_output(["git", "show", BASE + ":" + CORE], cwd=ROOT, text=True)

def collision(text):
    start = text.index("/obj/item/projectile/proc/handleTurf(")
    end = text.index("/obj/item/projectile/ex_act()", start)
    return text[start:end]

def prepare(control=False):
    original = baseline()
    current = (ROOT / CORE).read_text(encoding="utf-8")
    before = original[:original.index("/obj/item/projectile/proc/handleTurf(")]
    after = original[original.index("/obj/item/projectile/ex_act()"):]
    assert current.startswith(before) and current.endswith(after), "Change escaped collision routing"
    assert collision(current).count("F.CheckPen(src,penloc)") == 1
    assert collision(current).index("for (var/obj/structure/vehicleparts/frame/F in T.contents)") < collision(current).index("for (var/atom/movable/AM in T.contents)")
    helper = collision(original).replace("/proc/handleTurf(", "/proc/routing_baseline_handleTurf(", 1)
    return (original if control else current), helper

def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("--byond-bin", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--source-check", action="store_true")
    parser.add_argument("--negative-control", choices=["ordering"])
    args = parser.parse_args()
    source, helper = prepare(bool(args.negative_control))
    if args.source_check:
        prepare(False)
        prepare(True)
        print("PASS: production collision scope, frame prepass, immutable baseline preparation; no native execution")
        return
    if not args.byond_bin or not args.output:
        parser.error("--byond-bin and --output are required for native execution")
    if args.output.exists():
        parser.error("Preserve evidence; output must not exist")
    args.output.mkdir(parents=True)
    prefix = ".vehicle_routing_" + uuid.uuid4().hex
    files = {suffix: ROOT / (prefix + suffix) for suffix in
             (".dme", "_world.dm", "_globals.dm", "_projectile.dm", "_baseline.dm", ".dmb", ".rsc")}
    tracked = [CORE, "code/modules/projectiles/projectile/cannon.dm",
               "code/modules/1713/machinery/modular_vehicles/frame.dm",
               "code/modules/1713/machinery/modular_vehicles/axis.dm",
               "code/game/atoms_movable.dm", "code/world.dm", "code/controllers/mc/globals.dm",
               "civ13.dme", "tests/vehicle_projectile_routing/probe.dm",
               "tests/vehicle_projectile_routing/run.py"]
    metadata = {"head_sha": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
                "baseline_sha": BASE, "control": args.negative_control,
                "source_sha256": {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in tracked},
                "compiled_projectile_sha256": hashlib.sha256(source.encode()).hexdigest(),
                "baseline_helper_sha256": hashlib.sha256(helper.encode()).hexdigest(),
                "scope": "Production routing/armor/movement; damage, hit-roll and explosion callbacks are counters"}
    (args.output / "metadata.json").write_text(json.dumps(metadata, indent=2) + "\n")
    flags = subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0
    try:
        world = (ROOT / "code/world.dm").read_text()
        at = world.index("/world/New()")
        parent = world.index("\n\t..()", at)
        world = world[:parent] + world[parent:].replace("\n\t..()", "", 1)
        world = world.replace("/world/New()", "/world/proc/unused_vehicle_routing_startup()", 1)
        marker = "/datum/global_init/New()\n"
        assert world.count(marker) == 1
        files["_world.dm"].write_text(world.replace(marker, marker + "\treturn\n", 1))
        globals_source = (ROOT / "code/controllers/mc/globals.dm").read_text()
        marker = "/datum/controller/global_vars/New()\n"
        assert globals_source.count(marker) == 1
        files["_globals.dm"].write_text(globals_source.replace(marker, marker + "\treturn\n", 1))
        files["_projectile.dm"].write_text(source)
        files["_baseline.dm"].write_text(helper)
        dme = (ROOT / "civ13.dme").read_text()
        for old, replacement in (("code\\world.dm", files["_world.dm"].name),
                                 ("code\\controllers\\mc\\globals.dm", files["_globals.dm"].name),
                                 ("code\\modules\\projectiles\\projectile.dm", files["_projectile.dm"].name)):
            assert dme.count(old) == 1, old
            dme = dme.replace(old, replacement, 1)
        dme = re.sub(r'^#include ".*\.dmm".*$', "", dme, flags=re.M)
        dme += '\n#include "' + files["_baseline.dm"].name + '"\n#include "tests/vehicle_projectile_routing/probe.dm"\n'
        files[".dme"].write_text(dme)
        compiler = args.byond_bin / ("dm.exe" if os.name == "nt" else "DreamMaker")
        daemon = args.byond_bin / ("dd.exe" if os.name == "nt" else "DreamDaemon")
        compile_result = subprocess.run([str(compiler), "-max_errors", "0", str(files[".dme"])],
                                        cwd=ROOT, capture_output=True, text=True, timeout=180, creationflags=flags)
        log = compile_result.stdout + compile_result.stderr
        (args.output / "compile.log").write_text(log)
        if compile_result.returncode or "516.1681" not in log or "0 errors, 0 warnings" not in log:
            raise RuntimeError("Pinned compile failed: " + log[-4000:])
        with tempfile.TemporaryDirectory(prefix="vehicle-projectile-routing-") as temp:
            runtime = Path(temp)
            for suffix in (".dmb", ".rsc"):
                shutil.copy2(files[suffix], runtime / files[suffix].name)
            shutil.copytree(ROOT / "config/names", runtime / "config/names")
            (runtime / "config/crafting").mkdir(parents=True)
            shutil.copy2(ROOT / "config/crafting/material_recipes_global.txt",
                         runtime / "config/crafting/material_recipes_global.txt")
            result = subprocess.run([str(daemon), str(runtime / files[".dmb"].name),
                                     *(["-invisible", "-close"] if os.name == "nt" else []),
                                     "-trusted", "-log", "runtime.log"],
                                    cwd=runtime, capture_output=True, text=True, timeout=60, creationflags=flags)
            diagnostics = result.stdout + result.stderr
            for name in ("runtime.log", "errors.txt", "result.txt", "fixture.json"):
                path = runtime / name
                if path.exists():
                    shutil.copy2(path, args.output / name)
                    if name in ("runtime.log", "errors.txt"):
                        diagnostics += path.read_text(errors="replace")
            (args.output / "daemon.log").write_text(result.stdout + result.stderr)
            actual = (runtime / "result.txt").read_text().strip() if (runtime / "result.txt").exists() else ""
            expected = "FAIL: armor checked before protected occupant" if args.negative_control else "PASS: vehicle projectile routing"
            if result.returncode or actual != expected or re.search(r"runtime error|bad ref|bad loc|cannot read null|cannot execute null|BUG:|## ERROR:|CRASH", diagnostics, re.I):
                raise RuntimeError(f"Expected {expected!r}, got {actual!r}; " + diagnostics[-3500:])
            fixture = json.loads((runtime / "fixture.json").read_text())
            assert fixture["checks"] >= (99 if args.negative_control else 140), "Incomplete fixture"
            print("PASS expected control: " + actual if args.negative_control else actual)
    finally:
        for path in files.values():
            path.unlink(missing_ok=True)

if __name__ == "__main__":
    main()
