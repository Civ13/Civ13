"""Chimneys carrying heat upstairs: source contracts. Behaviour is in probe.dm:

    python3 tests/storey_chimney/test_source.py
    python3 tests/ecology_spawning/run_linux.py . tests/storey_chimney/probe.dm
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


class StoreyChimneySource(unittest.TestCase):
    def test_states(self):
        self.assertTrue({'chimney', 'chimney_top', 'chimney_smoke'} <= dmi_states('icons/obj/storey_fittings.dmi'))

    def test_sheet_matches_generator(self):
        result = subprocess.run([sys.executable, str(ROOT / 'tests/sprites/create_storey_fittings.py'), '--check'],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_heat_hook(self):
        self.assertIn('if (istype(O, /obj/structure/chimney))', read('code/game/objects/building_insulation.dm'))

    def test_recipe_is_researched(self):
        self.assertIn(',chimney,/obj/structure/chimney,', read('config/crafting/material_recipes_global.txt'))
        self.assertIn('"/obj/structure/chimney" = "primitive_construction"', read('code/modules/research_tree/research_node.dm'))


if __name__ == '__main__':
    unittest.main()
