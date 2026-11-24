"""Offline source contracts for climbing down, standing ladders and stairs.

Behaviour is covered natively by tests/edge_climbing/run_native.py.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/multiz/edge_climbing.dm').read_text(encoding='utf-8-sig')


def proc(name):
    return SOURCE.split(name + '\n', 1)[1].split('\n/', 1)[0]


class EdgeClimbing(unittest.TestCase):
    def test_included_in_build(self):
        self.assertIn('#include "code\\modules\\multiz\\edge_climbing.dm"', (ROOT / 'civ13.dme').read_text())

    def test_descent_reuses_climber_and_landing_checks(self):
        source = proc('/proc/edge_descent_destination(mob/living/human/H, direction, list/why, terrain_only = FALSE)')
        for guard in ('ledge_climber_problem(H)', 'edge_open_air(edge)', 'edge_open_air(here)', 'multiz_level_below(edge.z)',
                      'ledge_landing_clear(destination)', 'map.check_caribbean_block(H, destination)',
                      'persistence_movement_allowed(H, destination)'):
            self.assertIn(guard, source)

    def test_descent_revalidates_after_wait(self):
        source = proc('/mob/living/human/proc/climb_down_edge(direction)')
        self.assertLess(source.index('do_after'), source.index('edge_descent_destination(src, direction) != destination'))
        self.assertLess(source.index('edge_descent_destination(src, direction) != destination'), source.index('trench_climb_place(src, destination)'))

    def test_grab_click_and_verb_wired(self):
        click = (ROOT / 'code/_onclick/other_mobs.dm').read_text()
        unarmed = click.split('/mob/living/human/UnarmedAttack(', 1)[1].split('\n/', 1)[0]
        self.assertLess(unarmed.index('grab_climb_down_edge(A)'), unarmed.index('A.attack_hand('))
        source = proc('/mob/living/human/proc/grab_climb_down_edge(atom/A)')
        self.assertIn('a_intent != I_GRAB || get_active_hand()', source)
        self.assertNotIn('do_after', source)
        tree = (ROOT / 'code/game/objects/structures/tree_climbing.dm').read_text()
        verb = tree.split('/mob/living/human/verb/climb_down_tree_verb()', 1)[1].split('\n/', 1)[0]
        self.assertIn('climb_down_any_edge()', verb)

    def test_ladder_pair_is_unnumbered_and_removed_together(self):
        self.assertEqual(SOURCE.count('ladder_list -= src'), 2)
        self.assertEqual(SOURCE.count('qdel(other)'), 2)
        place = proc('/obj/item/weapon/hole_ladder/proc/try_stand_ladder(atom/A, mob/user)')
        self.assertLess(place.index('do_after'), place.rindex('placed_ladder_spot(T, user, why)'))
        self.assertLess(place.rindex('placed_ladder_spot(T, user, why)'), place.index('qdel(src)'))

    def test_stairs_need_open_stairwell_and_top_floor(self):
        source = proc('/proc/stairs_destination(mob/living/human/H, obj/covers/S, list/why)')
        self.assertIn('edge_open_air(well)', source)
        self.assertIn('ledge_landing_clear(landing)', source)
        for path in ('/obj/covers/wood/stairs', '/obj/covers/cobblestone/stairs', '/obj/covers/sandstone/stairs'):
            self.assertIn(path + '\n\tstairs = TRUE', SOURCE)

    def test_stairwells_step_down_instead_of_falling(self):
        building = (ROOT / 'code/game/objects/building_levels.dm').read_text()
        entered = building.split('/turf/sky/building/Entered(atom/movable/A)', 1)[1].split('\n/', 1)[0]
        self.assertLess(entered.index('stairs_soft_descent(A, below)'), entered.index('A.forceMove(below)'))
        open_space = (ROOT / 'code/modules/multiz/open_space.dm').read_text()
        entered = open_space.split('/turf/floor/broken_floor/Entered(atom/movable/A)', 1)[1].split('\n/', 1)[0]
        self.assertLess(entered.index('stairs_soft_descent(A, floorbelowz)'), entered.index('persistence_set_z(A.z - 1)'))
        self.assertIn('stairs_step_on(H, src, OL)', (ROOT / 'code/game/turfs/turf.dm').read_text())

    def test_hole_rendering_skips_its_own_turf_without_changing_movement(self):
        open_space = (ROOT / 'code/modules/multiz/open_space.dm').read_text()
        render = open_space.split('/turf/floor/broken_floor/update_icon()\n', 1)[1].split('\n/', 1)[0]
        self.assertIn('if (floorbelowz && floorbelowz != src)\n\t\ticon = floorbelowz.icon', render)
        self.assertLess(render.index('overlays.Cut()'), render.index('floorbelowz != src'))
        entered = open_space.split('/turf/floor/broken_floor/Entered(atom/movable/A)', 1)[1].split('\n/', 1)[0]
        self.assertIn('if (floorbelowz)', entered)
        self.assertLess(entered.index('A.forceMove(get_step(src,push_dir))'), entered.index('persistence_set_z(A.z - 1)'))

    def test_stairs_cooldown_is_runtime_only(self):
        self.assertIn('/mob/living/human/var/tmp/stairs_moved_at', SOURCE)
        self.assertIn('key == "stairs_moved_at"', SOURCE)


class UpDownButtons(unittest.TestCase):
    """The HUD up and down buttons; behaviour is in the native probe."""

    def test_every_style_places_both_buttons_on_their_own_spots(self):
        import re
        hud = (ROOT / 'code/datums/hud.dm').read_text()
        blocks = re.split(r'^(?=/datum/hud/human)', hud, flags=re.M)[1:]
        self.assertEqual(len(blocks), 5)
        for block in blocks:
            for key, kind in (('go up', '/obj/screen/updown'), ('go down', '/obj/screen/updown/down')):
                spot = re.search(r'"' + key + r'" = \s*list\("type" = ' + re.escape(kind) + r',\s*"loc" = "([^"]+)"\)', block)
                self.assertIsNotNone(spot, key)
                self.assertEqual(len(re.findall(r'"loc" = "' + re.escape(spot[1]) + '"', block)), 1, key)
        species = (ROOT / 'code/game/mob/living/carbon/human/species/species_hud.dm').read_text()
        self.assertIn('"go up", "go down"', species)

    def test_every_sheet_has_lit_and_greyed_arrows(self):
        for sheet in ('1713Style', 'ConsoleStyle', 'litewebStyle', 'FoFStyle'):
            data = (ROOT / f'icons/mob/screen/{sheet}.dmi').read_bytes()
            import zlib, struct
            i = data.find(b'zTXt')
            length = struct.unpack('>I', data[i - 4:i])[0]
            chunk = data[i + 4:i + 4 + length]
            text = zlib.decompress(chunk[chunk.index(bytes(1)) + 2:]).decode()
            for state in ('arrow_up', 'arrow_up_off', 'arrow_down', 'arrow_down_off'):
                self.assertIn(f'state = "{state}"', text, sheet)

    def test_buttons_and_keys_share_one_press(self):
        hud = (ROOT / 'code/_onclick/hud/updown_buttons.dm').read_text()
        self.assertIn('set name = "go-up"', hud)
        self.assertIn('set name = "go-down"', hud)
        self.assertEqual(hud.count('press_updown('), 4)  # proc, two keys, the tile
        keys = (ROOT / 'code/modules/client/action_keybindings.dm').read_text()
        self.assertIn('"floor_up" = list("Go up a level (ladder, stairs, ledge, surface)", "go-up", list(), list())', keys)
        self.assertIn('"floor_down" = list("Go down a level (ladder, edge, tree, dive)", "go-down", list(), list())', keys)
        floors = (ROOT / 'code/modules/multiz/floor_buttons.dm').read_text()
        # The offer looks at the ground only; the press goes through the same
        # checked climbs as the verbs.
        self.assertIn('ledge_climb_destination(src, d, null, TRUE)', floors)
        self.assertIn('edge_descent_destination(src, d, null, TRUE)', floors)
        for climb in ('climb_ledge(d)', 'climb_down_edge(d)', 'climb_stairs(stairs)', 'L.attack_hand(src)',
                      'start_vehicle_deck_down()', 'start_climb_down()'):
            self.assertIn(climb, floors)
        # In the sea the buttons Dive and Surface through the verbs' own procs.
        self.assertIn('var/sea = sea_updown_offer(direction)', floors)
        self.assertIn('return surface_from_seabed()', floors)
        self.assertIn('return free_dive()', floors)
        diving = (ROOT / 'code/modules/1713/machinery/modular_vehicles/ships/free_diving.dm').read_text()
        self.assertIn('\tsurface_from_seabed()\n', diving)  # the Surface verb
        self.assertIn('free_dive_target(T)', diving)
        dme = (ROOT / 'civ13.dme').read_text()
        self.assertIn('updown_buttons.dm', dme)
        self.assertIn('floor_buttons.dm', dme)


    def test_stairs_down_built_below_opening_and_revalidated(self):
        source = proc('/proc/stairs_down_spot(mob/user, stairs_type, list/why)')
        for guard in ('tile_build_refusal(here, stairs_type)', 'edge_open_air(well)', 'multiz_level_below(well.z)',
                      'tile_floor_cover(lower)', 'building_floor_error(lower)', 'ledge_landing_clear(lower, TRUE)',
                      'ledge_landing_clear(here, TRUE)', 'turn(direction, 180)'):
            self.assertIn(guard, source)
        stack = (ROOT / 'code/game/objects/items/stacks/stack.dm').read_text(encoding='utf-8-sig')
        produce = stack.split('/obj/item/stack/proc/produce_recipe(', 1)[1].split('\n/obj/item/stack/proc/', 1)[0]
        first = produce.index('stairs_down_spot(user, recipe.result_type, stairs_why)')
        wait = produce.index('do_after(user, buildtime, ship_craft = ship_craft)')
        second = produce.index('stairs_down_spot(user, recipe.result_type, stairs_why)', wait)
        self.assertLess(first, wait)
        self.assertLess(second, produce.index('new recipe.result_type(build_loc)'))
        self.assertIn('O.set_dir(stairs_down ? stairs_down[2] : user.dir)', produce)

if __name__ == '__main__':
    unittest.main()
