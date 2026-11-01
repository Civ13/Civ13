"""Inspect native PNG exports without generating or modifying any image."""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image


def verify(folder):
    """Require all runtime assertions and every stone/clay empty/full pair."""
    data = json.loads((folder / "stone-casting-checks.json").read_text())
    assert data["cases"] and all(row["passed"] for row in data["cases"])
    shapes = {"ingot", "axehead", "sword", "knife", "spearhead", "pickaxe", "shovel", "arrowhead"}
    records = {(r["shape"], r["surface"], r["state"]): r for r in data["sprites"]}
    assert len(records) == len(data["sprites"]) == 32
    results = []
    for shape in sorted(shapes):
        for state in ("empty", "full"):
            stone = records[shape, "stone", state]
            clay = records[shape, "clay", state]
            expected_capacity = 1 if state == "full" else 0
            assert stone["capacity"] == clay["capacity"] == expected_capacity
            assert stone["material"] == clay["material"] == ("copper" if state == "full" else None)
            assert stone["icon_state"] == clay["icon_state"]
            assert stone["icon_state"].endswith("_" + state)
            matrix = stone["color"]
            assert len(matrix) == 20 and clay["color"] is None
            stone_path, clay_path = folder / stone["file"], folder / clay["file"]
            with Image.open(stone_path) as s, Image.open(clay_path) as c:
                assert s.size == c.size == (32, 32)
                sp, cp = list(s.convert("RGBA").getdata()), list(c.convert("RGBA").getdata())
            assert any(p[3] for p in sp)
            assert [p[3] for p in sp] == [p[3] for p in cp]
            assert sp != cp, "Stone tint was omitted"
            for observed, original in zip(sp, cp):
                if not original[3]:
                    continue
                for channel in range(4):
                    expected = max(0, min(255, sum(original[i] * matrix[4*i+channel] for i in range(4)) + 255*matrix[16+channel]))
                    assert abs(observed[channel] - expected) <= 1.01, (shape, state, observed, original)
            results.append({"shape": shape, "state": state, "stone_sha256": hashlib.sha256(stone_path.read_bytes()).hexdigest(), "clay_sha256": hashlib.sha256(clay_path.read_bytes()).hexdigest(), "native_pixels_match_runtime_matrix": True})
        assert records[shape, "stone", "empty"]["icon_state"] != records[shape, "stone", "full"]["icon_state"]
    return {"status": "passed", "runtime_cases": len(data["cases"]), "native_pngs": 32, "pairs": results, "limits": data["limits"]}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("folder", type=Path)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    if args.report.exists():
        parser.error("Preserve existing render verification reports")
    report = verify(args.folder)
    args.report.write_text(json.dumps(report, indent=2) + "\n")
    print(f"PASS: {report['runtime_cases']} native assertions; 32 actual engine PNGs, 16 tint/control pairs")
