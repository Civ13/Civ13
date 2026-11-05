"""Long-term memory for an agent character: places, people and events that survive a restart.

A real player remembers where home is, where the clean water was and who was friendly. The
autopilot used to forget all of that whenever it reattached. This keeps a small JSON file per
character on the host (data/agent-control/memory/), updates it from each observation, and gives
the model a short slice of it in every prompt.

People are remembered by the name the character sees, as a player would: no ckeys or other
account data are read or stored. What players said is kept as quoted game text (data, never
instructions) and only ever goes to the local model. Staff reset a character by deleting its file.
"""
import json
import os
import re
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_DIR = ROOT / "data" / "agent-control" / "memory"
VERSION = 1
MAX_EVENTS = 40
MAX_FACTS = 20
MAX_PEOPLE = 60
MAX_PLACES = 8  # per kind
MAX_LINES = 4  # remembered lines per person, each way
MAX_STRUCTURES = 200
# Structures worth maintaining: what holds a roof or a tunnel up, and what the character lives in.
STRUCTURE_WORDS = ("wall", "door", "roof", "support", "fence", "campfire", "bed", "table", "furnace", "bloomery",
                   "kiln", "anvil", "rack", "chest", "shelf", "palisade", "ladder", "tunnel", "shaft", "floor")
# Ones the game keeps as objects in view (floors and most walls are turfs, which the observation lists only by kind).
VISIBLE_STRUCTURES = ("door", "roof support", "mine support", "fence", "campfire", "bed", "table", "furnace",
                      "bloomery", "kiln", "anvil", "rack", "chest", "shelf", "ladder")
TRUST_MIN, TRUST_MAX = -5, 5

# What a nearby or terrain row is, for the places worth finding again.
PLACE_KINDS = (
    ("clean water", lambda row: _is_water(row) and not row.get("sickness") and not row.get("salty")),
    ("unclean water", lambda row: _is_water(row) and (row.get("sickness") or row.get("salty"))),
    ("ore", lambda row: re.search(r"\bore\b|deposit", _lower(row)) is not None),
    ("rock", lambda row: "rock" in _lower(row) and not row.get("mob")),
    ("clay", lambda row: "clay" in _lower(row) and not row.get("mob")),
    ("fire", lambda row: any(word in _lower(row) for word in ("campfire", "fireplace", "bonfire"))),
)


def _lower(row):
    return str(row.get("name", "")).lower()


def _is_water(row):
    name = _lower(row)
    return any(word in name for word in ("river", "lake", "water", "pond", "sea", "ocean", "well"))


def _safe(name):
    return re.sub(r"[^A-Za-z0-9_-]+", "_", str(name or "character")).strip("_")[:48] or "character"


def _clip(text, limit=160):
    return str(text).replace("\n", " ").strip()[:limit]


def _direction(dx, dy):
    """Compass words for an offset (east and north are positive)."""
    ns = "north" if dy > 0 else "south" if dy < 0 else ""
    ew = "east" if dx > 0 else "west" if dx < 0 else ""
    if abs(dx) > 2 * abs(dy):
        ns = ""
    elif abs(dy) > 2 * abs(dx):
        ew = ""
    return (ns + ew) or "here"


def _is_person(row, me):
    """A living human other than herself (animals, corpses and her own row are not people)."""
    if not row.get("mob") or row.get("stat") == 2 or not str(row.get("type", "")).startswith("/mob/living/human"):
        return False
    if me.get("ref") and row.get("ref") == me.get("ref"):
        return False
    return not (row.get("dx") == 0 and row.get("dy") == 0 and str(row.get("name", "")) == str(me.get("name", "")))


class CharacterMemory:
    def __init__(self, path, name=""):
        self.path = Path(path)
        self.data = {"version": VERSION, "character": name, "home": None, "places": {}, "people": {},
                     "events": [], "facts": [], "steps": 0, "structures": [], "made": {},
                     "project": None}  # the blueprint being built (see blueprints.py)
        self.dirty = False

    # --- persistence --------------------------------------------------------------------------
    @classmethod
    def load(cls, name, directory=None):
        directory = Path(directory) if directory else DEFAULT_DIR
        memory = cls(directory / f"{_safe(name)}.json", name)
        try:
            saved = json.loads(memory.path.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            return memory
        if isinstance(saved, dict) and saved.get("version") == VERSION:
            for key in memory.data:
                if key in saved and isinstance(saved[key], type(memory.data[key]) if memory.data[key] is not None else (dict, type(None))):
                    memory.data[key] = saved[key]
        return memory

    def save(self):
        if not self.dirty:
            return
        self.path.parent.mkdir(parents=True, exist_ok=True)
        temp = self.path.with_suffix(".tmp")
        temp.write_text(json.dumps(self.data, indent=1, sort_keys=True), encoding="utf-8")
        os.replace(temp, self.path)  # a crash mid-write keeps the previous file
        self.dirty = False

    # --- recording ----------------------------------------------------------------------------
    def event(self, text, when=None):
        events = self.data["events"]
        text = _clip(text)
        if events and events[-1].get("text") == text:
            return
        events.append({"t": int(when or time.time()), "text": text})
        del events[:-MAX_EVENTS]
        self.dirty = True

    def remember(self, fact):
        """A fact the model asked to keep (a promise, a plan, where something is)."""
        fact = _clip(fact, 120)
        if not fact or fact in self.data["facts"]:
            return
        self.data["facts"].append(fact)
        del self.data["facts"][:-MAX_FACTS]
        self.dirty = True

    def made(self, recipe):
        """Count one more of something made; returns the new count."""
        key = _clip(recipe, 60).lower()
        made = self.data.setdefault("made", {})
        made[key] = made.get(key, 0) + 1
        if len(made) > 300:
            del made[min(made, key=made.get)]
        self.dirty = True
        return made[key]

    def built(self, name, x, y, z):
        """Record a structure the character placed, so it can be checked and kept up later."""
        if not all(isinstance(v, int) for v in (x, y)) or not any(word in str(name).lower() for word in STRUCTURE_WORDS):
            return
        ledger = self.data.setdefault("structures", [])
        for item in ledger:
            if item["x"] == x and item["y"] == y and item.get("z") == z and item["name"] == _clip(name, 40):
                item["built"] = int(time.time())
                self.dirty = True
                return
        ledger.append({"name": _clip(name, 40), "x": x, "y": y, "z": z, "built": int(time.time())})
        del ledger[:-MAX_STRUCTURES]
        self.dirty = True

    def maintenance(self, observation, radius=4):
        """Problems with the character's own structures in view: unsupported roofs, missing pieces, unsafe tunnels."""
        me = observation.get("self", {})
        x, y, z = me.get("x"), me.get("y"), me.get("z")
        if not all(isinstance(v, int) for v in (x, y)):
            return []
        problems = []
        here = observation.get("here") or {}
        if here.get("cave_supported") is False:
            problems.append("the tunnel where you stand has no support and can cave in: build a mine support here now, or climb out")
        rows = [r for r in observation.get("nearby", []) + observation.get("terrain", []) if isinstance(r, dict)
                and isinstance(r.get("dx"), int) and isinstance(r.get("dy"), int)]
        for row in rows:
            if "roof" in _lower(row) and row.get("supported") is False and max(abs(row["dx"]), abs(row["dy"])) <= 3:
                problems.append(f"the roof at ({x + row['dx']},{y + row['dy']}) has no support and can collapse: "
                                "build a roof support within 3 tiles of it (or a wall within 2)")
                break
        # The game lists what the character can see, at most 64 things: a piece behind a wall, in the dark or
        # past that cap is out of view, not gone. Only the tiles next to the character are surely in view.
        ledger = self.data.get("structures", [])
        listing_full = len(observation.get("nearby", [])) >= 64
        for item in list(ledger):
            if item.get("z") != z or max(abs(item["x"] - x), abs(item["y"] - y)) > min(radius, 1):
                continue
            name = item["name"].lower()
            if listing_full or not any(word in name for word in VISIBLE_STRUCTURES):
                continue
            present = any(max(abs(x + r["dx"] - item["x"]), abs(y + r["dy"] - item["y"])) <= 1
                          and _lower(r) and (name in _lower(r) or _lower(r) in name) for r in rows)
            if not present:
                problems.append(f"your {item['name']} at ({item['x']},{item['y']}) is gone: rebuild it, or check what holds up the roof near it")
                ledger.remove(item)  # said once; a rebuilt one goes back in the ledger
                self.dirty = True
        return problems[:3]

    def boat(self, name, x, y, z):
        """Where she left a boat moored, so travel can take it back (the "boat" place)."""
        places = self.data["places"].setdefault("boat", [])
        places[:] = [p for p in places if max(abs(p["x"] - x), abs(p["y"] - y)) > 3 or p.get("z") != z]
        self._place("boat", name, x, y, z)
        self.event(f"left my {_clip(name, 30)} moored at ({x},{y})")

    def set_home(self, x, y, z, why="home"):
        self.data["home"] = {"x": x, "y": y, "z": z, "why": _clip(why, 60)}
        self.event(f"made {why} my home at ({x},{y})")

    def _place(self, kind, name, x, y, z):
        places = self.data["places"].setdefault(kind, [])
        for place in places:
            if abs(place["x"] - x) <= 3 and abs(place["y"] - y) <= 3 and place.get("z") == z:
                place["seen"] = int(time.time())
                return
        places.append({"name": _clip(name, 40), "x": x, "y": y, "z": z, "seen": int(time.time())})
        del places[:-MAX_PLACES]
        self.dirty = True

    def forget_non_people(self, own_name, animal_words=("horse", "cow", "goat", "sheep", "pig", "chicken", "dog", "cat", "deer", "wolf", "bear")):
        """Drop people records that were really herself or an animal (older memory files had both)."""
        own = str(own_name or "").lower()
        for name in list(self.data["people"]):
            lowered = name.lower()
            if lowered == own or lowered in animal_words:
                del self.data["people"][name]
                self.dirty = True

    def person(self, name):
        people = self.data["people"]
        key = _clip(name, 40)
        if key not in people:
            if len(people) >= MAX_PEOPLE:
                oldest = min(people, key=lambda who: people[who].get("last_seen", 0))
                del people[oldest]
            people[key] = {"first_met": int(time.time()), "last_seen": 0, "times_met": 0,
                           "trust": 0, "they_said": [], "i_said": [], "notes": []}
            self.dirty = True
        return people[key]

    def adjust_trust(self, name, amount, why):
        who = self.person(name)
        who["trust"] = max(TRUST_MIN, min(TRUST_MAX, who.get("trust", 0) + amount))
        who["notes"].append(_clip(why, 100))
        del who["notes"][:-6]
        self.event(f"{name}: {why}")
        self.dirty = True

    def observe(self, observation, speech=(), attackers=(), now=None):
        """Update places and people from one observation; speech is [(speaker, line)]."""
        now = int(now or time.time())
        me = observation.get("self", {})
        x, y, z = me.get("x"), me.get("y"), me.get("z")
        if not all(isinstance(v, int) for v in (x, y)):
            return
        self.data["steps"] = self.data.get("steps", 0) + 1
        self.dirty = True
        for row in observation.get("terrain", []) + observation.get("nearby", []):
            if not isinstance(row, dict) or not isinstance(row.get("dx"), int) or not isinstance(row.get("dy"), int):
                continue
            for kind, test in PLACE_KINDS:
                if test(row):
                    self._place(kind, row.get("name", kind), x + row["dx"], y + row["dy"], z)
                    break
            if _is_person(row, me):
                who = self.person(row.get("name", "someone"))
                if now - who.get("last_seen", 0) > 600:  # a new meeting after ten minutes apart
                    who["times_met"] = who.get("times_met", 0) + 1
                    who["met_at"] = {"x": x, "y": y, "z": z}
                    if who["times_met"] == 1:
                        self.event(f"met {row.get('name')} at ({x},{y})")
                who["last_seen"] = now
        animals = {str(row.get("name", "")).lower() for row in observation.get("nearby", []) if row.get("mob") and not _is_person(row, me)}
        for speaker, line in speech:
            if str(speaker).lower() in animals or str(speaker).lower() == str(me.get("name", "")).lower():
                continue  # a horse "screams", and her own words are not someone else's
            who = self.person(speaker)
            who["last_seen"] = now
            if _clip(line) not in who["they_said"]:
                who["they_said"].append(_clip(line))
                del who["they_said"][:-MAX_LINES]
                who["talks"] = who.get("talks", 0) + 1
                if who["talks"] % 3 == 0 and who.get("trust", 0) < 2:  # talk makes someone familiar, not a friend
                    who["trust"] = who.get("trust", 0) + 1
        people = {str(row.get("name", "")).lower(): str(row.get("name", "")) for row in observation.get("nearby", []) if _is_person(row, me)}
        for name in dict.fromkeys(str(n).lower() for n in attackers if n):
            if name in people:  # a person, not an animal, hit her
                self.adjust_trust(people[name], -3, "attacked me")

    def said(self, speakers, text):
        """Record what the character answered the people it was answering."""
        for name in speakers:
            who = self.person(name)
            who["i_said"].append(_clip(text))
            del who["i_said"][:-MAX_LINES]
        self.dirty = True

    # --- recall -------------------------------------------------------------------------------
    @staticmethod
    def standing(trust):
        if trust <= -2:
            return "hostile"
        if trust >= 3:
            return "friend"
        if trust >= 1:
            return "friendly"
        return "acquaintance"

    def recall(self, observation, limit_people=4):
        """A few lines of memory relevant to where the character is and who is around."""
        me = observation.get("self", {})
        x, y, z = me.get("x"), me.get("y"), me.get("z")
        if not all(isinstance(v, int) for v in (x, y)):
            return ""
        lines = []
        home = self.data.get("home")
        if home and home.get("z") == z:
            dx, dy = home["x"] - x, home["y"] - y
            far = max(abs(dx), abs(dy))
            lines.append(f"Home ({home.get('why')}): " + ("you are there" if far <= 3 else f"{far} tiles {_direction(dx, dy)}"))
        for kind in ("clean water", "ore", "clay", "rock", "fire", "boat"):
            known = [p for p in self.data["places"].get(kind, []) if p.get("z") == z]
            if not known:
                continue
            near = min(known, key=lambda p: max(abs(p["x"] - x), abs(p["y"] - y)))
            far = max(abs(near["x"] - x), abs(near["y"] - y))
            if far > 2:  # what is in view is listed anyway
                lines.append(f"Known {kind}: {near['name']} {far} tiles {_direction(near['x'] - x, near['y'] - y)}")
        visible = {str(row.get("name", "")) for row in observation.get("nearby", []) if row.get("mob")}
        people = self.data["people"]
        shown = [name for name in people if name in visible][:limit_people]
        for name in shown:
            who = people[name]
            text = f"{name}: {self.standing(who.get('trust', 0))}, met {who.get('times_met', 1)} time(s)"
            if who.get("notes"):
                text += "; " + who["notes"][-1]
            if who.get("they_said"):
                text += f"; last said: {who['they_said'][-1][:100]}"
            if who.get("i_said"):
                text += f"; you told them: {who['i_said'][-1][:80]}"
            lines.append(text)
        for problem in self.maintenance(observation):
            lines.append("REPAIR: " + problem)
        own = [s for s in self.data.get("structures", []) if s.get("z") == z and max(abs(s["x"] - x), abs(s["y"] - y)) <= 8]
        if own:
            counts = {}
            for item in own:
                counts[item["name"]] = counts.get(item["name"], 0) + 1
            lines.append("Your structures here: " + ", ".join(f"{n} x{c}" if c > 1 else n for n, c in list(counts.items())[:8]))
        made = self.data.get("made") or {}
        if made:
            top = sorted(made.items(), key=lambda pair: -pair[1])[:5]
            lines.append("Already made: " + ", ".join(f"{count} {name}" for name, count in top))
        if self.data["facts"]:
            lines.append("Things you decided to remember: " + " | ".join(self.data["facts"][-5:]))
        recent = [e["text"] for e in self.data["events"][-3:]]
        if recent:
            lines.append("Recently: " + "; ".join(recent))
        return "\n".join("  " + line for line in lines)
