"""Crewed airships (code/modules/naval/air_hull.dm): wiring the native probe relies on.

Offline source checks only; building, lifting, flying, turning, firing down,
save/restore, holed and burnt gas cells, the bomb hatch and the wreck run natively in tests/pedal_bicycle/ride.py --probe air_hull_probe.dm.
"""
import hashlib
import importlib.util
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests/save_movement'))
from source_adapter import extract

SOURCE = (ROOT / 'code/modules/naval/air_hull.dm').read_text()
BUILT = (ROOT / 'code/modules/craft/built_body.dm').read_text()
COMBAT = (ROOT / 'code/game/objects/structures/pedal_airship_combat.dm').read_text()
BODY = '/datum/craft_body/built/air'


class Deck(unittest.TestCase):
    def test_planks_start_at_a_ladder_top_and_grow_edge_to_edge(self):
        lay = extract(SOURCE, '/proc/air_deck_lay_refusal')
        self.assertIn('/obj/structure/multiz', lay)
        self.assertIn('/obj/covers/airship_deck', lay)
        self.assertIn('for (var/d in cardinal)', lay)
        self.assertIn('C && !C.anchored', lay)
        survey = extract(SOURCE, '/proc/air_hull_survey')
        self.assertIn('found.len > AIR_HULL_MAX_TILES', survey)
        self.assertIn('#define AIR_HULL_MAX_TILES 60\n', SOURCE)

    def test_floors_move_before_what_stands_on_them(self):
        move = extract(BUILT, '/datum/craft_body/built/move_to')
        self.assertIn('riders.Insert(1, M)', move)
        self.assertLess(move.index('if (istype(M, /obj/covers))\n\t\t\t\t\triders.Insert(1, M)'), move.index('craft_step_move(M, D'))


class Flight(unittest.TestCase):
    def test_only_open_air_and_enough_lift(self):
        refusal = extract(SOURCE, BODY + '/tile_refusal')
        self.assertIn('air_deck_open(D)', refusal)
        plan = extract(SOURCE, BODY + '/plan')
        self.assertLess(plan.index('lift_refusal()'), plan.index('..()'))
        self.assertIn('#define AIR_HULL_CELL_LIFT 12\n', SOURCE)
        self.assertIn('return 0', extract(SOURCE, BODY + '/upper_z'))

    def test_engines_only_and_no_pixel_creep(self):
        self.assertIn('return FALSE', extract(SOURCE, '/datum/craft/air/offset_sails'))
        drives = extract(SOURCE, '/datum/craft/air/fit_drives')
        self.assertIn('/datum/craft_drive/fitted/engine', drives)

    def test_views_follow_her_and_are_never_saved(self):
        self.assertIn('update_views()', extract(SOURCE, '/datum/craft/air/on_hop'))
        self.assertIn('update_views()', extract(SOURCE, '/datum/craft/air/on_turn'))
        self.assertIn('key == "craft"', extract(SOURCE, '/obj/structure/airship_helm/persistence_runtime_var'))
        load = extract(SOURCE, '/obj/structure/airship_helm/after_load')
        self.assertIn('craft.anchored = TRUE', load)

    def test_deck_crew_fire_down(self):
        under = extract(COMBAT, '/proc/airborne_ground_under')
        self.assertIn('air_hull_under(user)', under)
        for path in ('code/modules/projectiles/projectile.dm', 'code/game/mob/living/carbon/carbon.dm'):
            self.assertIn('(aloft_pedal_airships.len || air_hull_crafts.len)', (ROOT / path).read_text(), path)


class Damage(unittest.TestCase):
    def test_ground_fire_reaches_her_cells(self):
        hook = extract(COMBAT, '/proc/airborne_overhead_hit')
        self.assertIn('air_hull_overhead_fire(P, T)', hook)
        fire = extract(SOURCE, '/proc/air_hull_overhead_fire')
        self.assertIn('P.is_shrapnel', fire)
        self.assertIn('B.contains(get_turf(P.firer))', fire)
        self.assertIn('prob(AIR_HULL_HIT_CHANCE / (2 ** (levels - 1)))', fire)
        self.assertIn('air_hull_levels_between(T, D)', fire)
        projectile = (ROOT / 'code/modules/projectiles/projectile.dm').read_text()
        self.assertIn('(airborne_aircraft.len || aloft_pedal_airships.len || air_hull_crafts.len) && T != starting', projectile)
        self.assertIn('air_hull_crafts', (ROOT / 'code/modules/projectiles/projectile_lob.dm').read_text())

    def test_holes_cut_lift_fire_burns_it_out(self):
        self.assertIn('burnt ? 0 : max(0, AIR_HULL_CELL_LIFT - holes * AIR_HULL_HOLE_LIFT)',
                      extract(SOURCE, '/obj/structure/airship_gas_cell/proc/lift'))
        struck = extract(SOURCE, '/datum/craft/air/proc/struck_by')
        self.assertIn('projectile_ignites_gas(P)', struck)
        self.assertLess(struck.index('G.hole(P)'), struck.index('check_lift()'))
        patch = extract(SOURCE, '/obj/structure/airship_gas_cell/attackby')
        self.assertIn('/obj/item/stack/material/cloth', patch)
        self.assertIn('holes--', patch)

    def test_short_of_lift_she_stops_and_half_short_she_falls(self):
        check = extract(SOURCE, '/datum/craft/air/proc/check_lift')
        self.assertLess(check.index('have * 2 < need'), check.index('crash()'))
        self.assertIn('set_anchor(TRUE)', check)
        crash = extract(SOURCE, '/datum/craft/air/proc/crash')
        self.assertIn('L.adjustBruteLoss(', crash)
        self.assertIn('falling_item_strike(M, G)', crash)
        # The helm goes last, since destroying it ends the craft.
        self.assertLess(crash.index('qdel(M)'), crash.index('qdel(helm)'))

    def test_bomb_hatch_drops_onto_the_ground_below(self):
        drop = extract(SOURCE, '/obj/structure/airship_bomb_hatch/attack_hand')
        self.assertLess(drop.index('B.forceMove(G)'), drop.index('B.detonate()'))
        self.assertIn('air_hull_solid_below(T)', extract(SOURCE, '/obj/structure/airship_bomb_hatch/proc/drop_turf'))
        self.assertIn('#define AIR_HULL_HATCH_BOMBS 2\n', SOURCE)


class HighFlight(unittest.TestCase):
    def test_open_air_is_seen_dropped_and_shot_through(self):
        open_air = extract(SOURCE, '/proc/air_hull_open_air')
        for blocker in ('/obj/covers', '/obj/roof', '/obj/structure/multiz'):
            self.assertIn(blocker, open_air)
        solid = extract(SOURCE, '/proc/air_hull_solid_below')
        self.assertIn('if (!air_hull_open_air(at))', solid)
        between = extract(SOURCE, '/proc/air_hull_levels_between')
        self.assertLess(between.index('return steps'), between.index('if (!air_hull_open_air(at))'))

    def test_views_and_wreck_reach_the_first_solid_level(self):
        views = extract(SOURCE, '/datum/craft/air/proc/update_views')
        self.assertIn('air_hull_solid_below(locate(min_x, min_y, B.z))', views)
        self.assertIn('var/turf/G = air_hull_solid_below(air)', views)
        crash = extract(SOURCE, '/datum/craft/air/proc/crash')
        self.assertIn('var/turf/G = air_hull_solid_below(D)', crash)
        self.assertIn('15 * (levels - 1)', crash)

    def test_deck_shots_aim_through_open_air(self):
        under = extract(COMBAT, '/proc/airborne_ground_under')
        self.assertIn('air_hull_solid_below(get_turf(user))', under)
        aim = extract(COMBAT, '/proc/airborne_aim_turf')
        self.assertIn('air_hull_open_air(T)', aim)
        projectile = (ROOT / 'code/modules/projectiles/projectile.dm').read_text()
        self.assertLess(projectile.index('airborne_aim_turf(user, targloc)'), projectile.index('airborne_launch_turf(user, targloc)'))
        carbon = (ROOT / 'code/game/mob/living/carbon/carbon.dm').read_text()
        self.assertLess(carbon.index('airborne_aim_turf(src, target)'), carbon.index('airborne_launch_turf(src, target)'))


class Wiring(unittest.TestCase):
    def test_recipes_research_and_include(self):
        recipes = (ROOT / 'config/crafting/material_recipes_global.txt').read_text()
        for line in ('RECIPE: /material/wood/,airship planks,/obj/item/airship_planks,3,40,0,1,vehicle parts,126,0,0,8,null',
                     'RECIPE: /material/cloth/,airship gas cell,/obj/item/airship_gas_cell,20,200,0,1,vehicle parts,126,0,0,8,null',
                     'RECIPE: /material/wood/,airship helm,/obj/item/airship_helm_kit,10,150,0,1,vehicle parts,126,0,0,8,null',
                     'RECIPE: /material/steel/,airship bomb hatch,/obj/structure/airship_bomb_hatch,6,100,1,1,vehicle parts,126,0,0,8,null'):
            self.assertIn(line, recipes)
        research = (ROOT / 'code/modules/research_tree/research_node.dm').read_text()
        for path in ('airship_planks', 'airship_gas_cell', 'airship_helm_kit'):
            self.assertIn('"/obj/item/' + path + '" = "powered_flight"', research)
        self.assertIn('"/obj/structure/airship_bomb_hatch" = "powered_flight"', research)
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8-sig')
        self.assertLess(dme.index('naval\\built_hull.dm"'), dme.index('naval\\air_hull.dm"'))

    def test_sprites_are_current(self):
        hashes = {'icons/obj/vehicles/airship_hull.dmi': HULL_SHA, 'icons/obj/vehicles/airship_gas_cell.dmi': CELL_SHA}
        for path, digest in hashes.items():
            self.assertEqual(hashlib.sha256((ROOT / path).read_bytes()).hexdigest(), digest, path)
        if importlib.util.find_spec('PIL'):
            subprocess.run([sys.executable, str(ROOT / 'tests/airship_hull/airship_hull_sprites.py'), '--check'], check=True)


HULL_SHA = '05536a6122859b869f775d8f1d4037bee9ea5aef181258ca8f9de47342dac134'
CELL_SHA = 'b4c94b9e3cc32b146c4fa9bd4eb9ddc3200948336dd8aa8a38ba8acb494c0df5'

if __name__ == '__main__':
    unittest.main()
