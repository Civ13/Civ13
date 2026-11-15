"""Aqueducts: source contract checks. The behaviour is in probe.dm:

    python3 tests/aqueducts/test_source.py
    python3 tests/ecology_spawning/run_linux.py . tests/aqueducts/probe.dm
"""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = (ROOT / 'code/modules/1713/aqueducts.dm').read_text(encoding='utf-8')


def dmi_states(path):
    from PIL import Image
    meta = Image.open(ROOT / path).info['Description']
    return {line.split('"')[1] for line in meta.splitlines() if line.startswith('state = ')}


class AqueductSource(unittest.TestCase):
    def test_states_exist_in_the_sheet(self):
        states = dmi_states('icons/obj/aqueducts.dmi')
        for prefix in ('channel', 'flume', 'arch', 'water', 'pipe_clay', 'pipe_lead'):
            for j in range(16):
                self.assertIn(f'{prefix}{j}', states)
        for state in ('qanat', 'qanat_wet', 'intake', 'noria', 'noria_on', 'fountain', 'fountain_full',
                      'tap', 'tap_running', 'bath', 'bath_full'):
            self.assertIn(state, states)
        self.assertIn('icon_state = "[junction_prefix][junction]"', SRC)
        self.assertIn('image(icon, "water[junction]")', SRC)

    def test_recipes_and_research(self):
        recipes = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
        research = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
        for material, name, path in (
                ('stone', 'aqueduct channel', '/obj/structure/aqueduct/channel'),
                ('stone', 'aqueduct arches', '/obj/structure/aqueduct/arch'),
                ('stone', 'qanat shaft', '/obj/structure/aqueduct/qanat'),
                ('stone', 'aqueduct intake', '/obj/structure/aqueduct_intake'),
                ('stone', 'public fountain', '/obj/structure/sink/aqueduct_fountain'),
                ('wood', 'timber flume', '/obj/structure/aqueduct/flume'),
                ('wood', 'noria', '/obj/structure/aqueduct_intake/noria'),
                ('clay', 'clay water pipe', '/obj/structure/aqueduct/pipe')):
            self.assertIn(f'RECIPE: /material/{material}/,{name},{path},', recipes)
            self.assertIn(f'"{path}" = "irrigation",', research)
        for material, name, path, node in (
                ('stone', 'public bath', '/obj/structure/aqueduct_bath', 'hygiene'),
                ('lead', 'lead water pipe', '/obj/structure/aqueduct/pipe/lead', 'sanitation'),
                ('bronze', 'water tap', '/obj/structure/sink/aqueduct_fountain/tap', 'sanitation')):
            self.assertIn(f'RECIPE: /material/{material}/,{name},{path},', recipes)
            self.assertIn(f'"{path}" = "{node}",', research)

    def test_hooks(self):
        power = (ROOT / 'code/modules/1713/mechanical_power.dm').read_text(encoding='utf-8')
        self.assertIn('if (race_fed_until > world.time)', power)
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertIn('#include "code\\modules\\1713\\aqueducts.dm"', dme)
        # One walk per minute for every network, bounded.
        self.assertIn('#define AQUEDUCT_WALK_LIMIT', SRC)
        self.assertIn('while (queue.len && steps < AQUEDUCT_WALK_LIMIT)', SRC)
        self.assertIn('if (world.time - aqueduct_last_flow < 550)', SRC)
        # Fountains only fill from the aqueduct.
        self.assertIn('/obj/structure/sink/aqueduct_fountain/refill()\n\treturn', SRC)


if __name__ == '__main__':
    unittest.main()
