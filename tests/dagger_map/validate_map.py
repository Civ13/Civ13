"""Static geometry checks for the inactive Dagger study, never runtime acceptance."""
from __future__ import annotations

import argparse
from collections import deque
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


def check_arrivals(layout, grid, actual, ports):
    """Overlay both trains onto parsed empty destinations for route analysis."""
    raids = [s for s in layout["slots"] if s["kind"] == "raid_berth"]
    for raid_z in {s["origin"][2] for s in raids}:
        composition = {(x, y): kind for (x, y, zz), (kind, area) in grid.items() if zz == raid_z}
        for arrival in raids:
            ax, ay, az = arrival["origin"]
            if az == raid_z:
                composition.update({(ax + x, ay + y): kind for (x, y), kind in actual.items()})
        composed_passable = {p for p, kind in composition.items() if source.PALETTE[kind][2]}
        shared_cells = set().union(*(rectangle(a["bounds"]) for a in layout["shared_access"] if a["z"] == raid_z))
        require(bool(shared_cells), "missing shared arrival access")
        shared_reachable = flood([next(iter(shared_cells))], composed_passable)
        require(shared_cells <= shared_reachable, "simultaneous arrivals disconnect shared platform")
        for arrival in raids:
            ax, ay, az = arrival["origin"]
            if az != raid_z:
                continue
            require({(ax + x, ay + y) for x, y in ports} <= shared_reachable, "simultaneous arrivals cannot route to platform")
            require(all((ax + p[0], ay + p[1]) in shared_reachable for p in layout["anchors"].values()), "simultaneous arrival internal route blocked")


def _validate(layout, dmm_text, root):
    require(layout["schema_version"] == 1, "unsupported schema")
    require(layout["coordinates"]["rotation_degrees"] == 0, "unsupported rotation")
    world = layout["world"]
    grid = parse_dmm(dmm_text.replace("\r\n", "\n"), world)
    bounds = layout["footprint"]["bounds"]
    footprint = rectangle(bounds)
    require(mask(bounds, layout["footprint"]["mask_rows_south_to_north"]) == footprint, "full rectangular footprint required")
    require(footprint == set(source.train()), "footprint differs from source train")
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
    reservations = []
    placed_masks = []
    for slot in slots:
        ox, oy, z = slot["origin"]
        require(1 <= z <= world["levels"], "slot z out of bounds")
        reserved = rectangle(slot["reserved_bounds"])
        require(all(1 <= x <= world["width"] and 1 <= y <= world["height"] for x, y in reserved), "reservation out of bounds")
        placed = {(ox + x, oy + y) for x, y in footprint}
        require(placed <= reserved, "full footprint does not fit reservation")
        for other_z, other in reservations:
            require(z != other_z or not reserved & other, "padded reservations overlap")
        reservations.append((z, reserved))
        placed_masks.append((z, placed))
        rows = slot.get("berth_mask_rows_south_to_north")
        if rows is not None:
            require(mask(bounds, rows) == footprint, "berth mask gaps")
        if slot["id"] != layout["prototype"]["slot"]:
            require(all(grid[x, y, z] == ("berth", slot["id"]) for x, y in placed), "destination DMM is occupied or mask has gaps")
    by_id = {s["id"]: s for s in slots}
    require(layout["prototype"]["slot"] in by_id, "missing prototype slot")
    for access in layout["shared_access"]:
        access_cells = rectangle(access["bounds"])
        az = access["z"]
        require(all(1 <= x <= world["width"] and 1 <= y <= world["height"] for x, y in access_cells), "shared access out of bounds")
        for rz, reserved in reservations:
            require(az != rz or not access_cells & reserved, "shared access encroaches reservation exclusion")
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
            for other_z, other in placed_masks:
                require(z != other_z or not bridge & other, "anchor bridge overlaps train mask")
        require(len(slot["bridge_cells"]) == len(expected_bridges) and {tuple(p) for p in slot["bridge_cells"]} == expected_bridges, "bridge mask gaps or offset")
    slot = by_id[layout["prototype"]["slot"]]
    ox, oy, z = slot["origin"]
    actual = {p: grid[ox + p[0], oy + p[1], z][0] for p in footprint}
    passable = {p for p, kind in actual.items() if source.PALETTE[kind][2]}
    protected = rectangle(layout["protected"]["bounds"])
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
    for p in layout["anchors"].values():
        require(tuple(p) in reachable, "unreachable anchor")
    for room in layout["rooms"]:
        room_cells = rectangle(room["bounds"])
        require(room_cells <= (protected if room["protected"] else exposed), "room region mismatch")
        require(bool(room_cells & reachable), "unreachable room")
    boundary = layout["protected"]["boundary_protection"]
    expected_boundary = set()
    for ring in (protected, vestibule):
        expected_boundary |= {p for p in ring if any(q not in ring for q in ((p[0]-1,p[1]), (p[0]+1,p[1]), (p[0],p[1]-1), (p[0],p[1]+1)))}
    expected_walls = {p for p in expected_boundary if actual[p] == "hull"}
    walls = [tuple(p) for p in boundary["wall_tiles"]]
    doors = [tuple(p) for p in boundary["door_tiles"]]
    require(len(walls) == len(set(walls)) and set(walls) == expected_walls
            and len(doors) == 2 and set(doors) == {inner, outer}, "boundary protection must cover exact protected walls and airlock doors")
    require(boundary["mode"] == "deny_mutation_not_health_only"
            and set(boundary["denied_paths"]) == {"damage", "deconstruction", "forced_entry", "removal", "replacement"}, "boundary protection must deny all mutation paths")
    require(boundary["preserve_on_transport_and_restore"] is True and boundary["exposed_walls_protected"] is False
            and boundary["enforced_by_this_map"] is False, "boundary protection scope or runtime declaration mismatch")
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
        require(rectangle(pad["bounds"]) <= reachable, "blocked build pad or keep-clear route")
    occupied_pads = set().union(*(rectangle(pad["bounds"]) for pad in layout["build_pads"]))
    clear_routes = set().union(*(rectangle(route["bounds"]) for route in layout["keep_clear"]))
    require(not occupied_pads & clear_routes, "build pads overlap main routes")
    remaining = flood([min(ports)], passable - occupied_pads)
    require(ports | clear_routes <= remaining and all(tuple(p) in remaining for p in layout["anchors"].values()), "occupied build pads cut main routes")
    check_arrivals(layout, grid, actual, ports)
    include = (Path(root) / "civ13.dme").read_text(encoding="utf-8")
    require(not re.search(r'^\s*#include\s+[^\n]*dagger_train_home', include, re.M | re.I), "draft map registered in civ13.dme")
    expected_grid, expected_layout = source.build()
    require(layout == expected_layout, "layout is not reproducible from generator")
    require(dmm_text.replace("\r\n", "\n") == source.render_dmm(expected_grid), "DMM is not reproducible from generator")
    return {"slots": len(slots), "raid_berths": len(raids), "reachable_train_tiles": len(reachable)}


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
