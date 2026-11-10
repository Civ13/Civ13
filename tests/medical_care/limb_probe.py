"""Compile and run projected production limb-surgery methods with fake organs."""
import argparse
import os
from pathlib import Path
import re
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def method(source, declaration, name):
    start = source.index(declaration + "\n")
    section = source[start:]
    match = re.search(rf"(?m)^\t{name}\([^\n]*\)\n(?:(?:\t\t[^\n]*|)\n)*", section)
    if not match:
        raise ValueError(f"missing {declaration}/{name}")
    lines = match.group().splitlines()
    return declaration + "/" + lines[0].lstrip() + "\n" + "\n".join(line[1:] for line in lines[1:]) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--byond-bin", type=Path, required=True)
    parser.add_argument("--negative-control", action="store_true")
    args = parser.parse_args()
    source = (ROOT / "code/modules/surgery/limb_reattach.dm").read_text(encoding="utf-8")
    if args.negative_control:
        original = "E.limb_name != target_zone"
        assert source.count(original) == 1
        source = source.replace(original, "FALSE", 1)
    methods = "\n".join(method(source, decl, name) for decl, name in (
        ("/datum/surgery_step/limb", "can_use"),
        ("/datum/surgery_step/limb/attach", "can_use"),
        ("/datum/surgery_step/limb/attach", "end_step"),
    ))
    with tempfile.TemporaryDirectory(prefix="limb_surgery_") as temp:
        directory = Path(temp)
        (directory / "fixture.dme").write_text('#include "limb_probe.dm"\n#include "methods.dm"\n#include "limb_cases.dm"\n', encoding="utf-8")
        (directory / "limb_probe.dm").write_text((HERE / "limb_probe.dm").read_text(encoding="utf-8"), encoding="utf-8")
        (directory / "limb_cases.dm").write_text((HERE / "limb_cases.dm").read_text(encoding="utf-8"), encoding="utf-8")
        (directory / "methods.dm").write_text(methods, encoding="utf-8")
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
        failures = int(result.read_text(encoding="utf-8"))
        print(f"{'negative control' if args.negative_control else 'production'}: {failures} failed assertions")
        return int((failures == 0) if args.negative_control else (failures != 0))


if __name__ == "__main__":
    raise SystemExit(main())
