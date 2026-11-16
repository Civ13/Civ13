"""Siege engines and castle defences: source contract checks. Behaviour is in probe.dm:

    python3 tests/siege_engines/test_source.py
    python3 tests/ecology_spawning/run_linux.py . tests/siege_engines/probe.dm
"""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = (ROOT / 'code/modules/1713/siege/siege_engines.dm').read_text(encoding='utf-8')


def dmi_states(path):
    from PIL import Image
    meta = Image.open(ROOT / path).info['Description']
    return {line.split('"')[1] for line in meta.splitlines() if line.startswith('state = ')}


class SiegeSource(unittest.TestCase):
    def test_states_exist(self):
        states = dmi_states('icons/obj/siege_engines.dmi')
        for s in ('ram', 'ram_swing', 'ballista', 'ballista_loaded', 'ballista_bolt', 'bolt_flight', 'winch',
                  'portcullis_closed', 'portcullis_open', 'portcullis_moving', 'drawbridge_down', 'drawbridge_up',
                  'murder_hole'):
            self.assertIn(s, states)
        for s in ('closed', 'open', 'moving'):          # the sections of a wide portcullis
            for end in 'wcenms':
                self.assertIn('portcullis_%s_%s' % (s, end), states)
        self.assertTrue({'trebuchet0', 'trebuchet1', 'trebuchet_fire'} <= dmi_states('icons/obj/trebuchet.dmi'))
        self.assertTrue({'siege_tower', 'siege_tower_bridge'} <= dmi_states('icons/obj/siege_tower.dmi'))

    def test_recipes_and_research(self):
        recipes = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
        research = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
        for name, path, node in (
                ('battering ram', '/obj/structure/siege_engine/ram', 'siege_engines'),
                ('ballista', '/obj/structure/siege_engine/ballista', 'siege_engines'),
                ('ballista bolt', '/obj/item/ballista_bolt', 'siege_engines'),
                ('siege tower', '/obj/structure/siege_engine/tower', 'siege_engines'),
                ('trebuchet', '/obj/structure/catapult/trebuchet', 'fortifications'),
                ('portcullis', '/obj/structure/castle_gate/portcullis', 'fortifications'),
                ('drawbridge', '/obj/structure/castle_gate/drawbridge', 'fortifications'),
                ('gate winch', '/obj/structure/castle_winch', 'fortifications'),
                ('murder hole', '/obj/structure/murder_hole', 'fortifications')):
            self.assertIn(f',{name},{path},', recipes)
            self.assertIn(f'"{path}" = "{node}",', research)

    def test_catapult_is_data_driven(self):
        cat = (ROOT / 'code/modules/1713/siege/catapult.dm').read_text(encoding='utf-8')
        self.assertIn('angle = Clamp(angle, min_range, max_range)', cat)
        self.assertIn('explosion(target, blast[1], blast[2], blast[3], 0)', cat)
        self.assertIn('icon_state = "[state_prefix]_fire"', cat)
        self.assertNotIn('Clamp(angle, 5, 80)', cat)
        self.assertIn('siege_can_fight()', SRC)


if __name__ == '__main__':
    unittest.main()
