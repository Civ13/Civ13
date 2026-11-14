"""Expedition lands: a playable region map from a world-chart template.

The world chart (docs/world-chart.md) keeps one template per discovered land:
biome, land type, size, the coasts that face open water, features, resources
and a seed. This module turns a template into a generator configuration, runs
the offline generator (retrying with derived seeds when a candidate is
rejected), writes the playable layout and then gives it the biome's look: the
area (which sets the in-game climate), ground turfs and trees.

Ore richness and food density follow the size class: smaller lands are given
more stone and supply sites per land tile, larger lands more forage. The
template's ore richness and kinds, rare finds and game animals are written to
the land report for the slot world to apply on load
(code/modules/naval/land_resources.dm).

Same template, same land: everything depends on the template's seed. Nothing
here launches the game. Run it with `python3 -m tools.procedural_maps land`.
"""
import hashlib
import json
import re
from math import isqrt
import time
from copy import deepcopy
from pathlib import Path

from .bundle import write_bundle
from .configuration import relief_preset, validate_config
from .dmm_export import TREES
from .generator import generate
from .io import json_text, new_output
from .playable import (SURFACE_AREA, apply_elevation, elevation_profile, playable_layout,
                       verify_types, write_text, DEFAULT_LAPSE)
from .repo_source import read_source
from .source_audit import parse_classic
from .terrain_files import write_terrain_files
from .validator import MAX_SIDE, unchanged

LAND_VERSION = "civ13-expedition-land/2"
MAX_ATTEMPTS = 8
# A land's world holds both planes of its map. The largest world measured on
# BYOND 516.1688 so far is about 1.04 million cells (the Americas drafts: a
# reload peak near half the 32-bit memory limit), so a land may not ask for
# more than this without a new measurement.
LAND_PLANES = 2
MEASURED_CELLS = 1050000
SIZES = ("TINY", "SMALL", "MEDIUM", "LARGE", "MASSIVE")
LAND_TYPES = ("COASTAL_PLAIN", "RIVER_DELTA", "HIGHLANDS", "ARCHIPELAGO", "FJORD_COAST", "MARSH", "VOLCANIC_ISLE",
              "PLATEAU")
ISLAND_TYPES = ("ARCHIPELAGO", "VOLCANIC_ISLE")
GRASS, DIRT, SAND = "/turf/floor/grass", "/turf/floor/dirt", "/turf/floor/beach/sand"

# Per biome: the area (its climate), ground swaps for grass, dirt and sand,
# the trees that replace generated ones, the generator's biome mix and climate.
BIOME_SKINS = {
    "ICE_SHEET": dict(area="/area/caribbean/nomads/ice",
                      ground={GRASS: "/turf/floor/winter", DIRT: "/turf/floor/dirt/winter", SAND: "/turf/floor/winter"},
                      trees=["/obj/structure/wild/tree/live_tree/pine"], tree_share=0.15,
                      mix={"STEPPE": 100}, moisture=[20, 50], temperature=[-40, -5]),
    "TUNDRA": dict(area="/area/caribbean/nomads/tundra",
                   ground={GRASS: "/turf/floor/winter/grass", DIRT: "/turf/floor/dirt/winter"},
                   trees=["/obj/structure/wild/tree/live_tree/pine"], tree_share=0.35,
                   mix={"STEPPE": 70, "TEMPERATE": 30}, moisture=[20, 60], temperature=[-25, 10]),
    "BOREAL": dict(area="/area/caribbean/nomads/taiga", ground={},
                   trees=["/obj/structure/wild/tree/live_tree/pine"], tree_share=1.0,
                   mix={"TEMPERATE": 70, "STEPPE": 30}, moisture=[40, 80], temperature=[-15, 18]),
    "TEMPERATE_FOREST": dict(area="/area/caribbean/nomads/forest", ground={},
                             trees=["/obj/structure/wild/tree/live_tree"], tree_share=1.0,
                             mix={"TEMPERATE": 80, "LUSH": 20}, moisture=[45, 85], temperature=[0, 28]),
    "GRASSLAND": dict(area="/area/caribbean/nomads", ground={},
                      trees=["/obj/structure/wild/tree/live_tree"], tree_share=0.4,
                      mix={"STEPPE": 60, "TEMPERATE": 40}, moisture=[25, 60], temperature=[0, 30]),
    "DESERT": dict(area="/area/caribbean/nomads/desert",
                   ground={GRASS: "/turf/floor/beach/sand/desert", DIRT: "/turf/floor/dirt/dust",
                           SAND: "/turf/floor/beach/sand/desert"},
                   trees=["/obj/structure/wild/tree/cactus", "/obj/structure/wild/palm"], tree_share=0.3,
                   mix={"DESERT": 70, "ARID": 30}, moisture=[0, 25], temperature=[15, 45]),
    "SAVANNA": dict(area="/area/caribbean/nomads/forest/savanna", ground={DIRT: "/turf/floor/dirt/dust"},
                    trees=["/obj/structure/wild/tree/live_tree"], tree_share=0.35,
                    mix={"ARID": 50, "STEPPE": 50}, moisture=[20, 50], temperature=[18, 38]),
    "RAINFOREST": dict(area="/area/caribbean/nomads/forest/Jungle",
                       ground={GRASS: "/turf/floor/grass/jungle", DIRT: "/turf/floor/dirt/jungledirt"},
                       trees=["/obj/structure/wild/jungle", "/obj/structure/wild/largejungle", "/obj/structure/wild/palm"],
                       tree_share=1.0, mix={"LUSH": 80, "TEMPERATE": 20}, moisture=[70, 100], temperature=[20, 35]),
    "SWAMP": dict(area="/area/caribbean/nomads/forest/Jungle",
                  ground={GRASS: "/turf/floor/grass/jungle", DIRT: "/turf/floor/dirt/jungledirt"},
                  trees=["/obj/structure/wild/jungle", "/obj/structure/wild/palm"], tree_share=0.7,
                  mix={"LUSH": 100}, moisture=[80, 100], temperature=[15, 32]),
}
# The slot world's map metadata (code/modules/persistence/expedition_land.dm).
EXPEDITION_METADATA = "/obj/map_metadata/nomads/expedition"
# Declaration file for every type a skin can place.
SKIN_SOURCES = {
    EXPEDITION_METADATA: "code/modules/persistence/expedition_land.dm",
    "/area/caribbean/nomads": "code/game/area/caribbean.dm",
    "/area/caribbean/nomads/ice": "code/game/area/caribbean.dm",
    "/area/caribbean/nomads/tundra": "code/game/area/caribbean.dm",
    "/area/caribbean/nomads/taiga": "code/game/area/caribbean.dm",
    "/area/caribbean/nomads/forest": "code/game/area/caribbean.dm",
    "/area/caribbean/nomads/desert": "code/game/area/caribbean.dm",
    "/area/caribbean/nomads/forest/savanna": "code/game/area/caribbean.dm",
    "/area/caribbean/nomads/forest/Jungle": "code/game/area/caribbean.dm",
    "/turf/floor/winter": "code/game/turfs/floor_types.dm",
    "/turf/floor/winter/grass": "code/game/turfs/floor_types.dm",
    "/turf/floor/grass/jungle": "code/game/turfs/floor_types.dm",
    "/turf/floor/beach/sand/desert": "code/game/turfs/floor_types.dm",
    "/turf/floor/dirt/winter": "code/game/turfs/flooring/flooring_premade.dm",
    "/turf/floor/dirt/dust": "code/game/turfs/flooring/flooring_premade.dm",
    "/turf/floor/dirt/jungledirt": "code/game/turfs/flooring/flooring_premade.dm",
    "/obj/structure/wild/tree/live_tree": "code/game/objects/structures/wild.dm",
    "/obj/structure/wild/tree/live_tree/pine": "code/game/objects/structures/wild.dm",
    "/obj/structure/wild/tree/cactus": "code/game/objects/structures/wild.dm",
    "/obj/structure/wild/palm": "code/game/objects/structures/wild.dm",
    "/obj/structure/wild/jungle": "code/game/objects/structures/wild.dm",
    "/obj/structure/wild/largejungle": "code/game/objects/structures/wild.dm",
}
# Smaller lands: more stone and supply sites per land tile (ore); larger
# lands: more forage sites (fertility). Generator bounds: 1..100 and 0..70.
ORE_DENSITY = {"rich": [45, 65], "good": [30, 45], "fair": [10, 30], "thin": [8, 16], "poor": [5, 10]}
FERTILITY = {"poor": [6, 14], "thin": [10, 22], "fair": [10, 35], "good": [22, 42], "rich": [30, 50]}
SIDES = ("N", "S", "E", "W")


def template_errors(t):
    """Reasons a template cannot become a land, or [] when it can."""
    problems = []
    if type(t) is not dict:
        return ["a template is a JSON object"]
    if t.get("biome") not in BIOME_SKINS:
        problems.append("unknown biome")
    if t.get("land_type") not in LAND_TYPES:
        problems.append("unknown land type")
    if t.get("size") not in SIZES:
        problems.append("unknown size")
    for key in ("width", "height"):
        if type(t.get(key)) is not int or not 64 <= t[key] <= MAX_SIDE:
            problems.append(key + " must be 64..%d tiles" % MAX_SIDE)
    if all(type(t.get(key)) is int for key in ("width", "height")) and t["width"] * t["height"] * LAND_PLANES > MEASURED_CELLS:
        problems.append("%d x %d on %d levels is more than the %d cells a world has been measured to hold"
                        % (t["width"], t["height"], LAND_PLANES, MEASURED_CELLS))
    coast = t.get("coast")
    if type(coast) is not list or not coast or not all(s in SIDES for s in coast):
        problems.append("a land needs at least one coast side (N, S, E or W)")
    if not isinstance(t.get("seed"), str) or not t["seed"]:
        problems.append("missing seed")
    resources = t.get("resources")
    if type(resources) is not dict or resources.get("ore") not in ORE_DENSITY or resources.get("fertility") not in FERTILITY:
        problems.append("resources need ore and fertility levels")
    features = t.get("features")
    if type(features) is not dict or type(features.get("ridges", 0)) is not int:
        problems.append("features must be an object")
    return problems


# Per land type: mountain and hill shares of the land (percent), rivers (per
# mille of land), lake sites per 100,000 land tiles, wetland (percent of land)
# and how broken the coast is (1 smooth .. 3 fjords).
LAND_RELIEF = {
    "COASTAL_PLAIN": dict(mountain=[0, 1], hill=[3, 6], river=[14, 20], lakes=[5, 9], swamp=[0, 0], rough=2),
    "RIVER_DELTA": dict(mountain=[0, 0], hill=[1, 3], river=[26, 34], lakes=[6, 10], swamp=[1, 3], rough=2),
    "HIGHLANDS": dict(mountain=[8, 12], hill=[12, 18], river=[14, 20], lakes=[8, 12], swamp=[0, 0], rough=2),
    "PLATEAU": dict(mountain=[3, 5], hill=[16, 22], river=[10, 16], lakes=[4, 8], swamp=[0, 0], rough=1),
    "FJORD_COAST": dict(mountain=[6, 10], hill=[8, 12], river=[14, 20], lakes=[6, 10], swamp=[0, 0], rough=3),
    "MARSH": dict(mountain=[0, 0], hill=[1, 3], river=[18, 26], lakes=[10, 16], swamp=[4, 8], rough=2),
    "ARCHIPELAGO": dict(mountain=[1, 3], hill=[4, 8], river=[10, 16], lakes=[10, 16], swamp=[0, 0], rough=2),
    "VOLCANIC_ISLE": dict(mountain=[7, 11], hill=[10, 14], river=[10, 16], lakes=[8, 12], swamp=[0, 0], rough=2),
}
DRY_BIOMES = ("DESERT", "ICE_SHEET")


def island_count(t):
    """Islands for an island land: more on a larger map, as [lo, hi]."""
    side = isqrt(t["width"] * t["height"])
    room = max(1, t["width"] * t["height"] // 1600)      # the generator wants 1,600 tiles an island
    if t["land_type"] == "VOLCANIC_ISLE":
        low, high = (1, 2) if side < 400 else (2, 3)
    else:
        low = max(3, min(12, side // 70))
        high = min(16, low + 2)
    return [min(low, room), min(high, room)]


def land_config(t, attempt=0):
    """The generator configuration for one attempt at a template's land. Every
    share below is of the land's own area, so the same template rules hold at
    any size (tools/procedural_maps/relief_generator.py)."""
    seed = "%s/a%d" % (t["seed"], attempt)
    skin = BIOME_SKINS[t["biome"]]
    relief = LAND_RELIEF[t["land_type"]]
    islands = t["land_type"] in ISLAND_TYPES
    c = relief_preset(seed, t["width"], t["height"], sea_sides=tuple(sorted(set(t["coast"]))), islands=island_count(t) if islands else None)
    layout = c["relief_layout"]
    ridges = max(0, min(3, t["features"].get("ridges", 0)))
    mountain = list(relief["mountain"])
    if t["land_type"] in ("COASTAL_PLAIN", "RIVER_DELTA", "MARSH"):
        # The chart's ridges count: 0 keeps the land flat, each ridge adds two percent.
        mountain = [ridges * 2, ridges * 2 + 1] if ridges else [0, 0]
    river, lakes = list(relief["river"]), list(relief["lakes"])
    if t["biome"] in DRY_BIOMES:
        river, lakes = [max(4, river[0] // 2), max(6, river[1] // 2)], [lakes[0] // 3, lakes[1] // 3]
    swamp = list(relief["swamp"])
    if t["biome"] == "SWAMP":
        swamp = [max(swamp[0], 4), max(swamp[1], 8)]
    layout.update(mountain_pct=mountain, hill_pct=list(relief["hill"]), river_permille=river, lakes_per_100k_land=lakes,
                  swamp_pct=swamp, coast_roughness=relief["rough"],
                  river_max_half_width=1 if t["width"] * t["height"] < 250000 else 2)
    if islands:
        # Islands always have a shore belt: the mix keeps COAST and scales the rest.
        mix = {"COAST": 30}
        for name, share in skin["mix"].items():
            mix[name] = mix.get(name, 0) + share * 70 // 100
        mix[max(skin["mix"], key=skin["mix"].get)] += 100 - sum(mix.values())
        c["biome_mix_pct"] = mix
    else:
        c["biome_mix_pct"] = dict(skin["mix"])
    c["climate"] = dict(moisture_range=list(skin["moisture"]), temperature_c_range=list(skin["temperature"]))
    c["resources"]["density_per_1000_land_tiles"] = list(ORE_DENSITY[t["resources"]["ore"]])
    c["vegetation"]["suitable_site_density_pct"] = list(FERTILITY[t["resources"]["fertility"]])
    return c


def _share(seed, x, y, salt):
    digest = hashlib.sha256(("%s|%s|%d|%d|%s" % (LAND_VERSION, seed, x, y, salt)).encode()).digest()
    return int.from_bytes(digest[:8], "big") / 2 ** 64


def verify_skin_types(catalog_root=None):
    texts = {}
    for typename, path in SKIN_SOURCES.items():
        if path not in texts:
            texts[path] = read_source(path, catalog_root).decode("utf-8")
        if not re.search(r"^" + re.escape(typename) + r"\s*$", texts[path], re.M):
            raise ValueError("LAND_TYPE_MISSING: " + typename)
    return True


def reskin(doc, layout, t):
    """Gives the surface layer the biome's area, ground and trees. Returns
    counts of what changed."""
    skin = BIOME_SKINS[t["biome"]]
    z = doc["layers"]["SURFACE"]["native_z"]
    generated_trees = set(TREES.values())
    counts = {"trees kept": 0, "trees removed": 0, "ground swapped": 0}
    for (x, y, level), recipe in list(layout.items()):
        if level != z:
            continue
        atoms = recipe.split(",")
        out = []
        for atom in atoms:
            name = atom.split("{")[0]
            if atom == SURFACE_AREA:
                out.append(skin["area"])
            elif name in skin["ground"] and atom == name:
                out.append(skin["ground"][name])
                counts["ground swapped"] += 1
            elif name in generated_trees:
                if _share(t["seed"], x, y, "tree") < skin["tree_share"]:
                    trees = skin["trees"]
                    out.append(trees[int(_share(t["seed"], x, y, "kind") * len(trees)) % len(trees)])
                    counts["trees kept"] += 1
                else:
                    counts["trees removed"] += 1
            else:
                out.append(atom)
        layout[(x, y, level)] = ",".join(out)
    return counts


def build_land(t, out, catalog_root=None, lapse=DEFAULT_LAPSE, full_bundle=False):
    """Generates the land for template t into the new folder out: the
    generator's seed manifest and preview (bundle/), the region map
    (land.dmm) and a report (land.json). full_bundle also keeps the typed IR
    and sidecar, which `verify` and `playable` read. Returns the report."""
    problems = template_errors(t)
    if problems:
        raise ValueError("LAND_TEMPLATE: " + "; ".join(problems))
    verify_types(catalog_root, "native")
    verify_skin_types(catalog_root)
    folder = new_output(Path(out), True)
    started = time.monotonic()
    rejected = []
    for attempt in range(MAX_ATTEMPTS):
        config = land_config(t, attempt)
        errors = validate_config(config)
        if errors:
            raise ValueError("LAND_CONFIG: " + json.dumps(errors))
        result = generate(config)
        if result["document"] is not None:
            break
        rejected.append({"attempt": attempt, "reasons": result.get("reasons", [])})
    else:
        raise ValueError("LAND_REJECTED: no candidate in %d attempts: %s" % (MAX_ATTEMPTS, json.dumps(rejected[-1:])))
    generated = time.monotonic()
    doc = result["document"]
    # The generator has just validated and hashed this document; nothing below changes it.
    with unchanged(doc, [], result["manifest"]["generation_result"]["ir_sha256"]):
        write_bundle(new_output(folder / "bundle", True), result["document"], result["manifest"], catalog_root, True, fresh=True,
                     light=not full_bundle)
        layout, counts = playable_layout(doc, "native")
        skin_counts = reskin(doc, layout, t)
        profile = elevation_profile(doc, lapse)
        apply_elevation(layout, profile, EXPEDITION_METADATA)
        text = write_text(doc, layout)
        _, parsed, dims = parse_classic(text)
        if parsed != layout or sorted(dims) != [[doc["width"], doc["height"], 1], [doc["width"], doc["height"], 2]]:
            raise ValueError("LAND_LAYOUT_MISMATCH")
        (folder / "land.dmm").write_text(text, encoding="utf-8", newline="\n")
        terrain = write_terrain_files(folder, doc, layout)
    finished = time.monotonic()
    report = {
        "schema": LAND_VERSION,
        "template": deepcopy(t),
        "attempt": attempt,
        "rejected": rejected,
        "profile": doc["profile"],
        "width": doc["width"],
        "height": doc["height"],
        "area": BIOME_SKINS[t["biome"]]["area"],
        "dmm_sha256": hashlib.sha256(text.encode()).hexdigest(),
        "starts": len(doc["starts"]),
        "supplies": dict(sorted(counts.items())),
        "skin": skin_counts,
        # Hill levels, river currents and flood reaches beside the map (terrain_files.py).
        "terrain": terrain,
        # Applied by the slot world, not placed in the map (docs/expedition-lands.md).
        "slot_world": {"ore": t["resources"]["ore"], "ores": t["resources"].get("ores", []), "rare": t["resources"].get("rare", []),
                       "game": t["resources"].get("game", [])},
        "seconds": {"generate": round(generated - started, 2), "total": round(finished - started, 2)},
    }
    (folder / "land.json").write_text(json_text(report), encoding="utf-8", newline="\n")
    return report
