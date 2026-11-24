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
    with Image.open(ROOT / path) as source:
        meta = source.info['Description']
    return {line.split('"')[1] for line in meta.splitlines() if line.startswith('state = ')}


class SiegeSource(unittest.TestCase):
    def test_hot_container_examine_keeps_the_glass_range_result(self):
        pour = (ROOT / 'code/modules/1713/siege/castle_pour.dm').read_text(encoding='utf-8')
        glass = (ROOT / 'code/modules/reagents/reagent_containers/glass.dm').read_text(encoding='utf-8')
        examine = pour.split('/obj/item/weapon/reagent_containers/examine(', 1)[1].split('\n//', 1)[0]
        self.assertTrue(examine.startswith('mob/user, distance = -1)\n'))
        self.assertIn('\t. = ..(user, distance)\n', examine)
        self.assertIn('\tif (is_hot())\n\t\tto_chat(user, SPAN_WARNING("It is hot."))', examine)
        detail = glass.split('/glass/examine(', 1)[1].split('\n/obj/', 1)[0]
        self.assertLess(detail.index('if (!..(user, 2))'), detail.index('reagents.total_volume'))

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

    def test_iron_gate_winch_discovery_is_exact_and_follows_whole_runs(self):
        controls = (ROOT / 'code/game/objects/controls.dm').read_text(encoding='utf-8')
        runs = (ROOT / 'code/modules/1713/siege/portcullis_runs.dm').read_text(encoding='utf-8')
        self.assertIn('return type == /obj/structure/gate || type == /obj/structure/gate/open', controls)
        self.assertIn('if (!QDELETED(G) && G.is_iron_grid_gate())', runs)
        self.assertIn('list(axis, turn(axis, 180))', runs.split('/proc/iron_grid_run()', 1)[1])
        self.assertIn('while (G && !(G in .))', runs)
        self.assertIn('G = G.iron_grid_neighbour(direction)', runs)
        self.assertIn('if (QDELETED(I) || !I.is_iron_grid_gate() || I in .)', SRC)
        self.assertIn('. |= I.iron_grid_run()', SRC)
        self.assertIn('I.set_iron_grid_open(raise)', SRC)
        self.assertIn('G.set_open(raise)', SRC)  # Castle gates still use their own rules.

    def test_iron_gate_controls_share_one_guarded_animated_transition(self):
        controls = (ROOT / 'code/game/objects/controls.dm').read_text(encoding='utf-8')
        self.assertIn('G.set_iron_grid_open(!G.open)', controls)
        transition = controls.split('/proc/set_iron_grid_open(raise)', 1)[1].split('/attackby(', 1)[0]
        self.assertIn('iron_grid_moving || open == raise', transition)
        self.assertIn('iron_grid_moving = TRUE', transition)
        self.assertIn('PROC_REF(finish_iron_grid_motion), raise), 3 SECONDS', transition)
        self.assertIn('iron_grid_moving = FALSE', transition)
        self.assertIn('density = !raise', transition)
        self.assertTrue({'gate_opening', 'gate_closing', 'gate1', 'gate0'} <=
                        dmi_states('icons/obj/doors/material_doors.dmi'))
        self.assertNotIn('crush_under', transition)

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
