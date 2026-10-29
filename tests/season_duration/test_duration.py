"""Source-derived shared timer checks only; no compiler, runtime or real waits."""
from pathlib import Path
import re
import subprocess
from types import SimpleNamespace as NS
import unittest

ROOT = Path(__file__).resolve().parents[2]
META = "code/game/objects/map_metadata/_map_metadata.dm"
BASE = "d6b06c638517bb4100beeca6a90d09adc3629fb7"
import sys
sys.path.insert(0, str(ROOT / "tests/snowfall_ground"))
from source_contract import without_season_snow
sys.path.insert(0, str(ROOT / "tests/seasonal_construction"))
from construction_contract import without_construction_hook


def body(source, signature):
    return re.search(r"^" + re.escape(signature) + r"\n(.*?)(?=^/|\Z)", source, re.M | re.S).group(1)


def delay(source, override=None, configured=60, configured_present=True):
    instructions = {
        "var/minutes = season_duration_minutes": "minutes = override",
        "if (isnull(minutes))": "if minutes is None:",
        "minutes = config ? config.season_duration_minutes : 60": "minutes = configured if configured_present else 60",
        "if (!isnum(minutes) || minutes < 1 || minutes > 1440)": "if not isinstance(minutes, (int, float)) or minutes < 1 or minutes > 1440:",
        "minutes = 60": "minutes = 60",
        "return minutes * 600": "return minutes * 600",
    }
    lines = ["def projected(override, configured, configured_present):"]
    for raw in body(source, "/obj/map_metadata/proc/season_loop_delay()").splitlines():
        if not raw.strip():
            continue
        depth = len(raw) - len(raw.lstrip("\t"))
        lines.append("    " * depth + instructions[raw.strip()])
    env = {}
    exec("\n".join(lines), env)
    return env["projected"](override, configured, configured_present)


class DurationTests(unittest.TestCase):
    def setUp(self):
        self.source = (ROOT / META).read_text()

    def test_default_sixty_minutes_and_absent_config(self):
        self.assertEqual(delay(self.source), 36000)
        self.assertEqual(delay(self.source, configured_present=False), 36000)
        config = (ROOT / "code/datums/configuration.dm").read_text()
        self.assertIn("var/season_duration_minutes = 60", config)
        self.assertIn("SEASON_DURATION_MINUTES 60", (ROOT / "config/config.txt").read_text())

    def test_configured_and_per_map_durations(self):
        for minutes in (1, 30, 60, 90, 1440, 1.5):
            self.assertEqual(delay(self.source, configured=minutes), minutes * 600)
            self.assertEqual(delay(self.source, override=minutes, configured=17), minutes * 600)

    def test_invalid_runtime_values_fall_back_to_sixty(self):
        for bad in (0, -1, 1441, "60", None):
            self.assertEqual(delay(self.source, configured=bad), 36000)
        for bad in (0, -1, 1441, "60"):
            self.assertEqual(delay(self.source, override=bad), 36000)

    def test_file_parser_validates_before_assignment(self):
        config = (ROOT / "code/datums/configuration.dm").read_text()
        block = config.split('if ("season_duration_minutes")', 1)[1].split('\n\t\t\t\tif (', 1)[0]
        self.assertIn("var/minutes = text2num(value)", block)
        self.assertIn('isnum(minutes) && minutes >= 1 && minutes <= 1440 && "[minutes]" == trim(value)', block)
        self.assertTrue(block.rstrip().endswith("season_duration_minutes = minutes"))

    def test_durable_and_sleeping_branches_use_same_singleton_delay(self):
        schedule = body(self.source, "/obj/map_metadata/proc/season_schedule_loop()")
        self.assertIn("season_retired || season_loop_scheduled || map != src", schedule)
        self.assertEqual(schedule.count("season_loop_scheduled = TRUE"), 1)
        self.assertIn("var/delay = season_loop_delay()", schedule)
        self.assertIn('if(durable_schedule("season_loop", delay)) return', schedule)
        self.assertIn("spawn(delay)", schedule)
        self.assertIn("season_loop_scheduled = FALSE", schedule)
        self.assertIn("if (!season_retired && map == src)\n\t\t\tseasons()", schedule)

    def test_request_queue_force_controls_and_gameplay_bodies_unchanged(self):
        old = subprocess.check_output(["git", "show", BASE + ":" + META], cwd=ROOT, text=True)
        # Flow owns default destination/queue parity; duration owns request cadence.
        signature = "/obj/map_metadata/proc/seasons(var/looping = TRUE, var/force = FALSE, var/advance_decay = null)"
        self.assertEqual(body(self.source, signature), body(old, signature))
        for relative in ("code/modules/admin/verbs/weather.dm", "code/processes/abandoned_items.dm",
                         "code/modules/persistence/durable_environment.dm", "code/modules/persistence/durable_timers.dm",
                         "code/game/objects/map_metadata/nomads/nomads.dm",
                         "code/game/objects/map_metadata/colonia.dm", "code/game/objects/map_metadata/pepelsibirsk.dm"):
            before = subprocess.check_output(["git", "show", BASE + ":" + relative], cwd=ROOT)
            current = (ROOT / relative).read_text()
            if relative == "code/processes/abandoned_items.dm":
                current = without_construction_hook(current)
            self.assertEqual(current, without_season_snow(before.decode())[0], relative)
        # Durable topology may evolve; duration owns only the saved timer schema.
        relative = "code/modules/persistence/durable_world.dm"
        old_world = subprocess.check_output(["git", "show", BASE + ":" + relative], cwd=ROOT, text=True)
        current_world = (ROOT / relative).read_text()
        self.assertEqual(body(current_world, "/proc/durable_weather_schema()"),
                         body(old_world, "/proc/durable_weather_schema()"))
        # Weather selection can evolve independently. Keep this duration check
        # scoped to its startup cadence/defaults; weather_policy checks RNG parity.
        relative = "code/processes/weather.dm"
        before = subprocess.check_output(["git", "show", BASE + ":" + relative], cwd=ROOT, text=True)
        current = (ROOT / relative).read_text()
        self.assertEqual(current.split("/process/weather/fire()", 1)[0],
                         before.split("/process/weather/fire()", 1)[0])

    def test_independent_special_maps_keep_original_timers_and_initial_thirty(self):
        for name in ("mountain", "ice_age"):
            relative = "code/game/objects/map_metadata/nomads/nomads_" + name + ".dm"
            current = (ROOT / relative).read_text()
            before = subprocess.check_output(["git", "show", BASE + ":" + relative], cwd=ROOT, text=True)
            self.assertIn("season_duration_minutes = 30", current)
            projected = re.sub(r'^\tseason_duration_minutes = 30[^\n]*\n', "", current, flags=re.M)
            self.assertEqual(projected, without_season_snow(before)[0])

    def test_duration_is_author_policy_and_old_pending_remainders_are_untouched(self):
        runtime = body(self.source, "/obj/map_metadata/persistence_runtime_var(var/key)")
        self.assertIn('"season_duration_minutes"', runtime)
        schema = (ROOT / "code/modules/persistence/durable_contract.dm").read_text()
        self.assertNotIn('"season_duration_minutes"', schema)
        timers = (ROOT / "code/modules/persistence/durable_timers.dm").read_text()
        self.assertIn("/datum/durable_timer_queue/proc/restore", timers)
        self.assertNotIn("season_duration_minutes", timers)


if __name__ == "__main__":
    unittest.main()
