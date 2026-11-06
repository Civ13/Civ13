#!/usr/bin/env python3
"""Run the stream save benchmark modes and sample Dream Daemon's address space.

Each mode runs in its own Dream Daemon process (bench.dmb, -trusted) inside
--work, while this script samples the process every --interval seconds with
address_space.py. The work directory must hold bench.dmb, the shim and the
helper for the platform, and COPIES of the level saves. Nothing outside
--work is written; the live server and its map_saves are never touched.

    py -3 run_bench.py --work D:\\savestream-bench --dd "C:\\Program Files (x86)\\BYOND\\bin\\dd.exe" --level 2
    python3 run_bench.py --work /tmp/bench --dd DreamDaemon --level 2

Writes <work>/report_z<level>.json: per mode, the bench result (time, node
counts, helper summary) and the sampled peaks (private committed memory,
peak working set, smallest largest-free-block).

read_text, read_wire and compare_text (not in the default list) read a copied
level-format-5 stream, <level>.stream.sav, as the level reader does.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import address_space as asp  # noqa: E402

DEFAULT_MODES = ["idle", "read_savefile", "convert", "verify", "read_stream", "write_savefile", "write_stream"]


def run_mode(args, mode: str, level: int) -> dict:
    work = Path(args.work)
    sav, stream = f"z{level}.sav", f"z{level}.stream"
    params = {
        "idle": "mode=idle",
        "read_savefile": f"mode=read_savefile&src={sav}",
        "convert": f"mode=convert&src={sav}&dst={stream}",
        "verify": f"mode=verify&src={sav}&dst={stream}",
        "read_stream": f"mode=read_stream&src={stream}",
        "write_savefile": f"mode=write_savefile&src={stream}&dst=z{level}.replay.sav",
        "write_stream": f"mode=write_stream&src={stream}&dst=z{level}.replay.stream",
        "read_text": f"mode=read_text&src={level}.stream.sav",
        "read_wire": f"mode=read_wire&src={level}.stream.sav",
        "compare_text": f"mode=compare_text&src={level}.stream.sav",
    }[mode]
    result_file = work / f"bench_{mode}.json"
    result_file.unlink(missing_ok=True)
    # Each mode starts with a fresh dynamic resource cache: one left by an
    # earlier mode logs "Crc mismatch" BUG lines, slows reads and makes cached
    # icons compare unequal.
    (work / "bench.dyn.rsc").unlink(missing_ok=True)
    cmd = [args.dd, "bench.dmb", "-trusted", "-invisible", "-params", params]
    started = time.time()
    proc = subprocess.Popen(cmd, cwd=work, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(0.3)
    peaks = {"max_private_committed_mb": 0.0, "min_largest_free_mb": 1e9, "max_working_set_mb": 0.0, "samples": 0}
    phase_maps = []
    phases = work / "bench_phases.log"
    # The log is shared by all modes; only lines this process appends count.
    seen = len(phases.read_text().splitlines()) if phases.exists() else 0
    try:
        handle = asp.open_process(proc.pid)
        while proc.poll() is None:
            try:
                regs = asp.regions(handle)
                counters = asp.counters(handle)
            except OSError:
                break
            summary = asp.summarize(regs)
            peaks["samples"] += 1
            peaks["max_private_committed_mb"] = max(peaks["max_private_committed_mb"], summary["private_committed_mb"])
            peaks["min_largest_free_mb"] = min(peaks["min_largest_free_mb"], summary["largest_free_mb"])
            ws = counters.get("working_set_mb", counters.get("VmRSS", 0.0))
            peaks["max_working_set_mb"] = max(peaks["max_working_set_mb"], ws)
            peaks["counters_last"] = counters
            if phases.exists():
                lines = phases.read_text().splitlines()
                if len(lines) > seen:
                    for line in lines[seen:]:
                        if not line.strip():
                            continue
                        phase_maps.append({"phase": line.split(" ", 3)[-1], **summary, **counters})
                    seen = len(lines)
            time.sleep(args.interval)
    except OSError as error:
        peaks["sampler_error"] = str(error)
    proc.wait(timeout=args.timeout)
    out = {"mode": mode, "wall_seconds": round(time.time() - started, 1), "sampled": peaks, "phases": phase_maps}
    if result_file.exists():
        out["bench"] = json.loads(result_file.read_text())
    else:
        out["bench"] = {"ok": False, "error": "no result file"}
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--work", required=True)
    ap.add_argument("--dd", required=True, help="dd.exe / DreamDaemon path")
    ap.add_argument("--level", type=int, default=2)
    ap.add_argument("--modes", default=",".join(DEFAULT_MODES))
    ap.add_argument("--interval", type=float, default=0.5)
    ap.add_argument("--timeout", type=float, default=7200)
    args = ap.parse_args()
    report = {"platform": sys.platform, "level": args.level, "modes": []}
    for mode in args.modes.split(","):
        print(f"running {mode}...", flush=True)
        entry = run_mode(args, mode, args.level)
        report["modes"].append(entry)
        bench = entry["bench"]
        print(json.dumps({"mode": mode, "ok": bench.get("ok"), "seconds": bench.get("seconds"),
                          "max_private_mb": entry["sampled"]["max_private_committed_mb"],
                          "max_ws_mb": entry["sampled"]["max_working_set_mb"],
                          "min_largest_free_mb": entry["sampled"]["min_largest_free_mb"],
                          "error": bench.get("error")}), flush=True)
        Path(args.work, f"report_z{args.level}.json").write_text(json.dumps(report, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
