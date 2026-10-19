"""Fixed player contract shared by discovery and the proposal validator.

Importing or invoking this file performs no network, game or model operations.
Discovery describes source support, never installed availability or permission.
"""
import copy
import json
import re

VERSION = 3
IDENT = re.compile(r"[A-Za-z0-9_-]{1,64}\Z")
RECIPES = frozenset({"grass_twine", "sharpen_stick", "bind_flint_axe", "leather_canopy", "deploy_canopy"})
CATALOG = {
    "move": {"direction": ["north", "south", "east", "west"]},
    **{name: {"target": "entity_id"} for name in
       ("examine", "use", "pickup", "drop", "consume", "gather", "refill", "drink")},
    "swap_hands": {},
    "equip": {"target": "entity_id", "slot": ["belt"]},
    "craft": {"target": "entity_id", "recipe": sorted(RECIPES)},
    "intent": {"intent": ["help", "grab", "walk"]},
    "say": {"text": "speech_160"},
}
CAPABILITIES = frozenset(CATALOG) | {"observe"}
UNSUPPORTED = ("join", "container_open", "container_close", "container_insert",
               "container_remove", "unequip", "repair", "rest", "sleep", "attack",
               "respawn", "vehicle", "shuttle", "party", "extraction")
REASONS = frozenset({"none", "invalid_request", "unsupported_action", "stale_observation",
                     "target_unavailable", "busy", "cooldown", "capability_denied",
                     "no_verified_state_change", "cancel_requested", "cancelled",
                     "transport_uncertain", "receipt_expired", "stopped"})
TERMINAL = frozenset({"completed", "denied", "cancelled", "failed", "unknown"})
# Query uncertainty is not a game acknowledgement of worker quiescence.
WIRE_FINAL = TERMINAL - {"unknown"}
STATES = TERMINAL | {"queued", "dispatched", "running", "cancel_requested"}
CONTROL_FIELDS = frozenset({"version", "operation", "assignment", "epoch", "request_id"})
QUERY_FIELDS = frozenset({"version", "epoch", "base_seq"})
ENVELOPE_FIELDS = frozenset({"version", "assignment", "epoch", "observation_seq", "action_seq", "request_id", "action"})


def action_error(action):
    if type(action) is not dict:
        return "action"
    kind = action.get("type")
    if not isinstance(kind, str) or kind not in CATALOG:
        return "unsupported_action"
    if set(action) != {"type", *CATALOG[kind]}:
        return "schema"
    for key, rule in CATALOG[kind].items():
        value = action[key]
        if isinstance(rule, list):
            if not isinstance(value, str) or value not in rule:
                return {"recipe": "recipe", "direction": "direction", "intent": "intent"}.get(key, "slot")
        elif rule == "entity_id":
            if not isinstance(value, str) or not IDENT.fullmatch(value):
                return "slot" if kind == "equip" else "recipe" if kind == "craft" else "target"
        elif rule == "speech_160":
            if (not isinstance(value, str) or not value.strip() or len(value) > 160
                    or any(ord(c) < 32 or ord(c) == 127 or c in "*^:;<>" for c in value)):
                return "speech"
    return None


def discovery():
    return {"version": VERSION, "compatible_versions": [2, 3],
            "availability": "disabled_source_only", "authority": "assigned_ordinary_player",
            "actions": [{"id": name, "arguments": copy.deepcopy(args),
                         "available": "requires_current_capability_and_affordance",
                         "lifecycle": "living_human"} for name, args in sorted(CATALOG.items())],
            "unsupported": [{"id": name, "reason": "unsupported_action"} for name in UNSUPPORTED],
            "states": sorted(STATES), "reasons": sorted(REASONS),
            "limits": {"json_bytes": 32768, "observation_bytes": 24576, "json_depth": 16, "entity_visits": 256,
                       "entities": 128, "own_hands": 2, "radius": 3, "z_levels": 1,
                       "history_snapshots": 4, "history_bytes": 131072,
                       "receipts": 64, "new_actions_per_second": 1,
                       "pending_or_inflight": 1, "snapshot_seconds": 15},
            "operations": {"observation": ["full", "delta_or_reset"],
                           "action": ["submit", "status", "cancel"]},
            "schemas": {
                "action_envelope": {key: ("action_catalog" if key == "action" else
                                          "integer_1_to_2147483647" if key in ("action_seq", "observation_seq") else
                                          "integer_3" if key == "version" else "opaque_id_1_to_64_ascii")
                                    for key in sorted(ENVELOPE_FIELDS)},
                "control": {key: (["status", "cancel"] if key == "operation" else
                                  "integer_3" if key == "version" else "opaque_id_1_to_64_ascii")
                            for key in sorted(CONTROL_FIELDS)},
                "delta_query": {"version": "integer_3", "epoch": "opaque_id_1_to_64_ascii",
                                "base_seq": "integer_1_to_2147483647"},
                "receipt": {"request_id": "opaque_id_1_to_64_ascii", "status": sorted(STATES),
                            "reason": sorted(REASONS), "detail": "public_text_max_512"}},
            "cancel": "request_acknowledgement_is_not_worker_quiescence",
            "running": "reserved_until_game_acknowledgement; dispatch_is_not_execution",
            "native_verified": False, "admin_diagnostics": False}


def dm_catalog():
    """Generated fixed-key validator; no caller-selected dispatch/proc paths."""
    rows = ["// Generated from scripts/gameplay_bridge/catalog.py; do not edit by hand.\n",
            "/proc/gameplay_action_fields(list/A)\n\tif (!islist(A))\n\t\treturn FALSE\n\tvar/list/keys\n\tswitch(A[\"type\"])\n"]
    for kind, args in sorted(CATALOG.items()):
        keys = ", ".join(json.dumps(x) for x in ["type", *args])
        rows.append(f'\t\tif ("{kind}")\n\t\t\tkeys = list({keys})\n')
        for key, rule in args.items():
            if isinstance(rule, list):
                values = ", ".join(json.dumps(x) for x in rule)
                condition = f'!istext(A["{key}"]) || !(A["{key}"] in list({values}))'
            else:
                bound = 160 if rule == "speech_160" else 64
                condition = f'!istext(A["{key}"]) || !length(A["{key}"]) || length(A["{key}"]) > {bound}'
            rows.append(f'\t\t\tif ({condition})\n\t\t\t\treturn FALSE\n')
    rows.append("\tif (!keys || A.len != keys.len)\n\t\treturn FALSE\n\tfor (var/key in A)\n\t\tif (!(key in keys))\n\t\t\treturn FALSE\n\treturn TRUE\n")
    return "".join(rows)


if __name__ == "__main__":
    print(json.dumps(discovery(), sort_keys=True))
