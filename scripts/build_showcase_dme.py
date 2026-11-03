"""Generate showcase.dme: the separate showcase/demo build.

civ13.dme (the live game) never includes the showcase room loader. This
script copies civ13.dme, defines CIV13_SHOWCASE_BUILD and adds
code/modules/admin/showcase_rooms.dm, so the demo build compiles to its own
showcase.dmb. Run that build only as a disposable, non-persistent demo
instance, never alongside or in place of a persistent world such as Gaia.

    python3 scripts/build_showcase_dme.py [--output showcase.dme] [--compile]
"""
from __future__ import annotations

import argparse
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
DEFINE = "#define CIV13_SHOWCASE_BUILD\n"
ANCHOR = '#include "code\\modules\\admin\\admin_verbs.dm"\n'
INCLUDE = '#include "code\\modules\\admin\\showcase_rooms.dm"\n'


def generate(source: str) -> str:
    if "CIV13_SHOWCASE_BUILD" in source or INCLUDE in source:
        raise ValueError("civ13.dme must not already contain the showcase build")
    if source.count(ANCHOR) != 1:
        raise ValueError("civ13.dme must include admin_verbs.dm exactly once")
    return DEFINE + source.replace(ANCHOR, ANCHOR + INCLUDE, 1)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n", 1)[0])
    parser.add_argument("--output", default="showcase.dme",
                        help="file name in the repository root (default: showcase.dme)")
    parser.add_argument("--compile", action="store_true", help="compile it with DreamMaker afterwards")
    args = parser.parse_args(argv)
    output = Path(args.output)
    if output.name != str(output) or output.suffix != ".dme" or output.name == "civ13.dme":
        parser.error("--output must be a .dme file name other than civ13.dme, in the repository root")
    source = (ROOT / "civ13.dme").read_text(encoding="utf-8")
    (ROOT / output).write_text(generate(source), encoding="utf-8", newline="\n")
    print(f"wrote {output}")
    if args.compile:
        compiler = shutil.which("DreamMaker") or shutil.which("dm.exe") or shutil.which("dm")
        if not compiler:
            print("DreamMaker not found on PATH", file=sys.stderr)
            return 2
        return subprocess.call([compiler, "-max_errors", "0", output.name], cwd=ROOT)
    return 0


if __name__ == "__main__":
    sys.exit(main())
