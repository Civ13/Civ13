"""Run the production spawn_stack helper with stack.dm's own New/merge in an offline native fixture."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
HELPER = ROOT / "code/game/objects/items/stacks/stack_spawn.dm"
STACK = ROOT / "code/game/objects/items/stacks/stack.dm"
EXPECTED_CHECKS = 12


def proc_block(source, header):
    start = source.index(header)
    lines = source[start:].split("\n")
    body = [lines[0]]
    for line in lines[1:]:
        if line and not line.startswith(("\t", " ")):
            break
        body.append(line)
    return "\n".join(body).rstrip() + "\n"


def stack_procs():
    source = STACK.read_text(encoding="utf-8")
    return proc_block(source, "/obj/item/stack/New(") + "\n" + proc_block(source, "/obj/item/stack/proc/merge(")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--byond-bin", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(HELPER, output / "production.dm")
    (output / "stack_procs.dm").write_text(stack_procs(), encoding="utf-8")
    shutil.copyfile(ROOT / "tests/stack_spawn/probe.dm", output / "probe.dm")
    (output / "probe.dme").write_text('#define TRUE 1\n#define FALSE 0\n#include "probe.dm"\n#include "stack_procs.dm"\n#include "production.dm"\n')
    flags = subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0
    compiler = args.byond_bin / ("dm.exe" if os.name == "nt" else "DreamMaker")
    daemon = args.byond_bin / ("dd.exe" if os.name == "nt" else "DreamDaemon")
    built = subprocess.run([str(compiler), "-max_errors", "0", "probe.dme"], cwd=output,
                           capture_output=True, text=True, timeout=60, creationflags=flags)
    log = built.stdout + built.stderr
    if built.returncode or "0 errors, 0 warnings" not in log:
        raise SystemExit(log)
    ran = subprocess.run([str(daemon), "probe.dmb", "-invisible", "-close", "-trusted", "-ip", "127.0.0.1", "-log", "runtime.log"],
                         cwd=output, capture_output=True, text=True, timeout=30, creationflags=flags)
    runtime = output / "runtime.log"
    combined = (runtime.read_text() if runtime.exists() else "") + ran.stdout + ran.stderr
    if re.search(r"runtime error|Bad ref|BUG:", combined, re.I):
        raise SystemExit(combined)
    result = json.loads((output / "result.json").read_text())
    if result["checks"] != EXPECTED_CHECKS or result["failed_labels"]:
        raise SystemExit(f"FAIL {result}")
    print(json.dumps(result))
    print("PASS spawn_stack fixture")


if __name__ == "__main__":
    main()
