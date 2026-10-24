"""Restricted production policy/process projections; native weather stays unrun."""
from pathlib import Path
import re
import subprocess
from types import SimpleNamespace as NS
import unittest

ROOT = Path(__file__).resolve().parents[2]
BASE = "d6b06c638517bb4100beeca6a90d09adc3629fb7"
POLICY = ROOT / "code/modules/1713/weather_policy.dm"


def body(source, signature):
    return re.search(r"^" + re.escape(signature) + r"\n(.*?)(?=^/|\Z)", source, re.M | re.S).group(1)


class DMList(list):
    def __init__(self, values=(), associations=None):
        if isinstance(values, dict):
            associations, values = values, list(values)
        super().__init__(values)
        self.associations = associations or {}

    def lookup(self, key):
        return self.associations.get(key)


def identifier(value):
    entries = re.findall(r'if \((WEATHER_\w+)\) return "([A-Z]+)"', body(POLICY.read_text(), "/proc/weather_policy_identifier(value)"))
    constants = {"WEATHER_NONE": 1, "WEATHER_WET": 2, "WEATHER_EXTREME": 3, "WEATHER_SMOG": 4}
    return {constants[key]: name for key, name in entries}.get(value)


def project(source, signature):
    instructions = {
        "if (!isnull(weather_timing))": "if self.weather_timing is not None:",
        "if (!islist(weather_timing) || weather_timing.len > 4)": "if not isinstance(self.weather_timing, DMList) or len(self.weather_timing) > 4:",
        "for (var/key in weather_timing)": "for key in self.weather_timing:",
        'if (!(key in list("mod_interval", "change_interval", "minimum_mod_delay", "minimum_change_delay")))':
            'if key not in ["mod_interval", "change_interval", "minimum_mod_delay", "minimum_change_delay"]:',
        "var/value = weather_timing[key]": "value = self.weather_timing.lookup(key)",
        "if (!isnum(value) || value < 10 || value > 864000)": "if not isinstance(value, (int, float)) or value < 10 or value > 864000:",
        "return FALSE": "return False",
        "return TRUE": "return True",
        "if (!isnull(weather_transitions))": "if self.weather_transitions is not None:",
        "if (!islist(weather_transitions) || weather_transitions.len > 5)": "if not isinstance(self.weather_transitions, DMList) or len(self.weather_transitions) > 5:",
        "for (var/key in weather_transitions)": "for key in self.weather_transitions:",
        'if (!(key in list("ANY", "NONE", "WET", "EXTREME", "SMOG")))': 'if key not in ["ANY", "NONE", "WET", "EXTREME", "SMOG"]:',
        "var/list/targets = weather_transitions[key]": "targets = self.weather_transitions.lookup(key)",
        "if (!islist(targets) || targets.len > 4)": "if not isinstance(targets, DMList) or len(targets) > 4:",
        "var/list/seen = list()": "seen = []",
        "for (var/target in targets)": "for target in targets:",
        'if (!(target in list("NONE", "WET", "EXTREME", "SMOG")) || (target in seen) || !isnull(targets[target]))':
            'if target not in ["NONE", "WET", "EXTREME", "SMOG"] or target in seen or targets.lookup(target) is not None:',
        "seen += target": "seen.append(target)",
        "if (weather_timing && (key in weather_timing))": "if self.weather_timing and key in self.weather_timing:",
        "return weather_timing[key]": "return self.weather_timing.lookup(key)",
        "return fallback": "return fallback",
        "if (!weather_policy_valid())": "if not self.weather_policy_valid():",
        "return null": "return None",
        "if (isnull(weather_transitions))": "if self.weather_transitions is None:",
        "return possibilities": "return possibilities",
        "var/current = weather_policy_identifier(weather)": "current = identifier(state.weather)",
        "var/list/targets": "targets = None",
        "if (current in weather_transitions)": "if current in self.weather_transitions:",
        "targets = weather_transitions[current]": "targets = self.weather_transitions.lookup(current)",
        'else if ("ANY" in weather_transitions)': 'elif "ANY" in self.weather_transitions:',
        'targets = weather_transitions["ANY"]': 'targets = self.weather_transitions.lookup("ANY")',
        "else": "else:",
        "var/list/choices = list()": "choices = []",
        "for (var/candidate in possibilities)": "for candidate in possibilities:",
        "if ((weather_policy_identifier(candidate) in targets) && (candidate == WEATHER_NONE || (candidate in valid_weather_types)))":
            "if identifier(candidate) in targets and (candidate == 1 or candidate in self.valid_weather_types):",
        "choices += candidate": "choices.append(candidate)",
        "return choices": "return choices",
    }
    lines = ["def projected(self, state, key=None, fallback=None, possibilities=None):"]
    for raw in body(source, signature).splitlines():
        code = raw.split("//", 1)[0].rstrip()
        if code.strip():
            depth = len(code) - len(code.lstrip("\t"))
            lines.append("    " * depth + instructions[code.strip()])
    env = dict(DMList=DMList, identifier=identifier)
    exec("\n".join(lines), env)
    return env["projected"]


class Map:
    def __init__(self, state, timing=None, transitions=None, allowed=(1, 2, 3, 4)):
        self.state = state
        self.weather_timing, self.weather_transitions, self.valid_weather_types = timing, transitions, allowed
        source = POLICY.read_text()
        valid = project(source, "/obj/map_metadata/proc/weather_policy_valid()")
        timing_fn = project(source, "/obj/map_metadata/proc/weather_timing_value(key, fallback)")
        choices = project(source, "/obj/map_metadata/proc/weather_policy_choices(list/possibilities)")
        self.weather_policy_valid = lambda: valid(self, state)
        self.weather_timing_value = lambda key, fallback: timing_fn(self, state, key=key, fallback=fallback)
        self.weather_policy_choices = lambda values: choices(self, state, possibilities=values)


def process(source, include_durable=False):
    full = body(source, "/process/weather/fire()")
    prefix = full.split("\tif ((season ==", 1)[0] if include_durable else full.split("\tif(map && map.uses_durable_metadata())", 1)[0]
    instructions = {
        "if(persistence_save_in_progress) return": "if state.saving: return",
        "if (map && !map.weather_policy_valid())": "if state.map and not state.map.weather_policy_valid():",
        "if (!map || map.weather_policy_valid())": "if not state.map or state.map.weather_policy_valid():",
        "if(map && map.uses_durable_metadata())": "if state.map and state.map.uses_durable_metadata():",
        "map.durable_weather_events()": "state.map.durable_weather_events()",
        "return": "return",
        'var/mod_interval = map ? map.weather_timing_value("mod_interval", mod_weather_interval) : mod_weather_interval': 'mod_interval = state.map.weather_timing_value("mod_interval", self.mod_weather_interval) if state.map else self.mod_weather_interval',
        'var/change_interval = map ? map.weather_timing_value("change_interval", change_weather_interval) : change_weather_interval': 'change_interval = state.map.weather_timing_value("change_interval", self.change_weather_interval) if state.map else self.change_weather_interval',
        'var/mod_delay = map ? map.weather_timing_value("minimum_mod_delay", minimum_mod_weather_delay) : minimum_mod_weather_delay': 'mod_delay = state.map.weather_timing_value("minimum_mod_delay", self.minimum_mod_weather_delay) if state.map else self.minimum_mod_weather_delay',
        'var/change_delay = map ? map.weather_timing_value("minimum_change_delay", minimum_change_weather_delay) : minimum_change_weather_delay': 'change_delay = state.map.weather_timing_value("minimum_change_delay", self.minimum_change_weather_delay) if state.map else self.minimum_change_weather_delay',
        "var/prob_of_weather_mod = (25*schedule_interval)/mod_interval": "prob_of_weather_mod = 25 * self.schedule_interval / mod_interval",
        "var/prob_of_weather_change = (25*schedule_interval)/change_interval": "prob_of_weather_change = 25 * self.schedule_interval / change_interval",
        "var/prob_of_weather_mod = (25*schedule_interval)/mod_weather_interval": "prob_of_weather_mod = 25 * self.schedule_interval / self.mod_weather_interval",
        "var/prob_of_weather_change = (25*schedule_interval)/change_weather_interval": "prob_of_weather_change = 25 * self.schedule_interval / self.change_weather_interval",
        "if (weather == WEATHER_WET || weather == WEATHER_EXTREME)": "if state.weather in (2, 3):",
        "prob_of_weather_change = (prob_of_weather_change*3)": "prob_of_weather_change *= 3",
        "if (prob(prob_of_weather_mod))": "if state.prob(prob_of_weather_mod):",
        "if (world.realtime >= next_can_mod_weather)": "if state.now >= self.next_can_mod_weather:",
        "modify_weather_somehow()": "state.modifications += 1",
        "next_can_mod_weather = world.realtime + mod_delay": "self.next_can_mod_weather = state.now + mod_delay",
        "next_can_mod_weather = world.realtime + minimum_mod_weather_delay": "self.next_can_mod_weather = state.now + self.minimum_mod_weather_delay",
        "else if (prob(prob_of_weather_change))": "elif state.prob(prob_of_weather_change):",
        "if (world.realtime >= next_can_change_weather)": "if state.now >= self.next_can_change_weather:",
        "change_weather_somehow()": "state.changes += 1",
        "next_can_change_weather = world.realtime + change_delay": "self.next_can_change_weather = state.now + change_delay",
        "next_can_change_weather = world.realtime + minimum_change_weather_delay": "self.next_can_change_weather = state.now + self.minimum_change_weather_delay",
    }
    lines = ["def projected(self, state):"]
    for raw in prefix.splitlines():
        if raw.strip() and not raw.strip().startswith("//"):
            depth = len(raw) - len(raw.lstrip("\t"))
            lines.append("    " * depth + instructions[raw.strip()])
    env = {}
    exec("\n".join(lines), env)
    return env["projected"]


def state(weather=1, rolls=(False, True), future=False):
    s = NS(weather=weather, now=10000, saving=False, modifications=0, changes=0, probabilities=[])
    pending = iter(rolls)
    def prob(value):
        s.probabilities.append(value)
        return next(pending)
    s.prob = prob
    s.map = Map(s)
    p = NS(schedule_interval=100, mod_weather_interval=3500, change_weather_interval=3500,
           minimum_mod_weather_delay=1000, minimum_change_weather_delay=1000,
           next_can_mod_weather=20000 if future else 0, next_can_change_weather=20000 if future else 0)
    return s, p


class WeatherPolicyTests(unittest.TestCase):
    def setUp(self):
        self.source = (ROOT / "code/processes/weather.dm").read_text()

    def test_default_process_probability_order_deadlines_and_selection_match_immutable_master(self):
        old = subprocess.check_output(["git", "show", BASE + ":code/processes/weather.dm"], cwd=ROOT, text=True)
        current, baseline = process(self.source), process(old)
        for weather in range(1, 5):
            for rolls in ((True,), (False, False), (False, True)):
                for future in (False, True):
                    a, pa = state(weather, rolls, future)
                    b, pb = state(weather, rolls, future)
                    current(pa, a)
                    baseline(pb, b)
                    self.assertEqual((a.probabilities, a.modifications, a.changes, vars(pa)),
                                     (b.probabilities, b.modifications, b.changes, vars(pb)))
                    pool = [2, 1, 3]
                    self.assertIs(a.map.weather_policy_choices(pool), pool)

    def test_timing_overrides_probabilities_and_future_cooldowns_without_rescaling_pending_deadlines(self):
        s, p = state(2)
        s.map.weather_timing = DMList({"mod_interval": 7000, "change_interval": 14000, "minimum_change_delay": 2000})
        process(self.source)(p, s)
        self.assertEqual(s.probabilities, [2500 / 7000, 7500 / 14000])
        self.assertEqual(p.next_can_change_weather, 12000)
        self.assertEqual(p.next_can_mod_weather, 0)
        self.assertEqual(p.mod_weather_interval, 3500)

    def test_invalid_timing_fails_before_rng_weather_or_deadlines_change(self):
        for bad in (DMList({"change_interval": 0}), DMList({"change_interval": -1}),
                    DMList({"minimum_mod_delay": 864001}), DMList({"change_interval": "60"}),
                    DMList({"unknown": 100}), "invalid", DMList(["mod_interval"])):
            s, p = state()
            s.map.weather_timing = bad
            before = vars(p).copy()
            process(self.source)(p, s)
            self.assertEqual(s.probabilities, [])
            self.assertEqual((s.modifications, s.changes, vars(p)), (0, 0, before))
            self.assertIsNone(s.map.weather_policy_choices([1, 2, 3]))

    def test_timing_bounds_and_empty_configuration(self):
        s, _ = state()
        for value in (10, 1000, 3500, 864000, 10.5):
            s.map.weather_timing = DMList({"change_interval": value})
            self.assertTrue(s.map.weather_policy_valid())
        s.map.weather_timing = DMList()
        self.assertEqual(s.map.weather_timing_value("mod_interval", 3500), 3500)

    def test_transition_rows_filter_existing_season_pool_and_map_allowlist(self):
        s, _ = state(2)
        s.map.weather_transitions = DMList({"WET": DMList(["NONE", "EXTREME"])})
        self.assertEqual(s.map.weather_policy_choices([2, 1, 3]), [1, 3])
        s.map.valid_weather_types = (1, 2)
        self.assertEqual(s.map.weather_policy_choices([2, 1, 3]), [1])
        self.assertEqual(s.map.weather_policy_choices([1, 2]), [1])

    def test_specific_row_precedes_any_and_missing_row_keeps_legacy_pool(self):
        s, _ = state(2)
        pool = [1, 2, 3]
        s.map.weather_transitions = DMList({"ANY": DMList(["NONE"]), "WET": DMList(["EXTREME"])})
        self.assertEqual(s.map.weather_policy_choices(pool), [3])
        s.weather = 1
        self.assertEqual(s.map.weather_policy_choices(pool), [1])
        s.map.weather_transitions = DMList({"WET": DMList(["NONE"])})
        self.assertIs(s.map.weather_policy_choices(pool), pool)

    def test_empty_or_incompatible_intersection_holds_without_inventing_weather(self):
        s, _ = state()
        for targets in (DMList(), DMList(["SMOG"]), DMList(["EXTREME"])):
            s.map.weather_transitions = DMList({"ANY": targets})
            self.assertEqual(s.map.weather_policy_choices([1, 2]), [])

    def test_unknown_event_duplicate_associated_and_malformed_rows_reject(self):
        s, _ = state()
        for bad in (DMList({"EVENT": DMList(["NONE"])}), DMList({"ANY": DMList(["EVENT"])}),
                    DMList({"ANY": DMList(["NONE", "NONE"])}), DMList({"ANY": "WET"}),
                    DMList({"ANY": DMList(["WET"], {"WET": "payload"})}), DMList(["ANY"]), 3):
            s.map.weather_transitions = bad
            self.assertFalse(s.map.weather_policy_valid())
            self.assertIsNone(s.map.weather_policy_choices([1, 2, 3]))

    def test_reload_and_repeated_lookup_have_no_policy_cursor(self):
        s, _ = state(2)
        policy = DMList({"WET": DMList(["NONE", "WET"])})
        s.map.weather_transitions = policy
        first = s.map.weather_policy_choices([1, 2, 3])
        for _ in range(4):
            self.assertEqual(s.map.weather_policy_choices([1, 2, 3]), first)
        s.map = Map(s, transitions=policy)
        self.assertEqual(s.map.weather_policy_choices([1, 2, 3]), first)

    def test_climate_application_direct_weather_events_and_season_counters_are_unchanged(self):
        before = subprocess.check_output(["git", "show", BASE + ":code/modules/1713/weather.dm"], cwd=ROOT, text=True)
        current = (ROOT / "code/modules/1713/weather.dm").read_text()
        for signature in ("/proc/change_weather(_weather = WEATHER_NONE, var/bypass_same_weather_check = FALSE)",
                          "/proc/apply_area_weather(var/area/caribbean/A)"):
            self.assertEqual(body(current, signature), body(before, signature))
        old_process = subprocess.check_output(["git", "show", BASE + ":code/processes/weather.dm"], cwd=ROOT, text=True)
        marker = "\tif(map && map.uses_durable_metadata())"
        self.assertEqual(self.source.split(marker)[1], old_process.split(marker)[1])
        for relative in ("code/processes/abandoned_items.dm", "code/modules/persistence/durable_environment.dm",
                         "code/modules/persistence/durable_timers.dm", "code/modules/persistence/durable_world.dm"):
            self.assertEqual((ROOT / relative).read_bytes(), subprocess.check_output(["git", "show", BASE + ":" + relative], cwd=ROOT))

    def test_random_selector_only_filters_immediately_before_pick_and_no_native_configuration_import(self):
        source = (ROOT / "code/modules/1713/weather.dm").read_text()
        selector = body(source, "/proc/change_weather_somehow()")
        self.assertIn("possibilities = map.weather_policy_choices(possibilities)", selector)
        self.assertIn("if (possibilities && possibilities.len)\n\t\tchange_weather(pick(possibilities))", selector)
        modifier = body(source, "/proc/modify_weather_somehow()")
        self.assertTrue(modifier.strip().startswith("if (map && !map.weather_policy_valid())\n\t\treturn"))
        metadata = (ROOT / "code/game/objects/map_metadata/_map_metadata.dm").read_text()
        for key in ("weather_timing", "weather_transitions"):
            self.assertIn('"' + key + '"', body(metadata, "/obj/map_metadata/persistence_runtime_var(var/key)"))
            self.assertNotIn('"' + key + '"', (ROOT / "code/modules/persistence/durable_contract.dm").read_text())
        self.assertEqual((ROOT / "civ13.dme").read_text().count("code\\modules\\1713\\weather_policy.dm"), 1)


if __name__ == "__main__":
    unittest.main()
