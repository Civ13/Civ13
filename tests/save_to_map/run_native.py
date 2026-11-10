"""Native save-to-map check: synthetic saves in level formats 3, 4 and 5 go
through tools/save_to_map/export.py, including the full-game compile check.

    python3 tests/save_to_map/run_native.py --byond-bin <BYOND bin> [--no-compile]

Needs the pinned BYOND (DreamMaker, DreamDaemon) and a host C compiler for the
stream helper. Only synthetic data is written; no game world is started.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "save_to_map"))
sys.path.insert(0, str(ROOT / "tests" / "savestream"))
import export  # noqa: E402
from helper_client import Helper, Path_, build_helper, record  # noqa: E402

GENERATION = "round-v2:synthetic0123456789abcdef"
SECRETS = ("Secret", "Player Name", "privateckey", "zone-house", GENERATION)


def round_state():
    return {
        "version": 2, "generation": GENERATION, "map": "SYNTHETIC", "maxx": 4, "maxy": 3, "maxz": 2,
        "game_id": "private-game", "elevation": {"version": 1, "maxx": 4, "maxy": 3, "maxz": 2, "default_metres": 120,
                                                 "regions": [{"x1": 1, "x2": 2, "y1": 1, "y2": 3, "z": 1, "metres": 135}]},
        "world_state": {
            "map_type": "/obj/map_metadata/nomads", "accounts": {"private": "never exported"},
            "topology": {
                "schema": 2, "allocator": {"namespace": GENERATION, "next": 4},
                "zones": [{"id": "zone-outside", "type": "/area/caribbean/nomads/forest", "fields": {"name": "Private"}},
                          {"id": "zone-house", "type": "/area/caribbean/roofed", "fields": {}},
                          {"id": "zone-sky", "type": "/area/caribbean/nomads", "fields": {}}],
                "spawns": {"latejoin": {"JoinLateCiv": [{"x": 3, "y": 1, "z": 1, "zone": "zone-outside"}],
                                        "Bad\"Name": [{"x": 1, "y": 2, "z": 1, "zone": "zone-outside"}]},
                           "start": [{"x": 1, "y": 3, "z": 1, "zone": "zone-outside"}],
                           "join": [], "paradrop": [], "supply": []},
            },
        },
    }


def write_stream(helper_exe, folder, z):
    rows = json.loads((folder / f"{z}.stream.json").read_text(encoding="utf-8"))
    (folder / f"{z}.stream.json").unlink()
    batch = record("/generation", GENERATION)
    for row in rows:
        base = f"/entries/{(row['ref'] - 1) // 512}/{row['ref']}"
        batch += record(base + "/type", Path_(row["type"]))
        fields = row["fields"] if isinstance(row["fields"], dict) else {}
        for name, value in fields.items():
            if isinstance(value, dict):
                value = {"kind": value["kind"], "value": value["value"]}
            batch += record(base + "/" + name, value)
        if row["contents"]:
            batch += record(base + "/content", [row["contents"]])
    helper = Helper(helper_exe, "write", folder / f"{z}.stream.sav")
    assert helper.request("W", batch) == b"OK"
    summary = json.loads(helper.request("F", ""))
    helper.close()
    assert summary["published"], summary


def make_generation(byond_bin, maker, helper_exe, folder, fmt):
    folder.mkdir()
    for name in ("make_save.dmb", "make_save.rsc"):
        if (maker / name).exists():
            shutil.copyfile(maker / name, folder / name)
    subprocess.run([str(byond_bin / "DreamDaemon"), "make_save.dmb", "0", "-ip", "127.0.0.1", "-trusted",
                    "-invisible", "-nowebclient", "-close", "-params", f"format={fmt}&generation={GENERATION}"],
                   cwd=folder, capture_output=True, timeout=120, check=False)
    for name in ("make_save.dmb", "make_save.rsc"):
        (folder / name).unlink(missing_ok=True)
    if fmt == 5:
        for z in (1, 2):
            write_stream(helper_exe, folder, z)
    (folder / "round.json").write_text(json.dumps(round_state()), encoding="utf-8")
    (folder / "map.txt").write_text("SYNTHETIC\n5000 B.C.\n", encoding="utf-8")
    (folder / "save_complete.txt").write_text(GENERATION, encoding="utf-8")


def check_package(package, fmt, compiled):
    report = json.loads((package / "report.json").read_text())
    assert report["status"] == "complete", report
    counters = report["counters"]
    expect = {"retained_cells": 24, "sparse_baseline_cells": 10, "retained_objects": 4, "excluded_objects": 2,
              "excluded_entity_roots": 1, "excluded_content_roots": 1, "spawn_markers": 2}
    for key, value in expect.items():
        assert counters.get(key) == value, (fmt, key, counters)
    dmm = (package / "map" / "synthetic.dmm").read_text()
    assert "/obj/structure/bed/chair{dir = 4; pixel_x = 6}" in dmm, dmm
    assert "/obj/covers/wood{dir = 8}" in dmm
    assert "/obj/structure/closet," in dmm, "closet dir 99 resets"
    assert '/obj/effect/landmark{name = "JoinLateCiv"}' in dmm and '/obj/effect/landmark{name = "start"}' in dmm
    assert "Bad" not in dmm, "unsafe spawn names stay out"
    assert "/obj/roof/wood,/turf/floor/wood,/area/caribbean/roofed" in dmm
    assert "/turf/sky/building,/area/caribbean/nomads)" in dmm
    assert "/obj/map_metadata/export_synthetic," in dmm
    assert "/mob/" not in dmm and "/obj/item" not in dmm and "vehicleparts" not in dmm
    metadata = (package / "metadata" / "export_synthetic.dm").read_text()
    assert 'ID = "EXPORT_SYNTHETIC"' in metadata and "override_mapgen = 1" in metadata
    assert "elevation_default_metres = 120" in metadata and '"metres" = 135' in metadata
    for path in package.rglob("*"):
        if path.is_file():
            text = path.read_text(encoding="utf-8", errors="replace")
            for secret in SECRETS:
                assert secret not in text, (path, secret)
    if compiled:
        result = json.loads((package / "compile.json").read_text())
        assert result["passed"], result
        assert report["compile_status"] == "passed"
    return dmm


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--byond-bin", type=Path, required=True)
    parser.add_argument("--no-compile", action="store_true")
    args = parser.parse_args()
    byond_bin = args.byond_bin.resolve()
    with tempfile.TemporaryDirectory(prefix="save-to-map-native-") as tmp:
        tmp = Path(tmp)
        maker = tmp / "maker"
        maker.mkdir()
        shutil.copyfile(Path(__file__).parent / "native" / "make_save.dm", maker / "make_save.dm")
        (maker / "make_save.dme").write_text('#include "make_save.dm"\n')
        build = subprocess.run([str(byond_bin / "DreamMaker"), "-max_errors", "0", "make_save.dme"],
                               cwd=maker, capture_output=True, text=True)
        assert build.returncode == 0 and "0 errors, 0 warnings" in build.stdout, build.stdout
        helper_exe = build_helper(tmp)
        rendered = {}
        for fmt in (3, 4, 5):
            folder = tmp / f"saves{fmt}"
            make_generation(byond_bin, maker, helper_exe, folder, fmt)
            before = {p.name: p.read_bytes() for p in folder.iterdir()}
            package = tmp / f"export{fmt}"
            compiled = not args.no_compile and fmt == 3
            code = export.main(["--save-dir", str(folder), "--export-id", "synthetic", "--title", "Synthetic [export]",
                                "--output", str(package), "--byond-bin", str(byond_bin)] + (["--compile"] if compiled else []))
            assert code == 0, (fmt, (package / "report.json").read_text() if (package / "report.json").exists() else None)
            assert before == {p.name: p.read_bytes() for p in folder.iterdir()}, "original save bytes changed"
            rendered[fmt] = check_package(package, fmt, compiled)
            print(f"PASS format {fmt}" + (" (+ full-game compile and missing-type control)" if compiled else ""))
        assert rendered[3] == rendered[4] == rendered[5], "formats must export identical maps"
        # Strict mode rejects a save without topology instead of guessing areas.
        folder = tmp / "saves3"
        state = round_state()
        del state["world_state"]["topology"]
        (folder / "round.json").write_text(json.dumps(state))
        code = export.main(["--save-dir", str(folder), "--export-id", "synthetic", "--title", "x",
                            "--output", str(tmp / "rejected"), "--byond-bin", str(byond_bin)])
        assert code == 2, code
        print("PASS missing topology rejected")
    print("PASS native save-to-map export; gameplay of the exported map UNRUN")


if __name__ == "__main__":
    main()
