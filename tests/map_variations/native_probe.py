"""Headless map variation probe (developer evidence, not CI).

Builds a temporary copy of civ13.dme with a battle map selected and
tests/map_variations/native_probe.dm appended, compiles it with the pinned
compiler, runs it once in DreamDaemon from a fresh evidence directory (with
config/ and maps/zones/variations/ copied in) and checks result.json. No
client, no live server files. Generated sources are removed afterwards.

    python3 tests/map_variations/native_probe.py --byond-bin ~/byond-516.1688/byond/bin \\
        --map maps/1943/smallingrad.dmm --output /fresh/dir
"""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
BEGIN, END = "// BEGIN_SELECTED_MAP", "// END_SELECTED_MAP"


def generate(prefix, map_path):
    dme = (ROOT / "civ13.dme").read_text(encoding="utf-8-sig")
    start, stop = dme.index(BEGIN), dme.index(END)
    include = map_path.replace("/", "\\")
    dme = dme[:start] + BEGIN + '\n#include "%s"\n' % include + dme[stop:]
    dme += '\n#include "tests\\map_variations\\native_probe.dm"\n'
    path = ROOT / (prefix + ".dme")
    path.write_text(dme, encoding="utf-8")
    return path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--byond-bin", type=Path, required=True)
    parser.add_argument("--map", default="maps/1943/smallingrad.dmm")
    parser.add_argument("--output", type=Path, required=True, help="fresh evidence directory")
    parser.add_argument("--deadline", type=int, default=900)
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists() and any(output.iterdir()):
        raise SystemExit(f"Evidence directory is not empty: {output}")
    output.mkdir(parents=True, exist_ok=True)
    source = generate("map_variation_probe_" + uuid.uuid4().hex[:8], args.map)
    created = [source.with_suffix(s) for s in (".dme", ".dmb", ".rsc", ".int", ".lk")]
    try:
        build = subprocess.run([str(args.byond_bin / "DreamMaker"), "-max_errors", "0", source.name], cwd=ROOT,
                               capture_output=True, text=True, timeout=900)
        log = build.stdout + build.stderr
        (output / "compile.log").write_text(log, encoding="utf-8")
        if build.returncode or "0 errors, 0 warnings" not in log:
            raise RuntimeError("Probe compilation failed; see compile.log")
        shutil.copy2(source.with_suffix(".dmb"), output / "probe.dmb")
        shutil.copy2(source.with_suffix(".rsc"), output / "probe.rsc")
        tracked = subprocess.check_output(["git", "-C", str(ROOT), "ls-files", "--", "config"], text=True).splitlines()
        for path in tracked:
            dest = output / path
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / path, dest)
        shutil.copytree(ROOT / "maps" / "zones" / "variations", output / "maps" / "zones" / "variations")
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
        if not (output / "result.json").exists():
            raise RuntimeError(f"No result.json (daemon exit {process.returncode}); see {output}")
        result = json.loads((output / "result.json").read_text())
        result["wall_seconds"] = round(time.monotonic() - started)
        print(json.dumps(result, indent=2))
        if not result.get("passed"):
            raise SystemExit(1)
    finally:
        for path in created:
            if path.exists():
                path.unlink()


if __name__ == "__main__":
    main()
