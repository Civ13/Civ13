"""Headless performance probes for the CM-SS13 adoption gates (developer evidence, not CI).

    python3 tests/perf_probes/native_probe.py projectile --byond-bin ~/byond-516.1688/byond/bin --output /fresh/dir
    python3 tests/perf_probes/native_probe.py range --byond-bin ~/byond-516.1688/byond/bin --output /fresh/dir

Builds a temporary copy of civ13.dme (the selected map, Gaia by default) with
the probe .dm appended, compiles it with the pinned compiler, runs it once in
DreamDaemon from a fresh evidence directory and writes summary.json:

- projectile (step 10): per-bullet outcomes for 300 ordinary shots and one
  600-bullet stress wave, tick usage, peak projectile count and profiler cost
  of the projectile procs. Gate for step 11: any skipped_target or stopped_early
  bullet in the ordinary waves, or projectile procs above 10% of the run.
- range (step 12a): profiler share of server time spent in animal AI procs over
  a fixed window. Gate for step 12b: above 5%.

No client, no live server files, no ports beyond the local daemon. Generated
sources are removed afterwards.
"""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
PROBES = {"projectile": "projectile_probe.dm", "range": "range_probe.dm"}


def generate(probe, prefix):
    dme = (ROOT / "civ13.dme").read_text(encoding="utf-8-sig")
    dme += '\n#include "tests\\perf_probes\\' + PROBES[probe] + '"\n'
    path = ROOT / (prefix + ".dme")
    path.write_text(dme, encoding="utf-8")
    return path


def profile_rows(text):
    """BYOND's JSON profile: a list of {name, self, total, real, over, calls}."""
    if not text:
        return []
    data = json.loads(text) if isinstance(text, str) else text
    if isinstance(data, dict):
        data = data.get("procs") or data.get("entries") or []
    return [row for row in data if isinstance(row, dict) and "name" in row]


def total(rows, predicate, field="self"):
    return round(sum(float(r.get(field) or 0) for r in rows if predicate(r["name"])), 4)


def top(rows, predicate, count=15):
    picked = sorted((r for r in rows if predicate(r["name"])), key=lambda r: -float(r.get("self") or 0))
    return [{k: r.get(k) for k in ("name", "self", "total", "calls")} for r in picked[:count]]


def summarize_projectile(result):
    rows = profile_rows(result.pop("profile", None))
    counts = result.get("outcome_counts", {})
    is_projectile = lambda name: "/obj/item/projectile" in name or name.startswith("/process/projectile")
    seconds = float(result.get("game_seconds") or 0)
    projectile_self = total(rows, is_projectile)
    ordinary_bad = sum(v for k, v in counts.items() if k in ("ordinary:skipped_target", "ordinary:stopped_early"))
    share = projectile_self / seconds if seconds else 0
    return {
        "outcome_counts": counts,
        "baseline_ticks": result.get("baseline_ticks"),
        "ordinary_ticks": result.get("ordinary_ticks"),
        "stress_ticks": result.get("stress_ticks"),
        "peak_projectiles": result.get("peak_projectiles"),
        "stress_never_moved": counts.get("stress:never_moved", 0),
        "projectile_proc_self_seconds": projectile_self,
        "run_game_seconds": seconds,
        "projectile_share_of_run": round(share, 4),
        "top_projectile_procs": top(rows, is_projectile, 10),
        "world_fps": result.get("world_fps"),
        "gate_step_11": bool(ordinary_bad or share > 0.10),
        "gate_reason": f"{ordinary_bad} ordinary bullets skipped or stopped short; projectile procs {share:.1%} of the run",
    }


def summarize_range(result):
    rows = profile_rows(result.pop("profile", None))
    wall = float(result.get("window_wall_seconds") or 0)
    is_animal = lambda name: name.startswith("/mob/living/simple_animal")
    animal_self = total(rows, is_animal)
    share = animal_self / wall if wall else 0
    return {
        "living_animals": result.get("living_animals"),
        "window_wall_seconds": wall,
        "window_game_seconds": result.get("window_game_seconds"),
        "mean_tick_usage": result.get("mean_tick_usage"),
        "max_tick_usage": result.get("max_tick_usage"),
        "animal_proc_self_seconds": animal_self,
        "animal_share_of_wall": round(share, 4),
        "all_proc_self_seconds": total(rows, lambda name: True),
        "top_animal_procs": top(rows, is_animal),
        "top_procs": top(rows, lambda name: True),
        "world_fps": result.get("world_fps"),
        "gate_step_12b": share > 0.05,
        "gate_reason": f"animal AI procs used {share:.1%} of wall time with {result.get('living_animals')} animals",
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("probe", choices=sorted(PROBES))
    parser.add_argument("--byond-bin", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True, help="fresh evidence directory")
    parser.add_argument("--deadline", type=int, default=2400, help="whole-daemon wall-clock limit in seconds")
    parser.add_argument("--window-ds", type=int, default=6000, help="range probe profiling window (deciseconds)")
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists() and any(output.iterdir()):
        raise SystemExit(f"Evidence directory is not empty: {output}")
    output.mkdir(parents=True, exist_ok=True)
    prefix = f"perf_probe_{args.probe}_" + uuid.uuid4().hex[:8]
    source = generate(args.probe, prefix)
    created = [source] + [source.with_suffix(s) for s in (".dmb", ".rsc", ".int", ".lk")]
    try:
        build = subprocess.run([str(args.byond_bin / "DreamMaker"), "-max_errors", "0", source.name], cwd=ROOT,
                               capture_output=True, text=True, timeout=900)
        log = build.stdout + build.stderr
        (output / "compile.log").write_text(log, encoding="utf-8")
        if build.returncode or "0 errors" not in log:
            raise SystemExit("Probe compilation failed; see compile.log")
        shutil.copy2(source.with_suffix(".dmb"), output / "probe.dmb")
        shutil.copy2(source.with_suffix(".rsc"), output / "probe.rsc")
        for path in subprocess.check_output(["git", "-C", str(ROOT), "ls-files", "--", "config"], text=True).splitlines():
            dest = output / path
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / path, dest)
        params = f"skip_persistence=1&window_ds={args.window_ds}"
        command = [str(args.byond_bin / "DreamDaemon"), "probe.dmb", "-trusted", "-ip", "127.0.0.1",
                   "-params", params, "-log", "startup.log"]
        started = time.monotonic()
        with (output / "stdout.log").open("w") as out, (output / "stderr.log").open("w") as err:
            process = subprocess.Popen(command, cwd=output, stdout=out, stderr=err)
            try:
                while process.poll() is None:
                    if time.monotonic() - started > args.deadline:
                        raise SystemExit(f"Whole-daemon {args.deadline}-second deadline")
                    time.sleep(2)
            finally:
                if process.poll() is None:
                    process.kill()
                    process.wait(timeout=10)
        result_path = output / "result.json"
        if not result_path.exists():
            raise SystemExit(f"No result.json (daemon exit {process.returncode}); see {output}")
        result = json.loads(result_path.read_text())
        summary = {"probe": args.probe, "passed": bool(result.get("passed")), "failure": result.get("failure"),
                   "wall_seconds": round(time.monotonic() - started), "daemon_exit": process.returncode}
        if summary["passed"]:
            summary.update(summarize_projectile(result) if args.probe == "projectile" else summarize_range(result))
        (output / "summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
        print(json.dumps(summary, indent=2))
        if not summary["passed"]:
            raise SystemExit(1)
    finally:
        for path in created:
            if path.exists():
                path.unlink()


if __name__ == "__main__":
    main()
