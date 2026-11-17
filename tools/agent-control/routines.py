"""Need-driven routines and standing work orders, so the language model only directs.

Every turn the autopilot asks `Routines.choose` first. Each routine advertises how much it restores of one
need (the Sims "advertisement"); its score is that share times the need's urgency (needs.py). A standing work
order from the director (repeat a skill, keep building a blueprint, keep working leather, explore) scores a
flat WORK_DRIVE, so a need only interrupts work once it is pressing, and a critical need always does. When
nothing applies, or something new needs judgement (speech, danger, a failing routine, the director's turn),
the autopilot asks the model instead.

Routines only produce the same plan steps the model would write, with list numbers for targets, so they go
through the same parsing, expansion and execution as the model's plans: the same verbs and clicks a player has.
"""

import json

import blueprints
import needs
import scripts

WORK_DRIVE = 0.25  # what a standing order is worth against a need's urgency
MIN_NEED = 0.08  # needs pulling less than this are left alone even when idle
STICKY = 0.05  # bonus that keeps the last routine going rather than flip-flopping
MAX_TIMES = 40  # most repeats a director may order at once
SCRIPT_BUDGET = 30  # steps a script order may take before the director reviews it
FAIL_LIMIT = 2  # failed runs in a row before a routine is dropped and the director asked
LOG_KEEP = 8
WORK_DOS = ("build_next", "leather_next", "explore", "boil_water")
SELF_SKILLS = ("twist_twine", "eat", "treat", "dig_down")
DIRS = ("north", "south", "east", "west")
READY_WORDS = ("roasted", "cooked", "berr", "fruit", "bread", "apple")


class Choice:
    def __init__(self, name, plan, score, need="", note=""):
        self.name, self.plan, self.score, self.need, self.note = name, plan, score, need, note

    def answer(self, note=""):
        """The routine as a model-style reply, so it runs through the ordinary plan pipeline."""
        return json.dumps({"plan": self.plan, "note": note, "why": f"routine: {self.name}"})

    def __repr__(self):
        return f"Choice({self.name!r}, {self.plan!r}, {self.score:.2f})"


def _distance(row):
    try:
        return max(abs(int(row.get("dx"))), abs(int(row.get("dy"))))
    except (TypeError, ValueError):
        return 99


def numbered(plan, refs):
    """Plan steps as the model writes them, with list numbers for targets (0 is herself), or None when a target is not listed."""
    out = []
    for item in plan:
        item = dict(item)
        if "skill" in item:
            item["do"] = item.pop("skill")  # the model writes skills as {"do": skill, "target": n}
        target = item.get("target")
        if target is not None and not isinstance(target, int):
            if refs and target == refs[0]:
                item["target"] = 0
            elif target in refs:
                item["target"] = refs.index(target)
            else:
                return None
        out.append(item)
    return out


class Situation:
    """What one turn's routines may look at."""

    def __init__(self, observation, refs, kit, ignored=(), explore_dir="north", box=None, social_age=None, threatened=False):
        self.observation, self.refs, self.kit = observation, refs, kit
        self.me = observation.get("self", {}) or {}
        self.ignored, self.explore_dir, self.box = ignored, explore_dir, box or {}
        self.last = ""  # the routine that ran last turn
        self.levels = needs.read(self.me, social_age, threatened)
        # Floodwater where she stands (the observation's here.flood_band, 1 ankle to 4 over her head) is a danger too.
        band = flood_band(observation.get("here"))
        if band >= FLOOD_LEAVE and "safety" in self.levels:
            self.levels["safety"] = min(self.levels["safety"], FLOOD_SAFETY.get(band, 0.0))

    def rows(self):
        return [row for row in self.kit.target_rows(self.observation).values()
                if row.get("ref") not in self.ignored and row.get("ref") in self.refs]

    def nearest(self, test):
        rows = [row for row in self.rows() if test(row)]
        return min(rows, key=_distance) if rows else None

    def carrying(self, test):
        return self.kit.has(self.me, test)


# Need routines: (name, need, share of the need it restores, plan function). A plan function returns plan
# steps (targets as refs or 0) or None when the routine cannot run here.

FLOOD_LEAVE = 3  # waist-deep: slow, and one step from swimming
FLOOD_SAFETY = {3: 25.0, 4: 0.0}  # safety level while standing in that much floodwater


def flood_band(row):
    try:
        return int((row or {}).get("flood_band") or 0)
    except (TypeError, ValueError, AttributeError):
        return 0


def plan_leave_flood(sit):
    """Wade out of deep floodwater: explore toward the open side with the shallowest water, ties going her way."""
    here = flood_band(sit.observation.get("here"))
    if here < FLOOD_LEAVE:
        return None
    sides = sit.observation.get("surroundings") or {}
    best = None
    for direction in (sit.explore_dir,) + tuple(d for d in DIRS if d != sit.explore_dir):
        side = sides.get(direction)
        if not isinstance(side, dict) or side.get("blocked"):
            continue
        band = flood_band(side)
        if best is None or band < best[0]:
            best = (band, direction)
    if best is None:
        return None
    return [{"do": "explore", "dir": best[1]}]


def plan_relieve(sit):
    bladder, bowels = sit.me.get("bladder") or 0, sit.me.get("bowels") or 0
    if isinstance(bowels, (int, float)) and bowels >= 250:
        return [{"do": "verb", "name": "poop"}]
    if isinstance(bladder, (int, float)) and bladder >= 100:
        return [{"do": "verb", "name": "pee"}]
    return None


def plan_drink(sit):
    step = sit.kit.thirst_plan(sit.observation, sit.explore_dir, sit.ignored, threshold=float("inf"))
    if step and step.get("do") == "boil_water":
        plan = scripts.water(sit)  # boiling, or fetching the mug, fire, stone or stick it still lacks
        return None if plan == scripts.DONE else plan
    return [step] if step else None


def _ready(name):
    name = str(name).lower()
    return any(word in name for word in READY_WORDS)


def plan_eat(sit):
    kit = sit.kit
    if sit.carrying(lambda n: kit.is_food(n) and _ready(n)):
        return [{"skill": "eat", "target": 0}]
    if sit.levels.get("hunger", 100) < needs.CRITICAL["hunger"] and sit.carrying(kit.is_food):
        return [{"skill": "eat", "target": 0}]  # starving: raw food beats none
    return None


def _is_fire(sit, row):
    return not row.get("item") and any(word in str(row.get("name", "")).lower() for word in sit.kit.fire_words)


def plan_cook(sit):
    kit = sit.kit
    cooked = sit.nearest(lambda row: row.get("item") and kit.is_food(row.get("name")) and _ready(row.get("name")) and _distance(row) <= 3)
    if cooked:
        return [{"skill": "pick_up", "target": cooked["ref"]}]
    fire = sit.nearest(lambda row: _is_fire(sit, row))
    if not fire:
        return None
    raw = sit.carrying(lambda n: kit.is_food(n) and not _ready(n))
    lit = fire.get("lit")
    fuel = fire.get("fuel")
    if raw and not lit and isinstance(fuel, (int, float)) and fuel < 1 and sit.carrying(kit.is_fuel):
        return [{"skill": "fuel_fire", "target": fire["ref"]}]
    if raw:
        return [{"skill": "cook", "target": fire["ref"]}]
    if lit is False and sit.last == "cook":
        return [{"skill": "light_fire", "target": fire["ref"]}]  # the food she just put in cooks once it burns
    return None


def plan_warm(sit):
    body = sit.me.get("bodytemperature")
    if not isinstance(body, (int, float)) or body >= needs.COMFORT_LOW:
        return None  # too hot is the director's problem: shade and clothes need judgement
    step = sit.kit.cold_plan(sit.observation, sit.ignored, threshold=float("inf"))
    if step:
        return [step]
    # No clothes, fire or logs to hand: make what a campfire needs (flint, spear, axe, logs) rather than freeze.
    plan = scripts.campfire(sit)
    return None if plan == scripts.DONE else plan


def plan_treat(sit):
    if not sit.kit.worst_wound(sit.me):
        return None
    steps, error = sit.kit.treat_plan(sit.me)
    return [{"skill": "treat", "target": 0}] if steps and not error else None


def plan_cure(sit):
    # Freeing a hand can take more steps than one plan holds; the autopilot's illness override then runs them all.
    steps, error = sit.kit.illness_plan(sit.me)
    return steps if steps and not error else None


def plan_hunt(sit):
    if sit.levels.get("hunger", 100) >= 50 or sit.levels.get("safety", 100) < 100:
        return None
    step = scripts.hunt(sit)
    return None if step == scripts.DONE else step


def plan_rest(sit):
    if sit.levels.get("energy", 100) >= 25 or sit.levels.get("safety", 100) < 100:
        return None
    return [{"do": "wait", "ticks": 50}]  # stamina comes back while standing still


NEED_ROUTINES = (
    ("leave flood", "safety", 95, plan_leave_flood),
    ("cure", "health", 90, plan_cure),
    ("treat", "health", 60, plan_treat),
    ("drink", "thirst", 70, plan_drink),
    ("warm up", "warmth", 70, plan_warm),
    ("eat", "hunger", 60, plan_eat),
    ("cook", "hunger", 45, plan_cook),
    ("hunt", "hunger", 30, plan_hunt),
    ("relieve", "relief", 85, plan_relieve),
    ("rest", "energy", 40, plan_rest),
)

# Needs no routine can meet safely by itself: the director gets a hint instead.
HINTS = {
    "hygiene": "hygiene is low: undress, stand in water or a shower and use soap on yourself (or splash yourself with "
               "30+ water from a container), then dress; filth stops sleep and breeds fleas",
    "social": "you have been alone a long time: talk with someone nearby",
    "warmth": "you are too hot: get into shade or under a roof, drink, and take off heavy clothes",
}


def parse_order(raw):
    """A director's standing order from its reply: {"skill"|"do": ..., "times": n, "word": ...}, "none", or None."""
    if isinstance(raw, str):
        text = raw.strip().lower()
        if text in ("none", "stop", ""):
            return "none"
        raw = {"do": text} if text in WORK_DOS else {"script": text} if scripts.name_of(text) else {"skill": text}
    if not isinstance(raw, dict):
        return None
    script = scripts.name_of(raw.get("script"))
    if raw.get("script") is not None:
        if not script:
            return None
        order = {"script": script, "times": SCRIPT_BUDGET}
        if script == "wood":
            try:
                order["logs"] = max(1, min(40, int(raw.get("logs", raw.get("amount", 4)))))
            except (TypeError, ValueError):
                order["logs"] = 4
        return order
    try:
        times = int(raw.get("times", 5))
    except (TypeError, ValueError):
        times = 5
    times = max(1, min(MAX_TIMES, times))
    skill = str(raw.get("skill", "")).strip().lower()
    action = str(raw.get("do", "")).strip().lower()
    if action in ("none", "stop"):
        return "none"
    order = {"times": times}
    if skill:
        order["skill"] = skill
        word = str(raw.get("word") or raw.get("on") or "").strip().lower()
        if word:
            order["word"] = word[:32]
    elif action in WORK_DOS:
        order["do"] = action
        if action == "explore":
            order["dir"] = str(raw.get("dir", "")).strip().lower() if str(raw.get("dir", "")).strip().lower() in DIRS else ""
        if action == "leather_next":
            order["make"] = str(raw.get("make", "")).strip().lower()[:24]
    else:
        return None
    return order


FAR_PROJECT = 40  # tiles: a building plan farther than this is from another life or land


def _far_project(project, me):
    try:
        if project.get("z") is not None and me.get("z") is not None and int(project["z"]) != int(me["z"]):
            return True
        return max(abs(int(project["x"]) - int(me["x"])), abs(int(project["y"]) - int(me["y"]))) > FAR_PROJECT
    except (KeyError, TypeError, ValueError):
        return False


def describe_order(order):
    if not order:
        return "none"
    what = ("make " + order["script"]) if order.get("script") else order.get("skill") or order.get("do")
    extra = f" on {order['word']}" if order.get("word") else f" {order['dir']}" if order.get("dir") else ""
    left = order.get("times")
    return f"{what}{extra}" + (f" ({left} more)" if left else "")


class Routines:
    """The scheduler: needs, the director's priorities and standing order, and a log of what ran without the model."""

    def __init__(self, enabled=True, director_every=8):
        self.enabled = enabled
        self.director_every = max(1, int(director_every or 1))
        self.priorities = {}
        self.order = None
        self.last = ""
        self.failures = {}
        self.log = []
        self.since_director = 0
        self.problem = ""  # why the director must decide next turn ("" when routines may run)
        self.routine_steps = 0
        self.director_calls = 0
        self.implicit = True  # with no order, follow the active project or the early survival ladder

    # The director -------------------------------------------------------------------------------------

    def directed(self, answer):
        """Read priorities and a standing order from the model's reply; returns a short note of what changed."""
        self.director_calls += 1
        self.since_director = 0
        self.problem = ""
        self.log.clear()
        self.failures.clear()  # the director has seen what failed; dropped routines get another chance
        try:
            data = json.loads(answer)
        except (TypeError, ValueError):
            return ""
        if not isinstance(data, dict):
            return ""
        notes = []
        raw = data.get("priorities")
        if isinstance(raw, dict):
            for name, value in raw.items():
                name = str(name).strip().lower()
                value = needs.clamp_priority(value)
                if name in needs.NEEDS and value is not None:
                    self.priorities[name] = value
            notes.append("priorities " + ", ".join(f"{k} x{v:g}" for k, v in sorted(self.priorities.items())))
        if "routine" in data:
            order = parse_order(data.get("routine"))
            if order == "none":
                self.order = None
                self.implicit = False  # she idles (needs only) until the director gives work again
                notes.append("routine stopped")
            elif order:
                self.order = order
                self.implicit = True
                self.failures.pop("work", None)
                notes.append("routine " + describe_order(order))
        return "; ".join(notes)

    def adopt_text_plan(self, answer):
        """A plan written as plain sentences ("Chop tree for wood logs") becomes the standing order for the first
        sentence that names a script, so a small model's direction still runs. Returns the order's description or ""."""
        try:
            data = json.loads(answer)
        except (TypeError, ValueError):
            return ""
        if not isinstance(data, dict) or not isinstance(data.get("plan"), list):
            return ""
        # Small models send a "routine" next to sentences that say what they actually mean; the sentence wins when it
        # names a script, since the reply as a whole had no step that could run. An explicit "none" still pauses work.
        if "routine" in data and parse_order(data.get("routine")) == "none":
            return ""
        for item in data["plan"]:
            if not isinstance(item, str):
                continue
            words = item.lower().split()
            if words and words[0] == "explore":
                order = {"do": "explore", "times": 5, "dir": words[1] if len(words) > 1 and words[1] in DIRS else ""}
            else:
                script = scripts.from_text(item)
                order = parse_order({"script": script}) if script else None
            if order:
                self.order = order
                self.implicit = True
                self.failures.pop("work", None)
                return describe_order(order)
        return ""

    def director_reason(self, sit, talk="", alarm="", prompted=False):
        """Why the model must decide this turn, or "" when routines may carry on."""
        if not self.enabled:
            return "routines off"
        if alarm:
            return "danger"
        if talk:
            return "someone is talking"
        if prompted:
            return "a question is open"
        if self.problem:
            return self.problem
        if self.director_calls == 0:
            return "first look"
        if self.since_director >= self.director_every:
            return "time to review"
        social = sit.levels.get("social")
        if social is not None and social < 30 and any(row.get("mob") and str(row.get("type", "")).startswith("/mob/living/human")
                                                      and row.get("stat") in (None, 0) for row in sit.rows()):
            return "lonely, and someone is near"
        return ""

    # Choosing ---------------------------------------------------------------------------------------------

    def _work(self, sit):
        """The standing order's next step (or the active project's), as (name, plan) or (name, None)."""
        order = self.order
        if not order:
            rung = scripts.ladder(sit) if self.implicit else ""
            if not self.implicit:
                return "", None
            if sit.box.get("leather"):
                order = {"do": "leather_next", "make": sit.box["leather"]}
            elif sit.box.get("project"):
                order = {"do": "build_next"}
            elif rung:
                order = {"script": rung}
            else:
                return "", None
        name = "work: " + describe_order({k: v for k, v in order.items() if k not in ("times", "logs")})
        if order.get("script"):
            script = scripts.SCRIPTS[order["script"]]
            step = script(sit, order.get("logs", 4)) if order["script"] == "wood" else script(sit)
            return name, step  # scripts.DONE once the product is in hand
        action = order.get("do")
        if action == "build_next":
            project = sit.box.get("project")
            if not project:
                return name, None
            if _far_project(project, sit.me):
                # A plan from another level, land or life cannot be walked to: drop it rather than walk at it forever.
                sit.box["project"] = None
                return name, None
            # A piece short of material gathers it (leaves for the roof, logs, stone) instead of failing every turn.
            try:
                steps, piece, problem = blueprints.next_steps(json.loads(json.dumps(project)), sit.observation, sit.box.get("structures", []))
            except (KeyError, TypeError, ValueError):
                steps, piece, problem = [], None, ""  # a project the planner cannot read: build_next reports it
            if not steps and piece is not None and problem.startswith("gather"):
                fetch = scripts.gather(sit, problem)
                if fetch and fetch != scripts.DONE:
                    return name, fetch
            return name, [{"do": "build_next"}]
        if action == "leather_next":
            return name, [{"do": "leather_next", "make": order.get("make") or sit.box.get("leather") or "leather"}]
        if action == "explore":
            return name, [{"do": "explore", "dir": order.get("dir") or sit.explore_dir}]
        if action == "boil_water":
            return name, [{"do": "boil_water"}]
        skill = order.get("skill", "")
        if skill not in sit.kit.skills:
            return name, None
        if skill in SELF_SKILLS:
            return name, [{"skill": skill, "target": 0}]
        check = sit.kit.skill_targets.get(skill, (lambda row: True, ""))[0]
        word = order.get("word", "")
        row = sit.nearest(lambda row: check(row) and (not word or word in str(row.get("name", "")).lower()))
        return name, [{"skill": skill, "target": row["ref"]}] if row else None

    def choose(self, sit):
        """The best routine for this turn as a Choice, or None (with self.problem set when the director must step in)."""
        if not self.enabled:
            return None
        sit.last = self.last
        pulls = needs.urgencies(sit.levels, self.priorities)
        best = None
        for name, need, share, plan_for in NEED_ROUTINES:
            pull = pulls.get(need, 0.0)
            if pull < MIN_NEED or self.failures.get(name, 0) >= FAIL_LIMIT:
                continue
            plan = plan_for(sit)
            plan = numbered(plan, sit.refs) if plan else None
            if not plan:
                continue
            score = pull * share / 100.0 + (STICKY if name == self.last else 0.0)
            if best is None or score > best.score:
                best = Choice(name, plan, score, need)
        work_name, work_plan = self._work(sit)
        if work_plan == scripts.DONE:
            if self.order:
                self.problem = f"your routine ({describe_order({'script': self.order['script']})}) is done"
                self.order = None
                if best is None or best.score < needs.CRITICAL_URGENCY:
                    return None
            work_name, work_plan = "", None
        if work_name and self.failures.get("work", 0) < FAIL_LIMIT:
            plan = numbered(work_plan, sit.refs) if work_plan else None
            if plan:
                score = WORK_DRIVE + (STICKY if work_name == self.last else 0.0)
                if best is None or score > best.score:
                    best = Choice(work_name, plan, score, "work")
            elif self.order and (best is None or best.score < WORK_DRIVE):
                self.problem = f"your routine ({describe_order(self.order)}) has nothing to work on here"
                self.order = None
                return None
        if best is None:
            hint = self.hint(sit)
            self.problem = "nothing to do by routine" + (f" ({hint})" if hint else "")
            return None
        return best

    def hint(self, sit):
        pulls = needs.urgencies(sit.levels, self.priorities)
        for need, text in HINTS.items():
            if pulls.get(need, 0.0) >= MIN_NEED * 2:
                if need == "warmth" and (sit.me.get("bodytemperature") or 0) <= needs.COMFORT_HIGH:
                    continue
                return text
        return ""

    def record(self, choice, summary):
        """Bookkeeping after a routine ran: repeats left, failures and the log the director reads next."""
        self.routine_steps += 1
        self.since_director += 1
        self.last = choice.name
        failed = "failed" in summary or "not possible" in summary or "refused" in summary
        key = "work" if choice.need == "work" else choice.name
        self.failures[key] = self.failures.get(key, 0) + 1 if failed else 0
        if self.failures[key] >= FAIL_LIMIT:
            self.problem = f"the {choice.name} routine failed {FAIL_LIMIT} times in a row ({summary[:120]})"
            if key == "work":
                self.order = None
        if choice.need == "work" and self.order and not failed:
            self.order["times"] = self.order.get("times", 1) - 1
            if self.order["times"] <= 0:
                self.problem = f"your routine ({describe_order({k: v for k, v in self.order.items() if k != 'times'})}) is done"
                self.order = None
        self.log.append(f"{choice.name}: {summary[:160]}")
        del self.log[:-LOG_KEEP]

    def report(self, sit):
        """Lines for the director's prompt: needs, standing order, and what routines did since it last decided."""
        lines = [needs.describe(sit.levels, self.priorities), "ROUTINE: " + describe_order(self.order)]
        if self.log:
            lines.append("ON ROUTINES SINCE YOU LAST DECIDED: " + " | ".join(self.log))
        hint = self.hint(sit)
        if hint:
            lines.append("NEED HINT: " + hint)
        return "\n".join(lines)
