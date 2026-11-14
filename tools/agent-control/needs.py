"""Ada's needs, read from the same bars a player sees, in the style of a Sims motive panel.

Each need is a level from 0 (empty, act now) to 100 (fully satisfied). Urgency grows with the square of
what is missing, so a half-empty bar matters a little and a nearly empty one dominates; a need below its
critical level always beats routine work. The director (the language model) can scale any need's weight.
"""

NEEDS = ("safety", "health", "thirst", "hunger", "warmth", "relief", "energy", "hygiene", "social")

# Base weights: how much a need matters when it is empty. Health and warmth kill fastest, hygiene and social never do.
WEIGHTS = {"safety": 2.0, "health": 1.6, "thirst": 1.3, "hunger": 1.0, "warmth": 1.3, "relief": 0.7,
           "energy": 0.5, "hygiene": 0.4, "social": 0.3}
# Below this level a need is critical: its urgency is at least CRITICAL_URGENCY, above any work order.
CRITICAL = {"safety": 50, "health": 35, "thirst": 25, "hunger": 20, "warmth": 30, "relief": 15, "energy": 10,
            "hygiene": 0, "social": 0}
CRITICAL_URGENCY = 1.0
PRIORITY_RANGE = (0.0, 3.0)  # what the director may multiply a weight by

NORMAL_BODY = 310.0
COMFORT_LOW, COMFORT_HIGH = 300.0, 316.0  # Kelvin: no warmth need inside this band
FREEZE, BOIL = 260.0, 330.0  # Kelvin: warmth is empty at these
CLEAN = 250.0  # HYGIENE_LEVEL_CLEAN
BLADDER_FULL, BOWELS_FULL = 500.0, 550.0  # the game makes her wet or soil herself around these
SOCIAL_HOURS = 0.5  # hours alone before social is empty


def _number(value):
    return value if isinstance(value, (int, float)) and not isinstance(value, bool) else None


def _clamp(value):
    return max(0.0, min(100.0, float(value)))


def _ratio(value, most, default_most):
    value = _number(value)
    if value is None:
        return None
    most = _number(most) or default_most
    return _clamp(100.0 * value / most) if most > 0 else None


def warmth_level(body):
    body = _number(body)
    if body is None:
        return None
    if body < COMFORT_LOW:
        return _clamp(100.0 * (body - FREEZE) / (COMFORT_LOW - FREEZE))
    if body > COMFORT_HIGH:
        return _clamp(100.0 * (BOIL - body) / (BOIL - COMFORT_HIGH))
    return 100.0


def health_level(me):
    health, most = _number(me.get("health")), _number(me.get("max_health")) or 100.0
    level = 100.0 if health is None else _clamp(100.0 * health / most)
    blood = _number(me.get("blood"))
    if blood is not None and blood > 0:
        level = min(level, _clamp(100.0 * (blood - 300.0) / 260.0))  # 560 is a full body; below about 300 is fatal
    wounds = [row for row in me.get("wounds") or [] if isinstance(row, dict)]
    if any(row.get("bleeding") for row in wounds):
        level = min(level, 30.0)
    elif wounds:
        level = min(level, 80.0)
    sick = me.get("illness")
    if isinstance(sick, dict) and sick.get("severe"):
        remedy = _number(sick.get("remedy")) or 0
        level = min(level, 50.0 if remedy >= 3 else 20.0)
    return level


def read(me, social_age=None, threatened=False):
    """Need levels (0-100) from a character_state row; needs the game did not report are left out."""
    me = me if isinstance(me, dict) else {}
    levels = {"safety": 0.0 if threatened else 100.0, "health": health_level(me)}
    levels["thirst"] = _ratio(me.get("water"), me.get("max_water"), 350.0)
    levels["hunger"] = _ratio(me.get("nutrition"), me.get("max_nutrition"), 400.0)
    levels["warmth"] = warmth_level(me.get("bodytemperature"))
    bladder, bowels = _number(me.get("bladder")), _number(me.get("bowels"))
    if bladder is not None or bowels is not None:
        levels["relief"] = min(_clamp(100.0 - 100.0 * (bladder or 0) / BLADDER_FULL),
                               _clamp(100.0 - 100.0 * (bowels or 0) / BOWELS_FULL))
    levels["energy"] = _ratio(me.get("stamina"), me.get("max_stamina"), 100.0)
    levels["hygiene"] = _ratio(me.get("hygiene"), CLEAN, CLEAN)
    if _number(social_age) is not None:
        levels["social"] = _clamp(100.0 - 100.0 * social_age / (SOCIAL_HOURS * 3600.0))
    return {name: round(level, 1) for name, level in levels.items() if level is not None}


def clamp_priority(value):
    value = _number(value)
    if value is None:
        return None
    low, high = PRIORITY_RANGE
    return max(low, min(high, float(value)))


def urgency(name, level, priorities=None):
    """How strongly a need pulls at her now: 0 when full, about its weight when empty, never under 1 when critical."""
    if level is None:
        return 0.0
    missing = (100.0 - level) / 100.0
    scale = (priorities or {}).get(name, 1.0)
    value = WEIGHTS.get(name, 0.5) * missing * missing * scale
    if level < CRITICAL.get(name, 0) and scale > 0:
        value = max(value, CRITICAL_URGENCY + missing)
    return round(value, 3)


def urgencies(levels, priorities=None):
    return {name: urgency(name, level, priorities) for name, level in levels.items()}


def most_urgent(levels, priorities=None):
    """(need, urgency) of the strongest pull, or ("", 0.0)."""
    ranked = sorted(urgencies(levels, priorities).items(), key=lambda pair: (-pair[1], NEEDS.index(pair[0]) if pair[0] in NEEDS else 99))
    return ranked[0] if ranked and ranked[0][1] > 0 else ("", 0.0)


def describe(levels, priorities=None):
    """One NEEDS line for the director: each need as a 0-100 level, the low ones flagged."""
    parts = []
    for name in NEEDS:
        if name not in levels:
            continue
        level = levels[name]
        flag = " CRITICAL" if level < CRITICAL.get(name, 0) else " low" if level < 50 else ""
        parts.append(f"{name} {round(level)}{flag}")
    scaled = {name: value for name, value in (priorities or {}).items() if value != 1.0}
    line = "NEEDS (0 empty, 100 full): " + ", ".join(parts)
    if scaled:
        line += " | your priorities: " + ", ".join(f"{name} x{value:g}" for name, value in sorted(scaled.items()))
    return line
