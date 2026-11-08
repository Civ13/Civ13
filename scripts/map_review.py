#!/usr/bin/env python3
"""Map review: before | after pictures and lint for every .dmm a change touches, with byond-devtools.

    python3 scripts/map_review.py --base origin/master [--head HEAD] --devtools ../byond-devtools \\
        [--byond <BYOND bin folder>] --out map-review

For each added, changed, renamed or deleted map between base and head it writes a line to
<out>/summary.md (also appended to --summary, e.g. $GITHUB_STEP_SUMMARY): changed tiles per level
and, with --byond, <out>/<map>.z<N>.png for each changed level (before | after | changed tiles,
at most 64x64 tiles around the changes) and the unknown types and undefined vars the change adds.
The type tree comes from one `DreamMaker -o civ13.dme` of the checked-out tree, so run it with head
checked out. Exits 1 only when a map at head cannot be read (a broken map file); everything else
is for review. The map-review workflow runs this on pull requests; run it locally the same way.
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAX_FILES = 60
MAX_LEVELS = 4
MAX_PROBLEMS_LISTED = 10
BASE_DIR = ".map-review-base"  # base versions, inside the project so byond-devtools can read them


def git(*args, binary=False):
    out = subprocess.run(["git", *args], cwd=ROOT, capture_output=True, check=True)
    return out.stdout if binary else out.stdout.decode("utf-8", "replace")


def changed_maps(base, head):
    """[(status, old_path, new_path)] for .dmm files between base and head (renames followed)."""
    rows = []
    for line in git("diff", "--name-status", "-M", f"{base}...{head}", "--", "*.dmm").splitlines():
        parts = line.split("\t")
        status = parts[0][:1]
        if status == "R":
            rows.append(("R", parts[1], parts[2]))
        elif status in "AMD":
            rows.append((status, parts[1], parts[1]))
    return rows


def type_tree(byond, dme, dest):
    """Write DreamMaker -o's object tree for dme to dest; returns None or an error line."""
    exe = Path(byond) / ("dm.exe" if os.name == "nt" else "DreamMaker")
    env = dict(os.environ, LD_LIBRARY_PATH=os.pathsep.join(p for p in (str(byond), os.environ.get("LD_LIBRARY_PATH", "")) if p))
    done = subprocess.run([str(exe), "-o", dme], cwd=ROOT, capture_output=True, env=env, timeout=600)
    text = done.stdout.decode("utf-8", "replace")
    at = text.find("<?xml")
    if at < 0 or "<dm>" not in text:
        return f"DreamMaker -o produced no type tree (exit {done.returncode}): {(text + done.stderr.decode('utf-8', 'replace'))[-300:]}"
    dest.write_text(text[at:], encoding="utf-8")
    return None


class Devtools:
    def __init__(self, devtools, dme, tree, node="node"):
        self.cli = Path(devtools) / "src" / "cli.js"
        if not self.cli.is_file():
            raise SystemExit(f"no byond-devtools CLI at {self.cli}")
        self.dme, self.tree, self.node = dme, tree, node

    def run(self, *args):
        """(exit code, parsed JSON or None, stderr) of one CLI call."""
        done = subprocess.run([self.node, str(self.cli), *args], cwd=ROOT, capture_output=True, text=True, timeout=600)
        try:
            data = json.loads(done.stdout)
        except ValueError:
            data = None
        return done.returncode, data, (done.stderr or done.stdout).strip()

    def typed(self):
        return ["--dme", self.dme, "--tree", str(self.tree)] if self.tree else []

    def lint(self, rel):
        """Set of (code, type, var) problems, or None when lint could not run."""
        if not self.tree:
            return None
        code, data, _ = self.run("lint", "--root", str(ROOT), "--map", rel, *self.typed())
        if code not in (0, 3) or not data:
            return None
        return {(p.get("code"), p.get("type") or p.get("path"), p.get("var")) for p in data["data"].get("problems", [])}


def describe_levels(diff):
    parts = []
    for level in diff.get("levels", []):
        parts.append(f"z{level['z']}: {level['changedCells']} tiles (x {level['x1']}-{level['x2']}, y {level['y1']}-{level['y2']})")
    return "; ".join(parts)


def problem_line(problem):
    code, path, var = problem
    return f"`{path}`" + (f" var `{var}`" if var else "") + f" ({code})"


def review(base, head, devtools, out, byond=None, dme="civ13.dme", node="node"):
    out.mkdir(parents=True, exist_ok=True)
    files = changed_maps(base, head)
    lines = ["## Map review", ""]
    broken = 0
    if not files:
        lines.append("No .dmm files changed.")
    with tempfile.TemporaryDirectory(prefix="map-review-") as tmp:
        tree = None
        if files and byond:
            tree = Path(tmp) / "tree.xml"
            error = type_tree(byond, dme, tree)
            if error:
                lines.append(f"- Type tree unavailable, so no pictures or lint: {error}")
                tree = None
        tools = Devtools(devtools, dme, tree, node)
        base_dir = ROOT / BASE_DIR
        shutil.rmtree(base_dir, ignore_errors=True)
        base_dir.mkdir()
        try:
            for n, (status, old, new) in enumerate(files[:MAX_FILES]):
                label = new if old == new else f"{old} -> {new}"
                kind = {"A": "new map", "D": "deleted", "R": "renamed", "M": "modified"}[status]
                if status == "D":
                    lines.append(f"- **{label}** ({kind})")
                    continue
                code, summary, err = tools.run("summary", "--root", str(ROOT), "--map", new)
                if code != 0 or not summary:
                    broken += 1
                    lines.append(f"- **{label}** ({kind}): could not be read: {err[:300]}")
                    continue
                world = summary["data"].get("world", {})
                size = f"{world.get('maxX')}x{world.get('maxY')}x{world.get('maxZ')}"
                problems = tools.lint(new)
                if status == "A":
                    lines.append(f"- **{label}** ({kind}, {size})")
                    added = sorted(problems or [])
                else:
                    before_rel = f"{BASE_DIR}/{n}.dmm"
                    (ROOT / before_rel).write_bytes(git("show", f"{base}:{old}", binary=True))
                    code, data, err = tools.run("diff", "--root", str(ROOT), "--map", new, "--before", before_rel, "--limit", "0")
                    if code != 0 or not data:
                        lines.append(f"- **{label}** ({kind}): diff failed: {err[:300]}")
                        continue
                    diff = data["data"]
                    world_change = diff.get("world", {})
                    resized = f", resized {world_change['before']['maxX']}x{world_change['before']['maxY']}x{world_change['before']['maxZ']} -> {size}" if world_change.get("changed") else ""
                    lines.append(f"- **{label}** ({kind}{resized}): {diff.get('changedCells', 0)} changed tiles"
                                 + (f"; {describe_levels(diff)}" if diff.get("levels") else ""))
                    if tree:
                        for level in diff.get("levels", [])[:MAX_LEVELS]:
                            image = out / f"{new}.z{level['z']}.png"
                            image.parent.mkdir(parents=True, exist_ok=True)
                            code, shot, err = tools.run("diff", "--root", str(ROOT), "--map", new, "--before", before_rel, "--limit", "0",
                                                        "--z", str(level["z"]), "--out", str(image), "--force", *tools.typed())
                            if code == 0 and shot and shot["data"].get("image", {}).get("out"):
                                region = shot["data"]["image"]["region"]
                                clipped = " (clipped to 64x64 tiles)" if region.get("clipped") else ""
                                lines.append(f"  - z{level['z']} picture `{image.relative_to(out)}`: x {region['x1']}-{region['x2']}, y {region['y1']}-{region['y2']}{clipped}")
                            else:
                                lines.append(f"  - z{level['z']} picture failed: {err[:200]}")
                        if len(diff.get("levels", [])) > MAX_LEVELS:
                            lines.append(f"  - and {len(diff['levels']) - MAX_LEVELS} more changed levels (not drawn)")
                    before_problems = tools.lint(before_rel) if problems is not None else None
                    added = sorted((problems or set()) - (before_problems or set()))
                if problems is None and tree:
                    lines.append("  - lint could not run on this map")
                for problem in added[:MAX_PROBLEMS_LISTED]:
                    lines.append(f"  - new lint problem: {problem_line(problem)}")
                if len(added) > MAX_PROBLEMS_LISTED:
                    lines.append(f"  - and {len(added) - MAX_PROBLEMS_LISTED} more new lint problems")
        finally:
            shutil.rmtree(base_dir, ignore_errors=True)
    if len(files) > MAX_FILES:
        lines.append(f"- and {len(files) - MAX_FILES} more maps (not reviewed)")
    if files:
        lines += ["", "Pictures: before | after | changed tiles (yellow modified, blue reordered, green added, red removed), in the map-review artifact."
                  if byond else "Run with --byond for pictures and lint."]
    text = "\n".join(lines) + "\n"
    (out / "summary.md").write_text(text, encoding="utf-8")
    return text, broken


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--base", required=True, help="base revision (merge base is used)")
    parser.add_argument("--head", default="HEAD")
    parser.add_argument("--devtools", default=os.environ.get("BYOND_DEVTOOLS", ""), help="byond-devtools checkout (default $BYOND_DEVTOOLS)")
    parser.add_argument("--byond", default=os.environ.get("BYOND_BIN", ""), help="BYOND bin folder for the type tree (pictures and lint)")
    parser.add_argument("--dme", default="civ13.dme")
    parser.add_argument("--out", type=Path, default=Path("map-review"))
    parser.add_argument("--summary", help="also append the summary to this file")
    args = parser.parse_args(argv)
    if not args.devtools:
        parser.error("--devtools or BYOND_DEVTOOLS is required")
    text, broken = review(args.base, args.head, args.devtools, args.out, byond=args.byond or None, dme=args.dme)
    print(text)
    if args.summary:
        with open(args.summary, "a", encoding="utf-8") as handle:
            handle.write(text)
    return 1 if broken else 0


if __name__ == "__main__":
    sys.exit(main())
