"""Run the production food toxin log helpers in an offline native fixture."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
PRODUCTION = ROOT / "code/modules/reagents/food_toxin_log.dm"
EXPECTED_CHECKS = 18


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--byond-bin", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(PRODUCTION, output / "production.dm")
    shutil.copyfile(ROOT / "tests/food_toxin_log/probe.dm", output / "probe.dm")
    (output / "probe.dme").write_text('#define TRUE 1\n#define FALSE 0\n#include "probe.dm"\n#include "production.dm"\n')
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
    print("PASS food toxin log fixture")


if __name__ == "__main__":
    main()
