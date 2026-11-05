"""Travel and boats for the autopilot: walk a planned route, and cross deep water by raft or boat when it needs one.

The game plans the route (character_route, code/modules/agent_control/agent_boats.dm): walking legs, and boat legs
where deep water is in the way, with the launch tile (the last dry tile), the landing tile, boats near the launch and
the raft recipe (10 wood logs, crafted where she stands). A travel step then:
  walk legs        queue a few moves at a time; a blocked move plans the route again
  boat leg, aboard steer one tile per move (a raft is paddled; a motor boat needs fuel and its engine running)
  boat leg, ashore board a boat near the launch, or craft a raft on the launch tile and board it
  landing          disembark onto the raft's tile, then walk on; the boat stays moored and is remembered
Maintenance: a motor boat with an empty tank is refuelled from a carried fuel container, and its engine is started
with the rudder; a boat that cannot move is reported instead of being steered into the bank.

travel(client, character, step, queue_since, hooks) returns (ok, detail, queue_since). hooks gives the autopilot's
own helpers so this module stays independent of it: run(steps, queue_since) -> (summary, queue_since) and
craft_steps(step, self_state) -> steps that hold the right stack and craft.
"""

import re

RAFT_LOGS = 10
MOVES = {"n": "north", "s": "south", "e": "east", "w": "west"}
DIRS = {"north": (0, 1), "south": (0, -1), "east": (1, 0), "west": (-1, 0)}
FUEL_WORDS = ("diesel", "gasoline", "petrol", "fuel", "ethanol", "biodiesel", "kerosene")
WALK_CHUNK = 10  # moves queued at once; a blocked one re-plans
SAIL_CHUNK = 8
MAX_ROUNDS = 12  # route requests per travel step
MAX_TILES = 150  # the game plans at most this far ahead
MOORED = re.compile(r"left the (.+?) moored at \((\d+),(\d+),(\d+)\)")


def target_of(step, self_state, places=None, home=None):
    """(x, y) for a travel step: x/y, dir + tiles from here, or a remembered place ("home", "boat", "ore"...)."""
    try:
        if step.get("x") is not None and step.get("y") is not None:
            return int(step["x"]), int(step["y"]), ""
    except (TypeError, ValueError):
        return None, None, "x and y must be numbers"
    try:
        here = int(self_state.get("x")), int(self_state.get("y"))
    except (TypeError, ValueError):
        return None, None, "your position is unknown"
    if step.get("dir") in DIRS:
        try:
            tiles = int(step.get("tiles") or 30)
        except (TypeError, ValueError):
            tiles = 30
        tiles = max(1, min(tiles, MAX_TILES))
        sx, sy = DIRS[step["dir"]]
        return here[0] + sx * tiles, here[1] + sy * tiles, ""
    place = str(step.get("to") or "").strip().lower()
    if place:
        if place == "home":
            if home and home.get("z") == self_state.get("z"):
                return home["x"], home["y"], ""
            return None, None, "you have no home on this level yet"
        known = [p for p in (places or {}).get(place, []) if p.get("z") == self_state.get("z")]
        if not known:
            return None, None, f"you remember no {place} on this level"
        near = min(known, key=lambda p: max(abs(p["x"] - here[0]), abs(p["y"] - here[1])))
        return near["x"], near["y"], ""
    return None, None, 'travel needs "x" and "y", "dir" (and "tiles"), or "to" a remembered place'


def describe(observation):
    """A BOAT line for the prompt: the boat she is on, or boats in view, with what they need."""
    me = observation.get("self", {})
    vehicle = me.get("vehicle")
    if isinstance(vehicle, dict):
        text = f"You are aboard the {vehicle.get('name')} as {vehicle.get('role', 'passenger')}"
        if vehicle.get("stalled"):
            text += f"; it cannot move: {vehicle['stalled']}"
        elif vehicle.get("role") == "driver":
            text += "; move steers it over water one tile at a time, disembark to get off at the shore"
        return text + "."
    rows = [row for row in observation.get("nearby", []) if isinstance(row, dict) and row.get("boat")]
    if not rows:
        return ""
    parts = []
    for row in rows[:3]:
        bits = [f"{row.get('name')} dx={row.get('dx')} dy={row.get('dy')}"]
        if row.get("driver"):
            bits.append(f"driven by {row['driver']}")
        if "fuel" in row:
            bits.append(f"fuel {row.get('fuel')}/{row.get('fuel_max')}")
        if row.get("cargo"):
            bits.append("cargo " + ", ".join(map(str, row["cargo"])))
        parts.append(" ".join(bits))
    return "Boats in view: " + "; ".join(parts) + "."


def is_raft_wood(name):
    """The wood stack a raft is crafted from: wood logs (the game's "wooden plank" stack), not cut soft planks."""
    name = str(name or "").lower()
    return ("log" in name and "wood" in name) or name in ("wooden plank", "wooden planks")


def raft_wood(self_state):
    """(name, amount) of the biggest raft-wood stack she holds or carries; a raft takes 10."""
    best = ("", 0)
    for row in self_state.get("items") or []:
        if not isinstance(row, dict) or not is_raft_wood(row.get("name")):
            continue
        try:
            amount = int(row.get("amount") or 1)
        except (TypeError, ValueError):
            amount = 1
        if amount > best[1]:
            best = (str(row["name"]), amount)
    return best


def fuel_item(self_state, fuels=()):
    """A carried container that looks like it holds fuel, by name or listed contents."""
    words = tuple(str(f).lower() for f in fuels) or FUEL_WORDS
    for row in self_state.get("items") or []:
        if not isinstance(row, dict):
            continue
        liquids = row.get("liquids") if isinstance(row.get("liquids"), dict) else {}
        text = " ".join([str(row.get("name", ""))] + [str(k) for k, v in liquids.items() if v]).lower()
        if any(word in text for word in words) and (not liquids or any(liquids.values())):
            return row.get("name")
    return None


def _observe(client, character, queue_since, radius=1):
    reply = client.request("character_observe", {"character": character, "radius": radius, "queue_since": queue_since})
    return reply.get("result", {}) if reply.get("ok") else {}


def _route(client, character, x, y):
    reply = client.request("character_route", {"character": character, "x": x, "y": y})
    if not reply.get("ok"):
        return None, f"{reply.get('error')} {reply.get('detail', '')}".strip()
    return reply["result"], ""


def _moves(letters):
    return [{"do": "move", "dir": MOVES[ch]} for ch in letters if ch in MOVES]


def _ran(summary, word="move"):
    """(moves that went, whether one was blocked or failed) from an execute summary."""
    went = summary.count(f"{word} ok (done)")
    stopped = f"{word} ok (blocked)" in summary or "failed" in summary or "refused" in summary
    return went, stopped


def _refuel_steps(boat, self_state):
    """Steps that pour a carried fuel container into a boat next to her, or None."""
    item = fuel_item(self_state, boat.get("fuels") or ())
    if not item:
        return None
    return [{"do": "take", "item": item, "soft": True}, {"do": "click", "target": boat["ref"]}]


def travel(client, character, step, queue_since, hooks, budget=60):
    """Walk and sail toward step["x"], step["y"] for up to budget tiles. Returns (ok, detail, queue_since)."""
    x, y = step["x"], step["y"]
    run, craft_steps = hooks["run"], hooks["craft_steps"]
    travelled = 0
    notes = []
    for _ in range(MAX_ROUNDS):
        if travelled >= budget:
            break
        route, error = _route(client, character, x, y)
        if route is None:
            return travelled > 0, f"could not plan the way: {error}", queue_since
        if not route.get("reachable"):
            return travelled > 0, route.get("reason") or "there is no way there", queue_since
        legs = route.get("legs") or []
        aboard = route.get("aboard")
        if not legs:
            if isinstance(aboard, dict):
                return travelled > 0, "there, but still aboard: disembark at a shore", queue_since
            notes.append("arrived")
            return True, f"travelled {travelled} tiles; " + "; ".join(notes), queue_since
        leg = legs[0]
        if leg["mode"] == "walk":
            if isinstance(aboard, dict):
                # At the shore on a boat: get off onto its tile, then walk on.
                summary, queue_since = run([{"do": "disembark"}], queue_since)
                if "disembark ok" not in summary:
                    return travelled > 0, f"could not get off the {aboard.get('name')} ({summary})", queue_since
                notes.append(f"left the {aboard.get('name')} moored at ({aboard.get('x')},{aboard.get('y')},{aboard.get('z')})")
            summary, queue_since = run(_moves(leg["moves"][:WALK_CHUNK]), queue_since)
            went, stopped = _ran(summary)
            travelled += went
            if stopped and not went:
                return travelled > 0, f"the way is blocked ({summary[-120:]})", queue_since
            continue
        # A boat leg: she is at the launch tile, or afloat.
        if isinstance(aboard, dict):
            if aboard.get("role") != "driver":
                return travelled > 0, f"you are a passenger on the {aboard.get('name')}; only its driver steers", queue_since
            if aboard.get("stalled"):
                fixed, queue_since = _maintain(aboard, client, character, queue_since, run)
                if not fixed:
                    return travelled > 0, f"the {aboard.get('name')} cannot move: {aboard['stalled']}", queue_since
                notes.append(fixed)
                continue
            summary, queue_since = run(_moves(leg["moves"][:SAIL_CHUNK]), queue_since)
            went, stopped = _ran(summary)
            travelled += went
            if stopped and not went:
                return travelled > 0, f"the {aboard.get('name')} is stuck ({summary[-120:]})", queue_since
            continue
        boats = [b for b in route.get("boats") or [] if not b.get("driver")]
        me = _observe(client, character, queue_since).get("self", {})
        here = [me.get("x"), me.get("y")]
        if boats:
            boat = boats[0]
            if list(boat.get("board_from") or []) != here:
                walk = route_to(client, character, boat["board_from"], queue_since, run)
                ok, detail, queue_since = walk
                if not ok:
                    return travelled > 0, f"could not reach the {boat.get('name')} ({detail})", queue_since
            if boat.get("stalled") and "fuel" in boat["stalled"]:
                steps = _refuel_steps(boat, me)
                if steps:
                    summary, queue_since = run(steps, queue_since)
                    notes.append(f"refuelled the {boat.get('name')}")
            summary, queue_since = run([{"do": "board", "target": boat["ref"]}], queue_since)
            if "board ok" not in summary:
                return travelled > 0, f"could not board the {boat.get('name')} ({summary})", queue_since
            notes.append(f"boarded the {boat.get('name')}")
            continue
        # No boat: build a raft on the launch tile.
        wood, logs = raft_wood(me)
        launch = route.get("launch")
        if logs < RAFT_LOGS:
            return travelled > 0, (f"deep water ahead: you need {RAFT_LOGS} wood logs to build a raft at the shore "
                                   f"({launch[0]},{launch[1]}) and have {logs}; chop trees for logs first") if launch else "deep water ahead and no boat", queue_since
        steps = craft_steps({"do": "craft", "recipe": "raft", "material": wood}, me)
        summary, queue_since = run(steps, queue_since)
        if "craft ok" not in summary:
            return travelled > 0, f"could not build a raft ({summary[-160:]})", queue_since
        look = _observe(client, character, queue_since)
        raft = next((row for row in look.get("nearby", []) if row.get("boat") and row.get("dx") == 0 and row.get("dy") == 0), None)
        if not raft:
            return travelled > 0, "built a raft but cannot see it on this tile (research may be needed)", queue_since
        notes.append("built a raft")
        summary, queue_since = run([{"do": "board", "target": raft["ref"]}], queue_since)
        if "board ok" not in summary:
            return travelled > 0, f"could not board the raft ({summary})", queue_since
    return travelled > 0, f"travelled {travelled} tiles" + ("; " + "; ".join(notes) if notes else "") + "; not there yet", queue_since


def route_to(client, character, xy, queue_since, run, limit=6):
    """Walk (no boat) to a tile. Returns (ok, detail, queue_since)."""
    for _ in range(limit):
        route, error = _route(client, character, xy[0], xy[1])
        if route is None or not route.get("reachable"):
            return False, error or (route or {}).get("reason", "no way"), queue_since
        legs = route.get("legs") or []
        if not legs:
            return True, "there", queue_since
        if route.get("needs_boat") or legs[0]["mode"] != "walk":
            return False, "it is across water", queue_since
        summary, queue_since = run(_moves(legs[0]["moves"][:WALK_CHUNK]), queue_since)
        went, stopped = _ran(summary)
        if stopped and not went:
            return False, "blocked", queue_since
    return False, "still walking", queue_since


def _maintain(boat, client, character, queue_since, run):
    """Fix what stops a boat she drives: fuel, then the engine. Returns (what was done or "", queue_since)."""
    stalled = str(boat.get("stalled", ""))
    if "fuel" in stalled:
        me = _observe(client, character, queue_since).get("self", {})
        steps = _refuel_steps(boat, me)
        if not steps:
            return "", queue_since
        summary, queue_since = run(steps, queue_since)
        return ("refuelled the boat" if "click ok" in summary else ""), queue_since
    if "engine is off" in stalled:
        summary, queue_since = run([{"do": "use"}], queue_since)  # the rudder in hand starts the engine
        return ("started the engine" if "use ok" in summary else ""), queue_since
    return "", queue_since


def moored(detail):
    """(name, x, y, z) of a boat a travel summary left moored, or None."""
    match = MOORED.search(detail or "")
    if not match:
        return None
    return match.group(1), int(match.group(2)), int(match.group(3)), int(match.group(4))
