"""What the autopilot's character noticed between two looks: change lists, prompts and sounds.

SensesClient wraps an AgentClient. Every character_observe it sends asks only for what changed since the
previous one (since_rev), and for prompts and sounds after the last ones it saw. It rebuilds the full nearby
list from its cache, so callers still get a complete observation, and it keeps what happened (things that
appeared or left, unanswered prompts, sounds) until the main loop takes it with take_news().
"""

import math

NEWS_MAX = 12  # prompts or sounds kept between two take_news() calls
DANGER_KINDS = ("gunshot", "explosion")
LOUD_RANGE = 12  # tiles: gunfire or an explosion this close is a warning


def _distance_key(row):
    dx, dy = abs(row.get("dx") or 0), abs(row.get("dy") or 0)
    return (max(dx, dy), dx + dy)


class _Seen:
    def __init__(self):
        self.rev = 0
        self.rows = {}  # ref -> row with "_x"/"_y" map position
        self.prompt_since = 0
        self.sound_since = 0
        self.prompts = []
        self.sounds = []
        self.appeared = {}  # ref -> name
        self.left = {}  # ref -> name
        self.radius = None  # comings and goings are only noted between looks of the same radius


class SensesClient:
    """Change-list observing over any client with request(action, args)."""

    def __init__(self, client):
        self.client = client
        self.seen = {}

    def request(self, action, args=None):
        if action != "character_observe" or not isinstance(args, dict) or not args.get("character"):
            return self.client.request(action, args)
        state = self.seen.setdefault(str(args["character"]), _Seen())
        sent = dict(args)
        if state.rev:
            sent.setdefault("since_rev", state.rev)
        sent.setdefault("prompt_since", state.prompt_since)
        sent.setdefault("sound_since", state.sound_since)
        reply = self.client.request(action, sent)
        if isinstance(reply, dict) and reply.get("ok") and isinstance(reply.get("result"), dict):
            radius = args.get("radius", 5)
            self._absorb(state, reply["result"], note=state.radius == radius)
            state.radius = radius
        return reply

    def _absorb(self, state, result, note=True):
        me = result.get("self") or {}
        x, y = me.get("x"), me.get("y")
        placed = isinstance(x, (int, float)) and isinstance(y, (int, float))
        incremental = result.get("changes_since") is not None and result.get("changes_since") == state.rev and placed
        if incremental:
            rows = dict(state.rows)
            for ref in result.get("nearby_removed") or []:
                gone = rows.pop(ref, None)
                if gone is not None and note:
                    state.left[ref] = gone.get("name")
                    state.appeared.pop(ref, None)
        else:
            rows = {}
        fresh = {}
        for row in result.get("nearby") or []:
            ref = row.get("ref")
            if ref is None:
                continue
            stored = dict(row)
            if placed:
                stored["_x"], stored["_y"] = x + (row.get("dx") or 0), y + (row.get("dy") or 0)
            fresh[ref] = stored
        if incremental:
            for ref, row in fresh.items():
                if ref not in rows and note:
                    state.appeared[ref] = row.get("name")
                    state.left.pop(ref, None)
                rows[ref] = row
        else:
            if state.rows and note:
                for ref, row in fresh.items():
                    if ref not in state.rows:
                        state.appeared[ref] = row.get("name")
                        state.left.pop(ref, None)
                for ref, row in state.rows.items():
                    if ref not in fresh:
                        state.left[ref] = row.get("name")
                        state.appeared.pop(ref, None)
            rows = fresh
        state.rows = rows
        if isinstance(result.get("rev"), int):
            state.rev = result["rev"]
        nearby = []
        for row in rows.values():
            out = {k: v for k, v in row.items() if k not in ("_x", "_y")}
            if placed and "_x" in row:
                out["dx"], out["dy"] = row["_x"] - x, row["_y"] - y
            nearby.append(out)
        nearby.sort(key=_distance_key)
        result["nearby"] = nearby
        for key in ("changes_since", "nearby_removed", "nearby_unchanged"):
            result.pop(key, None)
        for prompt in result.get("prompts") or []:
            state.prompts = (state.prompts + [prompt])[-NEWS_MAX:]
        if isinstance(result.get("last_prompt"), int):
            state.prompt_since = max(state.prompt_since, result["last_prompt"])
        for sound in result.get("sounds") or []:
            if isinstance(sound, dict) and placed:
                sound = dict(sound, _x=x + (sound.get("dx") or 0), _y=y + (sound.get("dy") or 0))
            state.sounds = (state.sounds + [sound])[-NEWS_MAX:]
        if isinstance(result.get("last_sound"), int):
            state.sound_since = max(state.sound_since, result["last_sound"])

    def take_news(self, character, self_state=None):
        """Prompts, sounds and comings and goings since the last call; sound offsets are from where the character is now."""
        state = self.seen.get(str(character))
        if state is None:
            return {"prompts": [], "sounds": [], "appeared": [], "left": []}
        me = self_state or {}
        x, y = me.get("x"), me.get("y")
        sounds = []
        for sound in state.sounds:
            out = {k: v for k, v in sound.items() if k not in ("_x", "_y")}
            if "_x" in sound and isinstance(x, (int, float)) and isinstance(y, (int, float)):
                out["dx"], out["dy"] = sound["_x"] - x, sound["_y"] - y
            sounds.append(out)
        news = {"prompts": state.prompts, "sounds": sounds,
                "appeared": [n for n in state.appeared.values() if n], "left": [n for n in state.left.values() if n]}
        state.prompts, state.sounds, state.appeared, state.left = [], [], {}, {}
        return news


def compass(dx, dy):
    """'north-east' style direction for an offset (y grows to the north), or 'right here'."""
    dx, dy = dx or 0, dy or 0
    if not dx and not dy:
        return "right here"
    angle = math.degrees(math.atan2(dy, dx)) % 360
    names = ("east", "north-east", "north", "north-west", "west", "south-west", "south", "south-east")
    return names[int((angle + 22.5) // 45) % 8]


def sound_line(sound):
    """One heard sound for the model: what it was and where it came from."""
    dx, dy = sound.get("dx") or 0, sound.get("dy") or 0
    tiles = max(abs(dx), abs(dy))
    kind = sound.get("kind")
    what = {"gunshot": "a gunshot", "explosion": "an explosion", "animal": f"an animal ({sound.get('sound')})",
            "voice": f"a voice ({sound.get('sound')})"}.get(kind, str(sound.get("sound") or "a sound"))
    where = "right here" if not tiles else f"{tiles} tiles {compass(dx, dy)}"
    return f"{what}, {where}"


def heard_lines(sounds, limit=6):
    """Distinct sounds, most recent last; repeats of one sound from one place are merged with a count."""
    merged = {}
    for sound in sounds:
        line = sound_line(sound)
        merged[line] = merged.get(line, 0) + 1
    lines = [line + (f" (x{count})" if count > 1 else "") for line, count in merged.items()]
    return lines[-limit:]


def sound_alarm(sounds):
    """A warning for gunfire or an explosion close by, or ''."""
    close = [s for s in sounds if s.get("kind") in DANGER_KINDS and max(abs(s.get("dx") or 0), abs(s.get("dy") or 0)) <= LOUD_RANGE]
    if not close:
        return ""
    nearest = min(close, key=lambda s: max(abs(s.get("dx") or 0), abs(s.get("dy") or 0)))
    return (f"WARNING: you heard {sound_line(nearest)}. Someone may be fighting nearby: take cover or move away "
            "unless you mean to join in.")


def prompt_lines(prompts, limit=3):
    """Prompts the character's steps could not answer, with how to answer them next time."""
    lines = []
    for prompt in prompts[-limit:]:
        asked = " - ".join(p for p in (str(prompt.get("title") or "").strip(), str(prompt.get("text") or "").strip()) if p)
        if prompt.get("choices"):
            options = ", ".join(map(str, prompt["choices"][:12]))
            took = prompt.get("took")
            lines.append(f'The game asked "{asked}" (options: {options}); ' + (f'it took "{took}". ' if took else "nothing was picked. ")
                         + 'To pick another, repeat that step with "choose": "<option>".')
        else:
            lines.append(f'The game asked "{asked}" ({prompt.get("kind") or "text"} input) and got no answer. Repeat that step with "choose": "<answer>".')
    return lines
