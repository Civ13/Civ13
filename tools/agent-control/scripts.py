"""Scripted task chains for Ada: the multi-step sequences the model used to direct one click at a time.

A script looks at what she carries and sees, and returns the next plan step toward its product, the way
`leather_next` and `build_next` already do. Scripts call each other for what they need first (an axe needs a
spear and sharpened flint), and return DONE once the product is in hand. Every step is a model-style plan
step ({"do": skill, "target": ref or 0}), so it runs through the same expansion and checks as the model's.
"""

DONE = "done"

PREY_RANGE = 8  # tiles: animals farther away are left to exploring or the director


def _distance(row):
    try:
        return max(abs(int(row.get("dx"))), abs(int(row.get("dy"))))
    except (TypeError, ValueError):
        return 99


def _lower(name):
    return str(name or "").lower()


def amount(me, word):
    """Total stack amount of carried or held items whose name contains word (1 per unstacked item)."""
    total = 0
    for row in me.get("items") or []:
        if isinstance(row, dict) and word in _lower(row.get("name")):
            value = row.get("amount")
            total += value if isinstance(value, int) and not isinstance(value, bool) else 1
    if total:
        return total
    names = [_lower((me.get(hand) or {}).get("name") if isinstance(me.get(hand), dict) else "") for hand in ("left_hand", "right_hand")]
    names += [_lower(str(item).split(" (", 1)[0]) for item in me.get("carried") or []]
    return sum(1 for name in names if word in name)


def explore(sit):
    return [{"do": "explore", "dir": sit.explore_dir}]


def _rock(sit):
    check = sit.kit.skill_targets["find_flint"][0]
    return sit.nearest(lambda row: check(row) and not row.get("item"))


def _has_blade(sit):
    return sit.carrying(lambda n: "sharpened flint" in n or "knife" in n or ("axe" in n and "pickaxe" not in n) or "hatchet" in n)


def flint(sit):
    """Sharpened flint: search a rock for flint, then sharpen it on the rock."""
    if sit.carrying(lambda n: "sharpened flint" in n):
        return DONE
    rock = _rock(sit)
    if not rock:
        return explore(sit)
    if sit.carrying(lambda n: "flint" in n and not any(word in n for word in ("sharpened", "axe", "knife", "spear", "lock"))):
        return [{"do": "sharpen_flint", "target": rock["ref"]}]
    return [{"do": "find_flint", "target": rock["ref"]}]


def _has_spear(sit):
    return sit.carrying(lambda n: "sharpened stick" in n or "spear" in n)


def stick(sit):
    """A plain stick in hand: break a branch off a tree, take its leaves, strip it, pick the stick up."""
    kit = sit.kit
    if sit.carrying(kit.is_plain_stick):
        return DONE
    loose = sit.nearest(lambda row: row.get("item") and kit.is_plain_stick(row.get("name")))
    if loose:
        return [{"do": "pick_up", "target": loose["ref"]}]
    cleared = sit.nearest(lambda row: row.get("branch") == "cleared")
    if cleared:
        return [{"do": "make_stick", "target": cleared["ref"]}]
    leafy = sit.nearest(lambda row: row.get("branch") == "leafy")
    if leafy:
        return [{"do": "pick_leaves", "target": leafy["ref"]}]
    tree = sit.nearest(lambda row: row.get("branches") not in (None, 0, False))
    if tree:
        return [{"do": "break_branch", "target": tree["ref"]}]
    return explore(sit)


def spear(sit):
    """A sharpened stick: sharpened flint, a stick, then sharpen the stick."""
    if _has_spear(sit) or sit.carrying(lambda n: ("axe" in n and "pickaxe" not in n) or "hatchet" in n):
        return DONE
    need = flint(sit)
    if need != DONE:
        return need
    need = stick(sit)
    if need != DONE:
        return need
    return [{"do": "sharpen_stick", "target": 0}]


def axe(sit):
    """A flint axe: a spear, sharpened flint, then twine (two grass cuttings twisted) or sinew to bind them."""
    kit = sit.kit
    if sit.carrying(lambda n: ("axe" in n and "pickaxe" not in n) or "hatchet" in n):
        return DONE
    need = spear(sit)
    if need != DONE:
        return need
    need = flint(sit)  # the spear's sharpening may have used the flint up
    if need != DONE:
        return need
    if sit.carrying(lambda n: any(word in n for word in kit.binding_words)):
        return [{"do": "bind_axe", "target": 0}]
    if amount(sit.me, "grass cutting") >= 2:
        return [{"do": "twist_twine", "target": 0}]
    grass = sit.nearest(kit.skill_targets["cut_grass"][0])
    if grass:
        return [{"do": "cut_grass", "target": grass["ref"]}]
    return explore(sit)


def _has_axe(sit):
    return sit.carrying(lambda n: ("axe" in n and "pickaxe" not in n) or "hatchet" in n)


def wood(sit, logs=4):
    """At least `logs` wood logs: an axe, then chop the nearest tree (logs are picked up after chopping)."""
    if amount(sit.me, "log") >= logs:
        return DONE
    need = axe(sit)
    if need != DONE:
        return need
    loose = sit.nearest(lambda row: row.get("item") and "log" in _lower(row.get("name")) and _distance(row) <= 4)
    if loose:
        return [{"do": "pick_up", "target": loose["ref"]}]
    tree = sit.nearest(sit.kit.skill_targets["chop"][0])
    if tree:
        return [{"do": "chop", "target": tree["ref"]}]
    return explore(sit)


def _fire(sit):
    return sit.nearest(lambda row: not row.get("item") and any(word in _lower(row.get("name")) for word in sit.kit.fire_words))


def campfire(sit):
    """A campfire in view: four wood logs, crafted on her own tile."""
    if _fire(sit):
        return DONE
    need = wood(sit, 4)
    if need != DONE:
        return need
    return [{"do": "craft", "recipe": "campfire", "material": "wood log"}]


def _prey(sit):
    kit = sit.kit
    return sit.nearest(lambda row: row.get("mob") and row.get("stat") in (None, 0) and _distance(row) <= PREY_RANGE
                       and str(row.get("type", "")).startswith("/mob/living/simple_animal") and not kit.is_predator(row))


TRAP_TARGET = 2  # traps of hers in view before the traps script counts its work as done


def material(me, word):
    """Amount of a plain material stack she carries or holds ("stone", "rope"), not tools named after it."""
    total = 0
    for row in me.get("items") or []:
        if not isinstance(row, dict):
            continue
        name = _lower(row.get("name")).split(" (", 1)[0].strip()
        if name in (word, word + "s"):
            value = row.get("amount")
            total += value if isinstance(value, int) and not isinstance(value, bool) else 1
    return total


def _my_traps(sit):
    return [row for row in sit.rows() if row.get("mine") and ("trap" in row or "fish" in row)]


def tend_traps(sit):
    """The next step at one of her traps that needs a hand (a catch, a sprung trap, fish in a weir), or None."""
    kit = sit.kit
    ready = sit.nearest(kit.trap_ready)
    return [{"do": "check_trap", "target": ready["ref"]}] if ready else None


def traps(sit):
    """Snares and deadfalls set nearby and tended: take catches and butcher them, reset sprung traps, craft and set
    new ones from 2 rope (snare) or 2 stone (deadfall). DONE once TRAP_TARGET traps stand and none needs her."""
    kit = sit.kit
    need = tend_traps(sit)
    if need:
        return need
    carcass = sit.nearest(lambda row: kit.skill_targets["butcher"][0](row) and _distance(row) <= 2)
    if carcass:
        need = flint(sit) if not _has_blade(sit) else DONE
        return need if need != DONE else [{"do": "butcher", "target": carcass["ref"]}]
    if len(_my_traps(sit)) >= TRAP_TARGET:
        return DONE
    if sit.carrying(kit.is_trap_kit):
        taken = {(row.get("dx"), row.get("dy")) for row in sit.rows() if "trap" in row or "fish" in row}
        ground = sit.nearest(lambda row: kit.is_trap_ground(row) and (row.get("dx"), row.get("dy")) not in taken)
        return [{"do": "set_trap", "target": ground["ref"]}] if ground else explore(sit)
    if material(sit.me, "stone") >= 2:
        return [{"do": "craft", "recipe": "deadfall trap", "material": "stone"}]
    if material(sit.me, "rope") >= 2:
        return [{"do": "craft", "recipe": "snare", "material": "rope"}]
    return DONE  # nothing to make traps from: the director decides whether to gather stone or rope


def hunt(sit):
    """Raw meat: butcher a dead animal in view, or arm herself and kill the nearest animal that is not a predator."""
    kit = sit.kit
    if sit.carrying(lambda n: kit.is_food(n)):
        return DONE
    need = tend_traps(sit)  # a catch in one of her traps is a hunt already won
    if need:
        return need
    carcass = sit.nearest(kit.skill_targets["butcher"][0])
    if carcass:
        need = flint(sit) if not _has_blade(sit) else DONE
        return need if need != DONE else [{"do": "butcher", "target": carcass["ref"]}]
    meat = sit.nearest(lambda row: row.get("item") and kit.is_food(row.get("name")) and _distance(row) <= 4)
    if meat:
        return [{"do": "pick_up", "target": meat["ref"]}]
    need = spear(sit)
    if need != DONE:
        return need
    prey = _prey(sit)
    if prey:
        return [{"do": "attack", "target": prey["ref"]}]
    return explore(sit)


SCRIPTS = {
    "flint": flint,
    "stick": stick,
    "spear": spear,
    "axe": axe,
    "wood": wood,
    "campfire": campfire,
    "hunt": hunt,
    "traps": traps,
}
ALIASES = {"sharpened flint": "flint", "make_flint": "flint", "make_spear": "spear", "sharpened stick": "spear",
           "make_axe": "axe", "flint axe": "axe", "gather_wood": "wood", "logs": "wood", "wood logs": "wood",
           "fire": "campfire", "food": "hunt", "meat": "hunt",
           "trap": "traps", "snare": "traps", "snares": "traps", "deadfall": "traps", "trapping": "traps"}


def name_of(text):
    text = str(text or "").strip().lower().replace("-", "_")
    text = ALIASES.get(text, text)
    return text if text in SCRIPTS else ""


def ladder(sit):
    """The early survival ladder as a script name, or "" once a camp has its tools and fire (then the director leads)."""
    if not _has_blade(sit) and not _has_axe(sit):
        return "flint"
    if not _has_axe(sit) and not _has_spear(sit):
        return "spear"
    if not _has_axe(sit):
        return "axe"
    if not _fire(sit):
        return "campfire"
    return ""
