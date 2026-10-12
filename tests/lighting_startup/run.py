"""Native startup ordering regression. --prepare-only never launches BYOND."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

BASELINE = "0e9b527ec492196b548d1cf92bc270c30ef30e67"
SYSTEM = "code/modules/lighting/lighting_system.dm"
CORNER = "code/modules/lighting/lighting_corner.dm"
OVERLAY = "code/modules/lighting/lighting_overlay.dm"
TURF = "code/modules/lighting/lighting_turf.dm"
DIAGNOSTICS = r"runtime error|Bad ref|Bad loc|Cannot read null|Infinite loop suspected|switching proc to background|PORT_OPEN"

def prepare(repo, mode, negative=False):
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
    overlay = overlay.replace("\t. = ..()", "\t. = ..()\n\tprobe_overlay_order += coord(loc)", 1)
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
    production = system + corner + overlay + turf_new + clear_overlay + build_overlay + support
    files = {"production.dm": production, "probe.dm": (repo/"tests/lighting_startup/probe.dm").read_text(),
             "probe.dme": '#define TRUE 1\n#define FALSE 0\n#define ASSERT(x) if (!(x)) CRASH("assertion")\n#define PoolOrNew probe_pool\n#define GAME_STATE_PREGAME 0\n#include "probe.dm"\n#include "production.dm"\n'}
    if mode == "candidate": files["probe.dme"] = "#define PROBE_CANDIDATE\n" + files["probe.dme"]
    files.update({"original-"+Path(path).name: source for path,source in originals.items()})
    manifest = {"head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=repo, text=True).strip(),
                "baseline": BASELINE, "mode": mode, "negative_control": negative,
                "sources": {path: hashlib.sha256(source.encode()).hexdigest() for path,source in originals.items()},
                "patch_sha256": hashlib.sha256(subprocess.check_output(["git", "diff", "HEAD"],cwd=repo)).hexdigest(),
                "adapters": ["isolated map/turf fields, overlay pool/render and startup hook", "64-candidate fixture pause ceiling with real tick_usage threshold", "wall icon resource omitted", "ordering observations only"]}
    return files,manifest

def execute(repo, out, mode, negative, byond):
    files,manifest=prepare(repo,mode,negative)
    out.mkdir(parents=True,exist_ok=False)
    for name,source in files.items(): (out/name).write_text(source)
    (out/"manifest.json").write_text(json.dumps(manifest,indent=2))
    if byond is None: return None
    compiler=byond/("dm.exe" if os.name=="nt" else "DreamMaker")
    daemon=byond/("dd.exe" if os.name=="nt" else "DreamDaemon")
    flags=subprocess.CREATE_NO_WINDOW if os.name=="nt" else 0
    build=subprocess.run([str(compiler),"-max_errors","0","probe.dme"],cwd=out,capture_output=True,text=True,timeout=120,creationflags=flags)
    log=build.stdout+build.stderr
    (out/"compile.log").write_text(log)
    assert build.returncode==0 and "516.1681" in log and "0 errors, 0 warnings" in log,log
    run=subprocess.run([str(daemon),"probe.dmb"]+(["-invisible"] if os.name=="nt" else [])+["-close","-safe","-log","runtime.log"],cwd=out,capture_output=True,text=True,timeout=120,creationflags=flags)
    log=(out/"runtime.log").read_text(errors="replace") if (out/"runtime.log").exists() else ""
    log+=run.stdout+run.stderr
    (out/"daemon.log").write_text(log)
    assert run.returncode==0 and not re.search(DIAGNOSTICS,log,re.I),log
    result=json.loads((out/"result.json").read_text())
    assert result["runtime_errors"]==0 and result["native_loop_checks"]==1,result
    if negative:
        assert result["early_activations"]>0,"Early-activation control was not detected"
    else:
        assert result["early_activations"]==0 and result["identity_failures"]==0,result
        if mode=="candidate":
            assert result["pauses"]>0 and result["premature_flags"]==0,result
            assert result["build_waiters"]>0 and result["new_callbacks"]<20,result
            assert result["failure_release"] and result["prestartup_contract"],result
            assert result["activity_waiters"]>0 and result["activity_waiter_done"],result
            assert result["owner_activations"]>0 and result["owner_duplicates"]==0,result
    return result

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--byond-bin",type=Path)
    parser.add_argument("--output",type=Path)
    parser.add_argument("--prepare-only",action="store_true")
    parser.add_argument("--negative-control",action="store_true")
    args=parser.parse_args()
    if not args.prepare_only and not args.byond_bin: parser.error("Runtime requires --byond-bin")
    repo=Path(__file__).resolve().parents[2]
    out=args.output or Path(tempfile.mkdtemp(prefix="civ13-lighting-startup-"))
    if args.output: out.mkdir(parents=True,exist_ok=False)
    results={}
    for mode in (["candidate"] if args.negative_control else ["baseline","candidate"]):
        results[mode]=execute(repo,out/mode,mode,args.negative_control,None if args.prepare_only else args.byond_bin)
    if not args.prepare_only and not args.negative_control:
        assert results["baseline"]["snapshots"]==results["candidate"]["snapshots"],"Shared masters/activity/overlay order differs"
        assert results["baseline"]["overlay_order"]==results["candidate"]["overlay_order"],"Overlay construction order differs"
    print(json.dumps({"output":str(out),"prepared_only":args.prepare_only,"negative_control":args.negative_control}))

if __name__=="__main__": main()
