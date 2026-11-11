"""Offline source contracts only; does not establish BYOND movement or UI behavior."""
from pathlib import Path
import unittest
import re
import struct
import zlib
ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/multiz/pit_climbing.dm').read_text(encoding='utf-8-sig')

def proc(name):
    return SOURCE.split(name + '\n', 1)[1].split('\n/', 1)[0]

class PitClimbing(unittest.TestCase):
    def test_all_player_digging_routes_have_no_free_ladder(self):
        for path in ('code/modules/1713/tools.dm', 'code/game/turfs/floor_attackby.dm', 'code/modules/multiz/dug_underground.dm'):
            source = (ROOT / path).read_text()
            self.assertEqual(source.count('/tunneltop/pit('), 2, path)
            self.assertNotRegex(source, r'new\s*/obj/structure/multiz/ladder/ww2/tunnelbottom\(')
    def test_leaf_payment_rechecked_after_wait(self):
        source = proc('/obj/structure/multiz/ladder/ww2/tunneltop/pit/attackby(obj/item/I, mob/user)')
        self.assertLess(source.index('do_after'), source.index('leaves.use(5)'))
        self.assertLess(source.index('leaves.use(5)'), source.index('leaf_covered = TRUE'))
        self.assertEqual(source.count('user.get_active_hand() != leaves'), 2)
        self.assertIn('QDELETED(leaves)', source)
    def test_landing_refuses_hazards_and_occupancy(self):
        source = proc('/proc/ledge_landing_clear(turf/T, allow_occupants = FALSE)')
        for guard in ('T.density', '/turf/floor/dirt/underground', '/turf/floor/beach/water', '/turf/floor/lava', 'A.density || isliving(A)', 'C.wall || C.incomplete', '!building_open_turf(T)', '/tunneltop/pit'):
            self.assertIn(guard, source)
    def test_climb_revalidates_geometry_after_wait(self):
        verb = proc('/mob/living/human/verb/climb_up_ledge()')
        self.assertIn('ledge_climb_directions(dir)', verb)
        self.assertIn('climb_ledge(direction)', verb)
        source = proc('/mob/living/human/proc/climb_ledge(direction)')
        self.assertLess(source.index('do_after'), source.index('ledge_climb_destination(src, direction) != destination'))
        self.assertLess(source.index('ledge_climb_destination(src, direction) != destination'), source.index('trench_climb_place(src, destination)'))
        self.assertIn('get_turf(src) != start || dir != direction', source)
    def test_grab_click_reuses_climb_up(self):
        source = proc('/mob/living/human/proc/grab_climb_ledge(atom/A)')
        self.assertIn('a_intent != I_GRAB || get_active_hand()', source)
        self.assertIn('get_step(here, direction) != target', source)
        self.assertLess(source.index('if (!ledge_climb_destination(src, direction) && !ledge_under_shaft(src))'), source.index('climb_ledge(direction)'))
        self.assertNotIn('trench_climb_place', source)
        self.assertNotIn('do_after', source)
        click = (ROOT / 'code/_onclick/other_mobs.dm').read_text()
        unarmed = click.split('/mob/living/human/UnarmedAttack(', 1)[1].split('\n/', 1)[0]
        self.assertLess(unarmed.index('grab_climb_ledge(A)'), unarmed.index('A.attack_hand('))
    def test_occupied_pits_still_work_and_transfers_align(self):
        self.assertIn('ledge_landing_clear(T, TRUE) ? T : null', SOURCE)
        self.assertIn('if (allow_occupants && isliving(A))', SOURCE)
        self.assertEqual(SOURCE.count('trench_climb_place('), 3)
        self.assertNotIn('.forceMove(', SOURCE)
    def test_no_numeric_z_or_free_flight(self):
        self.assertIn('multiz_level_above(here.z)', SOURCE)
        self.assertIn('multiz_level_below(z)', SOURCE)
        self.assertNotIn('FLYING', SOURCE)
        self.assertNotRegex(SOURCE, r'\.z\s*[+-]\s*1')
    def test_actor_and_save_guards(self):
        self.assertIn('!ledge_climber_problem(H)', proc('/proc/ledge_climber_ready(mob/living/human/H)'))
        source = proc('/proc/ledge_climber_problem(mob/living/human/H)')
        for guard in ('H.stat', 'H.lying', 'H.restrained()', 'H.buckled', 'H.pulling', 'H.pulledby', '!H.has_empty_hand()', 'persistence_save_in_progress'):
            self.assertIn(guard, source)
        source = proc('/proc/ledge_climb_destination(mob/living/human/H, direction, list/why)')
        self.assertIn('ledge_climber_problem(H)', source)
        self.assertIn('map.check_caribbean_block(H, destination)', source)
        self.assertIn('persistence_movement_allowed(H, destination)', source)
        self.assertIn('!shaft && !building_open_turf(overhead)', source)
    def test_camouflage_saved_and_sprite_exists(self):
        self.assertIn('. |= list("leaf_covered")', SOURCE)
        data = (ROOT / 'icons/obj/items.dmi').read_bytes()
        offset = 8
        description = ''
        while offset < len(data):
            n = struct.unpack('>I', data[offset:offset+4])[0]
            kind = data[offset+4:offset+8]
            body = data[offset+8:offset+8+n]
            if kind == b'zTXt':
                key, value = body.split(b'\0', 1)
                if key == b'Description':
                    description = zlib.decompress(value[1:]).decode()
            offset += n + 12
        self.assertIn('state = "punji2"', description)
    def test_pit_does_not_shift_mapped_pair_numbering(self):
        self.assertIn("ladder_list -= src", proc("/obj/structure/multiz/ladder/ww2/tunneltop/pit/New()"))
    def test_pit_does_not_inherit_ladder_crossing(self):
        source = proc('/obj/structure/multiz/ladder/ww2/tunneltop/pit/Crossed(atom/movable/A)')
        self.assertNotIn('..()', source)
        self.assertIn('persistence_movement_allowed(A, T)', source)
        self.assertIn('if (trench_climb_place(L, T))', source)

    def test_pull_links_break_instead_of_bridging_the_pit(self):
        source = proc('/obj/structure/multiz/ladder/ww2/tunneltop/pit/Crossed(atom/movable/A)')
        guard = source.split('return', 1)[0]
        self.assertNotIn('L.pulling', guard)
        self.assertNotIn('L.pulledby', guard)
        self.assertIn('L.buckled', guard)
        release = source.index('L.pulledby.stop_pulling()')
        self.assertLess(source.index('persistence_movement_allowed(A, T)'), release)
        self.assertLess(release, source.index('if (trench_climb_place(L, T))'))
        self.assertIn('L.stop_pulling()', source)

LADDER = (ROOT / 'code/modules/multiz/hole_ladder.dm').read_text(encoding='utf-8-sig')

def ladder_proc(name):
    return LADDER.split(name + '\n', 1)[1].split('\n/', 1)[0]

class HoleLadder(unittest.TestCase):
    def test_ladder_is_a_stone_age_wood_recipe(self):
        recipes = (ROOT / 'config/crafting/material_recipes_global.txt').read_text()
        self.assertIn('RECIPE: /material/wood/,wooden ladder,/obj/item/weapon/hole_ladder,4,60,0,1,tools,0,0,0,8,null', recipes)
        self.assertIn('"/obj/item/weapon/hole_ladder" = "basic_tools"', (ROOT / 'code/modules/research_tree/research_node.dm').read_text())
        dme = (ROOT / 'civ13.dme').read_text()
        self.assertLess(dme.index('multiz\\pit_climbing.dm'), dme.index('multiz\\hole_ladder.dm'))
    def test_fitted_ladder_stops_falls_and_is_saved(self):
        crossed = ladder_proc('/obj/structure/multiz/ladder/ww2/tunneltop/pit/Crossed(atom/movable/A)')
        self.assertLess(crossed.index('if (has_ladder)'), crossed.index('return ..()'))
        self.assertIn('. |= list("has_ladder")', LADDER)
    def test_fitting_rechecks_after_wait_and_pays_once(self):
        fit = ladder_proc('/obj/structure/multiz/ladder/ww2/tunneltop/pit/proc/fit_ladder(obj/item/weapon/hole_ladder/ladder, mob/user)')
        wait = fit.index('do_after')
        self.assertLess(wait, fit.index('QDELETED(ladder) || has_ladder'))
        self.assertLess(fit.index('QDELETED(ladder) || has_ladder'), fit.index('qdel(ladder)'))
        self.assertEqual(fit.count('qdel(ladder)'), 1)
        self.assertIn('locate(/obj/structure/multiz) in T', fit)
    def test_climbs_use_aligned_placement_and_movement_admission(self):
        for name in ('/obj/structure/multiz/ladder/ww2/tunneltop/pit/attack_hand(mob/user)', '/obj/structure/multiz/ladder/up/hole_ladder/attack_hand(mob/user)'):
            source = ladder_proc(name)
            self.assertLess(source.index('do_after'), source.index('persistence_movement_allowed(user, T)'))
            self.assertIn('trench_climb_place(user, T)', source)
        self.assertNotIn('.forceMove(', LADDER)
    def test_lower_ladder_is_removed_with_the_hole(self):
        self.assertIn('qdel(L)', ladder_proc('/obj/structure/multiz/ladder/ww2/tunneltop/pit/Destroy()'))
        self.assertIn('ladder_list -= src', LADDER)

if __name__ == '__main__':
    unittest.main()
