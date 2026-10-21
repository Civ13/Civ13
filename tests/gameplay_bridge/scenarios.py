"""Acceptance predicates for trusted isolated-harness state, never model output.

These are prepared native acceptance oracles, not gameplay implementations.
Current tests feed inert state dictionaries; no native pass is claimed.
"""
from math import isfinite


def number(state, key):
    value = state.get(key)
    if type(value) not in (int, float) or not isfinite(value):
        raise ValueError("missing or invalid harness state: " + key)
    return value


def evaluate(scenario, before, after):
    """Return concrete failed invariants. No textual success claims are accepted."""
    failed = []
    if after.get("alive") is not True:
        failed.append("actor_alive")
    if after.get("normal_mechanics") is not True or after.get("admin_shortcuts") is not False:
        failed.append("ordinary_mechanics")
    if scenario == "supplied_food_water":
        for field in ("nutrition", "hydration"):
            if number(after, field) <= number(before, field):
                failed.append(field + "_increased")
        for field in ("food_units", "water_units"):
            if number(after, field) >= number(before, field):
                failed.append(field + "_consumed")
    elif scenario == "gather_tool_shelter":
        for field in ("gathered_units", "crafted_tools", "shelter_parts", "paid_materials", "elapsed_ticks"):
            if number(after, field) <= number(before, field):
                failed.append(field + "_increased")
        if after.get("shelter_protects_actor") is not True:
            failed.append("shelter_protection")
    elif scenario == "peer_exchange":
        if before.get("item_owner") != "actor" or after.get("item_owner") != "peer":
            failed.append("same_item_transferred")
        before_identity = before.get("item_identity")
        after_identity = after.get("item_identity")
        if not isinstance(before_identity, str) or not before_identity or not isinstance(after_identity, str) or not after_identity or before_identity != after_identity:
            failed.append("item_identity_conserved")
        if number(after, "total_items") != number(before, "total_items"):
            failed.append("no_duplication")
        if after.get("peer_received_coordinate_message") is not True:
            failed.append("peer_heard_coordination")
    else:
        raise ValueError("unknown scenario")
    return failed
