"""Headless region travel carry probe (developer evidence, not CI).

Builds a temporary copy of civ13.dme with maps/EFT/crossroads_mall.dmm selected and
tests/region_carry/native_probe.dm appended, compiles it with the pinned
compiler, runs it once in DreamDaemon from a fresh evidence directory and
checks result.json. No client, no live server files, no ports opened to
anything but the local daemon. Generated sources are removed afterwards.

    python3 tests/region_carry/native_probe.py --byond-bin ~/byond-516.1688/byond/bin --output /fresh/dir
"""
import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
BEGIN, END = "// BEGIN_SELECTED_MAP", "// END_SELECTED_MAP"
RUNTIME = re.compile(r"runtime error: (.*)\nproc name: (.*)\n\s*source file: ([^,\n]+),(\d+)")
REQUIRED_CHECKS = ("carry_kinds", "refusals", "payload_roundtrip", "rebuild", "recipe_knowledge")


def generate(prefix):
    dme = (ROOT / "civ13.dme").read_text(encoding="utf-8-sig")
    start, stop = dme.index(BEGIN), dme.index(END)
    dme = dme[:start] + BEGIN + '\n#include "maps\\EFT\\crossroads_mall.dmm"\n' + dme[stop:]
    dme += '\n#include "tests\\region_carry\\native_probe.dm"\n'
    path = ROOT / (prefix + ".dme")
    path.write_text(dme, encoding="utf-8")
    return path


def runtime_errors(output):
    text = ""
    for path in sorted(output.rglob("*")):
        if path.is_file() and path.suffix in (".log", ".txt") and path.name not in ("compile.log", "stdout.log"):
            text += path.read_text(errors="replace") + "\n"
    rows = {}
    for message, proc, source, line in RUNTIME.findall(text):
        key = f"{source.replace(chr(92), '/')}:{line}: {message.strip()} ({proc.strip()})"
        rows[key] = rows.get(key, 0) + 1
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--byond-bin", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True, help="fresh evidence directory")
    parser.add_argument("--deadline", type=int, default=900)
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists() and any(output.iterdir()):
        raise SystemExit(f"Evidence directory is not empty: {output}")
    output.mkdir(parents=True, exist_ok=True)
    prefix = "region_carry_probe_" + uuid.uuid4().hex[:8]
    source = generate(prefix)
    created = [source, source.with_suffix(".dmb"), source.with_suffix(".rsc"), source.with_suffix(".int"), source.with_suffix(".lk")]
    try:
        build = subprocess.run([str(args.byond_bin / "DreamMaker"), "-max_errors", "0", source.name], cwd=ROOT,
                               capture_output=True, text=True, timeout=900)
        log = build.stdout + build.stderr
        (output / "compile.log").write_text(log, encoding="utf-8")
        if build.returncode or "0 errors, 0 warnings" not in log:
            raise RuntimeError("Probe compilation failed; see compile.log")
        shutil.copy2(source.with_suffix(".dmb"), output / "probe.dmb")
        shutil.copy2(source.with_suffix(".rsc"), output / "probe.rsc")
        for path in subprocess.check_output(["git", "-C", str(ROOT), "ls-files", "--", "config"], text=True).splitlines():
            dest = output / path
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / path, dest)
        command = [str(args.byond_bin / "DreamDaemon"), "probe.dmb", "-trusted", "-ip", "127.0.0.1",
                   "-params", "skip_persistence=1", "-log", "startup.log"]
        started = time.monotonic()
        with (output / "stdout.log").open("w") as out, (output / "stderr.log").open("w") as err:
            process = subprocess.Popen(command, cwd=output, stdout=out, stderr=err)
            try:
                while process.poll() is None:
                    if time.monotonic() - started > args.deadline:
                        raise RuntimeError(f"Whole-daemon {args.deadline}-second deadline")
                    time.sleep(2)
            finally:
                if process.poll() is None:
                    process.kill()
                    process.wait(timeout=10)
        errors = runtime_errors(output)
        (output / "runtime-errors.json").write_text(json.dumps(errors, indent=2), encoding="utf-8")
        if not (output / "result.json").exists():
            raise RuntimeError(f"No result.json (daemon exit {process.returncode}); see {output}")
        result = json.loads((output / "result.json").read_text())
        passed = [row["check"] for row in result.get("checks", []) if row.get("passed")]
        missing = [name for name in REQUIRED_CHECKS if name not in passed]
        mode_errors = {key: count for key, count in errors.items() if "region_travel" in key}
        summary = {"passed": bool(result.get("passed")) and not missing and not mode_errors,
                   "failure": result.get("failure"), "failed_phase": result.get("failed_phase"),
                   "missing_checks": missing, "mode_runtime_errors": mode_errors,
                   "other_runtime_error_sites": len(errors) - len(mode_errors),
                   "wall_seconds": round(time.monotonic() - started), "daemon_exit": process.returncode, "output": str(output)}
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
