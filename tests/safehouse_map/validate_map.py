"""Static geometry checks for the inactive safehouse study, never runtime acceptance."""
from __future__ import annotations

import argparse
from collections import deque
import json
from pathlib import Path
import re

import build_map as source

ROOT = Path(__file__).resolve().parents[2]
FURNITURE = {"house_marker", "secure_crate", "workbench", "car_workshop", "generator", "bed", "crate",
             "rack", "table", "chair", "anvil", "sink", "toilet"}
STRUCTURE = {"hull", "wall"}
DOORS = {"door", "gate", "inner_gate"}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def rectangle(bounds):
    require(len(bounds) == 4 and all(type(v) is int for v in bounds), "invalid rectangle")
    x0, y0, x1, y1 = bounds
    require(x0 <= x1 and y0 <= y1, "inverted rectangle")
    return {(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)}


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
    block = r'\(1,1,(\d+)\)\s*=\s*\{"\n([^"\r]*)"\}'
    for match in re.finditer(block, remainder):
        z = int(match[1])
        require(z not in blocks, "duplicate DMM level")
        rows = match[2].splitlines()
        require(len(rows) == world["height"], "DMM row count")
        require(all(len(row) == world["width"] * key_width for row in rows), "DMM row width")
        blocks[z] = rows
    remainder = re.sub(block, "", remainder)
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
        neighbors = {(x - 1, y, z), (x + 1, y, z), (x, y - 1, z), (x, y + 1, z)} | vertical.get(point, set())
        for neighbor in neighbors:
            if neighbor in passable and neighbor not in visited:
                visited.add(neighbor)
                pending.append(neighbor)
    return visited


def local_volume(grid, origin):
    """Project the prototype slot back into local coordinates."""
    ox, oy, oz = origin
    volume = {}
    for z in range(source.DECKS):
        for y in range(source.LENGTH):
            for x in range(source.WIDTH):
                volume[x, y, z] = grid[ox + x, oy + y, oz + z][0]
    return volume


def validate_template(layout, template):
    """Check a separate descriptor against a validated map, not a runtime ABI."""
    expected = source.template_descriptor(layout)
    require(json.dumps(template, sort_keys=True) == json.dumps(expected, sort_keys=True),
            "template descriptor differs from the map contract")
    require(template["berths"] == [], "a safehouse template has no raid berths")


def check_airlock(layout, volume):
    airlock = layout["protected"]["airlock"]
    outer, inner = tuple(airlock["outer_door"]), tuple(airlock["inner_door"])
    interior = rectangle(airlock["interior_bounds"])
    require(volume[outer + (0,)] == "gate" and volume[inner + (0,)] == "inner_gate", "airlock gate placeholders")
    require(outer[1] == 0 and 0 < inner[1] and inner not in interior and outer not in interior, "airlock gates sit on its boundary walls")
    require(all(volume[p + (0,)] == "safe" for p in interior), "airlock interior clear")
    shell = rectangle(airlock["bounds"]) - interior - {outer, inner}
    require(all(volume[p + (0,)] in STRUCTURE for p in shell), "airlock enclosure")
    ground = {(x, y) for (x, y, z) in volume if z == 0}
    passable = {p for p in ground if source.PALETTE[volume[p + (0,)]][2] and volume[p + (0,)] not in ("gate", "inner_gate")}
    interior_reach = flood3({p + (0,) for p in interior}, {p + (0,) for p in passable | interior})
    require(not any(p[:2] not in interior for p in interior_reach), "closed airlock doors isolate the vestibule")
    perimeter = {p for p in ground if p[0] in (0, source.WIDTH - 1) or p[1] in (0, source.LENGTH - 1)}
    require(all(volume[p + (0,)] in STRUCTURE for p in perimeter - {outer}), "ground hull breach")
    require(layout["protected"]["boundary_gates"] == [list(outer)], "boundary gates")
    upper_perimeter = {p for p in ground if p[0] in (0, source.WIDTH - 1) or p[1] in (0, source.LENGTH - 1)}
    require(all(volume[p + (1,)] in STRUCTURE for p in upper_perimeter), "upper hull breach")


def check_rooms(layout, volume):
    passable = {p for p, kind in volume.items() if source.PALETTE[kind][2]}
    links = []
    endpoints = set()
    for stair in layout["stairs"]:
        lower, upper = tuple(stair["lower"]), tuple(stair["upper"])
        require(lower[:2] == upper[:2] and upper[2] == lower[2] + 1, "stair alignment")
        require(volume[lower] == stair["lower_palette"] and volume[upper] == stair["upper_palette"], "stair endpoints")
        require(lower not in endpoints and upper not in endpoints, "shared stair endpoint")
        endpoints |= {lower, upper}
        links.append((lower, upper))
    require(len(layout["stairs"]) == 2, "two stair routes")
    arrival = tuple(layout["anchors"]["arrival"])
    reach = flood3({arrival}, passable, links)
    for room in layout["rooms"]:
        floor = {p + (room["local_z"],) for p in rectangle(room["bounds"])}
        require(floor & reach, f"room unreachable: {room['id']}")
        require(not any(volume[p] == "hull" for p in floor), f"room contains hull: {room['id']}")
    for name, anchor in layout["anchors"].items():
        x, y, z = anchor
        neighbors = {(x - 1, y, z), (x + 1, y, z), (x, y - 1, z), (x, y + 1, z)}
        require((x, y, z) in reach or neighbors & reach, f"anchor unreachable: {name}")
    for pad in layout["build_pads"]:
        require(all(volume[p + (pad["local_z"],)] == "pad" for p in rectangle(pad["bounds"])), f"build pad not clear: {pad['id']}")
    for clear in layout["keep_clear"]:
        floor = {p + (clear["local_z"],) for p in rectangle(clear["bounds"])}
        require(floor <= passable and not any(volume[p] in FURNITURE | STRUCTURE for p in floor), f"keep clear obstructed: {clear['id']}")
    markers = layout["account_markers"]
    for key, kind in (("house_marker", "house_marker"), ("secure_crate", "secure_crate"),
                      ("workbench", "workbench"), ("car_workshop", "car_workshop")):
        require(volume[tuple(markers[key])] == kind, f"account marker missing: {key}")
        require(sum(1 for value in volume.values() if value == kind) == 1, f"account marker duplicated: {key}")
    require(tuple(markers["secure_crate"])[:2] in {(markers["house_marker"][0] + dx, markers["house_marker"][1] + dy)
                                                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))}, "secure crate beside the terminal")
    sustenance = set(layout["protected"]["sustenance"]["rooms"])
    require(sustenance <= {room["id"] for room in layout["rooms"]}, "sustenance rooms exist")
    require(len(reach) >= 0.6 * len(passable), "most floor is reachable")
    return reach


def check_slots(layout, grid, volume):
    world = layout["world"]
    reserved = []
    for slot in layout["slots"]:
        require(slot["kind"] == "home", "slot kind")
        x, y, z = slot["origin"]
        bounds = slot["reserved_bounds"]
        rect = rectangle(bounds)
        require(rect >= rectangle([x, y, x + source.WIDTH - 1, y + source.LENGTH - 1]), "reserved bounds cover the footprint")
        require(bounds[0] >= 1 and bounds[1] >= 1 and bounds[2] <= world["width"] and bounds[3] <= world["height"], "slot inside world")
        require(slot["reserved_z"] == [z, z + source.DECKS - 1] and z + source.DECKS - 1 <= world["levels"], "slot z interval")
        for other in reserved:
            require(not (rect & other), "overlapping slot reservations")
        reserved.append(rect)
        if slot["id"] != layout["prototype"]["slot"]:
            for dz in range(source.DECKS):
                for p in rectangle([x, y, x + source.WIDTH - 1, y + source.LENGTH - 1]):
                    require(grid[p + (z + dz,)][0] in ("void", "hull", "yard"), "empty demonstration slot")


def check_protection(layout, volume):
    protection = layout["structure_protection"]
    actual = {
        "wall_tiles": [list(p) for p, kind in sorted(volume.items()) if kind in STRUCTURE],
        "door_tiles": [list(p) for p, kind in sorted(volume.items()) if kind in DOORS],
        "stair_tiles": [list(p) for p, kind in sorted(volume.items()) if kind.startswith("stair_")],
    }
    for key, value in actual.items():
        require(protection[key] == value, f"structure protection list stale: {key}")
    require(protection["enforced_by_this_map"] is False and layout["protected"]["enforced_by_this_map"] is False, "map claims enforcement")
    require(protection["player_built_contents_inherit_protection"] is False, "player-built contents must not inherit protection")
    for flag in ("interlocked", "authorize_from_either_side"):
        require(layout["protected"]["airlock"][flag] is True, f"airlock requirement flag: {flag}")
    require(layout["protected"]["airlock"]["enforced_by_this_map"] is False, "airlock claims enforcement")


def validate(layout, dmm, template=None):
    require(layout["schema_version"] == 1 and layout["kind"] == "safehouse", "layout schema")
    require(layout["template_id"] == source.TEMPLATE_ID and layout["template_revision"] == source.TEMPLATE_REVISION, "template identity")
    world = layout["world"]
    require(world == {"width": source.SIZE, "height": source.SIZE, "levels": source.WORLD_LEVELS}, "world dimensions")
    x0, y0, x1, y1 = layout["footprint"]["bounds"]
    require((x0, y0, x1, y1) == (0, 0, source.WIDTH - 1, source.LENGTH - 1), "footprint bounds")
    require(layout["footprint"]["local_z_levels"] == list(range(source.DECKS)), "footprint decks")
    require(layout["footprint"]["mask_rows_south_to_north"] == ["1" * source.WIDTH] * source.LENGTH, "footprint mask")
    require([level["local_z"] for level in layout["levels"]] == list(range(source.DECKS)), "level order")
    require(all(level["protected"] for level in layout["levels"]), "every deck is protected")
    grid = parse_dmm(dmm, world)
    prototype = next(s for s in layout["slots"] if s["id"] == layout["prototype"]["slot"])
    volume = local_volume(grid, prototype["origin"])
    check_airlock(layout, volume)
    reach = check_rooms(layout, volume)
    check_slots(layout, grid, volume)
    check_protection(layout, volume)
    require(volume == source.deck_levels(), "prototype volume differs from the generator")
    if template is not None:
        validate_template(layout, template)
    return {"reachable_cells": len(reach), "rooms": len(layout["rooms"]), "slots": len(layout["slots"]),
            "furniture": sum(1 for kind in volume.values() if kind in FURNITURE)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.parse_args()
    layout = json.loads(source.LAYOUT_PATH.read_text(encoding="utf-8"))
    template = json.loads(source.TEMPLATE_PATH.read_text(encoding="utf-8"))
    result = validate(layout, source.MAP_PATH.read_text(encoding="utf-8"), template)
    print("PASS static safehouse checks: " + json.dumps(result))


if __name__ == "__main__":
    main()
