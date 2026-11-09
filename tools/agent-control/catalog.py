"""Agent control action catalog shared by the CLI, MCP server and tests.

Keep in sync with agent_control_actions() in
code/modules/agent_control/agent_control.dm; tests/agent_control checks both.
"""

TARGET = {
    "type": "string",
    "description": (
        'An object: a ref like "[0x2000001]", "ckey:<ckey>" (that player\'s mob), '
        '"client:<ckey>", "turf:x,y,z", "world", "global" or "global:<var>" (e.g. global:ticker).'
    ),
}
VALUE = {
    "description": (
        'A number, string, boolean or null; or an object {"ref": "[0x..]"}, {"type": "/obj/item"}, '
        '{"ckey": "name"}, {"turf": [x, y, z]}, {"text": "..."} or {"list": [...]}.'
    ),
}
CHARACTER = {"type": "string", "description": "Ref of a character from character_list or character_spawn."}
WINDOW = {"type": "string", "description": "topic/close_window: a window name from character_observe windows"}
SLOT = {"type": "string", "enum": ["back", "mask", "belt", "id", "l_ear", "r_ear", "eyes", "gloves", "head", "shoes", "suit", "uniform", "l_store", "r_store", "s_store", "shoulder"], "description": "equip: the slot to put the held item in"}
LINK = {"type": "integer", "minimum": 1, "description": "topic: the number of a link in that window"}
LINK_LABEL = {"type": "string", "description": "topic: a link's label, instead of its number"}
CHARACTER_ACTIONS = ["move", "face", "say", "emote", "click", "use", "craft", "equip", "take", "examine", "drop", "swap_hand", "intent", "resist", "board", "disembark", "drag", "verb", "throw", "ooc", "bug_report", "topic", "close_window", "stance"]
RECIPE = {"type": "string", "description": 'craft: a recipe from character_observe self.craftable, e.g. "sharpened stick" or "group/title".'}
ZONE = {"type": "string", "enum": ["head", "eyes", "mouth", "chest", "groin", "l_arm", "r_arm", "l_hand", "r_hand", "l_leg", "r_leg", "l_foot", "r_foot"], "description": "click: the body part to aim at, e.g. a bleeding limb to bandage"}
ONTO = {"type": "string", "description": "drag: what the target is dragged onto, e.g. a boat ref (target is your own ref from self, or a crate)"}
CHOOSE = {"type": "string", "description": "answer to a menu the step opens, e.g. \"Tunnel\" for a shovel"}
VERB = {"type": "string", "description": 'verb: a verb name from character_observe self.verbs, self.item_verbs or a nearby row\'s verbs, e.g. "Lie Down" (target picks whose verb; onto or text is its argument)'}
EXPECT_NAME = {"type": "string", "description": "refuse the step (target_changed) unless the target's name still contains this, e.g. the name observe showed"}
UNTIL = {"type": "object", "additionalProperties": False, "description": "with repeat: stop early once a new message contains message, the active hand holds an item whose name contains holding, or its stack reaches amount", "properties": {
    "message": {"type": "string"}, "holding": {"type": "string"}, "amount": {"type": "integer", "minimum": 1}}}
ITEM = {"type": "string", "description": 'take: the name of a carried or worn item to take into the empty active hand, e.g. "sharpened flint".'}


def _schema(properties=None, required=()):
    return {"type": "object", "properties": properties or {}, "required": list(required), "additionalProperties": False}


ACTIONS = {
    "discover": ("observe", "List actions, this agent's scopes and rights, and handover settings.", _schema()),
    "status": ("observe", "Server, round, map, season and persistence status.", _schema()),
    "players": ("observe", "Connected players with their mob, health, area and admin rank.", _schema()),
    "inspect": ("observe", "Describe one object: type, location, contents and mob state.", _schema({"target": TARGET}, ["target"])),
    "look": ("observe", "List turfs and visible objects around a target (radius 0-7).", _schema({"target": TARGET, "radius": {"type": "integer", "minimum": 0, "maximum": 7}}, ["target"])),
    "find": ("observe", "Find atoms of a type, optionally on one z-level or matching a name.", _schema({"type": {"type": "string"}, "z": {"type": "integer"}, "name": {"type": "string"}, "limit": {"type": "integer", "minimum": 1, "maximum": 200}}, ["type"])),
    "logs": ("observe", "Recent admin log lines, including every agent action. kind \"food\" returns recent food toxin swallows with source, amounts and cause.", _schema({"count": {"type": "integer", "minimum": 1, "maximum": 200}, "kind": {"type": "string", "enum": ["admin", "food"]}})),
    "job": ("observe", "Result of a proc or verb call that was still running.", _schema({"job": {"type": "string"}}, ["job"])),
    "get_vars": ("vars_read", "Read variables of an object or global. Omit names for a summary of all.", _schema({"target": TARGET, "names": {"type": "array", "items": {"type": "string"}, "maxItems": 100}}, ["target"])),
    "set_var": ("vars_write", "Set one variable on an object or global (logged with old and new value).", _schema({"target": TARGET, "name": {"type": "string"}, "value": VALUE}, ["target", "name", "value"])),
    "call_proc": ("call_proc", "Call a proc on an object, or a global proc when target is omitted.", _schema({"target": TARGET, "proc": {"type": "string"}, "arguments": {"type": "array", "items": VALUE, "maxItems": 16}}, ["proc"])),
    "list_verbs": ("admin_verbs", "Admin verbs this agent's configured rights allow.", _schema()),
    "call_verb": ("admin_verbs", "Run an allowed admin verb by name or path, with optional arguments.", _schema({"verb": {"type": "string"}, "arguments": {"type": "array", "items": VALUE, "maxItems": 16}}, ["verb"])),
    "announce": ("message", "Announce a message to every player.", _schema({"text": {"type": "string"}}, ["text"])),
    "admin_pm": ("message", "Send a private admin message to one player.", _schema({"ckey": {"type": "string"}, "text": {"type": "string"}}, ["ckey", "text"])),
    "narrate": ("message", "Narrate text to one player, or to everyone when ckey is omitted.", _schema({"ckey": {"type": "string"}, "text": {"type": "string"}}, ["text"])),
    "asay": ("message", "Post a message to the online admins.", _schema({"text": {"type": "string"}}, ["text"])),
    "kick": ("moderation", "Disconnect a non-admin player.", _schema({"ckey": {"type": "string"}, "reason": {"type": "string"}}, ["ckey"])),
    "start_round": ("server", "Start the round now from the lobby.", _schema()),
    "restart": ("server", "Restart the world in five seconds (refused during saves).", _schema({"confirm": {"type": "boolean"}, "reason": {"type": "string"}}, ["confirm"])),
    "spawn_atom": ("spawn", "Create 1-20 objects or mobs of a type at a target's turf.", _schema({"type": {"type": "string"}, "target": TARGET, "amount": {"type": "integer", "minimum": 1, "maximum": 20}}, ["type", "target"])),
    "delete_atom": ("spawn", "Delete an object or a mob without a connected player.", _schema({"target": TARGET}, ["target"])),
    "character_spawn": ("characters", "Create a character this agent controls (no ckey needed). With job, it joins like a late joiner: that job's clothes, kit and spawn point.", _schema({"target": TARGET, "type": {"type": "string"}, "name": {"type": "string"}, "job": {"type": "string", "description": 'A late-join job title on this map, e.g. "Nomad".'}, "stay": {"type": "boolean", "description": "With job: start at the target instead of the job's spawn point."}}, ["target"])),
    "character_list": ("characters", "Characters this agent may control, including player handovers.", _schema()),
    "character_observe": ("characters", "What a character sees, its own state, messages it heard since an id, its action queue with results since queue_since, prompts the game raised that no step answered, menu windows it was shown (text and numbered links), and sounds it heard. With since_rev (the rev of the last observe) nearby lists only rows that appeared or changed, plus nearby_removed refs. wait_s holds the call until something is new.", _schema({
        "character": CHARACTER, "radius": {"type": "integer", "minimum": 1, "maximum": 7}, "since": {"type": "integer"}, "queue_since": {"type": "integer"},
        "since_rev": {"type": "integer", "description": "rev from the previous observe: return only nearby changes"},
        "prompt_since": {"type": "integer", "description": "prompts after this id (last_prompt)"},
        "window_since": {"type": "integer", "description": "menu windows shown or refreshed after this id (last_window)"},
        "sound_since": {"type": "integer", "description": "sounds after this id (last_sound)"},
        "footsteps": {"type": "boolean", "description": "include footstep sounds (default false)"},
        "wait_s": {"type": "number", "minimum": 0, "maximum": 60, "description": "wait up to this many seconds for a new message, queue result (queue_since), prompt (prompt_since), sound (sound_since) or nearby change (since_rev)"},
    }, ["character"])),
    "character_view": ("characters", "A picture of what a character sees: its view (radius 1-7, default 7) as an appearance dump with overlays, colours, planes and lighting (and the HUD when a player is in the body), the byond-devtools ingame format. The server sends it in parts (part, view); the client and MCP tool fetch them all and, with BYOND_DEVTOOLS set to a byond-devtools checkout, return it rendered as a PNG, animated with frames > 1. The render report lists undrawn: things in view a player could click that drew nothing.", _schema({
        "character": CHARACTER, "radius": {"type": "integer", "minimum": 1, "maximum": 7},
        "frames": {"type": "integer", "minimum": 1, "maximum": 8, "description": "snapshots to take (client side); more than 1 makes an animated PNG"},
        "interval_s": {"type": "number", "minimum": 0.2, "maximum": 10, "description": "seconds between snapshots (default 1)"},
        "view": {"type": "integer", "description": "with part > 1: the view id part 1 returned"},
        "part": {"type": "integer", "minimum": 1, "description": "which part of the dump text (the client fetches them all when omitted)"},
    }, ["character"])),
    "character_act": ("characters", "Make a character act: move, face, say, emote, click, use, craft, equip, take, examine, drop, swap_hand, intent, resist, board (a raft or boat next to you), disembark, drag (target onto onto), verb (a right-click or panel verb of yourself, a held or worn item or something next to you) throw (the held item at target), topic (press a numbered link of a menu window from character_observe windows), close_window, or stance (HUD toggles: move, defense, tactic, secondary, face_lock, aim); equip takes an optional slot; board, disembark, drag, verb, throw and topic only through character_queue. While driving a boat, move steers it one tile.", _schema({
        "character": CHARACTER,
        "do": {"type": "string", "enum": CHARACTER_ACTIONS},
        "recipe": RECIPE,
        "item": ITEM,
        "amount": {"type": "integer", "minimum": 1},
        "dir": {"type": "string", "enum": ["north", "south", "east", "west", "northeast", "northwest", "southeast", "southwest"]},
        "text": {"type": "string"},
        "target": TARGET,
        "modifier": {"type": "string", "enum": ["shift", "ctrl", "alt", "middle"]},
        "intent": {"type": "string", "enum": ["help", "disarm", "grab", "harm"]},
        "choose": CHOOSE,
        "zone": ZONE,
        "onto": ONTO,
        "name": VERB,
        "expect_name": EXPECT_NAME,
        "window": WINDOW,
        "link": LINK,
        "label": LINK_LABEL,
        "slot": SLOT,
        "move": {"type": "string", "enum": ["run", "walk", "sneak", "crawl"], "description": "stance: movement mode"},
        "defense": {"type": "string", "enum": ["dodge", "parry"], "description": "stance"},
        "tactic": {"type": "string", "enum": ["charge", "aim", "rush", "defend"], "description": "stance"},
        "secondary": {"type": "string", "enum": ["kick", "jump", "bite"], "description": "stance: the middle-click attack"},
        "face_lock": {"type": "boolean", "description": "stance: keep facing one way while moving"},
        "aim": {"type": "boolean", "description": "stance: gun aim mode (hold fire on a target)"},
    }, ["character", "do"])),
    "character_queue": ("characters", "Queue up to 32 actions (64 pending) that the server runs in order, each when its cooldown allows; results appear in character_observe.", _schema({
        "character": CHARACTER,
        "actions": {"type": "array", "maxItems": 32, "items": {
            "type": "object",
            "properties": {
                "do": {"type": "string", "enum": ["wait"] + CHARACTER_ACTIONS},
                "recipe": RECIPE,
                "item": ITEM,
                "amount": {"type": "integer", "minimum": 1},
                "ticks": {"type": "integer", "minimum": 1, "maximum": 600, "description": "wait only: deciseconds"},
                "dir": {"type": "string", "enum": ["north", "south", "east", "west", "northeast", "northwest", "southeast", "southwest"]},
                "text": {"type": "string"},
                "target": TARGET,
                "modifier": {"type": "string", "enum": ["shift", "ctrl", "alt", "middle"]},
                "intent": {"type": "string", "enum": ["help", "disarm", "grab", "harm"]},
                "choose": CHOOSE,
                "zone": ZONE,
                "onto": ONTO,
                "name": VERB,
                "expect_name": EXPECT_NAME,
        "window": WINDOW,
        "link": LINK,
        "label": LINK_LABEL,
        "slot": SLOT,
        "move": {"type": "string", "enum": ["run", "walk", "sneak", "crawl"], "description": "stance: movement mode"},
        "defense": {"type": "string", "enum": ["dodge", "parry"], "description": "stance"},
        "tactic": {"type": "string", "enum": ["charge", "aim", "rush", "defend"], "description": "stance"},
        "secondary": {"type": "string", "enum": ["kick", "jump", "bite"], "description": "stance: the middle-click attack"},
        "face_lock": {"type": "boolean", "description": "stance: keep facing one way while moving"},
        "aim": {"type": "boolean", "description": "stance: gun aim mode (hold fire on a target)"},
                "repeat": {"type": "integer", "minimum": 1, "maximum": 30, "description": "run this step up to this many times (each when its cooldown allows); a blocked move or a failure stops it"},
                "until": UNTIL,
            },
            "required": ["do"],
        }},
        "clear": {"type": "boolean", "description": "drop pending steps first (alone, cancels the queue)"},
        "stop_on_failure": {"type": "boolean", "description": "skip the rest when a step fails (default true)"},
    }, ["character"])),
    "character_route": ("characters", "Plan a route for a character to a tile on its level: walking legs, and when deep water is in the way, boat legs with the launch and landing points, boats near the launch and the raft recipe.", _schema({"character": CHARACTER, "target": TARGET, "x": {"type": "integer"}, "y": {"type": "integer"}, "reach": {"type": "integer", "minimum": 0, "maximum": 5, "description": "stop within this many tiles (default 0, or 1 when the goal tile is blocked)"}}, ["character"])),
    "character_release": ("characters", "Stop controlling a character; spawned ones can be deleted.", _schema({"character": CHARACTER, "delete": {"type": "boolean"}}, ["character"])),
    "visit_status": ("visits", "The running nomad visit (raid or trade): state, party, nearby people, new events since an id, the cue the leader is about to say, and the orders allowed now.", _schema({"since": {"type": "integer"}})),
    "visit_order": ("visits", "Order the running nomad visit: say, retreat, assault, bargain, tactic, focus, loot or price. The party controller checks every order against the current state and bounds.", _schema({
        "order": {"type": "string", "enum": ["say", "retreat", "assault", "bargain", "tactic", "focus", "loot", "price"]},
        "text": {"type": "string", "description": "say: up to 200 characters"},
        "emote": {"type": "string", "description": "say: optional emote, up to 120 characters"},
        "decision": {"type": "string", "enum": ["accept", "counter", "refuse"]},
        "demand": {"type": "integer", "description": "bargain counter: new tribute demand within min_demand..max_demand"},
        "tactic": {"type": "string", "enum": ["advance", "hold", "flank"]},
        "target": TARGET,
        "price": {"type": "integer", "description": "price: half to double the good's base price"},
    }, ["order"])),
    "visit_start": ("visits", "Start a nomad visit (raiders or traders) at the busiest settlement, or near a target.", _schema({"kind": {"type": "string", "enum": ["raid", "trade"]}, "target": TARGET, "size": {"type": "integer", "minimum": 2, "maximum": 6}})),
}

SCOPES = ("*", "observe", "vars_read", "vars_write", "call_proc", "admin_verbs", "message", "moderation", "server", "spawn", "characters", "visits", "ooc", "bug_report")
