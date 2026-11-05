"""Generate the playable Train Raid map from the two Dagger map studies.

The Hauler raid station study (tests/dagger_map/build_raid_train.py) leaves
both berths empty and the home train study (tests/dagger_map/build_map.py)
stands alone in its own staging map. This generator docks one copy of the
four-level home train, called the shuttle in play, in each berth of the
Hauler station and adds the objects the Train Raid mode needs: crew spawn and
store landmarks, helm consoles, bridge gates, crew-only airlock doors,
claimable beds, tiered loot pads and the map metadata object. The two WIP
studies, their validators and their manifests are not modified.

The output is maps/EFT/train_raid.dmm plus a small layout manifest that the
offline test suite checks against the generator and the checked-in map.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests/dagger_map"))
import build_map as home  # noqa: E402
import build_raid_train as raid  # noqa: E402

MAP_PATH = ROOT / "maps/EFT/train_raid.dmm"
LAYOUT_PATH = ROOT / "maps/EFT/train_raid.layout.json"
SIZE = raid.SIZE
LEVELS = raid.WORLD_LEVELS
CREWS = {"west": {"berth": "raid_west", "title": "West"}, "east": {"berth": "raid_east", "title": "East"}}

# Local (x, y) positions inside the shuttle ground deck. The bunk room is
# x1..11/y1..12 and the party stores room is x1..11/y14..25; both are inside
# the crew-only rear compartment behind the airlock.
SPAWN_POINTS = [(6, 3), (6, 7), (6, 11), (3, 5), (9, 5), (9, 1), (3, 9), (9, 9)]
STORE_POINTS = [(6, 16), (6, 18), (6, 20), (6, 22), (6, 24)]
HELM_POINT = (24, 37)
FLOOR = "/turf/floor/plating/steel"
WOOD = "/turf/floor/wood"

AREAS = {
    "void": "/area/train_raid/void",
    "yard": "/area/train_raid/station",
    "platform": "/area/train_raid/station/platform",
    "bridge": "/area/train_raid/station/platform",
}
SECTION_AREAS = {
    "brake_van": "/area/train_raid/hauler/brake_van",
    "flatcars": "/area/train_raid/hauler/flatcars",
    "boxcars": "/area/train_raid/hauler/boxcars",
    "coaches": "/area/train_raid/hauler/coaches",
    "vault": "/area/train_raid/hauler/vault",
    "locomotive": "/area/train_raid/hauler/locomotive",
    None: "/area/train_raid/hauler",
}


DRAFT_NAMES = {
    'name = "Station platform - draft only"': 'name = "station platform"',
    'name = "Boarding bridge - draft only"': 'name = "boarding bridge"',
    'name = "Flatcar deck - draft only"': 'name = "flatcar deck"',
}


def atoms_for(palette, kind):
    """Return a palette kind's atom list with study-only names made plain."""
    atoms = palette[kind][0]
    for draft, plain in DRAFT_NAMES.items():
        atoms = atoms.replace(draft, plain)
    return atoms


def hauler_atoms(kind, tier):
    """Hauler tiles: beds become claimable, loot anchors gain a loot pad."""
    atoms = atoms_for(raid.PALETTE, kind)
    if kind == "bed":
        return f"/obj/structure/bed/train_raid,{WOOD}"
    if kind in raid.LOOT_KINDS:
        return f"/obj/effect/train_raid_loot{{tier = {tier}}},{atoms}"
    if kind == "breach":
        return f'/obj/structure/simple_door{{name = "compartment door"}},{FLOOR}'
    if kind == "helm":
        return f'/obj/structure/table{{name = "Hauler controls"}},{FLOOR}'
    if kind == "engine_mount":
        return f'/obj/structure/props/engineprops{{name = "Hauler engine"}},{FLOOR}'
    if kind == "pillar":
        return '/turf/wall/iron{name = "support pillar"}'
    if kind == "cage":
        return '/turf/wall/iron{name = "vault cage wall"}'
    if kind == "deck":
        return '/turf/floor/plating/concrete{name = "flatcar deck"}'
    if kind == "crate_deck":
        return atoms
    return atoms


def shuttle_atoms(kind, crew, local):
    """Shuttle tiles: crew doors, helm, claimable beds, mode landmarks."""
    x, y, z = local
    atoms = atoms_for(home.PALETTE, kind)
    if kind in ("gate", "inner_gate"):
        return f'/obj/structure/simple_door/train_raid_crew{{crew = "{crew}"}},{WOOD}'
    if kind == "helm_control":
        return f'/obj/structure/train_raid_helm{{crew = "{crew}"}},{WOOD}'
    if kind == "engine_mount":
        return f'/obj/structure/props/engineprops{{name = "shuttle engine"}},{FLOOR}'
    if kind == "bed":
        return f"/obj/structure/bed/train_raid,{WOOD}"
    if kind == "pillar":
        return '/turf/wall/iron{name = "shuttle support pillar"}'
    if kind.startswith("stair_"):
        return atoms.replace('area_id = "dagger_draft_', f'area_id = "train_raid_{crew}_')
    if z == 0 and kind == "safe":
        if (x, y) in SPAWN_POINTS:
            return f'/obj/effect/landmark{{name = "JoinLateTrain{CREWS[crew]["title"]}"}},{WOOD}'
        if (x, y) in STORE_POINTS:
            return f'/obj/effect/landmark{{name = "TrainStores{CREWS[crew]["title"]}"}},{WOOD}'
    return atoms


def shuttle_area(crew, local):
    x, y, z = local
    title = CREWS[crew]["title"]
    if z == 0 and y <= home.PROTECTED_END:
        return f"/area/train_raid/shuttle/{crew}/crew"
    if z == 0:
        return f"/area/train_raid/shuttle/{crew}"
    return f"/area/train_raid/shuttle/{crew}/deck{z}"


def build():
    raid_grid, raid_layout = raid.build()
    sections = {s["id"]: s for s in raid_layout["sections"]}
    slots = {s["id"]: s for s in raid_layout["slots"]}
    grid = {}
    tx0, ty0, tx1, ty1 = raid_layout["target_train"]["bounds"]
    for (x, y, z), (kind, area) in raid_grid.items():
        if z == raid.TRAIN_ORIGIN[2] and tx0 <= x <= tx1 and ty0 <= y <= ty1:
            dx, dy = x - raid.TRAIN_ORIGIN[0], y - raid.TRAIN_ORIGIN[1]
            section = raid.section_of(dy)
            tier = sections[section]["tier"] if section else 0
            grid[x, y, z] = (hauler_atoms(kind, tier), SECTION_AREAS[section])
        elif kind in AREAS:
            grid[x, y, z] = (atoms_for(raid.PALETTE, kind), AREAS[kind])
        elif kind == "crate":
            grid[x, y, z] = (atoms_for(raid.PALETTE, kind), AREAS["yard"])
        elif kind == "berth":
            grid[x, y, z] = (atoms_for(raid.PALETTE, kind), AREAS["yard"])
        else:
            raise SystemExit(f"Unhandled raid tile {kind} at {(x, y, z)}")
    # Bridge gates sit on every bridge cell between a boarding port and the platform.
    crews = {}
    for crew, data in CREWS.items():
        slot = slots[data["berth"]]
        ox, oy, oz = slot["origin"]
        for (lx, ly, lz), kind in home.train_levels().items():
            grid[ox + lx, oy + ly, oz + lz] = (shuttle_atoms(kind, crew, (lx, ly, lz)), shuttle_area(crew, (lx, ly, lz)))
        for bx, by, bz in slot["bridge_cells"]:
            atoms, _ = grid[bx, by, bz]
            grid[bx, by, bz] = (f'/obj/structure/train_raid_bridge{{crew = "{crew}"}},{atoms}', AREAS["bridge"])
        crews[crew] = {
            "berth": data["berth"], "origin": slot["origin"],
            "bounds": [ox, oy, ox + home.WIDTH - 1, oy + home.LENGTH - 1], "z": [oz, oz + home.TRAIN_LEVELS - 1],
            "crew_bounds": [ox, oy, ox + home.WIDTH - 1, oy + home.PROTECTED_END],
            "spawn_points": [[ox + px, oy + py, oz] for px, py in SPAWN_POINTS],
            "store_points": [[ox + px, oy + py, oz] for px, py in STORE_POINTS],
            "helm": [ox + HELM_POINT[0], oy + HELM_POINT[1], oz],
            "airlock_doors": [[ox + 14, oy + 39, oz], [ox + 15, oy + 45, oz]],
            "boarding_ports": slot["boarding_ports"],
            "bridge_cells": slot["bridge_cells"]}
    grid[1, 1, 1] = ("/obj/map_metadata/train_raid,/turf/wall/iron", AREAS["void"])
    layout = {
        "schema_version": 1,
        "map": "maps/EFT/train_raid.dmm",
        "world": {"width": SIZE, "height": SIZE, "levels": LEVELS},
        "hauler": raid_layout["target_train"],
        "sections": [{"id": s["id"], "name": s["name"], "tier": s["tier"], "world_bounds": s["world_bounds"],
                      "loot_pads": len(s["loot_anchors"]), "platform_openings": s["platform_openings"]}
                     for s in raid_layout["sections"]],
        "platforms": raid_layout["platforms"],
        "crews": crews,
    }
    return grid, layout


def render_dmm(grid):
    entries = sorted(set(grid.values()))
    alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    if len(entries) > len(alphabet) ** 2:
        raise SystemExit("Too many distinct tiles for two-letter keys")
    keys = {entry: alphabet[i // len(alphabet)] + alphabet[i % len(alphabet)] for i, entry in enumerate(entries)}
    lines = ["// Generated by tests/train_raid/build.py. Edit the generator, not this file."]
    for (atoms, area), key in keys.items():
        lines.append(f'"{key}" = ({atoms},{area})')
    for z in range(1, LEVELS + 1):
        lines.extend(["", f'(1,1,{z}) = {{"'])
        for y in range(SIZE, 0, -1):
            lines.append("".join(keys[grid[x, y, z]] for x in range(1, SIZE + 1)))
        lines.append('"}')
    return "\n".join(lines) + "\n"


def outputs():
    grid, layout = build()
    return {MAP_PATH: render_dmm(grid), LAYOUT_PATH: json.dumps(layout, indent=2) + "\n"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="fail if the checked-in outputs differ")
    args = parser.parse_args()
    for path, content in outputs().items():
        if args.check:
            if not path.exists() or path.read_text(encoding="utf-8") != content:
                raise SystemExit(f"Generated output differs: {path}")
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding="utf-8", newline="\n")
    print("PASS: Train Raid map outputs are current" if args.check else "Wrote Train Raid map and layout")


if __name__ == "__main__":
    main()
