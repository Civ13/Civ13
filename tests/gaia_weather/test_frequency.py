"""Execute Gaia's production selector with offline adapters for DM lists.

No RNG simulation, native launch, real-time cadence or live-weather claims.
"""
from collections import Counter
from fractions import Fraction
import importlib.util
from pathlib import Path
import re
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
GAIA = ROOT / "code/game/objects/map_metadata/nomads/nomads_gaia.dm"
SIGNATURE = "/obj/map_metadata/nomads/gaia/weather_policy_choices(list/possibilities)"
spec = importlib.util.spec_from_file_location(
    "gaia_weather_parent_policy", ROOT / "tests/weather_policy/test_policy.py")
policy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(policy)


def project(source):
    """Translate every executable line; reject unfamiliar production syntax."""
    instructions = {
        "var/list/choices = ..()": "choices = parent(possibilities)",
        "if (weather != WEATHER_NONE || !choices || !(WEATHER_NONE in choices))":
            "if weather != 1 or not choices or 1 not in choices:",
        "return choices": "return choices",
        "var/list/weighted_choices = choices.Copy()": "weighted_choices = choices.copy()",
        "for (var/i = 1, i <= choices.len, i++)": "for i in range(len(choices)):",
        "weighted_choices += WEATHER_NONE": "weighted_choices.append(1)",
        "return weighted_choices": "return weighted_choices",
    }
    lines = ["def select(weather, possibilities, parent):"]
    for raw in policy.body(source, SIGNATURE).splitlines():
        code = raw.split("//", 1)[0].rstrip()
        if code.strip():
            depth = len(code) - len(code.lstrip("\t"))
            lines.append("    " * depth + instructions[code.strip()])
    env = {}
    exec("\n".join(lines), env)
    return env["select"]


def seasonal_pools():
    """Read the selector's actual lists, including the non-desert wet pool."""
    defines = (ROOT / "code/__defines/weather.dm").read_text()
    constants = {key: int(value) for key, value in
                 re.findall(r"^#define (WEATHER_\w+) (\d+)$", defines, re.M)}
    # The reused policy adapter and this adapter use these production identifiers.
    assert {k: constants[k] for k in ("WEATHER_NONE", "WEATHER_WET", "WEATHER_EXTREME", "WEATHER_SMOG")} == {
        "WEATHER_NONE": 1, "WEATHER_WET": 2, "WEATHER_EXTREME": 3, "WEATHER_SMOG": 4}
    source = (ROOT / "code/modules/1713/weather.dm").read_text()
    selector = policy.body(source, "/proc/change_weather_somehow()")
    cases = re.findall(r'\t\tif \("([^"\n]+)"\)\n(.*?)(?=\n\t\tif |\n\t/\*|\Z)', selector, re.S)
    result = {}
    for season, branch in cases:
        lists = re.findall(r"possibilities = list\((WEATHER_[A-Z_, ]+)\)", branch)
        result[season] = [constants[token.strip()] for token in lists[-1].split(",")]
    assert set(result) == {"WINTER", "SPRING", "Wet Season", "Dry Season", "SUMMER", "FALL"}
    return result


def chance(pool, outcome):
    return Fraction(Counter(pool)[outcome], len(pool))


class GaiaWeatherTests(unittest.TestCase):
    def setUp(self):
        self.source = GAIA.read_text()
        self.select = project(self.source)
        self.pools = seasonal_pools()

    def test_each_nonclear_start_is_halved_in_every_season(self):
        for season, pool in self.pools.items():
            with self.subTest(season=season):
                before = pool.copy()
                selected = self.select(1, pool, lambda value: value)
                self.assertEqual(pool, before, "Do not mutate a caller's pool")
                self.assertEqual(len(selected), 2 * len(pool))
                self.assertEqual(set(selected), set(pool))
                for outcome in set(pool) - {1}:
                    self.assertEqual(chance(selected, outcome), chance(pool, outcome) / 2)
                self.assertEqual(selected[:len(pool)], pool)

    def test_documented_spring_and_summer_probabilities(self):
        spring = self.select(1, self.pools["SPRING"], lambda value: value)
        summer = self.select(1, self.pools["SUMMER"], lambda value: value)
        self.assertEqual([chance(spring, i) for i in (1, 2, 3)],
                         [Fraction(2, 3), Fraction(1, 6), Fraction(1, 6)])
        self.assertEqual([chance(summer, i) for i in (1, 2, 3)],
                         [Fraction(3, 4), Fraction(1, 4), 0])

    def test_existing_wet_extreme_and_smog_spells_keep_original_pool(self):
        for weather in (2, 3, 4):
            for pool in self.pools.values():
                self.assertIs(self.select(weather, pool, lambda value: value), pool)

    def test_invalid_empty_and_clear_excluding_parent_results_are_unchanged(self):
        for weather in (1, 2, 3, 4):
            for result in (None, [], [2], [3, 2]):
                with self.subTest(weather=weather, result=result):
                    calls = []
                    pool = [1, 2, 3]
                    def parent(value):
                        calls.append(value)
                        return result
                    self.assertIs(self.select(weather, pool, parent), result)
                    self.assertEqual(calls, [pool])

    def test_inherited_policy_validation_filtering_and_holds_are_respected(self):
        state = SimpleNamespace(weather=1)
        parent = policy.Map(state)
        pool = self.pools["SPRING"]
        parent.weather_timing = policy.DMList({"change_interval": 0})
        self.assertIsNone(self.select(1, pool, parent.weather_policy_choices))
        parent.weather_timing = None
        for targets in ([], ["NONE"], ["NONE", "WET"], ["WET"], ["SMOG"]):
            parent.weather_transitions = policy.DMList({"ANY": policy.DMList(targets)})
            filtered = parent.weather_policy_choices(pool)
            selected = self.select(1, pool, parent.weather_policy_choices)
            self.assertEqual(set(selected), set(filtered))
            if 1 in filtered:
                self.assertEqual(len(selected), len(filtered) * 2)
            else:
                self.assertEqual(selected, filtered)
        parent.weather_transitions = policy.DMList({"ANY": policy.DMList(["NONE", "WET", "EXTREME"])})
        parent.valid_weather_types = (1, 2)
        self.assertNotIn(3, self.select(1, pool, parent.weather_policy_choices))

    def test_other_maps_and_repeated_lookups_keep_their_original_inputs(self):
        for weather in (1, 2, 3, 4):
            parent = policy.Map(SimpleNamespace(weather=weather))
            for pool in self.pools.values():
                self.assertIs(parent.weather_policy_choices(pool), pool)
                first = self.select(weather, pool, parent.weather_policy_choices)
                for _ in range(3):
                    self.assertEqual(self.select(weather, pool, parent.weather_policy_choices), first)

    def test_weighting_is_only_a_gaia_override_without_timing_or_rng_changes(self):
        self.assertEqual(self.source.count(SIGNATURE), 1)
        body = policy.body(self.source, SIGNATURE)
        self.assertNotRegex(body, r"\b(prob|rand|pick|change_weather|addtimer)\(")
        self.assertNotIn("weather_timing =", self.source)
        # The global random selector still uses the hook and then one uniform pick.
        selector = policy.body((ROOT / "code/modules/1713/weather.dm").read_text(),
                               "/proc/change_weather_somehow()")
        self.assertIn("possibilities = map.weather_policy_choices(possibilities)", selector)
        self.assertIn("change_weather(pick(possibilities))", selector)

    def test_controls_detect_missing_weighting_and_weighting_active_rain(self):
        pool = self.pools["SPRING"]
        baseline = self.source.replace("weighted_choices += WEATHER_NONE", "return choices")
        self.assertNotEqual(chance(project(baseline)(1, pool, lambda value: value), 2),
                            chance(pool, 2) / 2)
        # Forcing the clear-state adapter input reproduces an unconditional override.
        self.assertNotEqual(self.select(1, pool, lambda value: value), pool)
        self.assertIs(self.select(2, pool, lambda value: value), pool)


if __name__ == "__main__":
    unittest.main()
