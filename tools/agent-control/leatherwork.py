"""Leatherworking planner for the autopilot: raw hide to leather to a belt satchel or backpack.

The game's chain (code/game/objects/items/stacks/sheets/leather.dm, converters.dm):
  raw hide or pelt  --held blade, 5 s scrape-->           hairless hide (one piece per scrape)
  hairless hide     --held vessel with 5 water-->         wet hide
  wet hide          --held, on an empty tanning rack-->   dry hide after 30 s (take it off by hand)
  wood logs         --held hatchet, 2 logs-->             1 plank and 2 tree bark
  tree bark         --held vessel with 10 water-->        10 tannin in the vessel
  dry hide          --held vessel with 5 tannin-->        leather
Hides and bark are worked where they lie (next to her), with the vessel or tool in her active hand.

next_steps(observation, product) returns (plan steps, note). Steps use autopilot skills, which walk there and
set the hand and intent. One stage per turn: what a step makes appears on the ground and is picked up later.
"""

PRODUCTS = {"leather belt satchel": 3, "leather backpack": 6, "leather": 1}
ALIASES = {"belt": "leather belt satchel", "leather belt": "leather belt satchel", "belt satchel": "leather belt satchel",
           "backpack": "leather backpack", "bag": "leather backpack"}
VESSEL_WORDS = ("mug", "bucket", "cup", "tankard", "bowl", "pot", "glass", "canteen", "flask", "jug", "beaker", "waterskin")
RAW_WORDS = ("raw hide", "pelt")
WATER_WORDS = ("water", "river", "lake", "pond", "stream", "well", "sea", "ocean")
RACK_LOGS = 8


def product_name(text):
    """The product a leather_next step asks for ("belt" -> "leather belt satchel")."""
    name = str(text or "").strip().lower()
    name = ALIASES.get(name, name)
    return name if name in PRODUCTS else "leather"


def _details(me):
    """Held and carried items with counts and liquids (the observation's "items"), falling back to names."""
    rows = [row for row in me.get("items") or [] if isinstance(row, dict) and row.get("name")]
    if rows:
        return rows
    names = []
    for hand in ("left_hand", "right_hand"):
        item = me.get(hand)
        if isinstance(item, dict) and item.get("name"):
            names.append(item["name"])
    names += [str(item).split(" (", 1)[0] for item in me.get("carried") or []]
    return [{"name": name} for name in names]


def is_leather(name):
    """A leather stack ("leather sheet", "dark leather sheets"), not something made of leather."""
    name = str(name or "").lower().strip()
    return name in ("leather", "dark leather") or (name.endswith(("leather sheet", "leather sheets")))


def is_raw(name):
    """An untreated hide: "raw hide pieces" or a pelt ("wolf pelts"); "hairless hide pelts" is already scraped."""
    name = str(name or "").lower()
    return "raw hide" in name or ("pelt" in name and "hide" not in name)


def _is(name, word):
    name = str(name or "").lower()
    if word == "leather":
        return is_leather(name)
    if word == "raw":
        return is_raw(name)
    return word in name


def _count(me, word):
    return sum(int(row.get("amount") or 1) for row in _details(me) if _is(row.get("name"), word))


def _distance(row):
    try:
        return max(abs(int(row.get("dx"))), abs(int(row.get("dy"))))
    except (TypeError, ValueError):
        return 99


def _ground(observation, word, reach=7):
    rows = [row for row in observation.get("nearby", []) if isinstance(row, dict) and row.get("item") and _is(row.get("name"), word)
            and _distance(row) <= reach]
    return min(rows, key=_distance) if rows else None


def _vessel(me):
    """(name, water, tannin, room) of the open container she carries, or None."""
    for row in _details(me):
        if isinstance(row.get("liquids"), dict) or any(word in str(row.get("name", "")).lower().split() for word in VESSEL_WORDS):
            liquids = row.get("liquids") if isinstance(row.get("liquids"), dict) else {}
            water, tannin = float(liquids.get("water") or 0), float(liquids.get("tannin") or 0)
            volume = float(row.get("volume") or 40)
            return str(row["name"]), water, tannin, volume - sum(float(v or 0) for v in liquids.values())
    return None


def _water(observation):
    rows = [row for row in observation.get("terrain", []) + observation.get("nearby", [])
            if isinstance(row, dict) and not row.get("item") and not row.get("mob")
            and any(word in str(row.get("name", "")).lower() for word in WATER_WORDS)]
    return min(rows, key=_distance) if rows else None


def _rack(observation):
    rows = [row for row in observation.get("nearby", []) if isinstance(row, dict) and "tanning rack" in str(row.get("name", "")).lower()]
    return min(rows, key=_distance) if rows else None


BLADE_WORDS = ("sharpened flint", "knife", "dagger", "machete", "sword", "hatchet", "axe")


def is_blade(name):
    """A sharp tool that scrapes a hide (the game asks for any sharp item); a pickaxe is not one."""
    name = str(name or "").lower()
    return any(word in name for word in BLADE_WORDS) and "pickaxe" not in name and not any(w in name for w in ("head", "mold", "sheath"))


def _has_blade(me):
    return any(is_blade(row.get("name")) for row in _details(me))


def _tool_nearby(observation, test, reach=3):
    """A loose tool she needs lying close by (a hand freed for work can leave one on the ground)."""
    rows = [row for row in observation.get("nearby", []) if isinstance(row, dict) and row.get("item") and test(row.get("name")) and _distance(row) <= reach]
    return min(rows, key=_distance) if rows else None


def _is_axe(name):
    name = str(name or "").lower()
    return ("axe" in name or "hatchet" in name) and "pickaxe" not in name and "head" not in name


def _locked(me, material, recipe):
    """True when she holds the material stack and the game's craft list for it lacks the recipe (research gate)."""
    active = me.get("left_hand") if me.get("active_hand") == "left" else me.get("right_hand")
    held = str(active.get("name", "")) if isinstance(active, dict) else ""
    craftable = me.get("craftable")
    if not craftable or not _is(held, material):
        return False
    return not any(recipe in str(entry).lower() for entry in craftable)


def _has_axe(me):
    return any(("axe" in str(row.get("name", "")).lower() or "hatchet" in str(row.get("name", "")).lower())
               and "pickaxe" not in str(row.get("name", "")).lower() for row in _details(me))


def _fill(observation, vessel):
    water = _water(observation)
    if water is None:
        return [], f"your {vessel} needs water: go to a river, lake or well"
    return [{"skill": "fill_vessel", "target": water.get("ref")}], ""


def _vessel_or_make(me, observation):
    """Steps to get a vessel when she has none, else ([], "")."""
    loose = _ground(observation, "mug", reach=3) or _ground(observation, "bucket", reach=3)
    if loose:
        return [{"skill": "pick_up", "target": loose.get("ref")}], ""
    if _count(me, "log") >= 1:
        return [{"do": "craft", "recipe": "wood mug", "material": "wood log"}], ""
    return [], "you need a wood mug (1 wood log) or a bucket to carry water and tannin"


def _tannin(me, observation, vessel):
    """Steps that put at least 5 tannin in the vessel."""
    name, water, _tannin_now, room = vessel
    bark = _ground(observation, "bark")
    if water < 10 and room >= 5:
        return _fill(observation, name)
    if bark is not None and water >= 10:
        return [{"skill": "soak_bark", "target": bark.get("ref")}], ""
    if _count(me, "bark"):
        return [{"do": "drop", "material": "bark"}], ""
    logs = _ground(observation, "log", reach=3)
    if logs is not None and int(logs.get("amount") or 2) >= 2:
        if not _has_axe(me):
            axe = _tool_nearby(observation, _is_axe)
            if axe is not None:
                return [{"skill": "pick_up", "target": axe.get("ref")}], ""
            return [], "cutting logs for bark needs a hatchet or axe"
        return [{"skill": "cut_logs", "target": logs.get("ref")}], ""
    if _count(me, "log") >= 2:
        return [{"do": "drop", "material": "wood log"}], ""
    return [], "tannin comes from tree bark: chop a tree for at least 2 wood logs, then cut them with your hatchet"


def next_steps(observation, product="leather"):
    """(steps, note) for the next leatherworking step towards product; note explains a missing material."""
    me = observation.get("self", {})
    product = product_name(product)
    need = PRODUCTS[product]
    # Finished product: pick it up and wear it.
    if product != "leather":
        made = _ground(observation, product, reach=3)
        if made is not None:
            return [{"skill": "pick_up", "target": made.get("ref")}], ""
        if _count(me, product):
            worn = [str(item).lower() for item in me.get("worn") or []]
            if product not in worn:
                return [{"do": "equip", "material": product}], ""
            return [], f"you already wear a {product}"
    loose_leather = _ground(observation, "leather", reach=3)
    if loose_leather is not None:
        return [{"skill": "pick_up", "target": loose_leather.get("ref")}], ""
    leather = _count(me, "leather")
    if leather >= need:
        if product == "leather":
            return [], "you have leather"
        if _locked(me, "leather", product):
            return [], f"the {product} recipe is not available yet (it needs more research); keep the leather for other leather recipes"
        return [{"do": "craft", "recipe": product, "material": "leather"}], ""
    rack = _rack(observation)
    if rack is not None and "dry hide" in str(rack.get("holds", "")):
        return [{"skill": "unload_rack", "target": rack.get("ref")}], ""
    vessel = _vessel(me)
    # Dry hides: tan them.
    dry = _ground(observation, "dry hide")
    if dry is not None or _count(me, "dry hide"):
        if dry is None:
            return [{"do": "drop", "material": "dry hide"}], ""
        if vessel is None:
            return _vessel_or_make(me, observation)
        if vessel[2] >= 5:
            return [{"skill": "tan_hide", "target": dry.get("ref")}], ""
        return _tannin(me, observation, vessel)
    # Wet hides: onto the rack.
    wet = _ground(observation, "wet hide")
    if wet is not None and not _count(me, "wet hide"):
        return [{"skill": "pick_up", "target": wet.get("ref")}], ""
    if _count(me, "wet hide"):
        if rack is None:
            if _locked(me, "log", "tanning rack"):
                return [], "the tanning rack recipe is not available yet (it needs more research); keep the wet hides"
            if _count(me, "log") >= RACK_LOGS:
                return [{"do": "craft", "recipe": "tanning rack", "material": "wood log"}], ""
            return [], f"a tanning rack needs {RACK_LOGS} wood logs: chop a tree"
        if str(rack.get("holds", "nothing")) in ("nothing", ""):
            return [{"skill": "rack_hide", "target": rack.get("ref")}], ""
        return [{"do": "wait", "ticks": 50}], "the rack is still drying hides"
    # Hairless hides: wash them.
    hairless = _ground(observation, "hairless hide")
    if hairless is not None or _count(me, "hairless hide"):
        if hairless is None:
            return [{"do": "drop", "material": "hairless hide"}], ""
        if vessel is None:
            return _vessel_or_make(me, observation)
        if vessel[1] >= 5:
            return [{"skill": "wash_hide", "target": hairless.get("ref")}], ""
        return _fill(observation, vessel[0])
    # Raw hides and pelts: scrape them.
    raw = _ground(observation, "raw")
    if raw is not None or _count(me, "raw"):
        if raw is None:
            held = next(str(row["name"]) for row in _details(me) if _is(row.get("name"), "raw"))
            return [{"do": "drop", "material": held}], ""
        if not _has_blade(me):
            blade = _tool_nearby(observation, is_blade)
            if blade is not None:
                return [{"skill": "pick_up", "target": blade.get("ref")}], ""
            return [], "scraping a hide needs a sharpened flint or a knife"
        return [{"skill": "scrape_hide", "target": raw.get("ref")}], ""
    if rack is not None and "wet hide" in str(rack.get("holds", "")):
        return [{"do": "wait", "ticks": 50}], "the rack is still drying hides"
    return [], f"you need {need - leather} more raw hide(s): hunt an animal with your spear and butcher it"


def describe(observation, product="leather"):
    """One prompt line about the leather project."""
    me = observation.get("self", {})
    product = product_name(product)
    stock = {word: _count(me, word) for word in ("leather", "dry hide", "wet hide", "hairless hide", "raw")}
    have = ", ".join(f"{n} {w if w != 'raw' else 'raw hide'}" for w, n in stock.items() if n) or "no hides yet"
    steps, note = next_steps(observation, product)
    nxt = '{"do": "leather_next"} does the next step' if steps else note
    return f"Leatherwork towards a {product} ({PRODUCTS[product]} leather): you carry {have}; {nxt}."
