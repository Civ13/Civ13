"""Static geometry checks for the inactive Hauler raid study, never runtime acceptance."""
from __future__ import annotations

import argparse
from collections import deque
import json
from pathlib import Path
import re
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_map as home  # noqa: E402
import build_raid_train as source  # noqa: E402

STRUCTURE = {"hull", "pillar", "cage"}
DOORS = {"door", "breach"}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def rectangle(bounds):
    require(len(bounds) == 4 and all(type(v) is int for v in bounds), "invalid rectangle")
    x0, y0, x1, y1 = bounds
    require(x0 <= x1 and y0 <= y1, "inverted rectangle")
    return {(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)}


def parse_dmm(text, world, palette_source=source.PALETTE):
    """Parse this deliberately restricted source format; reject unknown atoms."""
    definitions = {}
    blocks = {}
    remainder = re.sub(r"//[^\n]*", "", text)
    pattern = r'^"([A-Za-z]+)"\s*=\s*\(([^\n]*)\)\s*$'
    palette = {value[0]: kind for kind, value in palette_source.items()}
    for match in re.finditer(pattern, remainder, re.M):
        key, atoms = match.groups()
        require(key not in definitions, "duplicate DMM key")
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


def passable(kind):
    return source.PALETTE[kind][2]


def train_tiles(grid, layout):
    ox, oy, oz = layout["target_train"]["origin"]
    return {(x, y): grid[ox + x, oy + y, oz][0] for y in range(source.TRAIN_LENGTH) for x in range(source.TRAIN_WIDTH)}


def check_train(layout, tiles):
    train = layout["target_train"]
    require(train["width"] == source.TRAIN_WIDTH and train["length"] == source.TRAIN_LENGTH, "target train dimensions")
    require(train["locked_doors_permitted"] is False and train["doors_breachable_without_pass"] is True, "target door policy")
    require(train["inherits_dagger_boundary_protection"] is False, "target train must not inherit Dagger protection")
    require(not any(kind == "locked_door" for kind in tiles.values()), "target compartment door locked")
    require(layout["structure"]["locked_doors"] == [], "declared locked doors")
    openings = {tuple(p) for section in layout["sections"] for p in section["platform_openings"]}
    ox, oy, _ = train["origin"]
    for x in range(source.TRAIN_WIDTH):
        require(tiles[x, 0] == "hull" and tiles[x, source.TRAIN_LENGTH - 1] == "hull", "train end walls")
    for y in range(source.TRAIN_LENGTH):
        for x in (0, source.TRAIN_WIDTH - 1):
            if (ox + x, oy + y) in openings:
                require(tiles[x, y] in ("floor", "door"), "declared side opening is blocked")
            else:
                require(tiles[x, y] == "hull", "undeclared hull opening")
    for y in train["coupling_rows"]:
        for x in range(source.TRAIN_WIDTH):
            require(tiles[x, y] == ("breach" if x in train["breach_x"] else "hull"), "coupling row must be hull with breach doors")
    sections = layout["sections"]
    require([s["id"] for s in sections] == [s["id"] for s in source.SECTIONS], "section order")
    tiers = [s["tier"] for s in sections]
    require(tiers == sorted(tiers) and tiers[0] < tiers[-1], "tiers must not fall toward the front")
    counts = [s["loot_anchor_count"] for s in sections]
    require(all(c >= 1 for c in counts), "every section needs loot anchors")
    require(counts[-1] > counts[0], "front must offer more loot anchors than the rear")
    covered = set()
    for index, section in enumerate(sections):
        x0, y0, x1, y1 = section["bounds"]
        require(x0 == 0 and x1 == source.TRAIN_WIDTH - 1, "sections span the train width")
        if index:
            require(y0 == sections[index - 1]["bounds"][3] + 2 and (y0 - 1) in train["coupling_rows"], "sections separated by one coupling row")
        interior = rectangle([x0 + 1, y0 + 1, x1 - 1, y1 - 1])
        covered |= rectangle(section["bounds"])
        anchors = {tuple(p) for p in section["loot_anchors"]}
        require(anchors == {p for p in interior if tiles[p] in source.LOOT_KINDS}, f"loot anchors stale: {section['id']}")
        require(len(anchors) == section["loot_anchor_count"], f"loot anchor count stale: {section['id']}")
        require(section["loot_table"] is None, "map must not choose loot tables")
        for x, y in section["platform_openings"]:
            require(y0 <= y - oy <= y1, f"platform opening outside its section: {section['id']}")
    require(covered | {(x, y) for y in train["coupling_rows"] for x in range(source.TRAIN_WIDTH)} == set(tiles), "sections and couplings cover the train")
    # Every section must be reachable from the platform; with every breach door
    # closed, each section is isolated from its neighbours.
    platform = set()
    for entry in layout["platforms"]:
        platform |= rectangle(entry["bounds"])
    return platform


def check_station(layout, grid, tiles, platform):
    oz = layout["target_train"]["z"]
    level = {(x, y): kind for (x, y, z), (kind, _) in grid.items() if z == oz}
    walkable = {p for p, kind in level.items() if passable(kind)}
    reach = flood({min(platform)}, walkable)
    require(platform <= reach, "platforms and heads must connect")
    ox, oy, _ = layout["target_train"]["origin"]
    for section in layout["sections"]:
        x0, y0, x1, y1 = section["bounds"]
        interior = {(ox + x, oy + y) for x, y in rectangle([x0 + 1, y0 + 1, x1 - 1, y1 - 1])}
        require(interior & reach, f"section unreachable from the platform: {section['id']}")
        for x, y in section["loot_anchors"]:
            wx, wy = ox + x, oy + y
            require({(wx - 1, wy), (wx + 1, wy), (wx, wy - 1), (wx, wy + 1)} & reach, f"loot anchor unreachable: {section['id']}")
    closed = walkable - {(ox + x, oy + y) for (x, y), kind in tiles.items() if kind == "breach"}
    for index, section in enumerate(layout["sections"][:-1]):
        x0, y0, x1, y1 = section["bounds"]
        here = {(ox + x, oy + y) for x, y in rectangle([x0 + 1, y0 + 1, x1 - 1, y1 - 1])} & closed
        nx0, ny0, nx1, ny1 = layout["sections"][index + 1]["bounds"]
        there = {(ox + x, oy + y) for x, y in rectangle([nx0 + 1, ny0 + 1, nx1 - 1, ny1 - 1])} & closed
        inside = flood(here, closed - platform)
        require(not inside & there, f"closed breach doors do not separate {section['id']} from the next section")


def check_berths(layout, grid, platform):
    world = layout["world"]
    reserved = []
    train_cells = rectangle(layout["target_train"]["bounds"])
    for slot in layout["slots"]:
        require(slot["kind"] == "raid_berth", "slot kind")
        x, y, z = slot["origin"]
        footprint = rectangle([x, y, x + home.WIDTH - 1, y + home.LENGTH - 1])
        rect = rectangle(slot["reserved_bounds"])
        require(footprint <= rect, "reserved bounds cover the berth")
        b = slot["reserved_bounds"]
        require(b[0] >= 1 and b[1] >= 1 and b[2] <= world["width"] and b[3] <= world["height"], "berth inside world")
        require(slot["reserved_z"] == [z, z + home.TRAIN_LEVELS - 1] and slot["reserved_z"][1] <= world["levels"], "berth z interval")
        require(not (rect & platform) and not (rect & train_cells), "berth reservation overlaps shared space")
        for other in reserved:
            require(not (rect & other), "overlapping berth reservations")
        reserved.append(rect)
        for dz in range(home.TRAIN_LEVELS):
            for p in footprint:
                require(grid[p + (z + dz,)][0] == "berth", "berth footprint must be empty on every deck")
        port_x = x + home.WIDTH - 1 if slot["platform_side"] == "east" else x
        expected_ports = [[port_x, y + by] for b0, b1 in home.BOARDING_BANDS for by in range(b0, b1 + 1)]
        require(slot["boarding_ports"] == expected_ports, "boarding ports follow the Dagger boarding bands")
        bridge = {tuple(c) for c in slot["bridge_cells"]}
        require(all(grid[c][0] == "bridge" for c in bridge), "bridge cells missing")
        require(all(c[2] == z for c in bridge) and not any((c[0], c[1]) in footprint for c in bridge), "bridge cells inside berth or off deck")
        level = {(px, py): kind for (px, py, pz), (kind, _) in grid.items() if pz == z}
        walkable = {p for p, kind in level.items() if passable(kind)}
        for port in expected_ports:
            px, py = port
            step = (px + 1, py) if slot["platform_side"] == "east" else (px - 1, py)
            require(step + (z,) in bridge, "boarding port does not open onto its bridge")
            require(flood({step}, walkable - footprint) & platform, "bridge does not reach the platform")


def check_arrivals(layout, grid):
    """Overlay both complete Dagger drafts; every boarding port still routes to the platform."""
    composition = {p: kind for p, (kind, _) in grid.items()}
    home_tiles = home.train_levels()
    for slot in layout["slots"]:
        origin = slot["origin"]
        for (dx, dy, dz), kind in home_tiles.items():
            composition[origin[0] + dx, origin[1] + dy, origin[2] + dz] = kind
    merged = dict(source.PALETTE)
    merged.update({k: v for k, v in home.PALETTE.items() if k not in merged})
    walkable = {p for p, kind in composition.items() if merged[kind][2]}
    platform = set()
    for entry in layout["platforms"]:
        platform |= {p + (entry["z"],) for p in rectangle(entry["bounds"])}
    visited = set(platform) & walkable
    pending = deque(visited)
    while pending:
        x, y, z = pending.popleft()
        for p in ((x - 1, y, z), (x + 1, y, z), (x, y - 1, z), (x, y + 1, z)):
            if p in walkable and p not in visited:
                visited.add(p)
                pending.append(p)
    for slot in layout["slots"]:
        for px, py in slot["boarding_ports"]:
            require((px, py, slot["origin"][2]) in visited, "docked Dagger boarding port cannot reach the platform")
    for a in layout["slots"]:
        for b in layout["slots"]:
            if a["id"] < b["id"]:
                fa = rectangle([a["origin"][0], a["origin"][1], a["origin"][0] + home.WIDTH - 1, a["origin"][1] + home.LENGTH - 1])
                fb = rectangle([b["origin"][0], b["origin"][1], b["origin"][0] + home.WIDTH - 1, b["origin"][1] + home.LENGTH - 1])
                require(not fa & fb, "both Dagger arrivals overlap")


def check_declarations(layout, tiles):
    structure = layout["structure"]
    actual = {
        "hull_tiles": [list(p) for p, kind in sorted(tiles.items()) if kind in STRUCTURE],
        "breach_doors": [list(p) for p, kind in sorted(tiles.items()) if kind == "breach"],
        "side_doors": [list(p) for p, kind in sorted(tiles.items()) if kind == "door"],
    }
    for key, value in actual.items():
        require(structure[key] == value, f"structure list stale: {key}")
    require(structure["enforced_by_this_map"] is False and layout["raid_access"]["enforced_by_this_map"] is False, "map claims enforcement")
    access = layout["raid_access"]
    require(access["required_inputs"] == ["loaded_fuel", "target_section_boarding_pass"], "raid inputs")
    for key in ("balance_values", "loot_tables", "pass_prices", "fuel_quantities", "extraction_timer", "travel_time"):
        require(access[key] is None, f"map must not choose {key}")
    require(access["target_compartment_doors"]["breachable_without_pass"] is True, "breachable door requirement")
    template = layout["home_template"]
    require(template == {"template_id": home.manifest()["template_id"], "width": home.WIDTH, "height": home.LENGTH,
                         "decks": home.TRAIN_LEVELS, "boarding_bands": [list(b) for b in home.BOARDING_BANDS]}, "home template binding")
    require(len(layout["slots"]) == 2 and layout["berth_geometry_groups"][0]["exclusive_reservation"] is False, "berth pair geometry")


def validate(layout, dmm):
    require(layout["schema_version"] == 1 and layout["study_id"] == "dagger_raid_hauler_v1", "layout schema")
    world = layout["world"]
    require(world == {"width": source.SIZE, "height": source.SIZE, "levels": source.WORLD_LEVELS}, "world dimensions")
    grid = parse_dmm(dmm, world)
    tiles = train_tiles(grid, layout)
    platform = check_train(layout, tiles)
    check_station(layout, grid, tiles, platform)
    check_berths(layout, grid, platform)
    check_arrivals(layout, grid)
    check_declarations(layout, tiles)
    require(tiles == source.hauler(), "target train differs from the generator")
    return {"sections": len(layout["sections"]), "berths": len(layout["slots"]),
            "loot_anchors": sum(s["loot_anchor_count"] for s in layout["sections"]),
            "breach_doors": len(layout["structure"]["breach_doors"])}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.parse_args()
    layout = json.loads(source.LAYOUT_PATH.read_text(encoding="utf-8"))
    result = validate(layout, source.MAP_PATH.read_text(encoding="utf-8"))
    print("PASS static Hauler raid checks: " + json.dumps(result))


if __name__ == "__main__":
    main()
