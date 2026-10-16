"""Original, inactive Dagger home study. No runtime transport or save hooks."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAP_PATH = ROOT / "maps/WIP/dagger_train_home.dmm"
LAYOUT_PATH = ROOT / "maps/WIP/dagger_train_home.layout.json"
SIZE = 128
WIDTH, LENGTH = 15, 51

# Source palette is also consumed by the static preview/validator. Doors are
# passable only for geometric route analysis; this is not authorization logic.
PALETTE = {
    "void": ("/turf/wall/iron", "#171f27", False),
    "hull": ("/turf/wall/iron", "#596975", False),
    "floor": ("/turf/floor/plating/steel", "#657b83", True),
    "safe": ("/turf/floor/wood", "#4b9b91", True),
    "yard": ("/turf/floor/plating/concrete", "#535e63", True),
    "berth": ("/turf/floor/plating/dark", "#34444e", True),
    "platform": ("/turf/floor/plating/concrete", "#b5a16d", True),
    "door": ("/obj/structure/simple_door,/turf/floor/plating/steel", "#ceaa5a", True),
    "gate": ('/obj/structure/simple_door{name = "Party boundary - draft only"; locked = 1},/turf/floor/wood', "#ffde7a", True),
    "bed": ("/obj/structure/bed,/turf/floor/wood", "#9cc6bc", False),
    "crate": ("/obj/structure/closet/crate,/turf/floor/plating/steel", "#aa7954", False),
    "rack": ("/obj/structure/table/rack,/turf/floor/plating/steel", "#9eacb8", False),
    "table": ("/obj/structure/table,/turf/floor/wood", "#c0ab8b", False),
    "chair": ("/obj/structure/bed/chair,/turf/floor/wood", "#b4a27c", False),
    "anvil": ("/obj/structure/anvil,/turf/floor/plating/steel", "#df9c5b", False),
    "sink": ("/obj/structure/sink,/turf/floor/wood", "#bfdad8", False),
    "toilet": ("/obj/structure/toilet,/turf/floor/wood", "#d3e3d9", False),
    "dirt": ("/obj/effect/decal/cleanable/dirt,/turf/floor/plating/steel", "#756d5c", True),
}


def cells(rect):
    x0, y0, x1, y1 = rect
    return {(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)}


def train():
    tiles = {(x, y): "floor" for y in range(LENGTH) for x in range(WIDTH)}
    for p in cells([0, 0, 14, 20]):
        tiles[p] = "safe"
    for x in range(WIDTH):
        tiles[x, 0] = tiles[x, 50] = "hull"
    for y in range(LENGTH):
        tiles[0, y] = tiles[14, y] = "hull"
    # Three-car profile: narrowed coupling walkways still lie inside the full
    # rectangular transport mask; unused corners are never reusable by a peer.
    for y in (21, 38):
        for x in range(WIDTH):
            tiles[x, y] = "floor" if 6 <= x <= 8 else "hull"
    for y in range(1, 19):
        tiles[5, y] = tiles[9, y] = "hull"
    for x in list(range(1, 5)) + list(range(10, 14)):
        tiles[x, 9] = "hull"
    for p in ((5, 4), (9, 4), (5, 14), (9, 14)):
        tiles[p] = "door"
    # Separate the wash nook from the mess table with a closing privacy door.
    for x in range(10, 14):
        tiles[x, 5] = "hull"
    tiles[11, 5] = "door"
    for x in range(1, 14):
        tiles[x, 20] = "hull"
    tiles[7, 20] = "gate"
    # Crew room, mess/wash nook, secure stores and a small repair nook.
    for p in ((2, 2), (2, 6), (3, 12), (3, 16)):
        tiles[p] = "bed" if p[1] < 9 else "crate"
    for p, kind in {
        (11, 2): "table", (12, 2): "table", (11, 3): "chair",
        (12, 3): "chair", (12, 7): "sink", (11, 7): "toilet",
        (11, 12): "table", (12, 12): "table", (12, 17): "rack",
        (2, 23): "rack", (3, 23): "rack", (12, 23): "crate",
        (2, 36): "anvil", (3, 36): "table", (12, 36): "rack",
        (2, 40): "rack", (12, 40): "rack", (2, 44): "crate",
        (12, 44): "crate", (5, 48): "table", (9, 48): "table",
        (7, 47): "chair",
    }.items():
        tiles[p] = kind
    # Side ports are only in the exposed carriage. No exterior safe-room door.
    for y in (26, 35):
        tiles[0, y] = tiles[14, y] = "door"
    for p in ((2, 25), (12, 27), (4, 33), (11, 34), (3, 42), (11, 46)):
        tiles[p] = "dirt"
    return tiles


def manifest():
    layout = {
        "schema_version": 1,
        "template_id": "dagger_home_draft_v1",
        "status": "map study only; runtime integration disabled",
        "coordinates": {"local": "zero-based southwest; +x east, +y north",
                        "world": "BYOND one-based", "transform": "world = origin + local", "rotation_degrees": 0},
        "world": {"width": SIZE, "height": SIZE, "levels": 2},
        "footprint": {"bounds": [0, 0, 14, 50], "mask_rows_south_to_north": ["1" * WIDTH] * LENGTH},
        "protected": {"bounds": [0, 0, 14, 20], "policy": "owning_party_only", "while_raid_docked": True,
                      "boundary_gates": [[7, 20]], "enforced_by_this_map": False},
        "exposed": {"bounds": [0, 21, 14, 50], "boarding_ports": [[0, 26], [14, 26], [0, 35], [14, 35]]},
        "anchors": {"crew_spawn": [7, 10], "workshop": [7, 30], "helm": [7, 46]},
        "rooms": [
            {"id": "crew", "name": "Crew bunks", "bounds": [1, 1, 4, 8], "protected": True},
            {"id": "mess", "name": "Mess and wash nook", "bounds": [10, 1, 13, 8], "protected": True},
            {"id": "stores", "name": "Party stores", "bounds": [1, 10, 4, 18], "protected": True},
            {"id": "repair", "name": "Quiet repair nook", "bounds": [10, 10, 13, 18], "protected": True},
            {"id": "workshop", "name": "Build and crafting carriage", "bounds": [1, 22, 13, 37], "protected": False},
            {"id": "utility", "name": "Utility and helm cabin", "bounds": [1, 39, 13, 49], "protected": False},
        ],
        "build_pads": [{"id": "west_build", "bounds": [2, 28, 4, 32]}, {"id": "east_build", "bounds": [10, 28, 12, 32]}],
        "keep_clear": [{"id": "spine", "bounds": [6, 22, 8, 45]},
                       {"id": "south_boarding", "bounds": [0, 26, 14, 26]},
                       {"id": "north_boarding", "bounds": [0, 35, 14, 35]}],
        "slots": [
            {"id": "home_west", "kind": "home", "origin": [20, 24, 1], "reserved_bounds": [17, 21, 37, 77]},
            {"id": "home_east", "kind": "home", "origin": [84, 24, 1], "reserved_bounds": [81, 21, 101, 77]},
            {"id": "raid_west", "kind": "raid_berth", "origin": [36, 36, 2], "reserved_bounds": [33, 33, 53, 89], "platform_side": "east", "platform_anchors": [[54, 62, 2], [54, 71, 2]]},
            {"id": "raid_east", "kind": "raid_berth", "origin": [65, 36, 2], "reserved_bounds": [62, 33, 82, 89], "platform_side": "west", "platform_anchors": [[61, 62, 2], [61, 71, 2]]},
        ],
        "prototype": {"slot": "home_west", "is_saved_player_train": False},
        "berth_geometry_groups": [{"id": "raid_pair_v1", "slot_ids": ["raid_west", "raid_east"],
                                   "exclusive_reservation": False}],
        "reservation_policy": {"scope": "selected_berth_and_whole_footprint",
                               "atomic_reservation_before_load_or_move": True,
                               "other_berths_remain_available": True, "enforced_by_this_map": False},
        "draft_limits": {"demonstration_home_slots": 2, "simultaneous_raid_berths": 2,
                         "production_train_or_party_limit": None, "dynamic_z_allocation": False},
        "future_identity": {"stable_train_id": "runtime-assigned persistent ID, never a slot/area/coordinate",
                            "crew_id": "runtime-owned stable crew identity; not a temporary party object",
                            "required_fences": ["schema_version", "train_generation", "reservation_token", "crew_authorization", "occupancy_generation"]},
        "runtime_contract_pending": ["atomic reservation of only the selected berth and own whole footprint before construction, load or move",
                                     "other berth remains available to another party; pair geometry is not an exclusive claim",
                                     "exclusive train custody across home and berth",
                                     "party access and damage protection in every location", "post-callback occupancy revalidation",
                                     "durable move/load rollback or quarantine", "bounded retirement and verified empty slot reuse"],
    }
    for slot in layout["slots"]:
        slot["berth_mask_rows_south_to_north"] = ["1" * WIDTH] * LENGTH
        if slot["kind"] == "raid_berth":
            bridge_x = range(51, 55) if slot["platform_side"] == "east" else range(61, 65)
            slot["bridge_cells"] = [[x, y, 2] for y in (62, 71) for x in bridge_x]
    return layout


def build():
    layout = manifest()
    grid = {(x, y, z): ("void", "Outside draft") for z in (1, 2) for y in range(1, SIZE + 1) for x in range(1, SIZE + 1)}

    def fill(rect, z, kind, area):
        for x, y in cells(rect):
            grid[x, y, z] = kind, area

    # Each demo home is sealed in a separate enclosure. There is no inter-home
    # corridor, player spawn, live teleporter or map-selection entry.
    fill([12, 16, 42, 83], 1, "yard", "Home west study")
    fill([76, 16, 106, 83], 1, "yard", "Home east study")
    # Two parallel destination berths share an exposed central platform.
    fill([27, 26, 88, 98], 2, "yard", "Raid station study")
    fill([54, 30, 61, 94], 2, "platform", "Boarding platform")
    fill([35, 91, 80, 95], 2, "platform", "Station concourse")
    for slot in layout["slots"]:
        x, y, z = slot["origin"]
        fill([x, y, x + 14, y + 50], z, "berth", slot["id"])
    for x, y in ((29, 31), (86, 31), (29, 92), (86, 92), (42, 96), (72, 96)):
        grid[x, y, 2] = "crate", "Raid station study"
    for x, y in ((30, 45), (85, 47), (30, 76), (85, 78), (48, 96), (68, 96)):
        grid[x, y, 2] = "dirt", "Raid station study"
    for (dx, dy), kind in train().items():
        area = "Dagger protected study" if dy <= 20 else "Dagger exposed study"
        grid[20 + dx, 24 + dy, 1] = kind, area
    return grid, layout


def render_dmm(grid):
    entries = sorted(set(grid.values()))
    alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    keys = {entry: alphabet[i // len(alphabet)] + alphabet[i % len(alphabet)] for i, entry in enumerate(entries)}
    lines = ["// Generated by tests/dagger_map/build_map.py. Inactive map study."]
    for (kind, area), key in keys.items():
        atoms = PALETTE[kind][0]
        lines.append(f'"{key}" = ({atoms},/area{{name = "{area}"; location = 0}})')
    for z in (1, 2):
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
    print("PASS: deterministic Dagger draft outputs" if args.check else "Wrote Dagger draft map and layout")


if __name__ == "__main__":
    main()
