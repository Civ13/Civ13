"""Read-only DMM resource inventory. This does not establish player reachability."""
import collections
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[1]
MAPS = ("continental", "pangea", "new_world", "mediterranean", "gaia", "europe")
CATALOGS = {"sea", "temperate", "tundra", "taiga", "desert", "semiarid", "savanna", "jungle"}


def inherited_values(path, variable):
    values = {}
    current = None
    for line in path.read_text(encoding="utf-8-sig").splitlines():
        if line.lstrip().startswith("//"):
            continue
        if line.startswith("/"):
            current = line.strip() if "(" not in line else None
        elif current:
            match = re.fullmatch(r'\s+(?:var/)?' + variable + r'\s*=\s*("[^"]*"|TRUE|FALSE)\s*(?://.*)?', line)
            if match:
                values[current] = match[1].strip('"')
    return values


def resolve(values, path):
    original = path
    while path:
        if path in values:
            return values[path]
        path = path.rsplit("/", 1)[0]
    raise ValueError(f"Unresolved inherited value: {original}")


def read_map(text):
    entries = re.findall(r'^"([A-Za-z]+)"\s*=\s*(\([^\n]+\))\s*$', text, re.M)
    definitions = dict(entries)
    if len(entries) != len(definitions):
        raise ValueError("Duplicate tile definitions")
    if not definitions or len({len(key) for key in definitions}) != 1:
        raise ValueError("Missing definitions or mixed tile-key lengths")
    length = len(next(iter(definitions)))
    tiles = {}
    blocks = list(re.finditer(r'\((\d+),(\d+),(\d+)\)\s*=\s*\{"\n(.*?)\n"\}', text, re.S))
    if not blocks:
        raise ValueError("No supported DMM grid blocks")
    for block in blocks:
        x0, y0, z = map(int, block.group(1, 2, 3))
        rows = block[4].splitlines()
        if len({len(row) for row in rows}) != 1 or len(rows[0]) % length:
            raise ValueError("Inconsistent grid width")
        for row_index, row in enumerate(rows):
            for offset in range(0, len(row), length):
                position = (x0 + offset // length, y0 + len(rows) - row_index - 1, z)
                if position in tiles:
                    raise ValueError("Overlapping map grid blocks")
                key = row[offset:offset + length]
                if key not in definitions:
                    raise ValueError(f"Undefined tile key: {key}")
                tiles[position] = definitions[key]
    return tiles


def audit(name, climates, salt):
    tiles = read_map((ROOT / f"maps/nomads/nomads_{name}.dmm").read_text(encoding="utf-8-sig"))
    bushes = collections.Counter()
    seeds = collections.Counter()
    water = set()
    soil = {}
    spawns = 0
    for position, definition in tiles.items():
        area = re.search(r'(/area/[A-Za-z0-9_/]+)', definition)
        turf = re.search(r'(/turf/[A-Za-z0-9_/]+)', definition)
        if not area or not turf:
            raise ValueError(f"Missing turf/area at {position}")
        area_override = re.search(r'/area/[A-Za-z0-9_/]+\{[^}]*\bclimate\s*=\s*"([^"]+)"', definition)
        climate = area_override[1] if area_override else resolve(climates, area[1])
        bushes[climate] += definition.count("/obj/structure/wild/smallbush")
        seeds.update(re.findall(r'/obj/item/stack/farming/seeds/([A-Za-z0-9_/]+)', definition))
        spawns += int('name = "JoinLateCiv"' in definition)
        # Only clear, directly ploughable plain grass/dirt and flooded dirt count.
        if turf[1] in ("/turf/floor/grass", "/turf/floor/dirt", "/turf/floor/dirt/flooded") and "/obj/" not in definition and "/mob/" not in definition:
            soil[position] = climate
        if turf[1].startswith("/turf/floor/beach/water") and "/ice" not in turf[1]:
            override = re.search(r'\bsalty\s*=\s*(TRUE|FALSE|0|1)', definition)
            salty = override[1] in ("TRUE", "1") if override else resolve(salt, turf[1]) == "TRUE"
            if not salty:
                water.add(position)
    unsupported = {climate for climate, count in bushes.items() if count and climate not in CATALOGS}
    if unsupported:
        raise ValueError(f"Unsupported bush climates: {sorted(unsupported)}")
    candidates = []
    for position, climate in soil.items():
        x, y, z = position
        source = next(((x + dx, y + dy, z) for dx in range(-2, 3) for dy in range(-2, 3) if (x + dx, y + dy, z) in water), None)
        if source:
            candidates.append({"soil": position, "fresh_water": source, "climate": climate})
    return {"map": name, "placed_tiles": len(tiles), "spawn_landmarks": spawns,
            "small_bushes_by_climate": dict(sorted((k, v) for k, v in bushes.items() if v)),
            "placed_seed_stacks": dict(sorted(seeds.items())),
            "fresh_non_ice_water_tiles": len(water), "clear_soil_near_water": len(candidates),
            "witness": candidates[0] if candidates else None}


if __name__ == "__main__":
    climates = inherited_values(ROOT / "code/game/area/caribbean.dm", "climate")
    climates.update(inherited_values(ROOT / "code/game/area/areas.dm", "climate"))
    salt = inherited_values(ROOT / "code/game/turfs/floor_types.dm", "salty")
    results = [audit(name, climates, salt) for name in MAPS]
    print(json.dumps({"acceptance": "static placed-resource inventory only; no route, tools, research or season acceptance", "maps": results}, indent=2))
