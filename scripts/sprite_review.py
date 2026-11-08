#!/usr/bin/env python3
"""Sprite review: compare every .dmi a change touches, state by state, with byond-devtools.

    python3 scripts/sprite_review.py --base origin/master [--head HEAD] --devtools ../byond-devtools --out sprite-review

For each added, changed or deleted .dmi between base and head it runs `node <devtools>/src/cli.js
icon-diff` and writes <out>/<icon path>.png (one row per changed state: before | after | heatmap)
and <out>/summary.md (also appended to --summary, e.g. $GITHUB_STEP_SUMMARY). Exits 1 only when
a DMI cannot be read (a broken sprite file); added, removed or changed states are for review.
The sprite-review workflow runs this on pull requests; run it locally the same way.
"""

import argparse
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAX_FILES = 200
MAX_STATES_LISTED = 12


def git(*args, binary=False):
    out = subprocess.run(["git", *args], cwd=ROOT, capture_output=True, check=True)
    return out.stdout if binary else out.stdout.decode("utf-8", "replace")


def changed_icons(base, head):
    """[(status, old_path, new_path)] for .dmi files between base and head (renames followed)."""
    rows = []
    for line in git("diff", "--name-status", "-M", f"{base}...{head}", "--", "*.dmi").splitlines():
        parts = line.split("\t")
        status = parts[0][:1]
        if status == "R":
            rows.append(("R", parts[1], parts[2]))
        elif status in "AMD":
            rows.append((status, parts[1], parts[1]))
    return rows


def review(base, head, devtools, out, node="node"):
    cli = Path(devtools) / "src" / "cli.js"
    if not cli.is_file():
        raise SystemExit(f"no byond-devtools CLI at {cli}")
    out.mkdir(parents=True, exist_ok=True)
    files = changed_icons(base, head)
    lines = ["## Sprite review", ""]
    if not files:
        lines.append("No .dmi files changed.")
    broken = 0
    with tempfile.TemporaryDirectory(prefix="sprite-review-") as tmp:
        for status, old, new in files[:MAX_FILES]:
            before, after = Path(tmp) / "before.dmi", Path(tmp) / "after.dmi"
            if status != "A":
                before.write_bytes(git("show", f"{base}:{old}", binary=True))
            if status != "D":
                after.write_bytes(git("show", f"{head}:{new}", binary=True))
            image = out / (new + ".png")
            image.parent.mkdir(parents=True, exist_ok=True)
            image.unlink(missing_ok=True)
            done = subprocess.run([node, str(cli), "icon-diff", "--before", str(before) if status != "A" else "none",
                                   "--after", str(after) if status != "D" else "none", "--out", str(image)],
                                  capture_output=True, text=True)
            before.unlink(missing_ok=True)
            after.unlink(missing_ok=True)
            label = new if old == new else f"{old} -> {new}"
            if done.returncode not in (0, 3):
                broken += 1
                lines.append(f"- **{label}**: could not be read: {(done.stderr or done.stdout).strip()[:300]}")
                continue
            data = json.loads(done.stdout)["data"]
            counts = ", ".join(f"{data[k]} {k}" for k in ("added", "changed", "removed") if data[k])
            lines.append(f"- **{label}** ({ {'A': 'new file', 'D': 'deleted', 'R': 'renamed', 'M': 'modified'}[status] }): {counts or 'no state changes'}"
                         + (f"; picture `{image.relative_to(out)}`" if image.exists() else ""))
            for state in data["states"][:MAX_STATES_LISTED]:
                name = state["state"] or "(unnamed)"
                lines.append(f"  - `{name}`{' (movement)' if state['movement'] else ''}: {state['change']}" + (f", {state['details']}" if state.get("details") else ""))
            if len(data["states"]) > MAX_STATES_LISTED:
                lines.append(f"  - and {len(data['states']) - MAX_STATES_LISTED} more")
    if len(files) > MAX_FILES:
        lines.append(f"- and {len(files) - MAX_FILES} more files (not reviewed)")
    lines += ["", "Pictures: before | after | heatmap per changed state, in the sprite-review artifact."]
    text = "\n".join(lines) + "\n"
    (out / "summary.md").write_text(text, encoding="utf-8")
    return text, broken


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--base", required=True, help="base revision (merge base is used)")
    parser.add_argument("--head", default="HEAD")
    parser.add_argument("--devtools", default=os.environ.get("BYOND_DEVTOOLS", ""), help="byond-devtools checkout (default $BYOND_DEVTOOLS)")
    parser.add_argument("--out", type=Path, default=Path("sprite-review"))
    parser.add_argument("--summary", help="also append the summary to this file")
    args = parser.parse_args(argv)
    if not args.devtools:
        parser.error("--devtools or BYOND_DEVTOOLS is required")
    text, broken = review(args.base, args.head, args.devtools, args.out)
    print(text)
    if args.summary:
        with open(args.summary, "a", encoding="utf-8") as handle:
            handle.write(text)
    return 1 if broken else 0


if __name__ == "__main__":
    sys.exit(main())
