"""Headless zombie city generation probe (developer evidence, not CI).

Builds a temporary copy of civ13.dme with maps/zombie_city/zombie_city.dmm
selected and tests/zombie_city/native_probe.dm appended, compiles it once with
the pinned compiler, then runs DreamDaemon once per requested seed from a fresh
evidence directory. Each run writes layout.json, grid.txt and result.json; the
checker (check.py) then verifies determinism, reachability, marker counts,
spacing and cost across the runs and renders a preview per seed. No client, no
live server files, no ports opened to anything but the local daemon. Generated
sources are removed afterwards.

    python3 tests/zombie_city/native_probe.py --byond-bin ~/byond-516.1688/byond/bin --output /fresh/dir --seeds 1 1 2
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
BEGIN, END = "// BEGIN_SELECTED_MAP", "// END_SELECTED_MAP"
RUNTIME = re.compile(r"runtime error: (.*)\nproc name: (.*)\n\s*source file: ([^,\n]+),(\d+)")


def generate(prefix: str) -> Path:
    dme = (ROOT / "civ13.dme").read_text(encoding="utf-8-sig")
    start, stop = dme.index(BEGIN), dme.index(END)
    dme = dme[:start] + BEGIN + '\n#include "maps\\zombie_city\\zombie_city.dmm"\n' + dme[stop:]
    dme += '\n#include "tests\\zombie_city\\native_probe.dm"\n'
    path = ROOT / (prefix + ".dme")
    path.write_text(dme, encoding="utf-8")
    return path


def runtime_errors(output: Path) -> dict:
    text = ""
    for path in sorted(output.rglob("*")):
        if path.is_file() and path.suffix in (".log", ".txt") and path.name not in ("compile.log", "stdout.log", "grid.txt"):
            text += path.read_text(errors="replace") + "\n"
    rows: dict = {}
    for message, proc, source, line in RUNTIME.findall(text):
        key = f"{source.replace(chr(92), '/')}:{line}: {message.strip()} ({proc.strip()})"
        rows[key] = rows.get(key, 0) + 1
    return rows


def run_seed(byond_bin: Path, dmb: Path, rsc: Path, run_dir: Path, seed: int, deadline: int) -> dict:
    run_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(dmb, run_dir / "probe.dmb")
    shutil.copy2(rsc, run_dir / "probe.rsc")
    for path in subprocess.check_output(["git", "-C", str(ROOT), "ls-files", "--", "config"], text=True).splitlines():
        dest = run_dir / path
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / path, dest)
    command = [str(byond_bin / "DreamDaemon"), "probe.dmb", "-trusted", "-ip", "127.0.0.1",
               "-params", f"skip_persistence=1&seed={seed}", "-log", "startup.log"]
    started = time.monotonic()
    with (run_dir / "stdout.log").open("w") as out, (run_dir / "stderr.log").open("w") as err:
        process = subprocess.Popen(command, cwd=run_dir, stdout=out, stderr=err)
        try:
            while process.poll() is None:
                if time.monotonic() - started > deadline:
                    raise RuntimeError(f"Whole-daemon {deadline}-second deadline for seed {seed}")
                time.sleep(2)
        finally:
            if process.poll() is None:
                process.kill()
                process.wait(timeout=10)
    errors = runtime_errors(run_dir)
    (run_dir / "runtime-errors.json").write_text(json.dumps(errors, indent=2), encoding="utf-8")
    result_path = run_dir / "result.json"
    if not result_path.exists():
        raise RuntimeError(f"No result.json for seed {seed} (daemon exit {process.returncode}); see {run_dir}")
    result = json.loads(result_path.read_text())
    result["runtime_errors"] = errors
    result["wall_seconds"] = round(time.monotonic() - started)
    result["daemon_exit"] = process.returncode
    result["run_dir"] = str(run_dir)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--byond-bin", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True, help="fresh evidence directory")
    parser.add_argument("--seeds", type=int, nargs="+", default=[1, 1, 2], help="seeds to run, in order (repeat one for determinism)")
    parser.add_argument("--deadline", type=int, default=600, help="seconds per daemon run")
    parser.add_argument("--no-check", action="store_true", help="only run the daemon; skip check.py")
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists() and any(output.iterdir()):
        raise SystemExit(f"Evidence directory is not empty: {output}")
    output.mkdir(parents=True, exist_ok=True)
    prefix = "zombie_city_probe_" + uuid.uuid4().hex[:8]
    source = generate(prefix)
    created = [source, source.with_suffix(".dmb"), source.with_suffix(".rsc"), source.with_suffix(".int"), source.with_suffix(".lk")]
    try:
        build = subprocess.run([str(args.byond_bin / "DreamMaker"), "-max_errors", "0", source.name], cwd=ROOT,
                               capture_output=True, text=True, timeout=900)
        log = build.stdout + build.stderr
        (output / "compile.log").write_text(log, encoding="utf-8")
        if build.returncode or "0 errors, 0 warnings" not in log:
            raise RuntimeError("Probe compilation failed; see compile.log")
        results = []
        for index, seed in enumerate(args.seeds, 1):
            results.append(run_seed(args.byond_bin, source.with_suffix(".dmb"), source.with_suffix(".rsc"),
                                    output / f"run{index}-seed{seed}", seed, args.deadline))
        (output / "runs.json").write_text(json.dumps(results, indent=2), encoding="utf-8")
        for row in results:
            print(f"seed {row['seed']}: passed={row['passed']} generation={row.get('generation_ds', 0) / 10:.1f}s "
                  f"runtime_errors={sum(row['runtime_errors'].values())} failure={row.get('failure')}")
        if not all(row["passed"] for row in results):
            raise SystemExit(1)
        if args.no_check:
            return 0
        check = subprocess.run([sys.executable, "-I", "-B", str(ROOT / "tests/zombie_city/check.py"), str(output)], cwd=ROOT)
        return check.returncode
    finally:
        for path in created:
            if path.exists():
                path.unlink()


if __name__ == "__main__":
    raise SystemExit(main())
