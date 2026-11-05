"""Blueprints: planned buildings the autopilot places piece by piece.

A blueprint is a small grid drawn north-up. Each symbol is a piece; the planner picks the next missing
piece, the tile to stand on (inside the room when it can, so walls go up around the character), the
direction to face and the recipe to build it from what she carries. Progress is read from what the
game shows at each tile, with the structure ledger in memory covering tiles out of view.

The project state is a plain dict, saved in the character's memory file:
    {"name", "x", "y", "z", "tries": {"x,y": n}, "skipped": ["x,y"], "unavailable": [recipe], "started"}
x, y is the north-west corner of the grid.
"""

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

# Symbol -> (role, the words that show it is built, recipe choices in order as (recipe, material)).
PIECES = {
    "#": ("wall", ("wall",), (("stone wall", "stone"), ("log wall", "wooden plank"), ("straw wall", "wooden plank"))),
    "D": ("door", ("door",), (("rustic door", "wooden plank"), ("primitive wood fence door", "wooden plank"), ("roman door", "stone"))),
    "s": ("roof support", ("roof support",), (("roof support", "wooden plank"),)),
    "b": ("bed", ("bed",), (("bed", "wooden plank"),)),
    "t": ("table", ("table",), (("table", "wooden plank"),)),
}
ROOF = ("roof", ("roof",), (("thatch roofing", "lea"),))  # "lea" matches leaves and leaf bundles
INTERIOR = "sbt."
DENSE_ROLES = ("wall", "door", "table")  # what a character cannot stand on once built
# Build order: corners first while the outside is open, then walls from inside, the support, the roof,
# furniture, and the door last.
ORDER = {"corner": 0, "wall": 1, "roof support": 2, "roof": 3, "bed": 4, "table": 5, "door": 6}
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
    height, width = len(grid), len(grid[0])
    out = []
    for row, line in enumerate(grid):
        for col, symbol in enumerate(line):
            x, y = project["x"] + col, project["y"] - row
            corner = row in (0, height - 1) and col in (0, width - 1)
            if symbol in PIECES:
                role, words, choices = PIECES[symbol]
                out.append({"key": f"{x},{y}", "x": x, "y": y, "z": project["z"], "role": role, "words": words,
                            "choices": choices, "order": ORDER["corner" if corner and role == "wall" else role]})
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


def _matches(piece, row):
    name = str(row.get("name", "")).lower()
    if piece["role"] == "roof":
        return "roof" in name and "support" not in name and "roofing" not in name and not row.get("item")
    return any(word in name for word in piece["words"]) and not row.get("item")


def is_built(piece, at, ledger, here, radius=5):
    """True when the game shows the piece at its tile, or the ledger has it and the tile is out of view."""
    if any(_matches(piece, row) for row in at.get((piece["x"], piece["y"]), [])):
        return True
    far = max(abs(piece["x"] - here[0]), abs(piece["y"] - here[1])) > radius
    return far and any(item.get("x") == piece["x"] and item.get("y") == piece["y"] and item.get("z") == piece["z"]
                       and any(word in str(item.get("name", "")).lower() for word in piece["words"]) for item in ledger or [])


def progress(project, observation, ledger=()):
    """(done, remaining) pieces, leaving out skipped ones."""
    here = _here(observation)
    if here is None:
        return [], []
    at = _rows_at(observation, here)
    done, remaining = [], []
    for piece in pieces(project):
        if is_built(piece, at, ledger, here):
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

    Inside the room when a neighbour is an open interior tile, otherwise just outside the grid.
    """
    inside = interior(project)
    whole = footprint(project)
    dense = {(p["x"], p["y"]) for p in done if p["role"] in DENSE_ROLES}
    choices = []
    for direction, (dx, dy) in DIRS.items():
        tile = (piece["x"] - dx, piece["y"] - dy)  # stand here, facing direction
        if tile in dense or tile == (piece["x"], piece["y"]):
            continue
        if tile in inside:
            choices.append((0, tile, direction))
        elif tile not in whole and piece["role"] != "roof":
            choices.append((1, tile, direction))
    if not choices:
        return None
    _, tile, direction = min(choices, key=lambda c: (c[0], list(DIRS).index(c[2])))
    return tile[0], tile[1], direction


def _holding(self_state, material):
    names = [str((self_state.get(hand) or {}).get("name", "")) if isinstance(self_state.get(hand), dict) else str(self_state.get(hand) or "")
             for hand in ("left_hand", "right_hand")]
    names += [str(item).split(" (", 1)[0] for item in self_state.get("carried") or []]
    return next((name for name in names if material in name.lower()), "")


def recipe_for(piece, project, self_state):
    """(recipe, material name she carries) for a piece, or (None, what to gather)."""
    choices = [c for c in piece["choices"] if c[0] not in project.get("unavailable", [])]
    for recipe, material in choices:
        held = _holding(self_state, material)
        if held:
            return recipe, held
    if piece["role"] == "roof" and _holding(self_state, "thatch roofing"):
        return "thatch roofing", "thatch roofing"
    if not choices:
        return None, f"no recipe left for the {piece['role']}"
    recipe, material = choices[0]
    return None, f"{'leaves' if material == 'lea' else material + 's'} for a {recipe}"


def next_steps(project, observation, ledger=()):
    """(steps, piece, problem) for the next missing piece. Steps are plan steps the autopilot expands:
    walk onto the stand tile, then build (or craft roofing and roof). problem says what is missing."""
    me = observation.get("self", {})
    done, remaining = progress(project, observation, ledger)
    for piece in remaining:
        stand = stand_tile(piece, project, done)
        if stand is None:
            continue
        recipe, material = recipe_for(piece, project, me)
        if recipe is None:
            return [], piece, f"gather {material}"
        target = f"turf:{stand[0]},{stand[1]},{project['z']}"
        at = [piece["x"], piece["y"], piece["z"]]
        steps = [{"do": "go", "target": target, "reach": 0, "blueprint": piece["key"]}]
        if piece["role"] == "roof":
            if material != "thatch roofing":
                steps.append({"do": "craft", "recipe": recipe, "material": material, "blueprint": piece["key"]})
            steps.append({"do": "roof", "dir": stand[2], "material": "roofing", "blueprint": piece["key"], "at": at})
        else:
            steps.append({"do": "build", "recipe": recipe, "material": material, "dir": stand[2], "blueprint": piece["key"], "at": at})
        return steps, piece, ""
    if remaining:
        return [], remaining[0], "no free tile to stand on for the remaining pieces"
    return [], None, ""


def bill(remaining, project):
    """Materials still needed, by material word: {"wooden plank": 30, ...}."""
    need = {}
    for piece in remaining:
        choices = [c for c in piece["choices"] if c[0] not in project.get("unavailable", [])] or piece["choices"]
        recipe, material = choices[0]
        word = "leaves" if material == "lea" else material
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
    """Count a failed attempt at a piece; skip it after MAX_TRIES and drop recipes the game does not offer."""
    key = next((s.get("blueprint") for s in steps if s.get("blueprint")), None)
    if not key:
        return
    if "no recipe" in summary or "not_found" in summary:
        recipe = next((s.get("recipe") for s in steps if s.get("do") in ("build", "craft") and s.get("recipe")), None)
        if recipe and recipe not in project.setdefault("unavailable", []):
            project["unavailable"].append(recipe)
        return  # not the tile's fault; the next recipe choice is tried
    if "failed" in summary or "stopped" in summary:
        tries = project.setdefault("tries", {})
        tries[key] = tries.get(key, 0) + 1
        if tries[key] >= MAX_TRIES and key not in project.setdefault("skipped", []):
            project["skipped"].append(key)
