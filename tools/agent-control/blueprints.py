"""Blueprints: planned buildings the autopilot places piece by piece.

A blueprint is a small grid drawn north-up. Each symbol is a piece; the planner picks the next missing
piece, the tile to stand on, the direction to face and the recipe to build it from what she carries.
Progress is read from what the game shows at each tile, with the structure ledger in memory covering
tiles out of view.

The game puts a crafted structure on the tile the crafter stands on (stack.dm produce_recipe: new
result_type(user.loc)), so walls, doors, supports and furniture are built standing on their own tile.
A roof is the exception: thatch roofing is "use"d and roofs get_step(user, user.dir), so it is built
from a neighbouring tile. Crafted items, roofing included, drop at the crafter's feet.

The project state is a plain dict, saved in the character's memory file:
    {"name", "x", "y", "z", "tries": {"x,y": n}, "skipped": ["x,y"], "unavailable": [recipe], "started"}
x, y is the north-west corner of the grid.
"""

import re
import time

# North-up grids: "#" wall, "D" door, "s" roof support, "b" bed, "t" table, "." open floor.
# Every tile inside the walls ("s", "b", "t", ".") is roofed.
BLUEPRINTS = {
    "hut": {
        "about": "a 2x2 room: walls, a door, a roof support, a thatch roof and a bed",
        "grid": ["####",
                 "#b.#",
                 "#s.#",
                 "##D#"],
    },
    "house": {
        "about": "a 3x3 room: walls, a door, a roof support, a thatch roof, a bed and a table",
        "grid": ["#####",
                 "#b.t#",
                 "#.s.#",
                 "#...#",
                 "##D##"],
    },
}

# Material key -> (what to call it, words that match the stack's in-game name). The game names stacks
# "wood logs", "stone blocks" and "leaf bundles" (material use_name + sheet name), singular when one is left.
LISTING_CAP = 64  # character_observe lists at most this many nearby things
MATERIALS = {
    "wood": ("wood logs", ("wood log", "wooden plank")),
    "stone": ("stone blocks", ("stone block",)),
    "leaves": ("leaf bundles", ("leaf bundle", "leaves")),
}
# Symbol -> (role, the words that show it is built, recipe choices in order as (recipe, material key)).
# Log and straw walls come with the stone-age baseline (primitive_construction); stone walls need stone masonry.
PIECES = {
    "#": ("wall", ("wall",), (("log wall", "wood"), ("straw wall", "wood"), ("stone wall", "stone"))),
    "D": ("door", ("door",), (("rustic door", "wood"), ("primitive wood fence door", "wood"), ("roman door", "stone"))),
    "s": ("roof support", ("roof support",), (("roof support", "wood"),)),
    "b": ("bed", ("bed",), (("bed", "wood"),)),
    "t": ("table", ("table",), (("table", "wood"),)),
}
ROOF = ("roof", ("roof",), (("thatch roofing", "leaves"),))
ROOFING = "roofing"  # the roofbuilder item: "thatch roofing"
INTERIOR = "sbt."
DENSE_ROLES = ("wall", "door", "table")  # what a character cannot step onto once built
# Build order: walls, the support, the roof, furniture, and the door last so the room stays open.
ORDER = {"wall": 0, "roof support": 1, "roof": 2, "bed": 3, "table": 4, "door": 5}
COST = {"stone wall": 8, "log wall": 6, "straw wall": 4, "rustic door": 4, "primitive wood fence door": 3,
        "roman door": 5, "roof support": 2, "bed": 4, "table": 4, "thatch roofing": 2}
MAX_TRIES = 3
DIRS = {"north": (0, 1), "south": (0, -1), "east": (1, 0), "west": (-1, 0)}
BLOCKING_TERRAIN = ("water", "river", "lake", "sea", "ocean", "rock", "mountain", "wall", "cliff", "lava")


def names():
    return sorted(BLUEPRINTS)


def pieces(project):
    """Every piece of a project: dicts with key, x, y, z, role, words, choices and order."""
    plan = BLUEPRINTS[project["name"]]
    grid = plan["grid"]
    out = []
    for row, line in enumerate(grid):
        for col, symbol in enumerate(line):
            x, y = project["x"] + col, project["y"] - row
            if symbol in PIECES:
                role, words, choices = PIECES[symbol]
                out.append({"key": f"{x},{y}", "x": x, "y": y, "z": project["z"], "role": role, "words": words,
                            "choices": choices, "order": ORDER[role]})
            if symbol in INTERIOR:
                role, words, choices = ROOF
                out.append({"key": f"{x},{y}:roof", "x": x, "y": y, "z": project["z"], "role": role, "words": words,
                            "choices": choices, "order": ORDER[role]})
    return sorted(out, key=lambda p: (p["order"], -p["y"], p["x"]))


def interior(project):
    plan = BLUEPRINTS[project["name"]]["grid"]
    return {(project["x"] + col, project["y"] - row) for row, line in enumerate(plan) for col, symbol in enumerate(line) if symbol in INTERIOR}


def footprint(project):
    plan = BLUEPRINTS[project["name"]]["grid"]
    return {(project["x"] + col, project["y"] - row) for row, line in enumerate(plan) for col in range(len(line))}


def _here(observation):
    me = observation.get("self", {})
    x, y, z = me.get("x"), me.get("y"), me.get("z")
    return (x, y, z) if isinstance(x, int) and isinstance(y, int) else None


def _rows_at(observation, here):
    """(x, y) -> rows of things the game lists on that tile."""
    at = {}
    for row in list(observation.get("nearby") or []) + list(observation.get("terrain") or []):
        if isinstance(row, dict) and isinstance(row.get("dx"), int) and isinstance(row.get("dy"), int):
            at.setdefault((here[0] + row["dx"], here[1] + row["dy"]), []).append(row)
    return at


def _named(piece, name):
    """True when a name is this piece's kind of structure (a roof is not a roof support or roofing)."""
    name = str(name or "").lower()
    if piece["role"] == "roof":
        return "roof" in name and "support" not in name and "roofing" not in name
    return any(word in name for word in piece["words"])


def _matches(piece, row):
    return _named(piece, row.get("name")) and not row.get("item")


def is_built(piece, at, ledger, here, radius=5, listing_full=False):
    """True when the game shows the piece at its tile, or the ledger has it and the tile may be unlisted:
    out of view, or in view while the game's nearby listing hit its 64-entry cap."""
    if any(_matches(piece, row) for row in at.get((piece["x"], piece["y"]), [])):
        return True
    unlisted = listing_full or max(abs(piece["x"] - here[0]), abs(piece["y"] - here[1])) > radius
    return unlisted and any(item.get("x") == piece["x"] and item.get("y") == piece["y"] and item.get("z") == piece["z"]
                            and _named(piece, item.get("name")) for item in ledger or [])


def progress(project, observation, ledger=()):
    """(done, remaining) pieces, leaving out skipped ones."""
    here = _here(observation)
    if here is None:
        return [], []
    at = _rows_at(observation, here)
    full = len(observation.get("nearby") or []) >= LISTING_CAP
    done, remaining = [], []
    for piece in pieces(project):
        if is_built(piece, at, ledger, here, listing_full=full):
            done.append(piece)
        elif piece["key"] not in project.get("skipped", []):
            remaining.append(piece)
    return done, remaining


def choose_site(name, observation, radius=4):
    """The north-west corner of a clear spot for the blueprint near the character, or None.

    Clear means nothing fixed in place is listed on any of its tiles, no water or rock terrain is listed
    there, and no one else's wall, door or fence is within a tile of it.
    """
    here = _here(observation)
    if here is None or name not in BLUEPRINTS:
        return None
    grid = BLUEPRINTS[name]["grid"]
    height, width = len(grid), len(grid[0])
    at = _rows_at(observation, here)
    taken, buildings = set(), set()
    for tile, rows in at.items():
        for row in rows:
            text = (str(row.get("name", "")) + " " + str(row.get("type", ""))).lower()
            if row.get("ref", "").startswith("turf:"):
                if any(word in text for word in BLOCKING_TERRAIN):
                    taken.add(tile)
            elif not row.get("item") and not row.get("mob"):
                taken.add(tile)
                if any(word in text for word in ("wall", "door", "fence", "palisade")):
                    buildings.add(tile)
    best = None
    for dx in range(-radius, radius + 1):
        for dy in range(-radius, radius + 1):
            corner = (here[0] + dx, here[1] + dy)
            tiles = {(corner[0] + col, corner[1] - row) for row in range(height) for col in range(width)}
            if any(max(abs(t[0] - here[0]), abs(t[1] - here[1])) > radius for t in tiles):
                continue  # keep the whole site in view
            if tiles & taken:
                continue
            if any(abs(t[0] - b[0]) <= 1 and abs(t[1] - b[1]) <= 1 for t in tiles for b in buildings):
                continue
            centre = (corner[0] + (width - 1) / 2, corner[1] - (height - 1) / 2)
            distance = abs(centre[0] - here[0]) + abs(centre[1] - here[1])
            if best is None or distance < best[0]:
                best = (distance, corner)
    return best[1] if best else None


def start(name, observation):
    """A new project for a blueprint at a clear spot near the character, or None when there is no room."""
    here = _here(observation)
    corner = choose_site(name, observation)
    if here is None or corner is None:
        return None
    return {"name": name, "x": corner[0], "y": corner[1], "z": here[2], "tries": {}, "skipped": [], "unavailable": [],
            "started": int(time.time())}


def stand_tile(piece, project, done):
    """Where to stand to build a piece, and which way to face: (x, y, dir) or None.

    A structure is built on the tile she stands on, so that is the piece's own tile, facing any open
    neighbour. A roof goes on the faced tile, so she stands on an open neighbour (inside the room when
    one is free, otherwise just outside the grid) facing the roof tile.
    """
    inside = interior(project)
    whole = footprint(project)
    dense = {(p["x"], p["y"]) for p in done if p["role"] in DENSE_ROLES}
    tile = (piece["x"], piece["y"])
    if piece["role"] != "roof":
        if tile in dense:
            return None
        for direction, (dx, dy) in DIRS.items():
            if (tile[0] + dx, tile[1] + dy) not in dense:
                return tile[0], tile[1], direction
        return None
    choices = []
    for direction, (dx, dy) in DIRS.items():
        stand = (tile[0] - dx, tile[1] - dy)  # stand here, facing direction
        if stand in dense:
            continue
        if stand in inside:
            choices.append((0, stand, direction))
        elif stand not in whole:
            choices.append((1, stand, direction))
    if not choices:
        return None
    _, stand, direction = min(choices, key=lambda c: (c[0], list(DIRS).index(c[2])))
    return stand[0], stand[1], direction


def _held_names(self_state):
    names = [str((self_state.get(hand) or {}).get("name", "")) if isinstance(self_state.get(hand), dict) else str(self_state.get(hand) or "")
             for hand in ("left_hand", "right_hand")]
    return names + [str(item).split(" (", 1)[0] for item in self_state.get("carried") or []]


def _stack_name(name):
    """A name without counts, notes or plurals: "wood logs (5)" -> "wood log"."""
    text = re.sub(r"\(.*?\)|\d+", " ", str(name or "").lower())
    return " ".join(word[:-1] if word.endswith("s") and len(word) > 3 else word for word in text.split())


def _holding(self_state, words):
    """The name of a held or carried item that is one of words (the whole name, or its last words:
    "thatch roofing" is roofing), or "". A stone axe is not stone and leather armor is not leaves."""
    if isinstance(words, str):
        words = (words,)
    wanted = [_stack_name(word) for word in words]
    for name in _held_names(self_state):
        have = _stack_name(name)
        if have and any(have == word or have.endswith(" " + word) for word in wanted):
            return name
    return ""


def recipe_for(piece, project, self_state):
    """(recipe, material name she carries) for a piece, (None, what to gather) when she lacks it,
    or (None, None) when the game offers none of its recipes."""
    choices = [c for c in piece["choices"] if c[0] not in project.get("unavailable", [])]
    for recipe, material in choices:
        held = _holding(self_state, MATERIALS[material][1])
        if held:
            return recipe, held
    if not choices:
        return None, None
    recipe, material = choices[0]
    return None, f"{MATERIALS[material][0]} for a {recipe}"


def _roofing_nearby(observation):
    """The ref of thatch roofing lying on the ground in view, nearest first, or None."""
    rows = [row for row in observation.get("nearby") or []
            if isinstance(row, dict) and row.get("item") and row.get("ref") and ROOFING in str(row.get("name", "")).lower()
            and isinstance(row.get("dx"), int) and isinstance(row.get("dy"), int)]
    rows.sort(key=lambda row: max(abs(row["dx"]), abs(row["dy"])))
    return rows[0]["ref"] if rows else None


def next_steps(project, observation, ledger=()):
    """(steps, piece, problem) for the next missing piece. Steps are plan steps the autopilot expands:
    walk onto the stand tile, then build; for a roof, craft roofing, pick it up, or walk and roof.
    problem says what is missing. Pieces the game offers no recipe for are skipped."""
    me = observation.get("self", {})
    done, remaining = progress(project, observation, ledger)
    for piece in remaining:
        stand = stand_tile(piece, project, done)
        if stand is None:
            continue
        recipe, material = recipe_for(piece, project, me)
        if recipe is None and material is None:
            project.setdefault("skipped", []).append(piece["key"])
            continue
        target = f"turf:{stand[0]},{stand[1]},{project['z']}"
        at = [piece["x"], piece["y"], piece["z"]]
        if piece["role"] == "roof":
            roofing = _holding(me, ROOFING)
            if roofing:
                return [{"do": "go", "target": target, "reach": 0, "blueprint": piece["key"]},
                        {"do": "roof", "dir": stand[2], "material": roofing, "blueprint": piece["key"], "at": at}], piece, ""
            loose = _roofing_nearby(observation)
            if loose:
                return [{"skill": "pick_up", "target": loose, "blueprint": piece["key"]}], piece, ""
            if recipe is None:
                return [], piece, f"gather {material}"
            # Crafting drops the roofing at her feet; the autopilot picks it up, and the next turn roofs with it.
            return [{"do": "craft", "recipe": recipe, "material": material, "blueprint": piece["key"]}], piece, ""
        if recipe is None:
            return [], piece, f"gather {material}"
        return [{"do": "go", "target": target, "reach": 0, "blueprint": piece["key"]},
                {"do": "build", "recipe": recipe, "material": material, "dir": stand[2], "blueprint": piece["key"], "at": at}], piece, ""
    if remaining and not all(p["key"] in project.get("skipped", []) for p in remaining):
        return [], remaining[0], "no free tile to stand on for the remaining pieces"
    return [], None, ""


def bill(remaining, project):
    """Materials still needed, by material name: {"wood logs": 30, ...}."""
    need = {}
    for piece in remaining:
        choices = [c for c in piece["choices"] if c[0] not in project.get("unavailable", [])] or piece["choices"]
        recipe, material = choices[0]
        word = MATERIALS[material][0]
        need[word] = need.get(word, 0) + COST.get(recipe, 2)
    return need


def describe(project, observation, ledger=()):
    """One line for the prompt: what is being built, how far along, and what comes next."""
    done, remaining = progress(project, observation, ledger)
    total = len(done) + len(remaining)
    if not remaining:
        return f"Your {project['name']} at ({project['x']},{project['y']}) is finished ({len(done)} pieces)."
    _, piece, problem = next_steps(project, observation, ledger)
    need = ", ".join(f"{n} {w}" for w, n in sorted(bill(remaining, project).items()))
    nxt = f"next: {piece['role']} at ({piece['x']},{piece['y']})" if piece else "next: none placeable"
    if problem:
        nxt += f" - {problem}"
    else:
        nxt += ' - use {"do": "build_next"} to place it'
    return f"Building a {project['name']} at ({project['x']},{project['y']}): {len(done)} of {total} pieces done; {nxt}. Still needed: about {need}."


def record_result(project, steps, summary):
    """Count an attempt to place a piece; skip it after MAX_TRIES and drop recipes the game does not offer.

    The game answers "craft ok" even when it refuses to build (another wall here, no support for the
    roof), so every placing attempt counts: a piece that was placed leaves the remaining list anyway.
    """
    key = next((s.get("blueprint") for s in steps if s.get("blueprint")), None)
    if not key:
        return
    if "no recipe" in summary or "not_found" in summary:
        recipe = next((s.get("recipe") for s in steps if s.get("do") in ("build", "craft") and s.get("recipe")), None)
        if recipe and recipe not in project.setdefault("unavailable", []):
            project["unavailable"].append(recipe)
        return  # not the tile's fault; the next recipe choice is tried
    placing = any(s.get("do") in ("build", "roof") for s in steps)
    if placing or "failed" in summary or "stopped" in summary:
        tries = project.setdefault("tries", {})
        tries[key] = tries.get(key, 0) + 1
        if tries[key] >= MAX_TRIES and key not in project.setdefault("skipped", []):
            project["skipped"].append(key)
