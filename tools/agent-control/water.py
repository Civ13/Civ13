"""Clean drinking water for the autopilot: boil river or puddle water before drinking it.

Untreated rivers, lakes, puddles and dirty wells give cholera on about one drink in seven, and cholera kills in
about 20 minutes without a medicine course. A clean well is safe. Otherwise the stone-age way is a hot stone:
fill a wood mug, put a stone block on a lit campfire's tile, hold the mug and a stick, and use the mug's
"Boil water with a hot stone" verb. Then drink from the mug.

next_steps(observation) returns (steps, note) for the next stage; steps use the autopilot's own skills and the
queue's actions, and an empty list comes with a note that says what is missing.
"""

import re

WATER_WORDS = ("water", "river", "lake", "pond", "puddle", "stream", "well")
NOT_WATER_WORDS = ("oil", "petroleum", "tar", "fuel", "acid")
FIRE_WORDS = ("campfire",)
BOIL_VERB = "Boil water with a hot stone"
STONE = "stone block"  # the stone stack's name; a stone pickaxe or wall is not one
EMERGENCY = 100  # below this much water, drinking unboiled water beats dying of thirst


def _name(item):
    if isinstance(item, dict):
        return str(item.get("name", "empty"))
    return str(item) if item else "empty"


def is_water(row):
    name = str(row.get("name", "")).lower()
    if any(re.search(rf"\b{word}\b", name) for word in NOT_WATER_WORDS) or "salt" in name or "sea" in name or row.get("salty"):
        return False
    return any(word in name for word in WATER_WORDS) and not row.get("item") and not row.get("mob")


def is_unclean(row):
    """True for water that can carry cholera: marked unclean, a puddle, or water the game has not vouched for."""
    if "puddle" in str(row.get("name", "")).lower():
        return True
    return row.get("sickness", 1) != 0


def _distance(row):
    try:
        return max(abs(int(row.get("dx"))), abs(int(row.get("dy"))))
    except (TypeError, ValueError):
        return 99


def sources(observation):
    """Listed water, clean first, then nearest."""
    rows = [row for row in observation.get("terrain", []) + observation.get("nearby", []) if isinstance(row, dict) and is_water(row)]
    return sorted(rows, key=lambda row: (is_unclean(row), _distance(row)))


def _mug(me):
    """The carried wood mug's detail row (name, liquids), or None."""
    for row in me.get("items") or []:
        if isinstance(row, dict) and "mug" in str(row.get("name", "")).lower():
            return row
    for name in [_name(me.get("left_hand")), _name(me.get("right_hand"))] + [str(n) for n in me.get("carried") or []]:
        if "mug" in name.lower():
            return {"name": name.split(" (", 1)[0]}
    return None


def _liquid(mug, reagent):
    liquids = mug.get("liquids") or mug.get("reagents") or {}
    if isinstance(liquids, dict):
        return sum(float(v or 0) for k, v in liquids.items() if reagent in str(k).lower())
    if isinstance(liquids, list):
        return sum(float(r.get("amount", r.get("volume", 0)) or 0) for r in liquids if isinstance(r, dict) and reagent in str(r.get("id", r.get("name", ""))).lower())
    return 0.0


def _has(me, word):
    names = [_name(me.get("left_hand")), _name(me.get("right_hand"))] + [str(n) for n in me.get("carried") or []]
    return any(word in name.lower() for name in names)


def _stick(me):
    names = [_name(me.get("left_hand")), _name(me.get("right_hand"))] + [str(n) for n in me.get("carried") or []]
    return next((n.split(" (", 1)[0] for n in names if re.search(r"\bstick\b", n.lower()) and "sharpened" not in n.lower()), None)


def _fire(observation):
    """The nearest campfire, lit ones with fuel first."""
    fires = [row for row in observation.get("nearby", []) if any(word in str(row.get("name", "")).lower() for word in FIRE_WORDS) and not row.get("item")]
    return min(fires, key=lambda row: (not _burning(row), _distance(row))) if fires else None


def _burning(fire):
    """True when the row says the fire is lit with fuel left (rows without the fields count as burning)."""
    return fire.get("lit", True) and float(fire.get("fuel", 1) or 0) >= 1


def _stone_on(observation, fire):
    return any(STONE in str(row.get("name", "")).lower() and row.get("item") and row.get("dx") == fire.get("dx") and row.get("dy") == fire.get("dy")
               for row in observation.get("nearby", []))


def boiled(mug):
    """True when the mug holds water and no cholera."""
    return mug is not None and _liquid(mug, "water") > 0 and _liquid(mug, "cholera") <= 0


def next_steps(observation):
    """The next stage towards a mug of boiled water, or drinking it: (steps, note)."""
    me = observation.get("self", {})
    mug = _mug(me)
    if mug is None:
        loose = next((row for row in observation.get("nearby", []) if row.get("item") and "mug" in str(row.get("name", "")).lower() and _distance(row) <= 3), None)
        if loose:
            return [{"skill": "pick_up", "target": loose.get("ref")}], ""
        if _has(me, "log"):
            return [{"do": "craft", "recipe": "wood mug", "material": "wood log"}], ""
        return [], "boiling water needs a wood mug: chop a tree for wood logs and craft one (1 wood log)"
    name = str(mug.get("name", "wood mug"))
    water = _liquid(mug, "water")
    if water > 0 and _liquid(mug, "cholera") <= 0 and mug.get("liquids") is not None:
        return [{"do": "drink_mug", "item": name}], ""
    if water <= 0:
        listed = sources(observation)
        if not listed:
            return [], "your mug is empty and no water is listed: explore to find a river, lake or well"
        return [{"skill": "fill_vessel", "target": listed[0].get("ref")}], ""
    fire = _fire(observation)
    if fire is None:
        return [], "boiling needs a lit campfire next to you: build one from 4 wood logs, fuel_fire it and light_fire it"
    if float(fire.get("fuel", 1) or 0) < 1:
        if _has(me, "log") or _has(me, "plank") or _has(me, "branch"):
            return [{"skill": "fuel_fire", "target": fire.get("ref")}], ""
        return [], "the campfire is out of fuel: bring wood logs and fuel_fire it"
    if not fire.get("lit", True):
        return [{"skill": "light_fire", "target": fire.get("ref")}], ""
    if not _stone_on(observation, fire):
        if _has(me, STONE):
            return [{"do": "place_stone", "target": fire.get("ref")}], ""
        return [], ("boiling needs a stone block on the campfire's tile: sift soil for one "
                    '({"do": "verb", "name": "Sift soil for resources", "choose": "Stone"} while standing on dirt or sand, 3 minutes), '
                    "or mine underground rock")
    stick = _stick(me)
    if stick is None:
        return [], "boiling needs a plain stick in your other hand to move the hot stone: break_branch a tree and make_stick"
    return [{"do": "boil_mug", "item": name, "stick": stick, "fire": fire.get("ref")}], ""
