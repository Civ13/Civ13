"""Timekeeping and lighthouses: source contracts. Behaviour is in probe.dm:

    python3 tests/timekeeping/test_source.py
    python3 tests/ecology_spawning/run_linux.py . tests/timekeeping/probe.dm
"""
import importlib.util
import re
import unittest
from pathlib import Path
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[2]
SRC = (ROOT / 'code/modules/1713/timekeeping.dm').read_text(encoding='utf-8')
spec = importlib.util.spec_from_file_location(
    'source_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)


def dmi_states(path):
    from PIL import Image
    meta = Image.open(ROOT / path).info['Description']
    return {line.split('"')[1] for line in meta.splitlines() if line.startswith('state = ')}


class TimekeepingSource(unittest.TestCase):
    def test_elapsed_seconds_respects_both_limits(self):
        elapsed = adapter.project(SRC, '/proc/timekeeping_elapsed_seconds',
                                  'configured_seconds, last_tick', {'world': SimpleNamespace(time=100)})
        for configured_seconds, last_tick, expected in (
            (0, 80, 0), (-3, 80, 0), (2, 105, 0), (2, 100, 0),
            (2, 93, 0.7), (0.5, 60, 0.5), (2, 80, 2), (10, 60, 2),
        ):
            with self.subTest(configured_seconds=configured_seconds, last_tick=last_tick):
                self.assertEqual(elapsed(configured_seconds, last_tick), expected)

    def test_every_state_used_is_drawn(self):
        clock = dmi_states('icons/obj/timekeeping.dmi')
        light = dmi_states('icons/obj/lighthouse.dmi')
        for state in ('sundial', 'water_clock', 'water_clock_empty', 'hourglass', 'hourglass_running',
                      'tower_clock', 'clock_face', 'bell', 'bell_ring'):
            self.assertIn(state, clock)
        for state in ('beacon', 'beacon_lit', 'beacon_reflector', 'lighthouse_lantern'):
            self.assertIn(state, light)

    def test_recipes_are_researched(self):
        recipes = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
        research = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
        for path in ('/obj/structure/sundial', '/obj/structure/water_clock', '/obj/item/hourglass',
                     '/obj/structure/tower_clock', '/obj/structure/clock_face', '/obj/structure/bell',
                     '/obj/structure/lighthouse_beacon', '/obj/structure/lighthouse_beacon/reflector',
                     '/obj/structure/lighthouse_lantern'):
            self.assertIn(f',{path},', recipes)
            self.assertIn(f'"{path}" = "', research)

    def test_no_spawn_and_runtime_stamps(self):
        self.assertIsNone(re.search(r'(?<![_a-z])spawn\(', SRC))
        self.assertIn('return (key in list("burn_seconds", "last_tick", "told")) || ..()', SRC)


if __name__ == '__main__':
    unittest.main()
