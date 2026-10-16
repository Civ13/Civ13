"""Static geometry checks for the inactive Dagger study, never runtime acceptance."""
from __future__ import annotations

import argparse
from collections import deque
from functools import lru_cache
import json
from pathlib import Path
import re

import build_map as source

ROOT = Path(__file__).resolve().parents[2]


def require(condition, message):
    if not condition:
        raise ValueError(message)


def rectangle(bounds):
    require(len(bounds) == 4 and all(type(v) is int for v in bounds), "invalid rectangle")
    x0, y0, x1, y1 = bounds
    require(x0 <= x1 and y0 <= y1, "inverted rectangle")
    return {(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)}


def mask(bounds, rows):
    x0, y0, x1, y1 = bounds
    require(len(rows) == y1 - y0 + 1, "mask height")
    require(all(len(row) == x1 - x0 + 1 and set(row) <= {"0", "1"} for row in rows), "mask width or values")
    return {(x0 + x, y0 + y) for y, row in enumerate(rows) for x, value in enumerate(row) if value == "1"}


def parse_dmm(text, world):
    """Parse this deliberately restricted source format; reject unknown atoms."""
    definitions = {}
    blocks = {}
    remainder = re.sub(r"//[^\n]*", "", text)
    pattern = r'^"([A-Za-z]+)"\s*=\s*\(([^\n]*)\)\s*$'
    palette = {value[0]: kind for kind, value in source.PALETTE.items()}
    for match in re.finditer(pattern, remainder, re.M):
        key, atoms = match.groups()
        require(key not in definitions, "duplicate DMM key")
        # Standalone map readers do not preprocess DM macros such as TRUE.
        # This draft deliberately permits only string/number/null overrides.
        assignments = re.findall(r'\b\w+\s*=\s*("[^"]*"|[^;}]+)', atoms)
        require(all(re.fullmatch(r'"[^"]*"|-?\d+(?:\.\d+)?|null', value.strip())
                    for value in assignments), "DMM overrides must use literal values")
        area_match = re.fullmatch(r'(.*),/area\{name = "([^"]+)"; location = 0\}', atoms)
        require(area_match is not None, "DMM objects/turf/area order or active area")
        body, area = area_match.groups()
        require(body in palette, "unknown, active or reordered DMM atoms")
        definitions[key] = (palette[body], area)
    remainder = re.sub(pattern, "", remainder, flags=re.M)
    require(bool(definitions), "missing DMM definitions")
    widths = {len(key) for key in definitions}
    require(len(widths) == 1, "mixed DMM key lengths")
    key_width = widths.pop()
    for match in re.finditer(r'\(1,1,(\d+)\)\s*=\s*\{"\n([^"\r]*)"\}', remainder):
        z = int(match[1])
        require(z not in blocks, "duplicate DMM level")
        rows = match[2].splitlines()
        require(len(rows) == world["height"], "DMM row count")
        require(all(len(row) == world["width"] * key_width for row in rows), "DMM row width")
        blocks[z] = rows
    remainder = re.sub(r'\(1,1,(\d+)\)\s*=\s*\{"\n([^"\r]*)"\}', "", remainder)
    require(not remainder.strip(), "unparsed DMM source")
    require(set(blocks) == set(range(1, world["levels"] + 1)), "DMM levels")
    grid = {}
    for z, rows in blocks.items():
        for row_index, row in enumerate(rows):
            for x in range(world["width"]):
                key = row[x * key_width:(x + 1) * key_width]
                require(key in definitions, "undefined DMM key")
                grid[x + 1, world["height"] - row_index, z] = definitions[key]
    return grid


def flood(start, passable):
    visited = set(start) & passable
    pending = deque(visited)
    while pending:
        x, y = pending.popleft()
        for p in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if p in passable and p not in visited:
                visited.add(p)
                pending.append(p)
    return visited


def extrude(cells, levels):
    return {(x, y, z) for z in levels for x, y in cells}


def translated(points, origin):
    return {tuple(a + b for a, b in zip(point, origin)) for point in points}


def flood3(start, passable, links=()):
    vertical = {}
    for lower, upper in links:
        vertical.setdefault(lower, set()).add(upper)
        vertical.setdefault(upper, set()).add(lower)
    visited = set(start) & passable
    pending = deque(visited)
    while pending:
        point = pending.popleft()
        x, y, z = point
        neighbors = {(x-1, y, z), (x+1, y, z), (x, y-1, z), (x, y+1, z)} | vertical.get(point, set())
        for neighbor in neighbors:
            if neighbor in passable and neighbor not in visited:
                visited.add(neighbor)
                pending.append(neighbor)
    return visited


def stair_links(layout, actual):
    links, endpoints, ids, areas = [], set(), set(), set()
    for stair in layout["stairs"]:
        lower, upper = tuple(stair["lower"]), tuple(stair["upper"])
        require(stair["id"] not in ids and stair["pair_area_id"] not in areas, "duplicate stair identity")
        ids.add(stair["id"])
        areas.add(stair["pair_area_id"])
        require(len(lower) == len(upper) == 3 and lower[:2] == upper[:2] and upper[2] == lower[2] + 1,
                "stairs must pair adjacent local decks at matching XY")
        require(lower in actual and upper in actual and not {lower, upper} & endpoints, "stair endpoint outside footprint or duplicated")
        endpoints.update((lower, upper))
        for point, field in ((lower, "lower_palette"), (upper, "upper_palette")):
            palette = stair[field]
            require(actual[point] == palette and source.PALETTE[palette][2], "missing or blocked stair endpoint")
            require(f'area_id = "{stair["pair_area_id"]}"' in source.PALETTE[palette][0], "stair pair area identity mismatch")
        links.append((lower, upper))
    require(len(links) == 6 and {p for p, kind in actual.items() if kind.startswith("stair_")} == endpoints,
            "all six stair pairs must be declared exactly")
    return links


def check_arrivals(layout, grid, actual, ports):
    """Overlay both complete 3D trains; only declared stairs link decks."""
    raids = [s for s in layout["slots"] if s["kind"] == "raid_berth"]
    levels = {z for slot in raids for z in range(slot["reserved_z"][0], slot["reserved_z"][1] + 1)}
    composition = {p: kind for p, (kind, area) in grid.items() if p[2] in levels}
    links = []
    for arrival in raids:
        origin = arrival["origin"]
        composition.update({tuple(a+b for a, b in zip(p, origin)): kind for p, kind in actual.items()})
        for stair in layout["stairs"]:
            lower, upper = (tuple(a+b for a,b in zip(stair[field], origin)) for field in ("lower", "upper"))
            links.append((lower, upper))
    composed_passable = {p for p, kind in composition.items() if source.PALETTE[kind][2]}
    shared_cells = set().union(*(extrude(rectangle(a["bounds"]), [a["z"]]) for a in layout["shared_access"]))
    require(bool(shared_cells), "missing shared arrival access")
    shared_reachable = flood3([min(shared_cells)], composed_passable, links)
    require(shared_cells <= shared_reachable, "simultaneous arrivals disconnect shared platform")
    for arrival in raids:
        require(translated(extrude(ports, [0]), arrival["origin"]) <= shared_reachable, "simultaneous arrivals cannot route to platform")
        require(translated({p for p, kind in actual.items() if source.PALETTE[kind][2]}, arrival["origin"]) <= shared_reachable,
                "simultaneous arrival deck or roof route blocked")


def check_core_separation(layout, passable, links):
    protected = extrude(rectangle(layout["protected"]["bounds"]), [0])
    eligible = extrude(rectangle(layout["protected"]["sustenance"]["bounds"]), [0])
    outside = passable - protected
    for field in ("inner_door", "outer_door"):
        door = tuple(layout["protected"]["airlock"][field]) + (0,)
        require(not flood3(outside, passable - {door}, links) & eligible,
                "closed airlock door permits a 3D protected-core bypass")


def _validate(layout, dmm_text, root):
    require(layout["schema_version"] == 2, "unsupported schema")
    require(layout["coordinates"]["rotation_degrees"] == 0, "unsupported rotation")
    world = layout["world"]
    grid = parse_dmm(dmm_text.replace("\r\n", "\n"), world)
    bounds = layout["footprint"]["bounds"]
    footprint = rectangle(bounds)
    require(mask(bounds, layout["footprint"]["mask_rows_south_to_north"]) == footprint, "full rectangular footprint required")
    require(footprint == set(source.train()), "footprint differs from source train")
    levels = layout["footprint"]["local_z_levels"]
    require(levels == [0, 1, 2, 3], "four local decks required")
    footprint3 = extrude(footprint, levels)
    require(set(source.train_levels()) == footprint3, "all-layer source footprint mismatch")
    require([(level["id"], level["local_z"]) for level in layout["levels"]] == list(zip(("ground", "upper_1", "upper_2", "roof"), levels))
            and all(level["build_supported"] is True and level["protected"] is (level["local_z"] == 0) for level in layout["levels"]), "deck identities or build/protection declaration mismatch")
    slots = layout["slots"]
    require(len({s["id"] for s in slots}) == len(slots), "duplicate slot ID")
    raids = [s for s in slots if s["kind"] == "raid_berth"]
    require(len(raids) == 2 and len({s["id"] for s in raids}) == 2, "exactly two distinct raid berths required")
    require("reservation_groups" not in layout, "whole-pair reservation claim is forbidden")
    groups = layout["berth_geometry_groups"]
    require(len(groups) == 1 and isinstance(groups[0]["id"], str) and bool(groups[0]["id"]), "exactly one named berth geometry group required")
    group = groups[0]
    require(len(group["slot_ids"]) == 2 and len(set(group["slot_ids"])) == 2
            and set(group["slot_ids"]) == {s["id"] for s in raids},
            "geometry group must cover both distinct raid berths only")
    require(group["exclusive_reservation"] is False, "whole-pair exclusive reservation is forbidden")
    policy = layout["reservation_policy"]
    require(policy["scope"] == "selected_berth_and_whole_footprint", "reservation scope must select only one berth and whole footprint")
    require(policy["atomic_reservation_before_load_or_move"] is True, "own berth and footprint reservation must be atomic")
    require(policy["other_berths_remain_available"] is True, "other berths must remain available")
    require(policy["enforced_by_this_map"] is False, "map must not claim runtime reservation enforcement")
    require(policy["all_levels_together"] is True, "reservation must claim all levels together")
    reservations = []
    placed_masks = []
    for slot in slots:
        ox, oy, z = slot["origin"]
        require(1 <= z <= world["levels"], "slot z out of bounds")
        rz0, rz1 = slot["reserved_z"]
        require(slot["local_z_levels"] == levels and [rz0, rz1] == [z, z + 3], "slot must reserve all four relative decks")
        reserved = extrude(rectangle(slot["reserved_bounds"]), range(rz0, rz1 + 1))
        require(all(1 <= x <= world["width"] and 1 <= y <= world["height"] and 1 <= zz <= world["levels"] for x, y, zz in reserved), "reservation out of bounds")
        placed = translated(footprint3, (ox, oy, z))
        require(placed <= reserved, "full footprint does not fit reservation")
        for other in reservations:
            require(not reserved & other, "padded reservations overlap")
        reservations.append(reserved)
        placed_masks.append(placed)
        rows = slot.get("berth_mask_rows_south_to_north")
        if rows is not None:
            require(mask(bounds, rows) == footprint, "berth mask gaps")
        if slot["id"] != layout["prototype"]["slot"]:
            require(all(grid[p] == ("berth", slot["id"]) for p in placed), "destination DMM is occupied or mask has gaps")
    by_id = {s["id"]: s for s in slots}
    require(layout["prototype"]["slot"] in by_id, "missing prototype slot")
    for access in layout["shared_access"]:
        access_cells = rectangle(access["bounds"])
        az = access["z"]
        require(all(1 <= x <= world["width"] and 1 <= y <= world["height"] for x, y in access_cells), "shared access out of bounds")
        for reserved in reservations:
            require(not extrude(access_cells, [az]) & reserved, "shared access encroaches reservation exclusion")
        require(all(source.PALETTE[grid[x, y, az][0]][2] for x, y in access_cells), "shared access blocked")
    bands = layout["exposed"]["boarding_bands"]
    band_ports = {(x, y) for lo, hi in bands for y in range(lo, hi + 1) for x in (bounds[0], bounds[2])}
    require({tuple(p) for p in layout["exposed"]["boarding_ports"]} == band_ports, "boarding ports must cover complete bands")
    for slot in raids:
        ox, oy, z = slot["origin"]
        anchors = slot["platform_anchors"]
        require(len(anchors) == 2 and len({tuple(p) for p in anchors}) == 2, "two distinct platform anchors required")
        side_x = ox + bounds[2] if slot["platform_side"] == "east" else ox + bounds[0]
        require(slot["platform_side"] in ("east", "west"), "invalid platform side")
        require(slot["boarding_width"] == 3 and all(hi - lo + 1 == slot["boarding_width"] for lo, hi in bands), "boarding band width")
        require(slot["platform_gap_tiles"] == 6, "platform gap width")
        expected_y = {oy + (lo + hi) // 2 for lo, hi in bands}
        require({a[1] for a in anchors} == expected_y, "platform anchors miss boarding ports")
        expected_bridges = set()
        for ax, ay, az in anchors:
            offset = slot["platform_gap_tiles"] + 1
            require(az == z and ax == side_x + (offset if slot["platform_side"] == "east" else -offset), "platform anchor offset")
            require(grid.get((ax, ay, az), (None,))[0] == "platform", "platform anchor missing from DMM")
            xs = range(side_x + 1, ax + 1) if ax > side_x else range(ax, side_x)
            bridge = {(x, y) for x in xs for y in range(ay - 1, ay + 2)}
            expected_bridges.update((x, y, z) for x, y in bridge)
            require(all(source.PALETTE[grid[x, y, z][0]][2] for x, y in bridge), "blocked anchor bridge")
            for other in placed_masks:
                require(not extrude(bridge, [z]) & other, "anchor bridge overlaps train mask")
        require(len(slot["bridge_cells"]) == len(expected_bridges) and {tuple(p) for p in slot["bridge_cells"]} == expected_bridges, "bridge mask gaps or offset")
    slot = by_id[layout["prototype"]["slot"]]
    ox, oy, z = slot["origin"]
    actual = {p: grid[ox + p[0], oy + p[1], z][0] for p in footprint}
    actual3 = {p: grid[ox + p[0], oy + p[1], z + p[2]][0] for p in footprint3}
    links = stair_links(layout, actual3)
    identity = layout["stair_identity_contract"]
    require(identity["draft_pair_ids_only"] is True
            and identity["runtime_pair_identity"] == "stable_train_id plus relative stair link ID"
            and identity["rebind_after_restore_or_move"] is True
            and identity["validate_actual_endpoint_occupancy"] is True
            and identity["enforced_by_this_map"] is False, "stair identity requires stable train/link rebinding and actual endpoint validation")
    passable3 = {p for p, kind in actual3.items() if source.PALETTE[kind][2]}
    reachable3 = flood3([tuple(layout["exposed"]["boarding_ports"][0]) + (0,)], passable3, links)
    require(passable3 <= reachable3, "disconnected deck or roof floor")
    passable = {p for p, kind in actual.items() if source.PALETTE[kind][2]}
    protected = rectangle(layout["protected"]["bounds"])
    require(layout["protected"]["local_z"] == 0, "protected compartment belongs on ground deck")
    require(layout["protected"]["region_id"] == "dagger_party_safe_compartment", "safe compartment identity")
    sustenance = layout["protected"]["sustenance"]
    for field in ("nutrition", "hydration"):
        require(sustenance[field] == "passive_increase", "sustenance must passively increase nutrition and hydration")
    require(sustenance["cap"] == "normal_healthy_limits" and sustenance["rate"] is None, "sustenance healthy cap and unspecified rate required")
    for field in ("requires_actual_occupancy", "requires_party_authorization", "suppresses_ordinary_drain", "single_metabolism_update", "resume_ordinary_on_exit"):
        require(sustenance[field] is True, f"sustenance requires {field}")
    require(sustenance["enforced_by_this_map"] is False and layout["protected"]["while_raid_docked"] is True, "sustenance declaration must apply docked without runtime claim")
    eligible = rectangle(sustenance["bounds"])
    require(eligible <= protected, "sustenance bounds outside protected region")
    airlock = layout["protected"]["airlock"]
    vestibule = rectangle(airlock["bounds"])
    interior = rectangle(airlock["interior_bounds"])
    ix0, iy0, ix1, iy1 = airlock["interior_bounds"]
    require(ix1 - ix0 + 1 == 4 and iy1 - iy0 + 1 == 5, "airlock interior must be four by five")
    inner, outer = tuple(airlock["inner_door"]), tuple(airlock["outer_door"])
    require(len(interior) == 20 and interior <= vestibule <= protected and not vestibule & eligible, "airlock must have twenty interior tiles outside sustenance zone")
    require(inner != outer and inner in vestibule and outer in vestibule, "airlock distinct single doors required")
    require(actual[inner] == "inner_gate" and actual[outer] == "gate"
            and {p for p, kind in actual.items() if kind in ("gate", "inner_gate")} == {inner, outer}, "airlock requires exactly two single door atoms")
    require(all(actual[p] == "safe" for p in interior), "airlock interior must be empty safe floor")
    require(airlock["policy"] == "owning_party_only" and airlock["interlocked"] is True
            and airlock["authorize_from_either_side"] is True and airlock["enforced_by_this_map"] is False
            and airlock["safe_egress_policy"] is None, "airlock authorization/interlock declaration or unresolved egress mismatch")
    exposed = rectangle(layout["exposed"]["bounds"])
    require(not protected & exposed and protected | exposed == footprint, "protected/exposed partition")
    gates = {tuple(p) for p in layout["protected"]["boundary_gates"]}
    ports = {tuple(p) for p in layout["exposed"]["boarding_ports"]}
    require(gates and gates <= protected and all(actual[p] == "gate" for p in gates), "missing boundary gate")
    require(gates == {outer}, "outer airlock door must be the sole protected boundary gate")
    require(ports <= exposed and not ports & protected and all(actual[p] == "door" for p in ports), "unsafe boarding ports")
    edge = {p for p in footprint if any(q not in footprint for q in ((p[0]-1,p[1]), (p[0]+1,p[1]), (p[0],p[1]-1), (p[0],p[1]+1)))}
    require(not edge & protected & passable, "protected exterior is open")
    reachable = flood([min(ports)], passable)
    require(passable <= reachable, "disconnected internal floor")
    require(not flood(exposed & passable, passable - gates) & protected, "route bypasses boundary gate")
    require(interior <= reachable, "airlock interior unreachable")
    for door in (inner, outer):
        require(not flood(exposed & passable, passable - {door}) & eligible, "closed airlock door does not separate eligible compartment")
    check_core_separation(layout, passable3, links)
    for p in layout["anchors"].values():
        require(tuple(p) in reachable, "unreachable anchor")
    for room in layout["rooms"]:
        room_cells = rectangle(room["bounds"])
        local_z = room["local_z"]
        region = (protected if room["protected"] else exposed) if local_z == 0 else footprint
        require(local_z in levels and (local_z == 0 or room["protected"] is False) and room_cells <= region, "room region mismatch")
        require(bool(extrude(room_cells, [local_z]) & reachable3), "unreachable room")
    boundary = layout["protected"]["boundary_protection"]
    expected_boundary = set()
    for ring in (protected, vestibule):
        expected_boundary |= {p for p in ring if any(q not in ring for q in ((p[0]-1,p[1]), (p[0]+1,p[1]), (p[0],p[1]-1), (p[0],p[1]+1)))}
    expected_walls = {p for p in expected_boundary if actual[p] in ("hull", "pillar")}
    walls = [tuple(p) for p in boundary["wall_tiles"]]
    doors = [tuple(p) for p in boundary["door_tiles"]]
    require(len(walls) == len(set(walls)) and set(walls) == expected_walls
            and len(doors) == 2 and set(doors) == {inner, outer}, "boundary protection must cover exact protected walls and airlock doors")
    require(boundary["mode"] == "deny_mutation_not_health_only"
            and set(boundary["denied_paths"]) == {"damage", "deconstruction", "forced_entry", "removal", "replacement"}, "boundary protection must deny all mutation paths")
    require(boundary["preserve_on_transport_and_restore"] is True and boundary["exposed_walls_protected"] is True
            and boundary["enforced_by_this_map"] is False, "boundary protection scope or runtime declaration mismatch")
    vertical_boundary = layout["protected"]["vertical_boundary"]
    require(vertical_boundary["floor_local_z"] == 0 and vertical_boundary["ceiling_local_z"] == 1
            and rectangle(vertical_boundary["bounds"]) == protected
            and vertical_boundary["no_uncontrolled_vertical_entry"] is True
            and vertical_boundary["enforced_by_this_map"] is False, "protected vertical boundary declaration mismatch")
    require(all(not (set(pair) & extrude(protected, [0])) for pair in links), "stairs bypass protected vertical boundary")
    structural = layout["structure_protection"]
    floor_layers = structural["floor_layers"]
    require(len(floor_layers) == 4 and {layer["local_z"] for layer in floor_layers} == set(levels)
            and all(rectangle(layer["bounds"]) == footprint for layer in floor_layers), "permanent floors must cover every entire deck")
    for field, expected in (("wall_tiles", {p for p, kind in actual3.items() if kind == "hull"}),
                            ("pillar_tiles", {p for p, kind in actual3.items() if kind == "pillar"}),
                            ("door_tiles", {p for p, kind in actual3.items() if kind in ("door", "gate", "inner_gate")}),
                            ("stair_tiles", {p for pair in links for p in pair})):
        points = [tuple(p) for p in structural[field]]
        require(len(points) == len(set(points)) and set(points) == expected, "permanent structure mask must cover exact walls pillars doors and stairs")
    require(structural["mode"] == "deny_mutation_not_health_only"
            and set(structural["denied_paths"]) == {"damage", "deconstruction", "forced_entry", "removal", "replacement"}
            and structural["preserve_on_transport_and_restore"] is True
            and structural["player_built_contents_inherit_protection"] is False
            and structural["enforced_by_this_map"] is False, "permanent structure protection must exclude player contents and remain declarative")
    transit = layout["transit_3d_contract"]
    require(transit["operations"] == ["reserve", "save", "restore", "move", "retire"]
            and all(transit[field] is True for field in ("all_levels_together", "stable_relative_z", "bounded_allocation", "post_callback_revalidation", "rollback_or_quarantine"))
            and transit["enforced_by_this_map"] is False, "3D transit must preserve all decks with bounded atomic lifecycle declarations")
    infrastructure = layout["protected"]["infrastructure"]
    rooms = {room["id"]: room for room in layout["rooms"]}
    for name, room_id, palette in (("helm_controls", "helm", "helm_control"), ("engine_room", "engine", "engine_mount")):
        marker = infrastructure[name]
        point = tuple(marker["marker"])
        require(marker["room_id"] == room_id and rooms[room_id]["protected"] is True
                and point in rectangle(rooms[room_id]["bounds"]) & eligible
                and marker["palette"] == palette and actual[point] == palette
                and sum(kind == palette for kind in actual.values()) == 1, "infrastructure marker must occur once in intended protected room")
        require(marker["upgradeable"] is True, "protected infrastructure must declare upgrades")
        neighbors = {(point[0]-1,point[1]), (point[0]+1,point[1]), (point[0],point[1]-1), (point[0],point[1]+1)}
        require(bool(neighbors & reachable), "protected infrastructure is unreachable")
    require(infrastructure["upgrade_costs"] is None and infrastructure["upgrade_effects"] is None
            and infrastructure["enforced_by_this_map"] is False, "infrastructure balance unspecified and runtime disabled")
    raid = layout["raid_access"]
    inputs = {"loaded_fuel", "target_section_boarding_pass"}
    require(len(raid["required_inputs"]) == 2 and set(raid["required_inputs"]) == inputs, "raid requires loaded fuel and target-section pass")
    require(raid["front_sections"] == {"loot": "better", "entry_cost": "higher"}
            and raid["balance_values"] is None and raid["enforced_by_this_map"] is False, "raid front rewards/costs must remain unbalanced declarations")
    target = raid["target_compartment_doors"]
    require(target["breachable_without_pass"] is True and target["inherits_dagger_boundary_protection"] is False, "target doors must remain breachable without Dagger protection")
    transaction = raid["transaction"]
    require(transaction["authority"] == "server" and transaction["atomic_commit"] is True
            and transaction["atomic_refund"] is True and transaction["idempotent"] is True
            and len(transaction["inputs"]) == 2 and set(transaction["inputs"]) == inputs,
            "raid transaction requires server atomic idempotent fuel/pass commit and refund")
    require(transaction["commit_point"] is None and transaction["refund_policy"] is None
            and transaction["failure_resolution"] == "rollback_or_quarantine_without_duplicate_value"
            and transaction["enforced_by_this_map"] is False, "raid transaction policy unresolved without duplicate value or runtime claim")
    sequence = raid["extraction_sequence"]
    states = ["reservation", "call", "arrival", "boarding", "departure"]
    require(sequence["states"] == states and set(sequence["requirements"]) == set(states)
            and all(isinstance(sequence["requirements"][state], str) and sequence["requirements"][state].strip() for state in states), "raid sequence requires all ordered states and requirements")
    require(sequence["timings"] is None and sequence["enforced_by_this_map"] is False, "raid sequence timings unspecified and runtime disabled")
    for pad in layout["build_pads"] + layout["keep_clear"]:
        require(extrude(rectangle(pad["bounds"]), [pad["local_z"]]) <= reachable3, "blocked build pad or keep-clear route")
    occupied_pads = set().union(*(extrude(rectangle(pad["bounds"]), [pad["local_z"]]) for pad in layout["build_pads"]))
    clear_routes = set().union(*(extrude(rectangle(route["bounds"]), [route["local_z"]]) for route in layout["keep_clear"]))
    require(not occupied_pads & clear_routes, "build pads overlap main routes")
    remaining = flood3([min(ports) + (0,)], passable3 - occupied_pads, links)
    require(extrude(ports, [0]) | clear_routes <= remaining and all(tuple(p) + (0,) in remaining for p in layout["anchors"].values())
            and all(point in remaining for pair in links for point in pair), "occupied build pads cut main routes")
    check_arrivals(layout, grid, actual3, ports)
    include = (Path(root) / "civ13.dme").read_text(encoding="utf-8")
    require(not re.search(r'^\s*#include\s+[^\n]*dagger_train_home', include, re.M | re.I), "draft map registered in civ13.dme")
    expected_dmm, expected_layout = expected_outputs()
    require(layout == expected_layout, "layout is not reproducible from generator")
    require(dmm_text.replace("\r\n", "\n") == expected_dmm, "DMM is not reproducible from generator")
    return {"slots": len(slots), "raid_berths": len(raids), "reachable_train_tiles": len(reachable3), "train_decks": len(levels)}


@lru_cache(maxsize=1)
def expected_outputs():
    grid, layout = source.build()
    return source.render_dmm(grid), layout


def validate(layout, dmm_text, root=ROOT):
    try:
        return _validate(layout, dmm_text, root)
    except (KeyError, TypeError, IndexError) as error:
        raise ValueError(f"malformed layout: {error}") from error


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--layout", type=Path, default=source.LAYOUT_PATH)
    parser.add_argument("--map", type=Path, default=source.MAP_PATH)
    args = parser.parse_args()
    try:
        result = validate(json.loads(args.layout.read_text(encoding="utf-8")), args.map.read_text(encoding="utf-8"))
    except (ValueError, KeyError, TypeError, IndexError) as error:
        raise SystemExit(f"FAIL: {error}") from error
    print(f"PASS: static Dagger geometry {result}; runtime protection unimplemented")


if __name__ == "__main__":
    main()
