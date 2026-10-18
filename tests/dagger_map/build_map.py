"""Original, inactive Dagger home study. No runtime transport or save hooks."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAP_PATH = ROOT / "maps/WIP/dagger_train_home.dmm"
LAYOUT_PATH = ROOT / "maps/WIP/dagger_train_home.layout.json"
TEMPLATE_PATH = ROOT / "maps/WIP/dagger_train_home.template.json"
SIZE = 256
WIDTH, LENGTH = 30, 102
TRAIN_LEVELS = 4
WORLD_LEVELS = 8
PROTECTED_END = 45
BOARDING_BANDS = ((52, 54), (68, 70))
PILLARS = [(x, y) for x in (12, 17) for y in (13, 26, 39, 45, 93)] + [(11, 78), (18, 78)]
STAIRS = [{"id": f"{core}{z}", "lower": [x, y + z, z], "upper": [x, y + z, z + 1],
           "lower_palette": f"stair_{core}{z}_up", "upper_palette": f"stair_{core}{z}_down",
           "pair_area_id": f"dagger_draft_{core}{z}"}
          for core, x, y in (("a", 13, 72), ("b", 16, 87)) for z in range(3)]

# Source palette is also consumed by the static preview/validator. Doors are
# passable only for geometric route analysis; this is not authorization logic.
PALETTE = {
    "void": ("/turf/wall/iron", "#171f27", False),
    "hull": ("/turf/wall/iron", "#596975", False),
    "pillar": ('/turf/wall/iron{name = "Permanent Dagger support pillar - draft only"}', "#9babb7", False),
    "floor": ("/turf/floor/plating/steel", "#657b83", True),
    "safe": ("/turf/floor/wood", "#4b9b91", True),
    "yard": ("/turf/floor/plating/concrete", "#535e63", True),
    "berth": ("/turf/floor/plating/dark", "#34444e", True),
    "platform": ("/turf/floor/plating/concrete", "#b5a16d", True),
    "door": ("/obj/structure/simple_door,/turf/floor/plating/steel", "#ceaa5a", True),
    "gate": ('/obj/structure/simple_door{name = "Party airlock outer door - draft only"; locked = 1},/turf/floor/wood', "#ffde7a", True),
    "inner_gate": ('/obj/structure/simple_door{name = "Party airlock inner door - draft only"; locked = 1},/turf/floor/wood', "#ffde7a", True),
    "helm_control": ('/obj/structure/table{name = "Upgradeable Dagger helm controls - draft only"; desc = "Protected helm placeholder. Upgrades and raid controls are not implemented."},/turf/floor/wood', "#74b9e8", False),
    "engine_mount": ('/obj/structure/props/engineprops{name = "Upgradeable Dagger engine mount - draft only"; desc = "Protected engine-room placeholder. Fuel, upgrades and propulsion are not implemented."},/turf/floor/plating/steel', "#dd9265", False),
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
for stair in STAIRS:
    for endpoint, suffix in (("lower", "up"), ("upper", "down")):
        PALETTE[stair[f"{endpoint}_palette"]] = (
            f'/obj/structure/multiz/ladder/ww2/stairs{suffix}{{area_id = "{stair["pair_area_id"]}"; dir = 1}},/turf/floor/plating/steel',
            "#9eb8eb", True)


def add_structure_and_stairs(tiles, local_z):
    for point in PILLARS:
        tiles[point] = "pillar"
    for stair in STAIRS:
        for endpoint in ("lower", "upper"):
            x, y, z = stair[endpoint]
            if z == local_z:
                tiles[x, y] = stair[f"{endpoint}_palette"]
    return tiles


def cells(rect):
    x0, y0, x1, y1 = rect
    return {(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)}


def train():
    tiles = {(x, y): "floor" for y in range(LENGTH) for x in range(WIDTH)}

    def fill(bounds, kind):
        for p in cells(bounds):
            tiles[p] = kind

    def row(x0, x1, y, kind):
        fill([x0, y, x1, y], kind)

    for p in cells([0, 0, WIDTH - 1, PROTECTED_END]):
        tiles[p] = "safe"
    for x in range(WIDTH):
        tiles[x, 0] = tiles[x, LENGTH - 1] = "hull"
    for y in range(LENGTH):
        tiles[0, y] = tiles[WIDTH - 1, y] = "hull"
    # Full-width mask includes coupling corners; they cannot be allocated to a peer.
    for y in (78, 79):
        row(1, 28, y, "hull")
        row(12, 17, y, "floor")

    # Protected rear: four-wide central corridor, separately furnished rooms.
    for x in (12, 17):
        fill([x, 1, x, 38], "hull")
        for y in (6, 7, 19, 20, 32, 33):
            tiles[x, y] = "door"
    for y in (13, 26):
        row(1, 11, y, "hull")
        row(18, 28, y, "hull")
    # Party-only vestibule: 4x5 interior and two distinct door placeholders.
    # Interlock, occupancy and authorization are mechanics-owned requirements.
    fill([1, 39, 28, 45], "hull")
    fill([13, 40, 16, 44], "safe")
    tiles[14, 39], tiles[15, 45] = "inner_gate", "gate"
    # Six bunks and individual gear lockers are furnishings, never a crew cap.
    for x in (2, 8):
        for y in (3, 7, 11):
            tiles[x, y] = "bed"
            tiles[x + 2, y] = "crate"
    tiles[5, 5] = "table"
    tiles[5, 4] = "chair"
    for y in (15, 19, 23):
        row(2, 4, y, "rack")
        row(8, 10, y, "crate")
    for y in (28, 32, 36):
        row(2, 4, y, "crate")
        row(8, 10, y, "rack")
    # Mess tables have seating and a separate counter along the rear wall.
    row(19, 27, 1, "table")
    tiles[22, 1] = "sink"
    for x0, y0 in ((20, 4), (24, 8)):
        fill([x0, y0, x0 + 2, y0 + 1], "table")
        for x in (x0, x0 + 2):
            tiles[x, y0 - 1] = tiles[x, y0 + 2] = "chair"
    # Separate wash stalls and a treatment room from eating and sleeping spaces.
    fill([23, 14, 23, 25], "hull")
    tiles[23, 20] = tiles[23, 21] = "door"
    for y in (18, 23):
        row(18, 22, y, "hull")
        tiles[20, y] = "door"
    for p, kind in {(19, 15): "toilet", (21, 15): "sink", (19, 25): "sink",
                    (21, 25): "toilet", (25, 15): "bed", (27, 15): "bed",
                    (25, 24): "table", (27, 24): "rack", (25, 22): "chair"}.items():
        tiles[p] = kind
    # Engine and helm are inside the protected hull, with independent access.
    # Inert table/engine-prop markers add no fuel or travel callbacks.
    tiles[17, 32] = tiles[17, 33] = "hull"
    for y in (29, 30, 35, 36):
        tiles[17, y] = "door"
    row(18, 28, 32, "hull")
    row(19, 21, 28, "table")
    tiles[25, 29] = "engine_mount"
    tiles[27, 28], tiles[27, 30] = "rack", "rack"
    row(22, 26, 37, "table")
    tiles[24, 37] = "helm_control"
    tiles[24, 36] = "chair"

    # Exposed incoming stores, followed by two large independent build bays.
    for x in (12, 17):
        fill([x, 46, x, 51], "hull")
        tiles[x, 48] = tiles[x, 49] = "door"
        fill([x, 55, x, 67], "hull")
        for y in (59, 60, 61):
            tiles[x, y] = "door"
    for x0, x1 in ((1, 11), (18, 28)):
        row(x0, x1, 55, "hull")
        row(x0, x1, 67, "hull")
        row(x0 + 4, x0 + 6, 55, "door")
        row(x0 + 1, x1 - 1, 66, "table")
        for y in (47, 50):
            row(x0 + 1, x0 + 3, y, "rack")
            row(x1 - 3, x1 - 1, y, "crate")
    # Three-wide lateral passages stay clear even when both build pads are full.
    for y0, y1 in BOARDING_BANDS:
        for y in range(y0, y1 + 1):
            tiles[0, y] = tiles[WIDTH - 1, y] = "door"
    row(2, 10, 74, "table")
    tiles[4, 74] = tiles[8, 74] = "anvil"
    for x in (3, 7, 10):
        tiles[x, 76] = "rack"
    for x in (20, 23, 26):
        tiles[x, 73] = "crate"
        tiles[x, 76] = "rack"

    # Forward utility rooms feed exposed cargo, never the protected controls.
    for x in (12, 17):
        fill([x, 80, x, 92], "hull")
        tiles[x, 85] = tiles[x, 86] = "door"
    for y in (82, 86, 90):
        row(2, 4, y, "rack")
        row(8, 10, y, "table")
        row(20, 22, y, "crate")
        row(25, 27, y, "rack")
    tiles[3, 84] = "anvil"
    row(1, 28, 93, "hull")
    row(13, 16, 93, "floor")
    for x in (3, 7, 22, 26):
        tiles[x, 99] = "crate"
    row(10, 12, 99, "table")
    tiles[3, 96] = tiles[26, 96] = "rack"
    for p in ((2, 53), (27, 54), (4, 69), (25, 70), (3, 72), (11, 75), (21, 88), (5, 97)):
        tiles[p] = "dirt"
    return add_structure_and_stairs(tiles, 0)


def upper_deck(local_z):
    """Permanent frame and empty build bays; furnishings are not starter stock."""
    tiles = {(x, y): "floor" for y in range(LENGTH) for x in range(WIDTH)}
    for x in range(WIDTH):
        tiles[x, 0] = tiles[x, LENGTH - 1] = "hull"
    for y in range(LENGTH):
        tiles[0, y] = tiles[WIDTH - 1, y] = "hull"
    if local_z < 3:
        for x in (12, 17):
            for y in range(1, 101):
                tiles[x, y] = "hull"
            for y in (6, 7, 19, 20, 32, 33, 48, 49, 60, 61, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 85, 86, 97, 98):
                tiles[x, y] = "door" if y < 68 or y > 77 else "floor"
        for y in (26, 45, 78, 79, 93):
            for x in list(range(1, 12)) + list(range(18, 29)):
                tiles[x, y] = "hull"
        # Side utility benches leave build rectangles and stair landings clear.
        for x in (2, 3, 4, 25, 26, 27):
            tiles[x, 76] = "table" if local_z == 1 else "rack"
        for x, y in ((3, 70), (26, 73), (6, 90), (23, 40)):
            tiles[x, y] = "dirt"
    else:
        # Walkable roof with a permanent perimeter and aligned supports.
        # Empty rectangles are construction zones, not free equipment.
        for x, y in ((3, 8), (26, 36), (5, 70), (25, 96)):
            tiles[x, y] = "dirt"
    return add_structure_and_stairs(tiles, local_z)


def train_levels():
    return {(x, y, z): kind for z in range(TRAIN_LEVELS)
            for (x, y), kind in (train() if z == 0 else upper_deck(z)).items()}


def manifest():
    layout = {
        "schema_version": 2,
        "template_id": "dagger_home_draft_v4",
        "template_revision": 1,
        "status": "map study only; runtime integration disabled",
        "coordinates": {"local": "zero-based southwest; +x east, +y north, +z up",
                        "world": "BYOND one-based", "transform": "world = origin + local", "rotation_degrees": 0},
        "world": {"width": SIZE, "height": SIZE, "levels": WORLD_LEVELS},
        "levels": [{"id": name, "local_z": z, "build_supported": True, "protected": z == 0}
                   for z, name in enumerate(("ground", "upper_1", "upper_2", "roof"))],
        "footprint": {"bounds": [0, 0, WIDTH - 1, LENGTH - 1], "local_z_levels": list(range(TRAIN_LEVELS)),
                      "mask_rows_south_to_north": ["1" * WIDTH] * LENGTH},
        "protected": {"bounds": [0, 0, 29, PROTECTED_END], "local_z": 0, "policy": "owning_party_only", "while_raid_docked": True,
                      "region_id": "dagger_party_safe_compartment", "boundary_gates": [[15, 45]], "enforced_by_this_map": False,
                      "sustenance": {"bounds": [0, 0, 29, 38], "nutrition": "passive_increase", "hydration": "passive_increase",
                                     "cap": "normal_healthy_limits", "rate": None, "requires_actual_occupancy": True,
                                     "requires_party_authorization": True, "suppresses_ordinary_drain": True,
                                     "single_metabolism_update": True, "resume_ordinary_on_exit": True, "enforced_by_this_map": False},
                      "airlock": {"bounds": [12, 39, 17, 45], "interior_bounds": [13, 40, 16, 44],
                                  "inner_door": [14, 39], "outer_door": [15, 45], "policy": "owning_party_only",
                                  "interlocked": True, "authorize_from_either_side": True,
                                  "enforced_by_this_map": False, "safe_egress_policy": None}},
        "exposed": {"bounds": [0, PROTECTED_END + 1, 29, 101], "boarding_bands": [list(b) for b in BOARDING_BANDS],
                    "boarding_ports": [[x, y] for x in (0, WIDTH - 1) for y0, y1 in BOARDING_BANDS for y in range(y0, y1 + 1)]},
        "anchors": {"crew_spawn": [14, 20], "workshop": [14, 60], "helm": [20, 35], "engine": [20, 29]},
        "rooms": [
            {"id": "crew", "name": "Crew bunks", "bounds": [1, 1, 11, 12], "protected": True},
            {"id": "mess", "name": "Mess and kitchen counter", "bounds": [18, 1, 28, 12], "protected": True},
            {"id": "lockers", "name": "Gear lockers", "bounds": [1, 14, 11, 25], "protected": True},
            {"id": "wash", "name": "Wash stalls", "bounds": [18, 14, 22, 25], "protected": True},
            {"id": "clinic", "name": "Treatment room", "bounds": [24, 14, 28, 25], "protected": True},
            {"id": "stores", "name": "Party stores", "bounds": [1, 27, 11, 38], "protected": True},
            {"id": "engine", "name": "Protected engine room", "bounds": [18, 27, 28, 31], "protected": True},
            {"id": "helm", "name": "Protected helm controls", "bounds": [18, 33, 28, 38], "protected": True},
            {"id": "receiving", "name": "Incoming salvage stores", "bounds": [1, 46, 28, 51], "protected": False},
            {"id": "west_build", "name": "West build bay", "bounds": [1, 55, 11, 67], "protected": False},
            {"id": "east_build", "name": "East build bay", "bounds": [18, 55, 28, 67], "protected": False},
            {"id": "crafting", "name": "Crafting and sorting benches", "bounds": [1, 71, 28, 77], "protected": False},
            {"id": "utility", "name": "Utility maintenance", "bounds": [1, 80, 11, 92], "protected": False},
            {"id": "spares", "name": "Exposed spare parts store", "bounds": [18, 80, 28, 92], "protected": False},
            {"id": "forward_cargo", "name": "Forward cargo cabin", "bounds": [1, 94, 28, 100], "protected": False},
        ],
        "build_pads": [{"id": "west_build", "bounds": [2, 56, 10, 65]}, {"id": "east_build", "bounds": [19, 56, 27, 65]}],
        "keep_clear": [{"id": "spine", "bounds": [13, 46, 16, 97]},
                       {"id": "south_boarding", "bounds": [0, 52, 29, 54]},
                       {"id": "north_boarding", "bounds": [0, 68, 29, 70]}],
        "slots": [
            {"id": "home_west", "kind": "home", "origin": [40, 48, 1], "reserved_bounds": [34, 42, 75, 155]},
            {"id": "home_east", "kind": "home", "origin": [168, 48, 1], "reserved_bounds": [162, 42, 203, 155]},
            {"id": "raid_west", "kind": "raid_berth", "origin": [72, 72, 2], "reserved_bounds": [66, 66, 107, 179], "platform_side": "east", "platform_anchors": [[108, 125, 2], [108, 141, 2]]},
            {"id": "raid_east", "kind": "raid_berth", "origin": [130, 72, 2], "reserved_bounds": [124, 66, 165, 179], "platform_side": "west", "platform_anchors": [[123, 125, 2], [123, 141, 2]]},
        ],
        "shared_access": [{"id": "raid_platform", "z": 2, "bounds": [108, 60, 123, 189]},
                          {"id": "raid_concourse", "z": 2, "bounds": [70, 182, 161, 191]}],
        "prototype": {"slot": "home_west", "is_saved_player_train": False},
        "berth_geometry_groups": [{"id": "raid_pair_v1", "slot_ids": ["raid_west", "raid_east"],
                                   "exclusive_reservation": False}],
        "reservation_policy": {"scope": "selected_berth_and_whole_footprint",
                               "atomic_reservation_before_load_or_move": True,
                               "all_levels_together": True,
                               "other_berths_remain_available": True, "enforced_by_this_map": False},
        "draft_limits": {"demonstration_home_slots": 2, "simultaneous_raid_berths": 2,
                         "production_train_or_party_limit": None, "dynamic_z_allocation": False},
        "future_identity": {"stable_train_id": "runtime-assigned persistent ID, never a slot/area/coordinate",
                            "crew_id": "runtime-owned stable crew identity; not a temporary party object",
                            "required_fences": ["schema_version", "train_generation", "reservation_token", "crew_authorization", "occupancy_generation"]},
        "raid_access": {
            "required_inputs": ["loaded_fuel", "target_section_boarding_pass"],
            "front_sections": {"loot": "better", "entry_cost": "higher"},
            "balance_values": None,
            "target_compartment_doors": {"breachable_without_pass": True, "inherits_dagger_boundary_protection": False},
            "transaction": {"authority": "server", "atomic_commit": True, "atomic_refund": True,
                            "idempotent": True, "commit_point": None, "refund_policy": None,
                            "failure_resolution": "rollback_or_quarantine_without_duplicate_value",
                            "inputs": ["loaded_fuel", "target_section_boarding_pass"],
                            "enforced_by_this_map": False},
            "extraction_sequence": {
                "states": ["reservation", "call", "arrival", "boarding", "departure"],
                "requirements": {
                    "reservation": "atomically claim selected berth and own whole footprint; validate loaded fuel and target-section pass",
                    "call": "server-authorized idempotent request tied to current train identity and reservation",
                    "arrival": "revalidate occupancy and ownership before placement and after callbacks; retain protected boundary",
                    "boarding": "track actual participants; enforce party-only protected airlock while exposed sections remain boardable",
                    "departure": "revalidate custody and durable movement; release claims only after verified empty-slot retirement"},
                "timings": None, "enforced_by_this_map": False},
            "enforced_by_this_map": False},
        "runtime_contract_pending": ["atomic reservation of only the selected berth and own whole four-level footprint before construction, load or move",
                                     "other berth remains available to another party; pair geometry is not an exclusive claim",
                                     "exclusive train custody across home and berth",
                                     "party access and damage protection in every location",
                                     "protected boundary walls and airlock doors deny damage, deconstruction, forced entry, removal and replacement bypass; preserve across transport and restore",
                                     "upgradeable helm controls and engine room stay inside protected compartment; upgrade costs and effects unspecified",
                                     "loaded fuel and target-section pass gate raid travel; front target sections have better loot and higher entry cost",
                                     "target train compartment doors remain breachable without a pass and do not inherit Dagger boundary protection",
                                     "server-side atomic fuel/pass commit and refund with idempotent reservation, call, arrival, boarding and departure states",
                                     "party-only airlock entry from either side with enforced two-door interlock",
                                     "safe airlock egress on membership change or disconnect remains a required policy decision",
                                     "safe-zone nutrition and hydration recovery replaces drain at normal healthy caps; recovery rate is unspecified",
                                     "post-callback occupancy revalidation",
                                     "durable move/load rollback or quarantine", "bounded retirement and verified empty slot reuse"],
    }
    for collection in ("rooms", "build_pads", "keep_clear"):
        for item in layout[collection]:
            item["local_z"] = 0
    # Upper decks have independent work/build rooms with a four-wide spine.
    # Their floor forms an unbroken ceiling over the protected ground core.
    segments = [(1, 25, 2, 23, "rear"), (27, 44, 28, 42, "mid"),
                (46, 67, 47, 65, "workshop"), (80, 92, 81, 90, "utility"),
                (94, 100, 95, 99, "forward")]
    for z in (1, 2):
        for side, x0, x1 in (("west", 1, 11), ("east", 18, 28)):
            for y0, y1, py0, py1, name in segments:
                identifier = f"upper_{z}_{side}_{name}"
                layout["rooms"].append({"id": identifier, "name": f"Upper {z} {side} {name} build room",
                                        "bounds": [x0, y0, x1, y1], "local_z": z, "protected": False})
                layout["build_pads"].append({"id": identifier, "bounds": [x0 + 1, py0, x1 - 1, py1], "local_z": z})
        layout["rooms"].append({"id": f"upper_{z}_landing", "name": f"Upper {z} sorting and stair landing",
                                "bounds": [1, 68, 28, 77], "local_z": z, "protected": False})
        layout["keep_clear"].extend([{"id": f"upper_{z}_spine", "bounds": [13, 1, 16, 100], "local_z": z},
                                     {"id": f"upper_{z}_crossing", "bounds": [1, 68, 28, 70], "local_z": z}])
    for side, x0, x1 in (("west", 2, 10), ("east", 19, 27)):
        for y0, y1, name in ((2, 38, "rear"), (46, 66, "centre"), (80, 99, "forward")):
            identifier = f"roof_{side}_{name}"
            bounds = [x0, y0, x1, y1]
            layout["rooms"].append({"id": identifier, "name": f"Roof {side} {name} build zone",
                                    "bounds": bounds, "local_z": 3, "protected": False})
            layout["build_pads"].append({"id": identifier, "bounds": bounds, "local_z": 3})
    layout["keep_clear"].extend([{"id": "roof_spine", "bounds": [13, 1, 16, 100], "local_z": 3},
                                 {"id": "roof_crossing", "bounds": [1, 68, 28, 70], "local_z": 3}])
    layout["stairs"] = STAIRS
    layout["stair_identity_contract"] = {
        "draft_pair_ids_only": True, "runtime_pair_identity": "stable_train_id plus relative stair link ID",
        "rebind_after_restore_or_move": True, "validate_actual_endpoint_occupancy": True, "enforced_by_this_map": False}
    layout["transit_3d_contract"] = {
        "operations": ["reserve", "save", "restore", "move", "retire"], "all_levels_together": True,
        "stable_relative_z": True, "bounded_allocation": True, "post_callback_revalidation": True,
        "rollback_or_quarantine": True, "enforced_by_this_map": False}
    layout["protected"]["vertical_boundary"] = {
        "floor_local_z": 0, "ceiling_local_z": 1, "bounds": list(layout["protected"]["bounds"]),
        "no_uncontrolled_vertical_entry": True, "enforced_by_this_map": False}
    layout["runtime_contract_pending"].extend([
        "all permanent structure on ground, both upper floors and roof denies damage, deconstruction, forced entry, removal and replacement; player-built contents do not inherit invincibility",
        "reserve, save, restore, move and retire all four levels together with bounded allocation, exclusive custody and recovery",
        "protected core floor and ceiling reject vertical, roof, construction and removal bypass",
        "rebind stair pairs by stable train identity and relative link ID after move or restore; validate endpoints without crossing parties"])
    protected_bounds = layout["protected"]["bounds"]
    boundary = {(x, y) for x, y in cells(protected_bounds)
                if x in (0, WIDTH - 1) or y in (0, PROTECTED_END)}
    airlock_bounds = layout["protected"]["airlock"]["bounds"]
    ax0, ay0, ax1, ay1 = airlock_bounds
    boundary |= {(x, y) for x, y in cells(airlock_bounds) if x in (ax0, ax1) or y in (ay0, ay1)}
    source_train = train()
    layout["protected"]["boundary_protection"] = {
        "wall_tiles": [list(p) for p in sorted(boundary) if source_train[p] in ("hull", "pillar")],
        "door_tiles": [[14, 39], [15, 45]],
        "mode": "deny_mutation_not_health_only",
        "denied_paths": ["damage", "deconstruction", "forced_entry", "removal", "replacement"],
        "preserve_on_transport_and_restore": True, "exposed_walls_protected": True,
        "enforced_by_this_map": False}
    layout["protected"]["infrastructure"] = {
        "helm_controls": {"room_id": "helm", "marker": [24, 37], "palette": "helm_control", "upgradeable": True},
        "engine_room": {"room_id": "engine", "marker": [25, 29], "palette": "engine_mount", "upgradeable": True},
        "upgrade_costs": None, "upgrade_effects": None, "enforced_by_this_map": False}
    volume = train_levels()
    layout["structure_protection"] = {
        "floor_layers": [{"local_z": z, "bounds": list(layout["footprint"]["bounds"])} for z in range(TRAIN_LEVELS)],
        "wall_tiles": [list(p) for p, kind in sorted(volume.items()) if kind == "hull"],
        "pillar_tiles": [list(p) for p, kind in sorted(volume.items()) if kind == "pillar"],
        "door_tiles": [list(p) for p, kind in sorted(volume.items()) if kind in ("door", "gate", "inner_gate")],
        "stair_tiles": [list(p) for p, kind in sorted(volume.items()) if kind.startswith("stair_")],
        "mode": "deny_mutation_not_health_only",
        "denied_paths": ["damage", "deconstruction", "forced_entry", "removal", "replacement"],
        "preserve_on_transport_and_restore": True, "player_built_contents_inherit_protection": False,
        "enforced_by_this_map": False}
    for slot in layout["slots"]:
        if slot["kind"] == "raid_berth":
            slot["origin"][2] = 5
            for anchor in slot["platform_anchors"]:
                anchor[2] = 5
        base_z = slot["origin"][2]
        slot["reserved_z"] = [base_z, base_z + TRAIN_LEVELS - 1]
        slot["local_z_levels"] = list(range(TRAIN_LEVELS))
        slot["berth_mask_rows_south_to_north"] = ["1" * WIDTH] * LENGTH
        if slot["kind"] == "raid_berth":
            slot["boarding_width"], slot["platform_gap_tiles"] = 3, 6
            bridge_x = range(102, 109) if slot["platform_side"] == "east" else range(123, 130)
            slot["bridge_cells"] = [[x, y, base_z] for _, ay, _ in slot["platform_anchors"] for y in range(ay - 1, ay + 2) for x in bridge_x]
    for access in layout["shared_access"]:
        access["z"] = 5
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
        "berths": [slot["id"] for slot in layout["slots"] if slot["kind"] == "raid_berth"],
    }


def build():
    layout = manifest()
    grid = {(x, y, z): ("void", "Outside draft") for z in range(1, WORLD_LEVELS + 1) for y in range(1, SIZE + 1) for x in range(1, SIZE + 1)}

    def fill(rect, z, kind, area):
        for x, y in cells(rect):
            grid[x, y, z] = kind, area

    # Each demo home is sealed in a separate enclosure. There is no inter-home
    # corridor, player spawn, live teleporter or map-selection entry.
    fill([24, 32, 85, 167], 1, "yard", "Home west study")
    fill([152, 32, 213, 167], 1, "yard", "Home east study")
    # Two parallel destination berths share an exposed central platform.
    fill([54, 52, 177, 197], 5, "yard", "Raid station study")
    for access in layout["shared_access"]:
        fill(access["bounds"], access["z"], "platform", access["id"])
    for slot in layout["slots"]:
        x, y, z = slot["origin"]
        for dz in slot["local_z_levels"]:
            fill([x, y, x + WIDTH - 1, y + LENGTH - 1], z + dz, "berth", slot["id"])
    for x, y in ((58, 62), (172, 62), (58, 184), (172, 184), (84, 193), (144, 193)):
        for dx, dy in ((0, 0), (1, 0), (0, 1)):
            grid[x + dx, y + dy, 5] = "crate", "Raid station study"
    for x, y in ((60, 90), (170, 94), (60, 152), (170, 156), (96, 194), (136, 194)):
        grid[x, y, 5] = "dirt", "Raid station study"
    for (dx, dy, dz), kind in train_levels().items():
        if dz == 0:
            area = "Dagger safe sustenance study" if dy <= 38 else "Dagger airlock study" if dy <= PROTECTED_END else "Dagger exposed ground study"
        else:
            area = f'Dagger {layout["levels"][dz]["id"]} exposed study'
        grid[40 + dx, 48 + dy, 1 + dz] = kind, area
    return grid, layout


def render_dmm(grid):
    entries = sorted(set(grid.values()))
    alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    keys = {entry: alphabet[i // len(alphabet)] + alphabet[i % len(alphabet)] for i, entry in enumerate(entries)}
    lines = ["// Generated by tests/dagger_map/build_map.py. Inactive map study."]
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
    print("PASS: deterministic Dagger draft outputs" if args.check else "Wrote Dagger draft map, layout and template descriptor")


if __name__ == "__main__":
    main()
