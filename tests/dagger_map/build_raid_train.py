"""Original, inactive Dagger raid target train. No runtime transport or loot hooks.

The Dagger home draft (build_map.py) leaves its two raid berths empty and
states that the target train and its breachable compartment doors are not
built by that map. This study builds that target: one long "Hauler" freight
train beside a shared platform, with sections ordered from the cheap rear to
the valuable front, every compartment door breachable, and two Dagger berths
whose boarding bridges reach the platform. It is a geometry handoff for the
mechanics owner: no fuel, boarding pass, loot table, timer or controller is
chosen here, and nothing is selectable.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_map as home  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
MAP_PATH = ROOT / "maps/WIP/dagger_raid_train.dmm"
LAYOUT_PATH = ROOT / "maps/WIP/dagger_raid_train.layout.json"
SIZE = 256
WORLD_LEVELS = 4
TRAIN_WIDTH, TRAIN_LENGTH = 24, 200
TRAIN_ORIGIN = (113, 29, 1)
PLATFORMS = {"west": [105, 21, 112, 236], "east": [137, 21, 144, 236]}
HEADS = {"south": [105, 21, 144, 28], "north": [105, 229, 144, 236]}
BERTHS = {"west": {"origin": [69, 78, 1], "platform_side": "east", "bridge_x": [99, 104]},
          "east": {"origin": [151, 78, 1], "platform_side": "west", "bridge_x": [145, 150]}}
COUPLING_ROWS = (12, 53, 94, 135, 166)
BREACH_X = (11, 12)
SECTIONS = [
    {"id": "brake_van", "name": "Rear brake van", "tier": 1, "bounds": [0, 0, 23, 11],
     "side_openings": [[2, 3]], "opening_kind": "gap"},
    {"id": "flatcars", "name": "Open flatcars", "tier": 1, "bounds": [0, 13, 23, 52],
     "side_openings": [[20, 22], [34, 36], [44, 46]], "opening_kind": "gap"},
    {"id": "boxcars", "name": "Freight boxcars", "tier": 2, "bounds": [0, 54, 23, 93],
     "side_openings": [[62, 64], [82, 84]], "opening_kind": "door"},
    {"id": "coaches", "name": "Crew coaches", "tier": 3, "bounds": [0, 95, 23, 134],
     "side_openings": [[97, 98], [131, 132]], "opening_kind": "door"},
    {"id": "vault", "name": "Armoured vault car", "tier": 4, "bounds": [0, 136, 23, 165],
     "side_openings": [], "opening_kind": None},
    {"id": "locomotive", "name": "Tender and locomotive", "tier": 5, "bounds": [0, 167, 23, 199],
     "side_openings": [[190, 191]], "opening_kind": "door"},
]

PALETTE = {
    "void": ("/turf/wall/iron", "#171f27", False),
    "hull": ("/turf/wall/iron", "#596975", False),
    "pillar": ('/turf/wall/iron{name = "Hauler support pillar - draft only"}', "#9babb7", False),
    "cage": ('/turf/wall/iron{name = "Vault cage wall - draft only"}', "#8a97a3", False),
    "floor": ("/turf/floor/plating/steel", "#657b83", True),
    "deck": ('/turf/floor/plating/concrete{name = "Flatcar deck - draft only"}', "#6d7a80", True),
    "cabin": ("/turf/floor/wood", "#7a6a4f", True),
    "yard": ("/turf/floor/plating/concrete", "#535e63", True),
    "berth": ("/turf/floor/plating/dark", "#34444e", True),
    "platform": ('/turf/floor/plating/concrete{name = "Station platform - draft only"}', "#b5a16d", True),
    "bridge": ('/turf/floor/plating/concrete{name = "Boarding bridge - draft only"}', "#d6c58d", True),
    "door": ("/obj/structure/simple_door,/turf/floor/plating/steel", "#ceaa5a", True),
    "breach": ('/obj/structure/simple_door{name = "Compartment door - breachable without a pass, draft only"},/turf/floor/plating/steel', "#f0b85a", True),
    "locked_door": ('/obj/structure/simple_door{name = "Locked door - must never appear on the target train"; locked = 1},/turf/floor/plating/steel', "#ff6b6b", True),
    "engine_mount": ('/obj/structure/props/engineprops{name = "Hauler engine - draft only"},/turf/floor/plating/steel', "#e5c04c", False),
    "helm": ('/obj/structure/table{name = "Hauler controls - draft only"},/turf/floor/plating/steel', "#dcc8a0", False),
    "bed": ("/obj/structure/bed,/turf/floor/wood", "#9cc6bc", False),
    "crate": ("/obj/structure/closet/crate,/turf/floor/plating/steel", "#aa7954", False),
    "crate_deck": ('/obj/structure/closet/crate,/turf/floor/plating/concrete{name = "Flatcar deck - draft only"}', "#a07048", False),
    "rack": ("/obj/structure/table/rack,/turf/floor/plating/steel", "#9eacb8", False),
    "table": ("/obj/structure/table,/turf/floor/wood", "#c0ab8b", False),
    "chair": ("/obj/structure/bed/chair,/turf/floor/wood", "#b4a27c", False),
    "dirt": ("/obj/effect/decal/cleanable/dirt,/turf/floor/plating/steel", "#756d5c", True),
}
LOOT_KINDS = {"crate", "crate_deck", "rack"}


def cells(rect):
    x0, y0, x1, y1 = rect
    return {(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)}


def hauler():
    """Local train tiles, zero-based southwest, rear at y0 and front at y199."""
    tiles = {(x, y): "floor" for y in range(TRAIN_LENGTH) for x in range(TRAIN_WIDTH)}

    def fill(bounds, kind):
        for p in cells(bounds):
            tiles[p] = kind

    def row(x0, x1, y, kind):
        fill([x0, y, x1, y], kind)

    for x in range(TRAIN_WIDTH):
        tiles[x, 0] = tiles[x, TRAIN_LENGTH - 1] = "hull"
    for y in range(TRAIN_LENGTH):
        tiles[0, y] = tiles[TRAIN_WIDTH - 1, y] = "hull"
    for y in COUPLING_ROWS:
        row(0, TRAIN_WIDTH - 1, y, "hull")
        for x in BREACH_X:
            tiles[x, y] = "breach"
    for section in SECTIONS:
        kind = section["opening_kind"]
        for y0, y1 in section["side_openings"]:
            for y in range(y0, y1 + 1):
                tiles[0, y] = tiles[TRAIN_WIDTH - 1, y] = "floor" if kind == "gap" else "door"
    # Rear brake van: guard's desk and a few supply crates.
    row(3, 6, 9, "rack")
    for x in (17, 19, 21):
        tiles[x, 3] = "crate"
    tiles[20, 9] = "crate"
    # Open flatcars: concrete deck with strapped cargo stacks, walkable sides.
    fill([1, 13, 22, 52], "deck")
    for y0 in (15, 25, 39):
        for x0 in (4, 16):
            fill([x0, y0, x0 + 3, y0], "crate_deck")
            fill([x0, y0 + 2, x0 + 3, y0 + 2], "crate_deck")
    for x in (10, 13):
        for y in (17, 30, 41, 50):
            tiles[x, y] = "pillar"
    # Two boxcars: a central partition keeps each car's load separate.
    row(1, 22, 73, "hull")
    tiles[11, 73] = tiles[12, 73] = "breach"
    for y0 in (56, 76):
        for y in (y0, y0 + 4, y0 + 8, y0 + 12):
            row(2, 5, y, "crate")
            row(18, 21, y, "rack")
        tiles[9, y0 + 2] = tiles[14, y0 + 10] = "crate"
    # Crew coaches: compartments with bunks, a galley table and lockers.
    fill([1, 95, 22, 134], "cabin")
    for y in (101, 107, 113, 119, 125):
        row(1, 9, y, "hull")
        row(14, 22, y, "hull")
        tiles[9, y] = tiles[14, y] = "door"
    for y0 in (96, 102, 108, 114, 120):
        tiles[2, y0 + 1] = tiles[2, y0 + 3] = "bed"
        tiles[21, y0 + 1] = tiles[21, y0 + 3] = "bed"
        tiles[7, y0 + 2] = tiles[16, y0 + 2] = "rack"
        tiles[5, y0 + 1] = tiles[18, y0 + 1] = "crate"
    fill([3, 128, 7, 129], "table")
    for x in (3, 5, 7):
        tiles[x, 127] = tiles[x, 130] = "chair"
    for x in (16, 18, 20):
        tiles[x, 128] = "crate"
    tiles[18, 131] = "rack"
    # Armoured vault car: no side doors, an inner cage with its own breach door.
    fill([4, 139, 19, 162], "cage")
    fill([5, 140, 18, 161], "floor")
    tiles[11, 139] = tiles[12, 139] = "breach"
    for y in (142, 146, 150, 154, 158):
        row(6, 8, y, "rack")
        row(15, 17, y, "rack")
        tiles[11, y] = tiles[12, y] = "crate"
    for y in (137, 164):
        tiles[2, y] = tiles[21, y] = "crate"
    # Tender and locomotive: fuel stores behind the engine room and cab.
    for y in (169, 173, 177):
        row(2, 6, y, "crate")
        row(17, 21, y, "crate")
    row(1, 22, 181, "hull")
    tiles[11, 181] = tiles[12, 181] = "breach"
    for p in ((4, 185), (19, 185), (4, 194), (19, 194)):
        tiles[p] = "engine_mount"
    row(9, 14, 184, "rack")
    for y in (188, 192):
        row(2, 3, y, "rack")
        row(20, 21, y, "crate")
    row(9, 14, 197, "helm")
    tiles[11, 196] = tiles[12, 196] = "chair"
    for x in (6, 17):
        for y in (187, 191):
            tiles[x, y] = "pillar"
    for p in ((3, 6), (20, 48), (6, 70), (18, 90), (10, 129), (13, 150), (8, 178), (15, 192)):
        tiles[p] = "dirt"
    return tiles


def section_of(y):
    for section in SECTIONS:
        if section["bounds"][1] <= y <= section["bounds"][3]:
            return section["id"]
    return None


def manifest():
    tiles = hauler()
    ox, oy, oz = TRAIN_ORIGIN
    layout = {
        "schema_version": 1,
        "study_id": "dagger_raid_hauler_v1",
        "status": "map study only; runtime integration disabled",
        "home_template": {"template_id": home.manifest()["template_id"], "width": home.WIDTH, "height": home.LENGTH,
                          "decks": home.TRAIN_LEVELS, "boarding_bands": [list(b) for b in home.BOARDING_BANDS]},
        "coordinates": {"local": "zero-based southwest of the target train; +x east, +y north toward the front",
                        "world": "BYOND one-based", "transform": "world = origin + local", "rotation_degrees": 0},
        "world": {"width": SIZE, "height": SIZE, "levels": WORLD_LEVELS},
        "target_train": {"id": "hauler", "origin": list(TRAIN_ORIGIN), "width": TRAIN_WIDTH, "length": TRAIN_LENGTH,
                         "bounds": [ox, oy, ox + TRAIN_WIDTH - 1, oy + TRAIN_LENGTH - 1], "z": oz,
                         "front_direction": "north", "coupling_rows": list(COUPLING_ROWS), "breach_x": list(BREACH_X),
                         "doors_breachable_without_pass": True, "locked_doors_permitted": False,
                         "inherits_dagger_boundary_protection": False},
        "sections": [],
        "platforms": [{"id": f"platform_{side}", "z": oz, "bounds": bounds} for side, bounds in PLATFORMS.items()]
                     + [{"id": f"head_{side}", "z": oz, "bounds": bounds} for side, bounds in HEADS.items()],
        "slots": [],
        "raid_access": {
            "required_inputs": ["loaded_fuel", "target_section_boarding_pass"],
            "front_sections": {"loot": "better", "entry_cost": "higher"},
            "balance_values": None, "loot_tables": None, "pass_prices": None, "fuel_quantities": None,
            "extraction_timer": None, "travel_time": None,
            "target_compartment_doors": {"breachable_without_pass": True, "inherits_dagger_boundary_protection": False},
            "enforced_by_this_map": False},
        "runtime_contract_pending": [
            "loaded fuel and target-section pass gate raid travel; the pass gates the entry transaction only and never locks a target compartment",
            "every target compartment door remains breachable without a pass; target structure does not inherit Dagger boundary protection",
            "front sections carry better loot at higher entry cost; tables, prices, fuel quantities and timers are unspecified",
            "each party atomically reserves only its selected berth and its whole four-level footprint; the other berth stays available",
            "reservation, call, arrival, boarding and departure states revalidate party, train identity, section, resources and occupancy on the server",
            "loot anchors are furniture positions, not spawned contents; no loot population system exists for this map",
            "no scav, contractor or NPC population, arrival marker or exit is chosen by this draft"],
    }
    for section in SECTIONS:
        x0, y0, x1, y1 = section["bounds"]
        interior = [p for p in cells([x0 + 1, y0 + 1, x1 - 1, y1 - 1])]
        anchors = sorted(p for p in interior if tiles[p] in LOOT_KINDS)
        layout["sections"].append({
            "id": section["id"], "name": section["name"], "tier": section["tier"],
            "bounds": list(section["bounds"]), "world_bounds": [ox + x0, oy + y0, ox + x1, oy + y1],
            "platform_openings": [[ox, oy + y] for y0_, y1_ in section["side_openings"] for y in range(y0_, y1_ + 1)]
                                 + [[ox + TRAIN_WIDTH - 1, oy + y] for y0_, y1_ in section["side_openings"] for y in range(y0_, y1_ + 1)],
            "opening_kind": section["opening_kind"],
            "loot_anchors": [list(p) for p in anchors],
            "loot_anchor_count": len(anchors),
            "entry_cost": "higher toward the front; value unspecified", "loot_table": None})
    for side, berth in BERTHS.items():
        x, y, z = berth["origin"]
        bx0, bx1 = berth["bridge_x"]
        port_x = x + home.WIDTH - 1 if berth["platform_side"] == "east" else x
        ports = [[port_x, y + band_y] for b0, b1 in home.BOARDING_BANDS for band_y in range(b0, b1 + 1)]
        layout["slots"].append({
            "id": f"raid_{side}", "kind": "raid_berth", "origin": [x, y, z],
            "reserved_bounds": [x - 6, y - 6, x + home.WIDTH - 1 + 6, y + home.LENGTH - 1 + 6],
            "reserved_z": [z, z + home.TRAIN_LEVELS - 1], "local_z_levels": list(range(home.TRAIN_LEVELS)),
            "berth_mask_rows_south_to_north": ["1" * home.WIDTH] * home.LENGTH,
            "platform_side": berth["platform_side"], "boarding_width": 3, "platform_gap_tiles": bx1 - bx0 + 1,
            "boarding_ports": ports,
            "bridge_cells": [[bx, py, z] for _, py in ports for bx in range(bx0, bx1 + 1)]})
    layout["berth_geometry_groups"] = [{"id": "hauler_pair_v1", "slot_ids": ["raid_west", "raid_east"], "exclusive_reservation": False}]
    layout["reservation_policy"] = {"scope": "selected_berth_and_whole_footprint", "atomic_reservation_before_load_or_move": True,
                                    "all_levels_together": True, "other_berths_remain_available": True, "enforced_by_this_map": False}
    layout["structure"] = {
        "hull_tiles": [list(p) for p, kind in sorted(tiles.items()) if kind in ("hull", "pillar", "cage")],
        "breach_doors": [list(p) for p, kind in sorted(tiles.items()) if kind == "breach"],
        "side_doors": [list(p) for p, kind in sorted(tiles.items()) if kind == "door"],
        "locked_doors": [list(p) for p, kind in sorted(tiles.items()) if kind == "locked_door"],
        "protection": "ordinary target structure; damage, breach and deconstruction policy is mechanics-owned",
        "enforced_by_this_map": False}
    return layout


def build():
    layout = manifest()
    grid = {(x, y, z): ("void", "Outside draft") for z in range(1, WORLD_LEVELS + 1)
            for y in range(1, SIZE + 1) for x in range(1, SIZE + 1)}

    def fill(rect, z, kind, area):
        for x, y in cells(rect):
            grid[x, y, z] = kind, area

    fill([54, 12, 195, 245], 1, "yard", "Hauler raid station study")
    for entry in layout["platforms"]:
        fill(entry["bounds"], entry["z"], "platform", entry["id"])
    for slot in layout["slots"]:
        x, y, z = slot["origin"]
        for dz in slot["local_z_levels"]:
            fill([x, y, x + home.WIDTH - 1, y + home.LENGTH - 1], z + dz, "berth", slot["id"])
        for bx, by, bz in slot["bridge_cells"]:
            grid[bx, by, bz] = "bridge", slot["id"] + " bridge"
    for (dx, dy), kind in hauler().items():
        section = section_of(dy)
        area = f"Hauler {section} study" if section else "Hauler coupling study"
        ox, oy, oz = TRAIN_ORIGIN
        grid[ox + dx, oy + dy, oz] = kind, area
    for x, y in ((58, 16), (190, 16), (58, 240), (190, 240)):
        for dx, dy in ((0, 0), (1, 0), (0, 1)):
            grid[x + dx, y + dy, 1] = "crate", "Hauler raid station study"
    return grid, layout


def render_dmm(grid):
    entries = sorted(set(grid.values()))
    alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    keys = {entry: alphabet[i // len(alphabet)] + alphabet[i % len(alphabet)] for i, entry in enumerate(entries)}
    lines = ["// Generated by tests/dagger_map/build_raid_train.py. Inactive map study."]
    for (kind, area), key in keys.items():
        lines.append(f'"{key}" = ({PALETTE[kind][0]},/area{{name = "{area}"; location = 0}})')
    for z in range(1, WORLD_LEVELS + 1):
        lines.extend(["", f'(1,1,{z}) = {{"'])
        for y in range(SIZE, 0, -1):
            lines.append("".join(keys[grid[x, y, z]] for x in range(1, SIZE + 1)))
        lines.append('"}')
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    grid, layout = build()
    outputs = {MAP_PATH: render_dmm(grid), LAYOUT_PATH: json.dumps(layout, indent=2) + "\n"}
    for path, content in outputs.items():
        if args.check:
            if path.read_text(encoding="utf-8") != content:
                raise SystemExit(f"Generated output differs: {path}")
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding="utf-8", newline="\n")
    print("PASS: deterministic Hauler raid draft outputs" if args.check else "Wrote Hauler raid draft map and layout")


if __name__ == "__main__":
    main()
