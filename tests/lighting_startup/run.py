"""Native startup ordering regression. --prepare-only never launches BYOND."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time

BASELINE = "0e9b527ec492196b548d1cf92bc270c30ef30e67"
SYSTEM = "code/modules/lighting/lighting_system.dm"
CORNER = "code/modules/lighting/lighting_corner.dm"
OVERLAY = "code/modules/lighting/lighting_overlay.dm"
TURF = "code/modules/lighting/lighting_turf.dm"
DIAGNOSTICS = r"runtime error|Bad ref|Bad loc|Cannot read null|Infinite loop suspected|switching proc to background|PORT_OPEN"

def prepare(repo, mode, negative=False, bulk_order_control=False, inactive_corner_control=False):
    def read(path):
        if mode == "baseline":
            return subprocess.check_output(["git", "show", BASELINE + ":" + path], cwd=repo, text=True)
        return (repo/path).read_text()
    originals = {path: read(path) for path in (SYSTEM, CORNER, OVERLAY, TURF)}
    system = originals[SYSTEM].split("/proc/update_lighting(")[0]
    corner = originals[CORNER].split("/datum/lighting_corner/proc/update_lumcount(")[0]
    overlay = re.search(r"^/atom/movable/lighting_overlay/New\([\s\S]*?(?=^/atom/movable/lighting_overlay/Destroy)", originals[OVERLAY], re.M).group()
    clear_overlay = re.search(r"^/turf/proc/lighting_clear_overlay\([\s\S]*?(?=// Builds)", originals[TURF], re.M).group()
    turf_new = re.search(r"^/turf/New\([\s\S]*?(?=^/turf/proc/)", originals[TURF], re.M).group()
    build_overlay = re.search(r"^/turf/proc/lighting_build_overlay\([\s\S]*?(?=// DAYLIGHT)", originals[TURF], re.M).group()
    turf_new = re.sub(r"^(\t*)spawn\(5\)", lambda m: m[1]+"probe_new_callbacks++\n"+m[0], turf_new, flags=re.M)
    build_overlay = build_overlay.replace("/turf/proc/lighting_build_overlay()\n", "/turf/proc/lighting_build_overlay()\n\tif (lighting_startup_in_progress)\n\t\tprobe_build_waiters++\n", 1)
    support = originals[TURF][originals[TURF].index("/turf/proc/supports_lighting_overlays()"):]
    support = re.split(r"\n(?=/)", support, maxsplit=1)[0]
    # Real constructor body, instrumented only to record order. Pool/reagents,
    # overlay rendering and hook dispatch are isolated adapters, not acceptance.
    overlay = overlay.replace("\t. = ..()", "\t. = ..()\n\tprobe_overlay_order += coord(loc)\n\tif (no_update)\n\t\tprobe_bulk_overlay_order += coord(loc)\n\telse\n\t\tprobe_compatibility_overlay_order += coord(loc)", 1)
    corner = corner.replace("\tactive = FALSE", "\tif (probe_startup && !probe_overlays_ready)\n\t\tprobe_early++\n\tprobe_activity_calls++\n\tactive = FALSE", 1)
    if mode == "candidate":
        corner = corner.replace("\tactive = FALSE", "\tif (startup_owner)\n\t\tprobe_owner_activations++\n\t\tif (probe_activated_corners[src])\n\t\t\tprobe_owner_duplicates++\n\t\tprobe_activated_corners[src] = TRUE\n\tactive = FALSE", 1)
    system = system.replace("'icons/turf/walls.dmi'", "null")
    marker = "create_startup_compatibility_overlays" if mode == "candidate" else "create_all_lighting_overlays"
    system = re.sub(r"^(\t+)"+marker+r"\(\)\n", lambda m: m[0]+m[1]+"probe_overlays_ready = TRUE\n", system, count=1, flags=re.M)
    if mode == "baseline": system += "\n/var/lighting_startup_in_progress = FALSE\n"
    if negative:
        assert mode == "candidate"
        match = re.search(r"^(\t+)create_all_lighting_overlays\(\)\n",system,re.M)
        indent = match[1]
        system = system[:match.start()] + indent + "for (var/datum/lighting_corner/early in fresh_corners)\n" + indent + "\tearly.update_active(TRUE)\n" + system[match.start():]
    if bulk_order_control:
        assert mode == "candidate"
        old_loop = "for (var/turf/T in block(locate(1, 1, zlevel), locate(world.maxx, world.maxy, zlevel)))"
        assert system.count(old_loop) == 2, "Bulk/corner iterator anchors changed"
        system = system.replace(old_loop, "for (var/turf/T in probe_reverse(block(locate(1, 1, zlevel), locate(world.maxx, world.maxy, zlevel))))", 1)
    if inactive_corner_control:
        assert mode == "candidate"
        anchor = "\t\tactivate_existing_lighting_corners()\n"
        assert system.count(anchor) == 1, "Corner reconciliation anchor changed"
        system = system.replace(anchor, "", 1)
    reserved_helper = ""
    if "omit_reserved_lighting_overlay" in originals[TURF]:
        reserved_helper = "/turf/var/tmp/lighting_reserved = FALSE\n/area/var/tmp/lighting_reserved_clearance_enabled = FALSE\n" + re.search(r"^/turf/proc/omit_reserved_lighting_overlay\([\s\S]*?(?=^// Clearing)", originals[TURF], re.M).group()
    production = system + corner + overlay + turf_new + clear_overlay + build_overlay + support + "\n" + reserved_helper
    files = {"production.dm": production, "probe.dm": (repo/"tests/lighting_startup/probe.dm").read_text(),
             "probe.dme": '#define TRUE 1\n#define FALSE 0\n#define ASSERT(x) if (!(x)) CRASH("assertion")\n#define PoolOrNew probe_pool\n#define GAME_STATE_PREGAME 0\n#include "probe.dm"\n#include "production.dm"\n'}
    if mode == "candidate": files["probe.dme"] = "#define PROBE_CANDIDATE\n" + files["probe.dme"]
    if bulk_order_control: files["probe.dme"] = "#define PROBE_ORDER_CONTROL\n" + files["probe.dme"]
    assert '/world/OpenPort(port)\n\tif (port == "none")\n\t\treturn ..()\n\treturn FALSE' in files["probe.dm"], "Closed-port adapter changed"
    assert 'OpenPort("none")' in files["probe.dm"] and 'if (world.port || OpenPort(0) || world.port)' in files["probe.dm"], "Closing/reopening native guards missing"
    files.update({"original-"+Path(path).name: source for path,source in originals.items()})
    manifest = {"head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=repo, text=True).strip(),
                "baseline": BASELINE, "mode": mode, "negative_control": negative, "bulk_order_control": bulk_order_control, "inactive_corner_control": inactive_corner_control,
                "sources": {path: hashlib.sha256(source.encode()).hexdigest() for path,source in originals.items()},
                "patch_sha256": hashlib.sha256(subprocess.check_output(["git", "diff", "HEAD"],cwd=repo)).hexdigest(),
                "adapters": ["isolated map/turf fields, overlay pool/render and startup hook", "64-candidate fixture pause ceiling with real tick_usage threshold", "wall icon resource omitted", "ordering observations only"]}
    return files,manifest

def run_logged(command, cwd, log_name, timeout, flags):
    """Retain partial child output and launch/deadline failures before raising."""
    started = time.monotonic()
    receipt = {"command": command, "timeout_seconds": timeout, "state": "launching"}
    receipt_path = cwd / (Path(log_name).stem + "-execution.json")
    receipt_path.write_text(json.dumps(receipt, indent=2))
    stdout = stderr = ""
    def decode(value):
        return value.decode(errors="replace") if isinstance(value, bytes) else (value or "")
    try:
        result = subprocess.run(command, cwd=cwd, capture_output=True, text=True,
                                timeout=timeout, creationflags=flags)
        stdout, stderr = result.stdout, result.stderr
        receipt.update(state="returned", returncode=result.returncode)
        return result
    except Exception as error:
        stdout = decode(getattr(error, "stdout", ""))
        stderr = decode(getattr(error, "stderr", ""))
        receipt.update(state="timeout" if isinstance(error, subprocess.TimeoutExpired) else "launch_error",
                       exception_type=type(error).__name__, error=str(error))
        raise
    finally:
        (cwd / log_name).write_text(stdout + stderr)
        receipt["elapsed_seconds"] = time.monotonic() - started
        receipt_path.write_text(json.dumps(receipt, indent=2))


def execute(repo, out, mode, negative, byond, bulk_order_control=False, inactive_corner_control=False):
    files,manifest=prepare(repo,mode,negative,bulk_order_control,inactive_corner_control)
    out.mkdir(parents=True,exist_ok=False)
    for name,source in files.items(): (out/name).write_text(source)
    (out/"manifest.json").write_text(json.dumps(manifest,indent=2))
    if byond is None: return None
    compiler=byond/("dm.exe" if os.name=="nt" else "DreamMaker")
    daemon=byond/("dd.exe" if os.name=="nt" else "DreamDaemon")
    flags=subprocess.CREATE_NO_WINDOW if os.name=="nt" else 0
    build=run_logged([str(compiler),"-max_errors","0","probe.dme"],out,"compile.log",120,flags)
    log=build.stdout+build.stderr
    (out/"compile.log").write_text(log)
    assert build.returncode==0 and "516.1681" in log and "0 errors, 0 warnings" in log,log
    run=run_logged([str(daemon),"probe.dmb"]+(["-invisible"] if os.name=="nt" else [])+["-close","-trusted","-log","runtime.log"],out,"daemon-child.log",240,flags)
    log=(out/"runtime.log").read_text(errors="replace") if (out/"runtime.log").exists() else ""
    log+=run.stdout+run.stderr
    (out/"daemon.log").write_text(log)
    assert run.returncode==0 and not re.search(DIAGNOSTICS,log,re.I),log
    result=json.loads((out/"result.json").read_text())
    assert result["runtime_errors"]==0 and result["native_loop_checks"]==1 and result["port_closed"],result
    if negative:
        assert result["early_activations"]>0,"Early-activation control was not detected"
    else:
        assert result["early_activations"]==0,result["early_activations"]
        assert result["identity_failures"]==(10240 if inactive_corner_control else 0), {"identity_failures":result["identity_failures"],"inactive_corner_control":inactive_corner_control}
        if mode=="candidate":
            assert result["pauses"]>0 and result["premature_flags"]==0,result
            assert result["owner_activations"]>0 and result["owner_duplicates"]==0,result
            if not bulk_order_control:
                assert result["build_waiters"]>0 and result["new_callbacks"]<20,result
                assert result["failure_release"] and result["prestartup_contract"],result
                assert result["activity_waiters"]>0 and result["activity_waiter_done"],result
                assert result["replacement_started"] and len(result["concurrent_snapshot"])==5120,result
                assert result["concurrent_overlay_order"].count("1,1,1")==2,result
                assert result["repeat_idempotent"], "Settled repeat changed corner activity or overlay ownership"
    return result

def validate_parity(baseline, candidate):
    """Compare synchronous bulk order; explicitly validate bounded fallback ordering."""
    assert baseline["snapshots"] == candidate["snapshots"], "Shared masters/activity/overlay/update registration differs"
    assert baseline["bulk_overlay_order"] == candidate["bulk_overlay_order"], "Bulk overlay construction order differs"
    assert sorted(baseline["compatibility_overlay_order"]) == sorted(candidate["compatibility_overlay_order"]), "Compatibility constructor eligibility/multiplicity differs"
    assert candidate["compatibility_overlay_order"] == candidate["expected_compatibility_order"], "Compatibility constructors do not follow native world traversal"
    assert baseline["expected_compatibility_order"] == candidate["expected_compatibility_order"], "Compatibility input geometry differs"


def validate_bulk_order_control(baseline, candidate):
    # The generated production iterator changes actual constructor order only.
    assert baseline["snapshots"] == candidate["snapshots"], "Order control changed final lighting state"
    assert sorted(baseline["bulk_overlay_order"]) == sorted(candidate["bulk_overlay_order"]), "Order control changed bulk eligibility"
    try:
        validate_parity(baseline, candidate)
    except AssertionError as error:
        assert str(error) == "Bulk overlay construction order differs", str(error)
    else:
        raise AssertionError("Reversed bulk iterator was not detected")


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--byond-bin",type=Path)
    parser.add_argument("--output",type=Path)
    parser.add_argument("--prepare-only",action="store_true")
    controls = parser.add_mutually_exclusive_group()
    controls.add_argument("--negative-control",action="store_true")
    controls.add_argument("--bulk-order-control",action="store_true")
    controls.add_argument("--inactive-corner-control",action="store_true")
    args=parser.parse_args()
    if not args.prepare_only and not args.byond_bin: parser.error("Runtime requires --byond-bin")
    repo=Path(__file__).resolve().parents[2]
    out=args.output or Path(tempfile.mkdtemp(prefix="civ13-lighting-startup-"))
    if args.output: out.mkdir(parents=True,exist_ok=False)
    results={}
    for mode in (["candidate"] if args.negative_control or args.inactive_corner_control else ["baseline","candidate"]):
        results[mode]=execute(repo,out/mode,mode,args.negative_control,None if args.prepare_only else args.byond_bin,args.bulk_order_control and mode=="candidate",args.inactive_corner_control)
    if not args.prepare_only and not args.negative_control and not args.inactive_corner_control:
        if args.bulk_order_control:
            validate_bulk_order_control(results["baseline"], results["candidate"])
        else:
            validate_parity(results["baseline"], results["candidate"])
    print(json.dumps({"output":str(out),"prepared_only":args.prepare_only,"negative_control":args.negative_control,"bulk_order_control":args.bulk_order_control,"inactive_corner_control":args.inactive_corner_control}))

if __name__=="__main__": main()
