"""Compile and run the production do_surgery() with stub steps.

Checks that an ordinary click with a bucket (or any open container) is not
claimed by a surgery step that does not apply, that aiming an open container at
your own mouth always drinks, and that real surgery still runs.
"""
import argparse
import os
from pathlib import Path
import re
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
APPLICABILITY = "if (!step_is_valid || !S.is_valid_target(M))\n\t\t\tcontinue"


def project(source):
    match = re.search(r"(?m)^proc/do_surgery\(.*\n(?:(?:\t[^\n]*|)\n)*", source)
    if not match:
        raise ValueError("missing do_surgery")
    return "/" + match.group()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--byond-bin", type=Path, required=True)
    parser.add_argument("--negative-control", action="store_true",
                        help="restore the old order (skill warning before applicability); must fail")
    args = parser.parse_args()
    source = (ROOT / "code/modules/surgery/surgery.dm").read_text(encoding="utf-8")
    if args.negative_control:
        assert source.count(APPLICABILITY) == 1
        source = source.replace(APPLICABILITY, "if ((!step_is_valid || !S.is_valid_target(M)) && quality > 50)\n\t\t\tcontinue", 1)
    with tempfile.TemporaryDirectory(prefix="surgery_drinking_") as temp:
        directory = Path(temp)
        (directory / "fixture.dme").write_text('#include "drink_stubs.dm"\n#include "method.dm"\n#include "drink_cases.dm"\n', encoding="utf-8")
        for name in ("drink_stubs.dm", "drink_cases.dm"):
            (directory / name).write_text((HERE / name).read_text(encoding="utf-8"), encoding="utf-8")
        (directory / "method.dm").write_text(project(source), encoding="utf-8")
        compiler = args.byond_bin / ("dm.exe" if os.name == "nt" else "DreamMaker")
        daemon = args.byond_bin / ("dd.exe" if os.name == "nt" else "DreamDaemon")
        compiled = subprocess.run([str(compiler), "fixture.dme"], cwd=directory, capture_output=True, text=True, timeout=120)
        if compiled.returncode or "0 errors" not in compiled.stdout:
            print(compiled.stdout + compiled.stderr)
            return 2
        runtime = subprocess.run([str(daemon), "fixture.dmb", "0", "-safe", "-invisible", "-close"], cwd=directory, capture_output=True, text=True, timeout=120)
        if runtime.returncode:
            print(runtime.stdout + runtime.stderr)
            return 2
        result = directory / "result.txt"
        if not result.exists():
            print("FAIL: no probe result")
            return 2
        log = directory / "log.txt"
        if log.exists():
            print(log.read_text(encoding="utf-8"), end="")
        failures = int(result.read_text(encoding="utf-8"))
        print(f"{'negative control' if args.negative_control else 'production'}: {failures} failed assertions")
        return int((failures == 0) if args.negative_control else (failures != 0))


if __name__ == "__main__":
    raise SystemExit(main())
