"""Timekeeping and lighthouses: source contracts. Behaviour is in probe.dm:

    python3 tests/timekeeping/test_source.py
    python3 tests/ecology_spawning/run_linux.py . tests/timekeeping/probe.dm
"""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = (ROOT / 'code/modules/1713/timekeeping.dm').read_text(encoding='utf-8')


def dmi_states(path):
    from PIL import Image
    meta = Image.open(ROOT / path).info['Description']
    return {line.split('"')[1] for line in meta.splitlines() if line.startswith('state = ')}


class TimekeepingSource(unittest.TestCase):
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
