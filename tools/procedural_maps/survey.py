"""Coarse survey map of a barren world for the space probe console.

The mission console (code/modules/space/survey.dm) shows players a coarse map
of the barren world instead of a real game level, so a probe costs no world
memory. This module downsamples a verified SURFACE bundle into that map: each
survey cell covers CELL_TILES x CELL_TILES tiles and takes the most common
class among them. Ties go to the more hazardous class, so a ridge or ice sheet
is never hidden by plains around it. Nothing here launches the game.

Rows run south to north (row 0 is the bundle's y = 0), matching the IR.
"""
import hashlib
import json
from pathlib import Path

from .bundle import verify_bundle
from .io import read_json

SCHEMA = "civ13-survey-map/1"
CELL_TILES = 5
# One character per class; the console reads the same table.
PLAIN, CHANNEL, ICE, RIDGE = ".", "~", "*", "^"
# Tie order: the earlier class wins a tie.
TIE_ORDER = (RIDGE, ICE, CHANNEL, PLAIN)


def classify(c):
    if c["water"] in {"LAKE", "SEA"}:
        return ICE
    if c["water"] in {"RIVER", "SWAMP"}:
        return CHANNEL
    if c["terrain"] in {"MOUNTAIN", "ROCK"}:
        return RIDGE
    return PLAIN


def survey_rows(doc, cell_tiles=CELL_TILES):
    if doc["profile"] != "SURFACE":
        raise ValueError("SURVEY_PROFILE: survey maps come from SURFACE bundles")
    if type(cell_tiles) is not int or not 1 <= cell_tiles <= 16:
        raise ValueError("SURVEY_CELL_TILES: 1..16")
    cells = doc["layers"]["SURFACE"]["cells"]
    width = doc["width"] // cell_tiles
    height = doc["height"] // cell_tiles
    if width < 8 or height < 8 or width > 64 or height > 64:
        raise ValueError("SURVEY_SIZE: the survey map must be 8..64 cells a side")
    rows = []
    for sy in range(height):
        row = []
        for sx in range(width):
            counts = {k: 0 for k in TIE_ORDER}
            for y in range(sy * cell_tiles, (sy + 1) * cell_tiles):
                for x in range(sx * cell_tiles, (sx + 1) * cell_tiles):
                    counts[classify(cells[y][x])] += 1
            row.append(max(TIE_ORDER, key=lambda k: (counts[k], -TIE_ORDER.index(k))))
        rows.append("".join(row))
    return rows


def build(folder, catalog_root=None, cell_tiles=CELL_TILES):
    folder = Path(folder)
    verify_bundle(folder, catalog_root)
    doc = read_json(folder / "map.ir.json")
    rows = survey_rows(doc, cell_tiles)
    if not any(PLAIN in r for r in rows):
        raise ValueError("SURVEY_NO_PLAINS: a probe needs somewhere to land")
    manifest = read_json(folder / "seed.manifest.json")
    return {
        "schema": SCHEMA,
        "seed": doc["seed"],
        "source_width": doc["width"],
        "source_height": doc["height"],
        "ir_sha256": manifest["generation_result"]["ir_sha256"],
        "cell_tiles": cell_tiles,
        "width": len(rows[0]),
        "height": len(rows),
        "legend": {PLAIN: "plain", CHANNEL: "channel", ICE: "ice", RIDGE: "ridge"},
        "rows": rows,
    }


def write(folder, out, catalog_root=None, cell_tiles=CELL_TILES):
    out = Path(out)
    if out.suffix.lower() != ".json":
        raise ValueError("survey output must end in .json")
    if out.exists():
        raise ValueError("output exists: " + str(out))
    data = build(folder, catalog_root, cell_tiles)
    text = json.dumps(data, indent=1, sort_keys=True) + "\n"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(text, encoding="utf-8", newline="\n")
    return {"schema": SCHEMA, "path": str(out), "width": data["width"], "height": data["height"],
            "sha256": hashlib.sha256(text.encode()).hexdigest()}
