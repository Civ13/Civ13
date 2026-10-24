"""Event service/end-body traces with an explicit independent timer adapter."""
from pathlib import Path
import subprocess
from types import SimpleNamespace as NS
import unittest

from test_policy import ROOT, DMList, body, process, state

EVENTS = ROOT / "code/modules/persistence/durable_environment.dm"
QUEUE = ROOT / "code/modules/persistence/durable_timers.dm"
PUBLISHED = "8bf59bd57d3b160dbb624c79063be596a60d1a0b"


def event_proc(source, signature):
    instructions = {
        'if(season == "WINTER" && triggered_blizzard && !blizzard && !durable_pending("blizzard_start"))':
            'if state.season == "WINTER" and self.triggered_blizzard and not self.blizzard and not self.pending("blizzard_start"):',
        'if((season == "SUMMER" || triggered_heatwave) && !heat_wave && !durable_pending("heat_start"))':
            'if (state.season == "SUMMER" or self.triggered_heatwave) and not self.heat_wave and not self.pending("heat_start"):',
        'if((prob(1) || triggered_heatwave) && (prob(50) || triggered_heatwave))':
            'if (state.prob(1) or self.triggered_heatwave) and (state.prob(50) or self.triggered_heatwave):',
        'if(season == "Dry Season" && triggered_sandstorm && !sandstorm && !durable_pending("sandstorm_start"))':
            'if state.season == "Dry Season" and self.triggered_sandstorm and not self.sandstorm and not self.pending("sandstorm_start"):',
        'to_chat(world, "<big>A huge blizzard is approaching!</big>")': 'state.messages.append("blizzard warning")',
        'to_chat(world, "<big>The weather starts to get hotter than normal...</big>")': 'state.messages.append("heat warning")',
        'to_chat(world, "<big>You start seeing dark clouds in the horizon...</big>")': 'state.messages.append("sandstorm warning")',
        'to_chat(world, "<big>The heat wave has subsided.</big>")': 'state.messages.append("heat ended")',
        "triggered_blizzard = FALSE": "self.triggered_blizzard = False",
        "triggered_heatwave = FALSE": "self.triggered_heatwave = False",
        "triggered_sandstorm = FALSE": "self.triggered_sandstorm = False",
        'durable_schedule("blizzard_start", 600)': 'self.scheduled.append(("blizzard_start", 600))',
        'durable_schedule("heat_start", 600)': 'self.scheduled.append(("heat_start", 600))',
        'durable_schedule("sandstorm_start", 600)': 'self.scheduled.append(("sandstorm_start", 600))',
        "blizzard = FALSE": "self.blizzard = False",
        "sandstorm = FALSE": "self.sandstorm = False",
        "heat_wave = FALSE": "self.heat_wave = False",
        "change_weather(WEATHER_NONE)": "state.weather = 1; state.weather_calls += 1",
        "for(var/obj/structure/sink/S)": "for S in state.sinks:",
        "if(istype(S, /obj/structure/sink/well) || istype(S, /obj/structure/sink/puddle))": "if S.kind in ('well', 'puddle'):",
        "S.dry = FALSE": "S.dry = False",
        "S.update_icon()": "S.updates += 1",
    }
    lines = ["def projected(self, state):"]
    for raw in body(source, signature).splitlines():
        if raw.strip():
            depth = len(raw) - len(raw.lstrip("\t"))
            lines.append("    " * depth + instructions[raw.strip()])
    env = {}
    exec("\n".join(lines), env)
    return env["projected"]


def active(event):
    s, p = state(1 if event == "heat_wave" else 3, rolls=())
    s.season = {"blizzard": "WINTER", "heat_wave": "SUMMER", "sandstorm": "Dry Season"}[event]
    s.messages, s.weather_calls, s.service_calls = [], 0, 0
    s.sinks = [NS(kind=k, dry=True, updates=0) for k in ("well", "puddle", "other")]
    m = s.map
    m.weather_timing = DMList({"change_interval": 0})
    m.triggered_blizzard = m.triggered_heatwave = m.triggered_sandstorm = False
    m.blizzard = m.heat_wave = m.sandstorm = False
    setattr(m, event, True)
    m.pending = lambda key: False
    m.scheduled = []
    m.uses_durable_metadata = lambda: True
    events = event_proc(EVENTS.read_text(), "/obj/map_metadata/proc/durable_weather_events()")
    def service():
        s.service_calls += 1
        events(m, s)
    m.durable_weather_events = service
    name = {"blizzard": "blizzard", "heat_wave": "heat", "sandstorm": "sandstorm"}[event]
    finish = event_proc(EVENTS.read_text(), "/obj/map_metadata/proc/durable_" + name + "_end()")
    deadline = s.now + 50
    # Native spawn/row ownership is not executed. This adapter invokes the real
    # end body at a due independent deadline, respecting the actual blocked body.
    blocked = body(QUEUE.read_text(), "/datum/durable_timer_queue/proc/blocked()").strip()
    if blocked != "return persistence_save_in_progress":
        raise ValueError(blocked)
    def expire():
        if s.now >= deadline and not s.saving and getattr(m, event):
            finish(m, s)
    return s, p, expire


class EventTests(unittest.TestCase):
    def setUp(self):
        self.source = (ROOT / "code/processes/weather.dm").read_text()

    def test_invalid_policy_services_each_active_event_and_independent_end_cleanup_without_rng(self):
        for event in ("blizzard", "heat_wave", "sandstorm"):
            with self.subTest(event=event):
                s, p, expire = active(event)
                before = vars(p).copy()
                process(self.source, include_durable=True)(p, s)
                self.assertEqual(s.service_calls, 1)
                self.assertEqual((s.probabilities, s.modifications, s.changes, vars(p)), ([], 0, 0, before))
                self.assertTrue(getattr(s.map, event))
                s.now += 50
                expire()
                self.assertFalse(getattr(s.map, event))
                self.assertEqual(s.probabilities, [])
                self.assertEqual(s.map.scheduled, [])
                if event == "heat_wave":
                    self.assertEqual([(x.dry, x.updates) for x in s.sinks], [(False, 1), (False, 1), (True, 0)])
                else:
                    self.assertEqual((s.weather, s.weather_calls), (1, 1))

    def test_save_hold_blocks_fire_and_independent_expiry_until_released(self):
        s, p, expire = active("blizzard")
        s.saving = True
        s.now += 50
        process(self.source, include_durable=True)(p, s)
        expire()
        self.assertEqual(s.service_calls, 0)
        self.assertTrue(s.map.blizzard)
        s.saving = False
        process(self.source, include_durable=True)(p, s)
        expire()
        self.assertEqual(s.service_calls, 1)
        self.assertFalse(s.map.blizzard)
        self.assertEqual(s.probabilities, [])

    def test_published_early_return_control_skips_service_but_does_not_cancel_independent_expiry(self):
        old = subprocess.check_output(["git", "show", PUBLISHED + ":code/processes/weather.dm"], cwd=ROOT, text=True)
        s, p, expire = active("blizzard")
        process(old, include_durable=True)(p, s)
        self.assertEqual(s.service_calls, 0, "published defect did not suppress tail service")
        s.now += 50
        expire()
        self.assertFalse(s.map.blizzard, "independent expiry was incorrectly attributed to fire")
        self.assertEqual(s.probabilities, [])

    def test_legacy_tail_and_timer_ownership_are_unchanged(self):
        old = subprocess.check_output(["git", "show", PUBLISHED + ":code/processes/weather.dm"], cwd=ROOT, text=True)
        marker = "\tif(map && map.uses_durable_metadata())"
        self.assertEqual(self.source.split(marker, 1)[1], old.split(marker, 1)[1])
        for file in (EVENTS, QUEUE):
            relative = file.relative_to(ROOT).as_posix()
            self.assertEqual(file.read_bytes(), subprocess.check_output(["git", "show", PUBLISHED + ":" + relative], cwd=ROOT))


if __name__ == "__main__":
    unittest.main()
