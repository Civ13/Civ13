"""Playable native layout for a verified offline bundle.

The offline bundle's map.dmm deliberately carries terrain only; abstract
FOOD/WOOD/STONE sites, cavern fungus and surface exits live in the sidecar.
This module adds one deterministic native supply layer on top of that layout
and writes a separate DMM, so the bundle contract and its pinned hashes stay
unchanged:

- STONE sites become flint rocks, WOOD sites trees, FOOD sites berry bushes,
  and about a third of surface FOOD sites also get a small game spawner.
- Open ground gets tall grass (twine) and small bushes (seeds); some water gets
  fish.
- Cavern floors become open dirt (the offline layout leaves them as solid
  mineable rock) and get rocks, mushroom seeds, mushrooms on fungus cells and dead
  trees on WOOD sites; every surface exit pair becomes a ladder pair.
- The IR's per-cell elevation becomes the map metadata's elevation profile
  (docs/elevation.md) with a temperature lapse rate, so hills and mined
  mountains are colder and rain over cold enough high ground settles as snow.

Placement depends only on the IR seed and coordinates, never on Python's
random state, so the same bundle always gives the same DMM. The types used are
checked against the DM source before writing. Nothing here launches the game.
"""
import hashlib
import json
import re
from pathlib import Path

from .bundle import verify_bundle
from .dmm_export import project
from .io import read_json
from .repo_source import read_source
from .source_audit import parse_classic

SUPPLY_VERSION = "civ13-native-supplies/2"
ELEVATION_VERSION = "civ13-region-elevation/1"
METADATA = "/obj/map_metadata/nomads"
# Standard atmosphere, the value docs/elevation.md suggests; 0..10 C per km.
DEFAULT_LAPSE = 6.5
MAX_ELEVATION_REGIONS = 256
# Coarser bands are tried in turn until the profile fits the 256-rectangle cap.
ELEVATION_STEPS = (1, 50, 100, 200, 500, 1000)
ROCK = "/obj/structure/wild/rock"
BUSH = "/obj/structure/wild/smallbush"
# Stocked forage: starts with berries and regrows them (berries.dm).
BERRY_BUSH = "/obj/structure/wild/berrybush/tinto"
TALL_GRASS = "/obj/structure/wild/tallgrass"
FISH = "/obj/structure/fish"
# Drops wood when chopped. Cave WOOD sites can sit in narrow passages, so the
# placed tree neither blocks movement nor sight.
DEAD_TREE = "/obj/structure/wild/tree/dead_tree"
DEAD_TREE_ATOM = DEAD_TREE + "{density = 0; opacity = 0}"
MUSHROOM_SEEDS = "/obj/item/stack/farming/seeds/mushroom"
MUSHROOM = "/obj/item/weapon/reagent_containers/food/snacks/grown/mushroom"
TURKEYS = "/obj/effect/spawner/mobspawner/turkeys"
BOARS = "/obj/effect/spawner/mobspawner/boars"
LADDER_DOWN = "/obj/structure/multiz/ladder/ww2"
LADDER_UP = "/obj/structure/multiz/ladder/ww2/up"
# The offline layout puts cave floors on /turf/floor/dirt/underground, which is
# solid, opaque, mineable rock. Open cave floor is plain dirt, the turf mining
# leaves behind.
SOLID_ROCK_TURF = "/turf/floor/dirt/underground"
CAVE_FLOOR_TURF = "/turf/floor/dirt"
TREE_BY_BIOME = {"ARID": "/obj/structure/wild/tree/live_tree/pine", "COAST": "/obj/structure/wild/palm"}
BROADLEAF = "/obj/structure/wild/tree/live_tree"

# Declaration file for every type the layer can place.
SOURCES = {
    ROCK: "code/game/objects/structures/rocks.dm",
    BUSH: "code/game/objects/structures/wild.dm",
    BERRY_BUSH: "code/game/objects/structures/berries.dm",
    TALL_GRASS: "code/game/objects/structures/wild.dm",
    DEAD_TREE: "code/game/objects/structures/wild.dm",
    BROADLEAF: "code/game/objects/structures/wild.dm",
    TREE_BY_BIOME["ARID"]: "code/game/objects/structures/wild.dm",
    TREE_BY_BIOME["COAST"]: "code/game/objects/structures/wild.dm",
    FISH: "code/game/mob/living/simple_animal/friendly/static.dm",
    MUSHROOM_SEEDS: "code/game/objects/farming.dm",
    MUSHROOM: "code/modules/reagents/reagent_containers/food/grown.dm",
    TURKEYS: "code/game/objects/effects/spawner.dm",
    BOARS: "code/game/objects/effects/spawner.dm",
    LADDER_DOWN: "code/modules/multiz/structures.dm",
    LADDER_UP: "code/modules/multiz/structures.dm",
    CAVE_FLOOR_TURF: "code/game/turfs/flooring/flooring_premade.dm",
}

# Shares of eligible cells, from the classic nomads map (about 3% each of tall
# grass and small bushes over its land).
GRASS_SHARE = 0.03
BUSH_SHARE = 0.03
GAME_SHARE = 0.35
FRESH_FISH_SHARE = 0.008
SEA_FISH_SHARE = 0.003
MUSHROOM_SHARE = 0.25


def verify_types(catalog_root=None):
    texts = {}
    for typename, path in SOURCES.items():
        if path not in texts:
            texts[path] = read_source(path, catalog_root).decode("utf-8")
        if not re.search(r"^" + re.escape(typename) + r"\s*$", texts[path], re.M):
            raise ValueError("SUPPLY_TYPE_MISSING: " + typename)
    return True


def share(seed, x, y, z, salt):
    """A stable value in [0, 1) for one cell."""
    digest = hashlib.sha256(("%s|%s|%d|%d|%d" % (SUPPLY_VERSION, seed, x, y, z) + "|" + salt).encode()).digest()
    return int.from_bytes(digest[:8], "big") / 2 ** 64


def surface_supply(c, value, game):
    if c["water"] != "NONE":
        if c["water"] == "SEA":
            return [FISH] if value < SEA_FISH_SHARE else []
        return [FISH] if c["salinity"] == "FRESH" and value < FRESH_FISH_SHARE else []
    if c["terrain"] in {"MOUNTAIN", "ROCK"} or c["blocked"] or c["tree"] != "NONE":
        return []
    if c["resource"] == "STONE":
        return [ROCK]
    if c["resource"] == "WOOD":
        return [TREE_BY_BIOME.get(c["biome"], BROADLEAF)]
    if c["resource"] == "FOOD":
        atoms = [BERRY_BUSH]
        if game < GAME_SHARE:
            atoms.append(BOARS if c["biome"] in {"STEPPE", "ARID"} else TURKEYS)
        return atoms
    if c["terrain"] == "BEACH" or c["soil"] == "SAND":
        return []
    if value < GRASS_SHARE:
        return [TALL_GRASS]
    if value < GRASS_SHARE + BUSH_SHARE:
        return [BUSH]
    return []


def cavern_supply(c, value):
    if c["terrain"] != "CAVE_FLOOR" or c["water"] != "NONE":
        return []
    if c["tree"] == "FUNGUS":
        return [MUSHROOM] if value < MUSHROOM_SHARE else []
    if c["resource"] == "STONE":
        return [ROCK]
    if c["resource"] == "WOOD":
        return [DEAD_TREE_ATOM]
    if c["resource"] == "FOOD":
        return [MUSHROOM_SEEDS]
    return []


def playable_layout(doc):
    layout = project(doc)
    starts = {tuple(p) for p in doc["starts"]}
    portals = {}
    for pair in doc.get("portals", []):
        # Ladders pair by an id taken from the coordinates, so both ends must line up.
        if pair["a"][:2] != pair["b"][:2]:
            raise ValueError("PLAYABLE_PORTAL_ALIGNMENT")
        for end in (pair["a"], pair["b"]):
            portals[(end[0], end[1], end[2])] = pair
    counts = {}
    for layer, level in doc["layers"].items():
        z = level["native_z"]
        for y, row in enumerate(level["cells"]):
            for x, c in enumerate(row):
                added = []
                key = (x + 1, y + 1, z)
                if layer == "UNDERGROUND" and c["terrain"] == "CAVE_FLOOR" and c["water"] == "NONE":
                    atoms = layout[key].split(",")
                    if atoms.count(SOLID_ROCK_TURF) != 1:
                        raise ValueError("PLAYABLE_CAVE_TURF")
                    atoms[atoms.index(SOLID_ROCK_TURF)] = CAVE_FLOOR_TURF
                    layout[key] = ",".join(atoms)
                    counts["open cave floor"] = counts.get("open cave floor", 0) + 1
                pair = portals.get((x, y, layer))
                if pair is not None:
                    # One area id per pair, so each top ladder finds exactly its own bottom.
                    area = 'area_id = "generated-%d-%d"' % (x, y)
                    added.append((LADDER_DOWN if layer == "SURFACE" else LADDER_UP) + "{" + area + "}")
                elif (x, y, layer) not in starts:
                    value = share(doc["seed"], x, y, z, "cell")
                    if layer == "UNDERGROUND" and doc["profile"] == "UNDERGROUND_CAVERN":
                        added = cavern_supply(c, value)
                    elif layer == "SURFACE":
                        added = surface_supply(c, value, share(doc["seed"], x, y, z, "game"))
                if added:
                    layout[key] = ",".join(added) + "," + layout[key]
                    for atom in added:
                        name = atom.split("{")[0]
                        counts[name] = counts.get(name, 0) + 1
    return layout, counts


def _number(value):
    return str(int(value)) if value == int(value) else repr(float(value))


def _rectangles(grid, default):
    """Disjoint rectangles covering every non-default cell of one plane.

    Equal runs in a row are merged with the identical run in the row above, so
    a ring of bands around a peak costs a few rectangles per row, not per tile.
    grid[y][x] is IR order (row zero is south); output is one-based DM x/y.
    """
    done, open_runs = [], {}
    for y, row in enumerate(grid):
        runs, x = {}, 0
        while x < len(row):
            value, start = row[x], x
            while x < len(row) and row[x] == value:
                x += 1
            if value != default:
                runs[(start, x - 1, value)] = True
        for run, rect in list(open_runs.items()):
            if run not in runs:
                done.append(rect)
                del open_runs[run]
        for run in runs:
            if run in open_runs:
                open_runs[run][3] = y
            else:
                open_runs[run] = [run[0], run[1], y, y, run[2]]
    done.extend(open_runs.values())
    return [{"x1": a + 1, "x2": b + 1, "y1": c + 1, "y2": d + 1, "metres": m} for a, b, c, d, m in done]


def elevation_profile(doc, lapse=DEFAULT_LAPSE):
    """Return the metadata elevation profile for an IR document.

    Elevations are rounded to the finest band that fits in the DM limit of 256
    rectangles; of the three most common bands, the one needing the fewest
    rectangles becomes the default. At the coarsest band
    the largest rectangles are kept and the rest fall back to the default.
    """
    if not isinstance(lapse, (int, float)) or isinstance(lapse, bool) or not 0 <= lapse <= 10:
        raise ValueError("ELEVATION_LAPSE: 0..10 C per km")
    for step in ELEVATION_STEPS:
        planes, counts = {}, {}
        for layer, level in doc["layers"].items():
            grid = [[int(round(c["elevation_m"] / step)) * step for c in row] for row in level["cells"]]
            planes[level["native_z"]] = grid
            for row in grid:
                for value in row:
                    counts[value] = counts.get(value, 0) + 1
        # Try the three most common bands as the default and keep the one that
        # needs the fewest rectangles (a uniform cave plane can outnumber the
        # surface's sea level); ties prefer the band nearest sea level.
        best = None
        for default in sorted(counts, key=lambda v: (-counts[v], abs(v), v))[:3]:
            found = []
            for z in sorted(planes):
                found.extend(dict(r, z=z) for r in _rectangles(planes[z], default))
            if best is None or len(found) < len(best[1]):
                best = (default, found)
        default, regions = best
        if len(regions) <= MAX_ELEVATION_REGIONS:
            break
    dropped = max(0, len(regions) - MAX_ELEVATION_REGIONS)
    if dropped:
        regions.sort(key=lambda r: (-(r["x2"] - r["x1"] + 1) * (r["y2"] - r["y1"] + 1), r["z"], r["y1"], r["x1"]))
        regions = regions[:MAX_ELEVATION_REGIONS]
    regions.sort(key=lambda r: (r["z"], r["y1"], r["x1"]))
    return {"version": ELEVATION_VERSION, "lapse_c_per_km": lapse, "default_metres": default,
            "step_m": step, "regions": regions, "dropped": dropped}


def elevation_text(profile):
    """The profile as the metadata's elevation_regions_text: rows of
    "x1 x2 y1 y2 z metres" joined by "|" (no commas or semicolons, so the DMM
    tile definition and its comma-split readers stay intact)."""
    return "|".join(" ".join(_number(r[k]) for k in ("x1", "x2", "y1", "y2", "z", "metres")) for r in profile["regions"])


def metadata_atom(profile):
    fields = []
    if profile["default_metres"]:
        fields.append("elevation_default_metres = " + _number(profile["default_metres"]))
    if profile["regions"]:
        fields.append('elevation_regions_text = "' + elevation_text(profile) + '"')
    if profile["lapse_c_per_km"] and (profile["regions"] or profile["default_metres"]):
        fields.append("elevation_lapse_c_per_km = " + _number(profile["lapse_c_per_km"]))
    return METADATA + ("{" + "; ".join(fields) + "}" if fields else "")


def apply_elevation(layout, profile):
    keys = [k for k, recipe in layout.items() if METADATA in recipe.split(",")]
    if len(keys) != 1:
        raise ValueError("PLAYABLE_METADATA")
    atoms = layout[keys[0]].split(",")
    atoms[atoms.index(METADATA)] = metadata_atom(profile)
    layout[keys[0]] = ",".join(atoms)
    return keys[0]


def write_text(doc, layout):
    recipes = sorted(set(layout.values()))
    alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    width = 2 if len(recipes) <= 52 ** 2 else 3
    if len(recipes) > 52 ** width:
        raise ValueError("DICTIONARY_CAPACITY")

    def key(n):
        return "".join(alphabet[(n // 52 ** power) % 52] for power in reversed(range(width)))

    keys = {recipe: key(i) for i, recipe in enumerate(recipes)}
    lines = ["// Generated playable layout (%s). Rebuild it from the bundle; do not edit by hand." % SUPPLY_VERSION]
    lines.extend('"' + keys[recipe] + '" = (' + recipe + ")" for recipe in recipes)
    for z in [1, 2]:
        lines.extend(["", "(1,1,%d) = {\"" % z])
        for y in range(doc["height"], 0, -1):
            lines.append("".join(keys[layout[(x, y, z)]] for x in range(1, doc["width"] + 1)))
        lines.append('"}')
    return "\n".join(lines) + "\n"


def build(folder, catalog_root=None, lapse=DEFAULT_LAPSE):
    """Verify an offline bundle and return (dmm text, report) for its playable layout."""
    folder = Path(folder)
    verify_bundle(folder, catalog_root)
    verify_types(catalog_root)
    doc = read_json(folder / "map.ir.json")
    layout, counts = playable_layout(doc)
    profile = elevation_profile(doc, lapse)
    apply_elevation(layout, profile)
    text = write_text(doc, layout)
    _, parsed, dims = parse_classic(text)
    if parsed != layout or sorted(dims) != [[doc["width"], doc["height"], 1], [doc["width"], doc["height"], 2]]:
        raise ValueError("PLAYABLE_LAYOUT_MISMATCH")
    report = {
        "schema": "civ13-playable-map/1",
        "supply_version": SUPPLY_VERSION,
        "profile": doc["profile"],
        "seed": doc["seed"],
        "width": doc["width"],
        "height": doc["height"],
        "bundle_dmm_sha256": hashlib.sha256((folder / "map.dmm").read_bytes()).hexdigest(),
        "dmm_sha256": hashlib.sha256(text.encode()).hexdigest(),
        "starts": len(doc["starts"]),
        "ladder_pairs": len(doc.get("portals", [])),
        "supplies": dict(sorted(counts.items())),
        "elevation": {k: profile[k] for k in ("version", "lapse_c_per_km", "default_metres", "step_m", "dropped")}
                     | {"regions": len(profile["regions"])},
    }
    return text, report


def write(folder, out, catalog_root=None, lapse=DEFAULT_LAPSE):
    out = Path(out)
    if out.suffix.lower() != ".dmm":
        raise ValueError("playable output must end in .dmm")
    report_path = out.with_suffix(".playable.json")
    if out.exists() or report_path.exists():
        raise ValueError("output exists: " + str(out))
    text, report = build(folder, catalog_root, lapse)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(text, encoding="utf-8", newline="\n")
    report_path.write_text(json.dumps(report, indent=1, sort_keys=True) + "\n", encoding="utf-8", newline="\n")
    return dict(report, path=str(out), report=str(report_path))
