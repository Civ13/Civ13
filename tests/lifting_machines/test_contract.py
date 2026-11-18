"""Shear legs and the heavy-load ladder rule: source contract checks.

Every ladder climb asks the heavy-load guard before it moves anything, the
listed heavy types exist, the shear legs have a recipe, a research node and
sprite states, and a haul moves the load only after the wait re-checks it.

    python3 tests/lifting_machines/test_contract.py
"""
import re
import subprocess
import sys
import unittest
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/1713/lifting_machines.dm').read_text(encoding='utf-8')
LADDERS = (ROOT / 'code/modules/multiz/structures.dm').read_text(encoding='utf-8')
RECIPES = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
NODES = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
DME = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
DMI = ROOT / 'icons/obj/lifting_machines.dmi'
LEGS = '/obj/structure/workshop_machine/shear_legs'


def proc_body(text, header):
    start = text.index(header)
    end = text.find('\n/', start + 1)
    return text[start:end]


def type_list(name):
    body = re.search(r'var/global/list/%s = list\((.*?)\n\)' % name, SOURCE, re.S).group(1)
    return re.findall(r'(/obj/[\w/]+),', body)


class LiftingMachines(unittest.TestCase):
    def test_shear_legs_have_a_recipe_and_a_research_node(self):
        rows = [l[len('RECIPE: '):].split(',') for l in RECIPES.splitlines()
                if l.startswith('RECIPE: ') and l.split(',')[2] == LEGS]
        self.assertEqual(len(rows), 1)
        self.assertEqual((rows[0][0], float(rows[0][3])), ('/material/wood/', 10))
        self.assertIn('"%s" = "primitive_construction"' % LEGS, NODES)
        self.assertRegex(SOURCE, r'(?m)^%s$' % re.escape(LEGS))

    def test_file_loads_after_the_workshop_machine_base(self):
        self.assertLess(DME.index('clay_lime_fire.dm'), DME.index('lifting_machines.dm'))

    def test_every_listed_type_is_defined(self):
        defined = set()
        for path in (ROOT / 'code').rglob('*.dm'):
            defined.update(re.findall(r'(?m)^(/obj/structure/[\w/]+)\s*$', path.read_text(encoding='utf-8', errors='replace')))
        heavy = type_list('hoist_only_types')
        self.assertGreaterEqual(len(heavy), 10)
        for path in heavy + type_list('hoist_exempt_types'):
            self.assertIn(path, defined, path)
        for path in ('/obj/structure/anvil', '/obj/structure/furnace', '/obj/structure/cannon',
                     '/obj/structure/vehicleparts', '/obj/structure/workshop_machine'):
            self.assertIn(path, heavy)
        # the legs themselves must be able to reach the upper floor
        self.assertIn(LEGS, type_list('hoist_exempt_types'))

    def test_every_ladder_climb_asks_the_guard_before_the_wait(self):
        # the other ladder attack_hand overrides only gate and call the parent
        carrying = 0
        for m in re.finditer(r'(?m)^/obj/structure/multiz/ladder[\w/]*/attack_hand\(', LADDERS):
            body = LADDERS[m.start():LADDERS.find('\n/', m.start() + 1)]
            if 'M.pulling' not in body:
                self.assertIn('..()', body)
                continue
            carrying += 1
            wait = body.index('do_after(')
            self.assertLess(body.index('if (ladder_refuses_load(M))'), wait)
            # a pull picked up during the wait is caught before anything moves
            after = body[wait:]
            self.assertLess(after.index('if (ladder_refuses_load(M))'), after.index('M.pulling.persistence_set_'))
        self.assertEqual(carrying, 2)

    def test_load_rule_allows_what_makes_sense(self):
        # Krunes report 2026-11-18: crates went up ladders though stairs
        # dropped every pull. Val: allow it where it makes sense.
        body = proc_body(SOURCE, '/proc/level_change_load_problem(')
        # people and small animals come along on ladders, big animals do not
        self.assertIn('if (ladder && L.mob_size > MOB_MEDIUM)', body)
        # hoist-only loads go on neither ladders nor stairs
        self.assertIn('if (needs_hoist(A))', body)
        self.assertLess(body.index('if (needs_hoist(A))'), body.index('if (ladder && !isitem(A))'))
        # wheeled carts are bumped up neither steps nor rungs
        self.assertIn('if (is_wheeled_load(A))', body)
        self.assertIn('/obj/structure/shopping_cart', type_list('wheeled_load_types'))
        # on a ladder only loose items, no crates or furniture
        self.assertIn('if (ladder && !isitem(A))', body)
        guard = proc_body(SOURCE, '/proc/ladder_refuses_load(mob/M)')
        self.assertIn('level_change_load_problem(M.pulling, TRUE)', guard)
        self.assertIn('if (!isobj(A))\n\t\treturn FALSE', proc_body(SOURCE, '/proc/needs_hoist('))

    def test_stairs_bring_what_they_can_and_let_go_of_the_rest(self):
        check = proc_body(SOURCE, '/proc/stairs_check_load(')
        self.assertIn('level_change_load_problem(load, FALSE)', check)
        self.assertIn('persistence_movement_allowed(load, destination)', check)
        self.assertIn('M.stop_pulling()', check)
        bring = proc_body(SOURCE, '/proc/stairs_bring_load(')
        self.assertIn('M.pulling.forceMove(M.loc)', bring)
        edge = (ROOT / 'code/modules/multiz/edge_climbing.dm').read_text(encoding='utf-8')
        for name in ('/mob/living/human/proc/climb_stairs(', '/proc/stairs_soft_descent('):
            body = proc_body(edge, name)
            self.assertNotIn('stop_pulling()\n\tif (pulledby)', body.replace('H.', ''))
            self.assertLess(body.index('stairs_check_load('), body.index('trench_climb_place('))
            self.assertLess(body.index('trench_climb_place('), body.index('stairs_bring_load('))

    def test_haul_rechecks_the_load_and_landing_after_the_wait(self):
        body = proc_body(SOURCE, LEGS + '/proc/haul(')
        wait = body.index('do_after(')
        move = body.index('load.persistence_set_loc(destination)')
        check = body.index('load.loc != start')
        self.assertLess(wait, check)
        self.assertLess(check, move)
        after = body[wait:move]
        for needed in ('hauler_ready(H)', 'sling_problem(load)', 'ledge_landing_clear(destination)', 'QDELETED(load)'):
            self.assertIn(needed, after)
        self.assertIn('busy = FALSE', after)

    def test_legs_refuse_fastened_loads_people_and_saves(self):
        body = proc_body(SOURCE, LEGS + '/proc/sling_problem(')
        self.assertIn('A.anchored', body)
        self.assertIn('locate(/mob/living) in A', body)
        self.assertIn("istype(A, /obj/item) || istype(A, /obj/structure)", body)
        ready = proc_body(SOURCE, LEGS + '/proc/hauler_ready(')
        for needed in ('anchored', 'persistence_save_in_progress', 'persistence_active_operation',
                       'persistence_load_recovery_required', 'H.incapacitated()'):
            self.assertIn(needed, ready)

    def test_loads_only_pass_through_open_air_onto_clear_ground(self):
        landing = proc_body(SOURCE, LEGS + '/proc/landing_on(')
        self.assertIn('ledge_landing_clear(T)', landing)
        self.assertIn('below_open_air && !edge_open_air(locate(T.x, T.y, z))', landing)
        choices = proc_body(SOURCE, LEGS + '/proc/haul_choices(')
        self.assertIn('edge_open_air(locate(load.x, load.y, up))', choices)
        self.assertIn('landing_on(multiz_level_below(z), TRUE)', choices)
        self.assertIn('edge_open_air(locate(T.x, T.y, z))', proc_body(SOURCE, LEGS + '/proc/loads_below('))

    def test_crane_is_the_same_hoist_with_a_longer_reach(self):
        crane = SOURCE[SOURCE.index('\n' + LEGS + '/crane\n'):]
        self.assertIn('reach = 3', crane)
        self.assertNotIn('/proc/', crane)
        self.assertIn('var/reach = 2', SOURCE)
        self.assertIn('range(reach, centre)', proc_body(SOURCE, LEGS + '/proc/landing_on('))
        self.assertIn('range(reach, centre)', proc_body(SOURCE, LEGS + '/proc/loads_below('))

    def test_sprite_sheet_states_and_script(self):
        data = DMI.read_bytes()
        at = data.index(b'zTXtDescription\x00\x00') + len(b'zTXtDescription\x00\x00')
        text = zlib.decompressobj().decompress(data[at:]).decode()
        states = {m.group(1): int(m.group(2))
                  for m in re.finditer(r'state = "([^"]+)"\n\tdirs = 1\n\tframes = (\d+)', text)}
        self.assertEqual(states, {'shear_legs': 1, 'shear_legs_haul': 4,
                                  'treadwheel_crane': 1, 'treadwheel_crane_haul': 4})
        for state in ('shear_legs', 'treadwheel_crane'):
            self.assertIn('base_state = "%s"' % state, SOURCE)
        self.assertIn('icon_state = "[base_state]_haul"', SOURCE)
        try:
            import PIL  # noqa: F401
        except ImportError:
            self.skipTest('Pillow not installed')
        result = subprocess.run([sys.executable, str(ROOT / 'tests/sprites/create_lifting.py'), '--check'],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
