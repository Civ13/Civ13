"""Check zombie city probe evidence and render previews.

Reads the runs.json that native_probe.py wrote plus each run's layout.json and
grid.txt, then verifies, independently of the in-game check:

- determinism: runs of the same seed produced identical grids and manifests,
  runs of different seeds did not;
- reachability: every insertion point, evacuation point, door, staircase and
  loot spot is reachable from every insertion point over passable grid cells,
  and on the upper level every door and loot spot is reachable from a
  staircase;
- counts: insertion, evacuation, block, building, room and loot numbers are
  within the plan's ranges and the four special lots exist;
- rooms: every room is at least three cells each way (halls and corridors two)
  inside its building, and every building's loot spots lie inside one of its
  rooms;
- spacing: insertion points at least 60 tiles apart (Chebyshev) and no
  evacuation point within 40 tiles of an insertion point;
- cost: generation under 30 s and no runtime error in code/modules/zombie_city.

A PNG preview of each seed goes under <evidence>/previews. The grid functions
are importable so the offline suite can test them on small fixtures.

    python3 -I -B tests/zombie_city/check.py /evidence/dir
"""
from __future__ import annotations

from collections import deque
import json
from pathlib import Path
import sys

BLOCKED = set("#WwX")
REQUIRED = set("EVDLS")
UPPER_REQUIRED = set("DL")
ENTRY_SPACING = 60
EXIT_SPACING = 40
MAX_GENERATION_DS = 300
COUNT_RANGES = {"entries": (4, 6), "exits": (3, 4), "blocks": (20, 400), "buildings": (40, 2000), "loot": (80, 8000), "rooms": (40, 8000)}
MIN_ROOM = 3
MIN_HALL = 2
POIS = ("hospital", "police", "hardware", "garage")
COLORS = {
    "#": (30, 30, 30), "=": (70, 70, 75), "-": (200, 180, 40), ".": (150, 150, 150), ",": (80, 140, 60),
    "_": (110, 110, 115), " ": (120, 100, 70), "f": (200, 190, 160), "W": (60, 45, 40), "w": (120, 180, 220),
    "D": (170, 110, 50), "L": (230, 60, 200), "E": (40, 220, 60), "V": (40, 120, 255), "x": (90, 80, 70),
    "X": (150, 40, 40), "o": (70, 110, 140), "~": (20, 20, 28), "S": (255, 200, 60),
}


def parse_grid(text: str) -> list[str]:
    rows = [row for row in text.split("\n") if row]
    if not rows or any(len(row) != len(rows[0]) for row in rows):
        raise ValueError("grid rows are empty or ragged")
    return rows


def reachability(rows: list[str], start: str = "E", required_chars: set[str] = REQUIRED, together: bool = False) -> dict:
    """BFS from each start cell (or from all of them at once when together);
    returns the unreachable required cells."""
    height = len(rows)
    width = len(rows[0])
    entries = [(x, y) for y in range(height) for x in range(width) if rows[y][x] == start]
    required = [(x, y) for y in range(height) for x in range(width) if rows[y][x] in required_chars]
    unreachable = {}
    for group in ([entries] if together else [[entry] for entry in entries]):
        if not group:
            continue
        start = group[0]
        seen = [[False] * width for _ in range(height)]
        queue = deque(group)
        for cell in group:
            seen[cell[1]][cell[0]] = True
        while queue:
            x, y = queue.popleft()
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if 0 <= nx < width and 0 <= ny < height and not seen[ny][nx] and rows[ny][nx] not in BLOCKED:
                    seen[ny][nx] = True
                    queue.append((nx, ny))
        missing = [cell for cell in required if not seen[cell[1]][cell[0]]]
        if missing:
            label = "all stairs" if together else f"entry at column {start[0] + 1} row {height - start[1]}"
            unreachable[label] = [f"column {x + 1} row {height - y}" for x, y in missing[:8]] if together else len(missing)
    return {"entries": len(entries), "required": len(required), "unreachable": unreachable}


def upper_reachability(rows: list[str], upper_rows: list[str]) -> dict:
    """Upper doors and loot must be reachable from the stairs, which sit at the
    same x, y on both levels."""
    if len(upper_rows) != len(rows) or any(len(a) != len(b) for a, b in zip(rows, upper_rows)):
        raise ValueError("upper grid does not match the ground grid")
    marked = []
    for row, upper in zip(rows, upper_rows):
        marked.append("".join("S" if c == "S" else u for c, u in zip(row, upper)))
    return reachability(marked, "S", UPPER_REQUIRED, together=True)


def spacing(manifest: dict) -> list[str]:
    problems = []
    entries = [(e["x"], e["y"]) for e in manifest["entries"]]
    exits = [(e["x"], e["y"]) for e in manifest["exits"]]
    for i, a in enumerate(entries):
        for b in entries[i + 1:]:
            if max(abs(a[0] - b[0]), abs(a[1] - b[1])) < ENTRY_SPACING:
                problems.append(f"insertion points {a} and {b} closer than {ENTRY_SPACING}")
        for b in exits:
            if max(abs(a[0] - b[0]), abs(a[1] - b[1])) < EXIT_SPACING:
                problems.append(f"evacuation point {b} within {EXIT_SPACING} of insertion point {a}")
    return problems


def counts(manifest: dict) -> list[str]:
    problems = []
    found = {"entries": len(manifest["entries"]), "exits": len(manifest["exits"]), "blocks": len(manifest["blocks"]),
             "buildings": len(manifest["buildings"]), "loot": sum(len(b["loot"]) for b in manifest["buildings"]),
             "rooms": sum(len(b.get("rooms", [])) for b in manifest["buildings"])}
    for key, (low, high) in COUNT_RANGES.items():
        if not low <= found[key] <= high:
            problems.append(f"{key}: {found[key]} outside {low}..{high}")
    for poi in POIS:
        if poi not in manifest.get("pois", {}):
            problems.append(f"missing special lot {poi}")
    if sum(1 for e in manifest["exits"] if e.get("checkpoint")) != 1:
        problems.append("exactly one evacuation point must be the checkpoint")
    return problems


def rooms(manifest: dict) -> list[str]:
    """Rooms fit inside their building with room to stand, and loot sits in a room."""
    problems = []
    for building in manifest["buildings"]:
        inside = []
        for room in building.get("rooms", []):
            least = MIN_HALL if room["kind"] == "hall" else MIN_ROOM
            if room["x2"] - room["x1"] + 1 < least or room["y2"] - room["y1"] + 1 < least:
                problems.append(f"building {building['id']}: {room['kind']} room smaller than {least}")
            if not (building["x1"] < room["x1"] <= room["x2"] < building["x2"] and building["y1"] < room["y1"] <= room["y2"] < building["y2"]):
                problems.append(f"building {building['id']}: {room['kind']} room outside the walls")
            inside.append(room)
        for loot in building["loot"]:
            if not any(r["x1"] <= loot["x"] <= r["x2"] and r["y1"] <= loot["y"] <= r["y2"] for r in inside):
                problems.append(f"building {building['id']}: loot at ({loot['x']}, {loot['y']}) is not in a room")
    return problems


def stable_manifest(manifest: dict) -> str:
    copy = dict(manifest)
    for key in ("generation_ds", "ascii", "counts"):
        copy.pop(key, None)
    return json.dumps(copy, sort_keys=True)


def render(rows: list[str], path: Path, scale: int = 3) -> bool:
    try:
        from PIL import Image
    except ImportError:
        return False
    width = len(rows[0])
    height = len(rows)
    image = Image.new("RGB", (width * scale, height * scale), COLORS["#"])
    pixels = image.load()
    for y, row in enumerate(rows):
        for x, char in enumerate(row):
            color = COLORS.get(char, (255, 0, 255))
            for dy in range(scale):
                for dx in range(scale):
                    pixels[x * scale + dx, y * scale + dy] = color
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)
    return True


def check(evidence: Path) -> dict:
    runs = json.loads((evidence / "runs.json").read_text())
    problems = []
    per_seed = {}
    details = []
    for run in runs:
        run_dir = Path(run["run_dir"])
        seed = run["seed"]
        if not run.get("passed"):
            problems.append(f"seed {seed}: probe failed: {run.get('failure')}")
            continue
        mode_errors = {k: v for k, v in run.get("runtime_errors", {}).items() if "zombie_city" in k}
        if mode_errors:
            problems.append(f"seed {seed}: runtime errors in zombie city code: {mode_errors}")
        if run.get("generation_ds", 0) > MAX_GENERATION_DS:
            problems.append(f"seed {seed}: generation took {run['generation_ds'] / 10:.1f} s, over {MAX_GENERATION_DS / 10:.0f} s")
        manifest = json.loads((run_dir / "layout.json").read_text())
        rows = parse_grid((run_dir / "grid.txt").read_text())
        reach = reachability(rows)
        if reach["unreachable"]:
            problems.append(f"seed {seed}: unreachable required cells {reach['unreachable']}")
        upper_path = run_dir / "grid2.txt"
        upper_rows = parse_grid(upper_path.read_text()) if upper_path.exists() else []
        if upper_rows:
            upper = upper_reachability(rows, upper_rows)
            if upper["unreachable"]:
                problems.append(f"seed {seed}: unreachable upper cells {upper['unreachable']}")
            if not upper["entries"]:
                problems.append(f"seed {seed}: an upper level without stairs")
            render(upper_rows, evidence / "previews" / f"seed{seed}-upper.png")
        for problem in spacing(manifest) + counts(manifest) + rooms(manifest):
            problems.append(f"seed {seed}: {problem}")
        signature = (stable_manifest(manifest), "\n".join(rows) + "\n".join(upper_rows))
        if seed in per_seed and per_seed[seed] != signature:
            problems.append(f"seed {seed}: two runs produced different cities")
        per_seed.setdefault(seed, signature)
        rendered = render(rows, evidence / "previews" / f"seed{seed}.png")
        details.append({"seed": seed, "attempt": manifest.get("attempt"), "generation_s": run.get("generation_ds", 0) / 10,
                        "counts": manifest.get("counts"), "reachable_from_entries": reach["entries"], "required_cells": reach["required"],
                        "other_runtime_error_sites": len(run.get("runtime_errors", {})) - len(mode_errors), "preview": rendered})
    seeds = list(per_seed)
    for i, a in enumerate(seeds):
        for b in seeds[i + 1:]:
            if per_seed[a][1] == per_seed[b][1]:
                problems.append(f"seeds {a} and {b} produced the same grid")
    repeated = [seed for seed in set(run["seed"] for run in runs) if sum(1 for run in runs if run["seed"] == seed) > 1]
    if not repeated:
        problems.append("no seed was run twice, so determinism was not checked")
    summary = {"passed": not problems, "problems": problems, "runs": details, "determinism_seeds": repeated}
    (evidence / "summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    return summary


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    summary = check(Path(sys.argv[1]).resolve())
    print(json.dumps(summary, indent=2))
    return 0 if summary["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
