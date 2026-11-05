"""Original, inactive Extraction party safehouse template. No runtime hooks.

The safehouse is the standalone "safehouse" kind of the extraction instance
contract (docs/extraction-instance-contract.md): one party-owned building that
is allocated as a private home, never transported and never raided. It is a
map study: the generated DMM, layout manifest and template descriptor are
editable source for a future instance owner. Nothing here is selectable,
loads player saves or changes shared extraction code.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAP_PATH = ROOT / "maps/WIP/extraction_safehouse.dmm"
LAYOUT_PATH = ROOT / "maps/WIP/extraction_safehouse.layout.json"
TEMPLATE_PATH = ROOT / "maps/WIP/extraction_safehouse.template.json"
SIZE = 128
WIDTH, LENGTH = 40, 48
DECKS = 2
WORLD_LEVELS = 2
TEMPLATE_ID = "safehouse_draft_v1"
TEMPLATE_REVISION = 1
ROOM = 1
HALL_X = (15, 24)
STAIRS = [{"id": core, "lower": [x, 29, 0], "upper": [x, 29, 1],
           "lower_palette": f"stair_{core}_up", "upper_palette": f"stair_{core}_down",
           "pair_area_id": f"safehouse_draft_{core}"}
          for core, x in (("a", 17), ("b", 22))]

HOUSE = "/turf/floor/plating/extraction_house"
STEEL = "/turf/floor/plating/steel"
# Source palette consumed by the validator and preview. Doors are passable only
# for geometric route analysis; the map enforces no authorization.
PALETTE = {
    "void": ("/turf/wall/iron", "#171f27", False),
    "hull": ("/turf/wall/iron", "#596975", False),
    "wall": ('/turf/wall/iron{name = "Permanent safehouse partition - draft only"}', "#7d8d99", False),
    "safe": (HOUSE, "#4b9b91", True),
    "bay": (f'{HOUSE}{{name = "Vehicle bay - draft only"}}', "#3d7f88", True),
    "pad": (f'{HOUSE}{{name = "Upgrade pad - draft only"}}', "#5a8f6e", True),
    "yard": ("/turf/floor/plating/concrete", "#535e63", True),
    "door": (f"/obj/structure/simple_door,{HOUSE}", "#ceaa5a", True),
    "gate": (f'/obj/structure/simple_door{{name = "Safehouse airlock outer door - draft only"; locked = 1}},{HOUSE}', "#ffde7a", True),
    "inner_gate": (f'/obj/structure/simple_door{{name = "Safehouse airlock inner door - draft only"; locked = 1}},{HOUSE}', "#ffde7a", True),
    "house_marker": (f"/obj/effect/extraction_house_marker{{room = {ROOM}}},{HOUSE}", "#ff9e6b", False),
    "secure_crate": (f"/obj/effect/extraction_secure_crate{{room = {ROOM}}},{HOUSE}", "#f07c4f", False),
    "workbench": (f"/obj/structure/component_workbench/extraction_private{{room = {ROOM}}},{HOUSE}", "#e3a04a", False),
    "car_workshop": (f"/obj/structure/car_workshop/extraction_private{{room = {ROOM}}},{HOUSE}", "#d98b3b", False),
    "generator": (f'/obj/structure/props/engineprops{{name = "Safehouse generator mount - draft only"}},{HOUSE}', "#e5c04c", False),
    "bed": (f"/obj/structure/bed,{HOUSE}", "#9cc6bc", False),
    "crate": (f"/obj/structure/closet/crate,{HOUSE}", "#aa7954", False),
    "rack": (f"/obj/structure/table/rack,{HOUSE}", "#9eacb8", False),
    "table": (f"/obj/structure/table,{HOUSE}", "#c0ab8b", False),
    "chair": (f"/obj/structure/bed/chair,{HOUSE}", "#b4a27c", False),
    "anvil": (f"/obj/structure/anvil,{HOUSE}", "#df9c5b", False),
    "sink": (f"/obj/structure/sink,{HOUSE}", "#bfdad8", False),
    "toilet": (f"/obj/structure/toilet,{HOUSE}", "#d3e3d9", False),
    "dirt": (f"/obj/effect/decal/cleanable/dirt,{HOUSE}", "#756d5c", True),
}
for stair in STAIRS:
    for endpoint, suffix in (("lower", "up"), ("upper", "down")):
        PALETTE[stair[f"{endpoint}_palette"]] = (
            f'/obj/structure/multiz/ladder/ww2/stairs{suffix}{{area_id = "{stair["pair_area_id"]}"; dir = 1}},{HOUSE}',
            "#9eb8eb", True)


def cells(rect):
    x0, y0, x1, y1 = rect
    return {(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)}


def frame():
    tiles = {(x, y): "safe" for y in range(LENGTH) for x in range(WIDTH)}
    for x in range(WIDTH):
        tiles[x, 0] = tiles[x, LENGTH - 1] = "hull"
    for y in range(LENGTH):
        tiles[0, y] = tiles[WIDTH - 1, y] = "hull"
    return tiles


def add_stairs(tiles, local_z):
    for stair in STAIRS:
        for endpoint in ("lower", "upper"):
            x, y, z = stair[endpoint]
            if z == local_z:
                tiles[x, y] = stair[f"{endpoint}_palette"]
    return tiles


def ground():
    tiles = frame()

    def fill(bounds, kind):
        for p in cells(bounds):
            tiles[p] = kind

    def row(x0, x1, y, kind):
        fill([x0, y, x1, y], kind)

    def column(x, y0, y1, kind):
        fill([x, y0, x, y1], kind)

    # Single entry: a 6 x 5 airlock vestibule through the south hull with two
    # distinct door placeholders. Interlock and party checks are mechanics-owned.
    fill([16, 0, 23, 6], "hull")
    fill([17, 1, 22, 5], "safe")
    tiles[19, 0], tiles[20, 6] = "gate", "inner_gate"
    # South band: receiving west, entry hall centre, vehicle bay east.
    column(15, 1, 13, "wall")
    column(24, 1, 13, "wall")
    tiles[15, 9] = tiles[15, 10] = tiles[24, 9] = tiles[24, 10] = "door"
    row(1, 38, 14, "wall")
    row(18, 21, 14, "safe")
    row(2, 6, 3, "table")
    for x in (9, 11, 13):
        tiles[x, 2] = "crate"
    for x in (2, 4, 6):
        tiles[x, 12] = "rack"
    tiles[13, 12] = "rack"
    tiles[26, 2] = "car_workshop"
    fill([29, 3, 35, 7], "bay")
    tiles[37, 2] = tiles[37, 4] = "crate"
    for x in (26, 28, 30):
        tiles[x, 12] = "rack"
    # Middle band: stash west, stair hall centre, workshop east.
    column(14, 15, 30, "wall")
    column(25, 15, 30, "wall")
    for y in (22, 23):
        tiles[14, y] = tiles[25, y] = "door"
    row(1, 38, 31, "wall")
    row(18, 21, 31, "safe")
    tiles[7, 22], tiles[8, 22] = "house_marker", "secure_crate"
    for y in (19, 25):
        row(3, 5, y, "rack")
        row(9, 11, y, "rack")
    for p in ((2, 16), (12, 16), (2, 29), (12, 29)):
        tiles[p] = "crate"
    tiles[31, 22] = "workbench"
    tiles[28, 17] = "anvil"
    row(27, 31, 28, "table")
    for y in (18, 22, 26):
        tiles[36, y] = "rack"
    tiles[28, 29] = tiles[36, 29] = "crate"
    # North band: clinic west, mess and kitchen centre, utility east.
    column(13, 32, 46, "wall")
    column(26, 32, 46, "wall")
    for y in (38, 39):
        tiles[13, y] = tiles[26, y] = "door"
    for y in (35, 41):
        tiles[3, y] = "bed"
        tiles[5, y] = "table"
    tiles[3, 33] = "chair"
    tiles[11, 34] = "rack"
    tiles[11, 45] = "sink"
    row(15, 24, 45, "table")
    tiles[19, 45] = "sink"
    for x0 in (15, 22):
        fill([x0, 36, x0 + 2, 37], "table")
        for x in (x0, x0 + 2):
            tiles[x, 35] = tiles[x, 38] = "chair"
    tiles[32, 40] = "generator"
    tiles[36, 34] = "sink"
    tiles[28, 45] = tiles[30, 45] = "crate"
    tiles[37, 42] = tiles[37, 44] = "rack"
    for p in ((3, 8), (36, 9), (20, 10), (12, 27), (33, 24), (17, 43)):
        tiles[p] = "dirt"
    return add_stairs(tiles, 0)


def upper():
    tiles = frame()

    def fill(bounds, kind):
        for p in cells(bounds):
            tiles[p] = kind

    def row(x0, x1, y, kind):
        fill([x0, y, x1, y], kind)

    def column(x, y0, y1, kind):
        fill([x, y0, x, y1], kind)

    # Full-length stair hall with partitioned rooms on both sides.
    column(14, 1, 46, "wall")
    column(25, 1, 46, "wall")
    for y in (7, 8, 22, 23, 38, 39):
        tiles[14, y] = tiles[25, y] = "door"
    for y in (14, 31):
        row(1, 13, y, "wall")
        row(26, 38, y, "wall")
    # Bunks west with individual lockers; wash stalls east.
    for x in (2, 8):
        for y in (3, 7, 11):
            tiles[x, y] = "bed"
            tiles[x + 2, y] = "crate"
    for x in (29, 33):
        column(x, 1, 3, "wall")
    for x in (27, 31, 35):
        tiles[x, 2] = "toilet"
    for x in (27, 30, 33):
        tiles[x, 12] = "sink"
    # Planning room west, armoury lockers east.
    fill([4, 21, 9, 23], "table")
    for x in (4, 6, 8):
        tiles[x, 20] = tiles[x, 24] = "chair"
    tiles[2, 16] = "rack"
    for y in (17, 20, 23, 26):
        row(28, 30, y, "rack")
        row(34, 36, y, "rack")
    # Two enclosed upgrade pads stay clear of every door and the hall.
    fill([2, 33, 12, 45], "pad")
    fill([27, 33, 37, 45], "pad")
    for p in ((6, 5), (31, 8), (10, 27), (19, 15), (20, 44)):
        tiles[p] = "dirt"
    return add_stairs(tiles, 1)


def deck_levels():
    return {(x, y, z): kind for z, deck in enumerate((ground(), upper())) for (x, y), kind in deck.items()}


def manifest():
    layout = {
        "schema_version": 1,
        "template_id": TEMPLATE_ID,
        "template_revision": TEMPLATE_REVISION,
        "kind": "safehouse",
        "status": "map study only; runtime integration disabled",
        "coordinates": {"local": "zero-based southwest; +x east, +y north, +z up",
                        "world": "BYOND one-based", "transform": "world = origin + local", "rotation_degrees": 0},
        "world": {"width": SIZE, "height": SIZE, "levels": WORLD_LEVELS},
        "levels": [{"id": "ground", "local_z": 0, "build_supported": False, "protected": True},
                   {"id": "upper", "local_z": 1, "build_supported": True, "protected": True}],
        "footprint": {"bounds": [0, 0, WIDTH - 1, LENGTH - 1], "local_z_levels": list(range(DECKS)),
                      "mask_rows_south_to_north": ["1" * WIDTH] * LENGTH},
        "protected": {"bounds": [0, 0, WIDTH - 1, LENGTH - 1], "local_z_levels": list(range(DECKS)),
                      "policy": "owning_party_only", "region_id": "safehouse_party_compartment",
                      "boundary_gates": [[19, 0]], "enforced_by_this_map": False,
                      "airlock": {"bounds": [16, 0, 23, 6], "interior_bounds": [17, 1, 22, 5],
                                  "outer_door": [19, 0], "inner_door": [20, 6], "policy": "owning_party_only",
                                  "interlocked": True, "authorize_from_either_side": True,
                                  "enforced_by_this_map": False, "safe_egress_policy": None},
                      "sustenance": {"rooms": ["clinic", "mess", "bunks"], "nutrition": "passive_increase",
                                     "hydration": "passive_increase", "cap": "normal_healthy_limits", "rate": None,
                                     "requires_actual_occupancy": True, "requires_party_authorization": True,
                                     "suppresses_ordinary_drain": True, "single_metabolism_update": True,
                                     "resume_ordinary_on_exit": True, "enforced_by_this_map": False}},
        "anchors": {"arrival": [20, 10, 0], "stash_terminal": [7, 22, 0], "secure_crate": [8, 22, 0],
                    "workbench": [31, 22, 0], "car_workshop": [26, 2, 0], "generator": [32, 40, 0],
                    "kitchen_sink": [19, 45, 0]},
        "account_markers": {"room": ROOM, "house_marker": [7, 22, 0], "secure_crate": [8, 22, 0],
                            "workbench": [31, 22, 0], "car_workshop": [26, 2, 0],
                            "current_range_rule": "production private rooms bind the crate, workbench and bay within four tiles of the marker",
                            "note": "this template places those objects by room, not by distance; the instance owner must bind them by instance identity before activation"},
        "rooms": [
            {"id": "airlock", "name": "Airlock vestibule", "bounds": [17, 1, 22, 5], "local_z": 0},
            {"id": "receiving", "name": "Receiving and sorting", "bounds": [1, 1, 14, 13], "local_z": 0},
            {"id": "entry_hall", "name": "Entry hall", "bounds": [16, 7, 23, 13], "local_z": 0},
            {"id": "garage", "name": "Vehicle bay", "bounds": [25, 1, 38, 13], "local_z": 0},
            {"id": "stash", "name": "Stash and secure storage", "bounds": [1, 15, 13, 30], "local_z": 0},
            {"id": "stair_hall", "name": "Stair hall", "bounds": [15, 15, 24, 30], "local_z": 0},
            {"id": "workshop", "name": "Workshop", "bounds": [26, 15, 38, 30], "local_z": 0},
            {"id": "clinic", "name": "Treatment room", "bounds": [1, 32, 12, 46], "local_z": 0},
            {"id": "mess", "name": "Mess and kitchen", "bounds": [14, 32, 25, 46], "local_z": 0},
            {"id": "utility", "name": "Generator and water utility", "bounds": [27, 32, 38, 46], "local_z": 0},
            {"id": "bunks", "name": "Crew bunks", "bounds": [1, 1, 13, 13], "local_z": 1},
            {"id": "upper_hall", "name": "Upper hall", "bounds": [15, 1, 24, 46], "local_z": 1},
            {"id": "wash", "name": "Wash stalls", "bounds": [26, 1, 38, 13], "local_z": 1},
            {"id": "planning", "name": "Planning room", "bounds": [1, 15, 13, 30], "local_z": 1},
            {"id": "armoury", "name": "Armoury lockers", "bounds": [26, 15, 38, 30], "local_z": 1},
            {"id": "west_upgrade", "name": "West upgrade room", "bounds": [1, 32, 13, 46], "local_z": 1},
            {"id": "east_upgrade", "name": "East upgrade room", "bounds": [26, 32, 38, 46], "local_z": 1},
        ],
        "build_pads": [{"id": "west_upgrade", "bounds": [2, 33, 12, 45], "local_z": 1},
                       {"id": "east_upgrade", "bounds": [27, 33, 37, 45], "local_z": 1}],
        "keep_clear": [{"id": "vehicle_bay", "bounds": [29, 3, 35, 7], "local_z": 0},
                       {"id": "ground_spine", "bounds": [18, 7, 21, 44], "local_z": 0},
                       {"id": "upper_spine", "bounds": [HALL_X[0], 1, HALL_X[1], 46], "local_z": 1}],
        "stairs": STAIRS,
        "stair_identity_contract": {
            "draft_pair_ids_only": True, "runtime_pair_identity": "stable_instance_id plus relative stair link ID",
            "rebind_after_restore": True, "validate_actual_endpoint_occupancy": True, "enforced_by_this_map": False},
        "slots": [
            {"id": "home_west", "kind": "home", "origin": [20, 40, 1], "reserved_bounds": [14, 34, 65, 93]},
            {"id": "home_east", "kind": "home", "origin": [72, 40, 1], "reserved_bounds": [66, 34, 117, 93]},
        ],
        "prototype": {"slot": "home_west", "is_saved_player_home": False},
        "reservation_policy": {"scope": "whole_footprint_all_decks", "atomic_reservation_before_load": True,
                               "all_levels_together": True, "enforced_by_this_map": False},
        "draft_limits": {"demonstration_home_slots": 2, "production_party_limit": None, "dynamic_z_allocation": False},
        "future_identity": {"stable_instance_id": "runtime-assigned persistent ID, never a slot/area/coordinate",
                            "party_id": "durable party identity from the instance record, not a temporary raid group",
                            "required_fences": ["schema_version", "instance_generation", "reservation_token", "party_authorization"]},
        "runtime_contract_pending": [
            "atomic reservation of the whole two-deck footprint before construction or load",
            "exclusive instance custody; one party per allocated home z interval",
            "every hull, partition, door and stair tile denies damage, deconstruction, forced entry, removal and replacement; player-built upgrade contents do not inherit invincibility",
            "party-only airlock entry from either side with enforced two-door interlock",
            "safe airlock egress on membership change or disconnect remains a required policy decision",
            "account markers bound by instance identity instead of the production four-tile distance rule",
            "safe-zone nutrition and hydration recovery in the clinic, mess and bunks; recovery rate is unspecified",
            "upgrade pad placement, costs, limits and supported structures need separate mechanics acceptance",
            "durable load rollback or quarantine, bounded retirement and verified empty slot reuse"],
    }
    for slot in layout["slots"]:
        base_z = slot["origin"][2]
        slot["reserved_z"] = [base_z, base_z + DECKS - 1]
        slot["local_z_levels"] = list(range(DECKS))
    volume = deck_levels()
    layout["structure_protection"] = {
        "floor_layers": [{"local_z": z, "bounds": list(layout["footprint"]["bounds"])} for z in range(DECKS)],
        "wall_tiles": [list(p) for p, kind in sorted(volume.items()) if kind in ("hull", "wall")],
        "door_tiles": [list(p) for p, kind in sorted(volume.items()) if kind in ("door", "gate", "inner_gate")],
        "stair_tiles": [list(p) for p, kind in sorted(volume.items()) if kind.startswith("stair_")],
        "mode": "deny_mutation_not_health_only",
        "denied_paths": ["damage", "deconstruction", "forced_entry", "removal", "replacement"],
        "preserve_on_restore": True, "player_built_contents_inherit_protection": False,
        "enforced_by_this_map": False}
    return layout


def template_descriptor(layout):
    """Export only the instance ABI v1 fields; never infer a template revision."""
    revision = layout.get("template_revision")
    if type(revision) is not int or not 1 <= revision <= 16777215:
        raise ValueError("explicit positive integer template_revision required")
    x0, y0, x1, y1 = layout["footprint"]["bounds"]
    return {
        "schema": 1,
        "template_id": layout["template_id"],
        "revision": revision,
        "width": x1 - x0 + 1,
        "height": y1 - y0 + 1,
        "decks": [{"layer": deck["local_z"] + 1, "id": deck["id"]} for deck in layout["levels"]],
        "berths": [],
    }


def build():
    layout = manifest()
    grid = {(x, y, z): ("void", "Outside draft") for z in range(1, WORLD_LEVELS + 1)
            for y in range(1, SIZE + 1) for x in range(1, SIZE + 1)}

    def fill(rect, z, kind, area):
        for x, y in cells(rect):
            grid[x, y, z] = kind, area

    # Each demo home is sealed in its own yard. There is no corridor between
    # the two slots, no player spawn, no teleporter and no map-selection entry.
    fill([16, 36, 63, 91], 1, "yard", "Safehouse west study")
    fill([68, 36, 115, 91], 1, "yard", "Safehouse east study")
    for slot in layout["slots"]:
        x, y, z = slot["origin"]
        fill([x, y, x + WIDTH - 1, y + LENGTH - 1], z, "yard", slot["id"])
    ox, oy, oz = next(s["origin"] for s in layout["slots"] if s["id"] == layout["prototype"]["slot"])
    for (dx, dy, dz), kind in deck_levels().items():
        if dz == 0:
            area = "Safehouse airlock study" if 16 <= dx <= 23 and dy <= 6 else "Safehouse ground study"
        else:
            area = "Safehouse upper study"
        grid[ox + dx, oy + dy, oz + dz] = kind, area
    return grid, layout


def render_dmm(grid):
    entries = sorted(set(grid.values()))
    alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    keys = {entry: alphabet[i // len(alphabet)] + alphabet[i % len(alphabet)] for i, entry in enumerate(entries)}
    lines = ["// Generated by tests/safehouse_map/build_map.py. Inactive map study."]
    for (kind, area), key in keys.items():
        atoms = PALETTE[kind][0]
        lines.append(f'"{key}" = ({atoms},/area{{name = "{area}"; location = 0}})')
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
    outputs = {MAP_PATH: render_dmm(grid), LAYOUT_PATH: json.dumps(layout, indent=2) + "\n",
               TEMPLATE_PATH: json.dumps(template_descriptor(layout), indent=2) + "\n"}
    for path, content in outputs.items():
        if args.check:
            if path.read_text(encoding="utf-8") != content:
                raise SystemExit(f"Generated output differs: {path}")
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding="utf-8", newline="\n")
    print("PASS: deterministic safehouse draft outputs" if args.check else "Wrote safehouse draft map, layout and template descriptor")


if __name__ == "__main__":
    main()
