"""Hill, current and flood files for a generated land.

A hand-made map gets these from scripts/terrain_heights.py (hills),
scripts/river_flow.py (currents) and scripts/river_flood.py (flood reaches),
and the game reads them when the map names a terrain_height_file
(docs/terrain-height.md, docs/river-flood.md). A generated land has no author
to run them, so its land folder gets all three, made from the land's own
relief with the same builders the hand-made maps use for currents and floods.

Hill levels follow the land's height above its sea. The game keeps water
flat, so every sea, lake, river and swamp tile is level 0 and the ground
climbs out of it a level a tile: a river high in the hills runs in a valley.
No two neighbouring tiles differ by more than two levels. Standard library only.
"""
import heapq
import re
import sys
from pathlib import Path

HEIGHTS_FILE = "land.heights.txt"
FLOW_FILE = "land.flow.txt"
FLOOD_FILE = "land.flood.txt"
# Metres of relief to one hill level.
METRES_PER_LEVEL = 70
# Half levels: dry ground is never level with the water, and stays under the summit.
MIN_LAND = 1
SUMMIT = 30
MAX_NEIGHBOUR_STEP = 4
# A bank climbs this much a tile for its first BANK_REACH tiles from the water.
BANK_STEP = 2
BANK_REACH = 6
_TURF = re.compile(r"/turf/[\w/]+")
_SCRIPTS = Path(__file__).resolve().parents[2] / "scripts"


def _scripts():
    """The sidecar builders of the hand-made maps (standard library at import)."""
    if str(_SCRIPTS) not in sys.path:
        sys.path.insert(0, str(_SCRIPTS))
    import river_flood
    import river_flow
    import terrain_heights
    return terrain_heights, river_flow, river_flood


def land_levels(doc):
    """Half levels (0-63) per surface tile, as rows from the south row up."""
    w, h = doc["width"], doc["height"]
    cells = doc["layers"][doc["active_layer"]]["cells"]
    n = w * h
    metres = [0] * n
    wet = bytearray(n)
    for y, row in enumerate(cells):
        base = y * w
        for x, c in enumerate(row):
            metres[base + x] = c["elevation_m"]
            if c["terrain"] == "WATER":
                wet[base + x] = 1
    low = min(metres[i] for i in range(n) if wet[i]) if any(wet) else min(metres)
    level = [0] * n
    for i in range(n):
        if not wet[i]:
            rise = (metres[i] - low) * 2 // METRES_PER_LEVEL
            level[i] = MIN_LAND if rise < MIN_LAND else SUMMIT if rise > SUMMIT else rise
    # Lowest tiles first, each caps its neighbours: a bank climbs BANK_STEP a
    # tile out of the water, so a river high in the hills runs in a valley, and
    # no other step is steeper than MAX_NEIGHBOUR_STEP.
    heap = [(level[i], i) for i in range(n)]
    heapq.heapify(heap)
    reach = [0 if wet[i] else -1 for i in range(n)]
    while heap:
        v, i = heapq.heappop(heap)
        if v != level[i]:
            continue
        x = i % w
        banked = reach[i] >= 0 and reach[i] < BANK_REACH
        cap = v + (BANK_STEP if banked else MAX_NEIGHBOUR_STEP)
        for q in (i - w, i + w, i - 1 if x else -1, i + 1 if x < w - 1 else -1):
            if 0 <= q < n and level[q] > cap:
                level[q] = cap
                reach[q] = reach[i] + 1 if banked else -1
                heapq.heappush(heap, (cap, q))
    return [level[y * w:(y + 1) * w] for y in range(h)]


def turf_rows(doc, layout, z=None):
    """The surface's turf paths, north row first, as the sidecar builders read a
    map. z is the layout's level holding the surface (the document's own by default)."""
    w, h = doc["width"], doc["height"]
    if z is None:
        z = doc["layers"][doc["active_layer"]]["native_z"]
    turf_of = {}
    rows = []
    for y in range(h, 0, -1):
        row = []
        for x in range(1, w + 1):
            atoms = layout[(x, y, z)]
            turf = turf_of.get(atoms)
            if turf is None:
                found = _TURF.search(atoms)
                turf = turf_of[atoms] = found.group(0) if found else ""
            row.append(turf)
        rows.append(row)
    return rows


def write_terrain_files(folder, doc, layout, z=None):
    """Writes the three files into folder and returns what they hold. z is the
    map level of the surface in layout and in the files (the document's own by default)."""
    terrain_heights, river_flow, river_flood = _scripts()
    w, h = doc["width"], doc["height"]
    if z is None:
        z = doc["layers"][doc["active_layer"]]["native_z"]
    folder = Path(folder)
    levels = [[v / 2 for v in row] for row in reversed(land_levels(doc))]
    rows = turf_rows(doc, layout, z)
    terrain_heights.write_heights(folder / HEIGHTS_FILE, w, h, {z: levels})
    flow = river_flow.build(rows, heights=levels)
    (folder / FLOW_FILE).write_text("%s\nsize %d %d\nz %d\n%s\n" % (river_flow.HEADER, w, h, z, "\n".join(flow)),
                                    encoding="ascii", newline="\n")
    # Whatever the flood builder returns is what its writer takes: reaches, labels
    # and thresholds, then the hollows rain pools in (flood file version 2).
    built = river_flood.build(rows, levels)
    river_flood.write_flood(folder / FLOOD_FILE, w, h, z, *built)
    reaches, thresholds = built[0], built[2]
    return {"z": z, "highest_level": max(max(row) for row in levels),
            "flowing_tiles": sum(c != "." for row in flow for c in row), "flood_reaches": len(reaches),
            "flood_tiles": sum(v is not None for row in thresholds for v in row),
            "hollows": len(built[3]) if len(built) > 3 else 0}
