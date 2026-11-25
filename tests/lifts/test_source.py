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

    def test_completion_rechecks_and_uses_same_load(self):
        source = read('code/modules/multiz/lifts.dm')
        travel = source.split('/proc/travel(mob/living/user', 1)[1].split('/proc/finish_travel', 1)[0]
        finish = source.split('/proc/finish_travel', 1)[1].split('/attack_hand', 1)[0]
        self.assertLess(travel.index('do_after('), travel.index('return finish_travel('))
        self.assertLess(finish.index('load_refusal(carried)'), finish.index('arrive(z, carried)'))

    def test_buckled_riders_follow_only_their_carried_seat(self):
        source = read('code/modules/multiz/lifts.dm')
        selection = source.split('/proc/riders()', 1)[1].split('/proc/load_refusal', 1)[0]
        arrival = source.split('/proc/arrive(', 1)[1].split('/proc/travel(', 1)[0]
        self.assertIn('if (M.buckled && !(M.buckled in carried))', selection)
        self.assertLess(arrival.index('A.persistence_set_loc(there)'),
                        arrival.index('M.buckled.loc == there'))

    def test_call_checks_both_directions_for_reachable_lifts(self):
        call = read('code/modules/multiz/lifts.dm').split('/proc/find_platform()', 1)[1]
        self.assertEqual(call.count('if (here.z in candidate.shaft_levels())'), 2)

    def test_recipes_are_researched(self):
        recipes = read('config/crafting/material_recipes_global.txt')
        research = read('code/modules/research_tree/research_node.dm')
        for path in ('/obj/structure/lift_platform', '/obj/structure/lift_call', '/obj/structure/lift_platform/iron',
                     '/obj/structure/lift_drive/steam', '/obj/structure/lift_drive/electric', '/obj/structure/lift_call/button'):
            self.assertIn(f',{path},', recipes)
            self.assertIn(f'"{path}" = "', research)


if __name__ == '__main__':
    unittest.main()
