"""Lifts between storeys: source contracts. Behaviour is in probe.dm:

    python3 tests/lifts/test_source.py
    python3 tests/ecology_spawning/run_linux.py . tests/lifts/probe.dm
"""
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


def dmi_states(path):
    from PIL import Image
    meta = Image.open(ROOT / path).info['Description']
    return {line.split('"')[1] for line in meta.splitlines() if line.startswith('state = ')}


class LiftsSource(unittest.TestCase):
    def test_states(self):
        self.assertTrue({'lift_wood', 'lift_iron', 'steam_lift_engine', 'steam_lift_engine_on', 'lift_motor',
                         'lift_motor_on', 'lift_bell', 'lift_button', 'lift_button_lit'} <= dmi_states('icons/obj/lifts.dmi'))

    def test_sheet_matches_generator(self):
        result = subprocess.run([sys.executable, str(ROOT / 'tests/sprites/create_lifts.py'), '--check'],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_platform_is_floor(self):
        self.assertIn('locate(/obj/structure/lift_platform) in T', read('code/modules/1713/siege/castle_traps.dm'))

    def test_recipes_are_researched(self):
        recipes = read('config/crafting/material_recipes_global.txt')
        research = read('code/modules/research_tree/research_node.dm')
        for path in ('/obj/structure/lift_platform', '/obj/structure/lift_call', '/obj/structure/lift_platform/iron',
                     '/obj/structure/lift_drive/steam', '/obj/structure/lift_drive/electric', '/obj/structure/lift_call/button'):
            self.assertIn(f',{path},', recipes)
            self.assertIn(f'"{path}" = "', research)


if __name__ == '__main__':
    unittest.main()
