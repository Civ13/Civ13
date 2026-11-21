"""Crewed airships (code/modules/naval/air_hull.dm): wiring the native probe relies on.

Offline source checks only; building in the air and on the ground, lifting
off, landing, sinking onto trees, flying, turning, firing down,
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
GAS = (ROOT / 'code/modules/naval/gas_works.dm').read_text()
BODY = '/datum/craft_body/built/air'


def type_block(path):
    start = SOURCE.index('\n' + path + '\n') + 1
    return SOURCE[start:SOURCE.index('\n\n', start)]


class Deck(unittest.TestCase):
    def test_planks_start_at_a_ladder_top_and_grow_edge_to_edge(self):
        lay = extract(SOURCE, '/proc/air_deck_lay_refusal')
        self.assertIn('/obj/structure/multiz', lay)
        self.assertIn('/obj/covers/airship_deck', lay)
        self.assertIn('for (var/d in cardinal)', lay)
        self.assertIn('C && !C.anchored', lay)
        survey = extract(SOURCE, '/proc/air_hull_survey')
        self.assertIn('found.len > AIR_HULL_MAX_TILES', survey)
        self.assertIn('#define AIR_HULL_MAX_TILES AIR_DRAUGHT_MAX_DECK\n', SOURCE)
        self.assertIn('#define AIR_DRAUGHT_MAX_DECK 60', (ROOT / 'code/__defines/naval.dm').read_text(encoding='utf-8'))

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
        self.assertIn('max(0, round(full - holes * hole_lift, 0.1))',
                      extract(SOURCE, '/obj/structure/airship_gas_cell/proc/lift'))
        struck = extract(SOURCE, '/datum/craft/air/proc/struck_by')
        self.assertIn('projectile_ignites_gas(P)', struck)
        self.assertLess(struck.index('G.hole(P)'), struck.index('check_lift()'))
        patch = extract(SOURCE, '/obj/structure/airship_gas_cell/attackby')
        self.assertIn('is_type_in_list(W, patches)', patch)
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


class Ground(unittest.TestCase):
    def test_decks_are_laid_on_clear_ground_or_beside_a_ladder_top(self):
        lay = extract(SOURCE, '/proc/air_deck_lay_refusal')
        self.assertIn('var/aloft = istype(T, /turf/sky)', lay)
        self.assertIn('air_ground_open(T)', lay)
        self.assertIn('aloft && (locate(/obj/structure/multiz) in N)', lay)
        ground = extract(SOURCE, '/proc/air_ground_open')
        for blocker in ('/obj/covers', '/obj/roof', '/obj/structure/multiz', 'aircraft_rough_ground()'):
            self.assertIn(blocker, ground)
        refusal = extract(SOURCE, BODY + '/tile_refusal')
        self.assertLess(refusal.index('air_ground_open(D)'), refusal.index('air_deck_open(D)'))

    def test_lift_off_needs_lift_and_open_sky_and_landing_clear_ground(self):
        lift = extract(SOURCE, '/datum/craft/air/proc/lift_off_refusal')
        self.assertIn('B.lift_refusal()', lift)
        self.assertIn('air_deck_open(U)', lift)
        self.assertIn('/obj/roof', lift)
        land = extract(SOURCE, '/datum/craft/air/proc/land_refusal')
        self.assertLess(land.index('air_hull_tree(G)'), land.index('air_ground_open(G)'))
        self.assertIn('G.z != ground', land)
        descend = extract(SOURCE, '/datum/craft/air/proc/descend_to_ground')
        self.assertLess(descend.index('land_refusal()'), descend.index('B.shift_level('))
        self.assertIn('#define AIR_HULL_LEVEL_TIME 30\n', SOURCE)

    def test_short_of_lift_she_sinks_flattens_a_few_trees_and_snags_in_many(self):
        check = extract(SOURCE, '/datum/craft/air/proc/check_lift')
        self.assertIn('B.landed()', check)
        self.assertLess(check.index('set_anchor(TRUE)'), check.index('sink()'))
        step = extract(SOURCE, '/datum/craft/air/proc/sink_step')
        self.assertIn('snaggers * AIR_HULL_TREE_SHARE > deck.len', step)
        self.assertLess(step.index('tear_on_tree(trees[W], W, FALSE)'), step.index('tear_on_tree(trees[W], W, TRUE)'))
        self.assertIn('#define AIR_HULL_TREE_SHARE 4\n', SOURCE)
        tear = extract(SOURCE, '/datum/craft/air/proc/tear_on_tree')
        self.assertIn('G.holes++', tear)
        self.assertIn('W.try_destroy()', tear)

    def test_falling_onto_a_tree_lands_beside_the_trunk(self):
        crash = extract(SOURCE, '/datum/craft/air/proc/crash')
        self.assertLess(crash.index('G = air_hull_beside(G)'), crash.index('L.adjustBruteLoss('))
        self.assertIn('max(5, rand(15, 35) + 15 * (levels - 1) - cushion)', crash)
        pedal = (ROOT / 'code/game/objects/structures/pedal_airship.dm').read_text()
        set_down = extract(pedal, '/obj/structure/vehicle/bicycle/airship/proc/set_down')
        self.assertLess(set_down.index('snag_in_tree(G, tree)'), set_down.index('set_aloft(FALSE)'))
        self.assertIn('pedal_airship_tree_gone(T)', extract(COMBAT, '/obj/structure/wild/Destroy'))


class Materials(unittest.TestCase):
    def test_deck_frames_weigh_burn_and_snag_by_material(self):
        load = extract(SOURCE, BODY + '/proc/load')
        self.assertIn('. += K.air_weight', load)
        for path, weight in (('/obj/covers/airship_deck/aluminium', 'air_weight = 0.5'), ('/obj/covers/airship_deck/steel', 'air_weight = 2')):
            block = type_block(path)
            self.assertIn(weight, block)
            self.assertIn('wood = FALSE', block)
            self.assertIn('flammable = FALSE', block)
        self.assertIn('snag_proof = TRUE', type_block('/obj/covers/airship_deck/steel'))
        step = extract(SOURCE, '/datum/craft/air/proc/sink_step')
        self.assertIn('snaggers * AIR_HULL_TREE_SHARE > deck.len', step)
        self.assertIn('new deck_type(T)', extract(SOURCE, '/obj/item/airship_planks/resolve_attackby'))
        fire = extract(SOURCE, '/proc/air_deck_catch_fire')
        self.assertIn('!D.wood', fire)
        self.assertIn('air_deck_catch_fire(get_turf(src))', extract(SOURCE, '/obj/structure/airship_gas_cell/proc/ignite'))

    def test_cells_lift_and_tear_by_material(self):
        rubber = type_block('/obj/structure/airship_gas_cell/rubber')
        self.assertIn('hole_lift = 2', rubber)
        self.assertIn('/obj/item/stack/material/plastic', rubber)
        skin = type_block('/obj/structure/airship_gas_cell/skin')
        self.assertIn('max_lift = 15', skin)
        self.assertIn('hole_lift = 5', skin)
        convert = extract(SOURCE, '/obj/item/airship_gas_cell/attackby')
        self.assertIn('S.use(AIR_HULL_RUBBER_SHEETS)', convert)
        self.assertIn('/obj/item/stack/sausagecasing', convert)
        self.assertIn('#define AIR_HULL_SKIN_LAYERS 6\n', SOURCE)
        self.assertIn('new folded_type(T)', extract(SOURCE, '/obj/structure/airship_gas_cell/attackby'))


class Gas(unittest.TestCase):
    def test_cells_hang_empty_and_lift_by_their_gas(self):
        hang = extract(SOURCE, '/obj/item/airship_gas_cell/resolve_attackby')
        self.assertLess(hang.index('G.gas = null'), hang.index('G.update_icon()'))
        lift = extract(SOURCE, '/obj/structure/airship_gas_cell/proc/lift')
        self.assertIn('gas_amount / AIR_HULL_CELL_GAS', lift)
        self.assertIn('gas == "helium" ? 0.9 : 1', lift)
        self.assertIn('G.flammable_gas()', extract(SOURCE, '/datum/craft/air/proc/struck_by'))
        self.assertIn('gas == "hydrogen"', extract(SOURCE, '/obj/structure/airship_gas_cell/proc/flammable_gas'))
        fill = extract(GAS, '/obj/structure/airship_gas_cell/attackby')
        self.assertIn('(id in lifting_gases)', fill)
        self.assertIn('H.reaches(src)', fill)
        self.assertIn('return ..()', fill)

    def test_works_make_gas_and_pipes_carry_it(self):
        self.assertIn('make("hydrogen", 3)', extract(GAS, '/obj/structure/gas_works/hydrogen_generator/work'))
        split = extract(GAS, '/obj/structure/gas_works/electrolysis_tank/work')
        self.assertLess(split.index('powered_now()'), split.index('make("oxygen", 1)'))
        self.assertIn('make("hydrogen", 2)', split)
        self.assertIn('station_has_water(1)', extract(GAS, '/obj/structure/gas_works/water_gas_retort/work'))
        helium = extract(GAS, '/obj/structure/gas_works/helium_separator/work')
        self.assertLess(helium.index('well()'), helium.index('make("helium", 1)'))
        self.assertIn('W.has_source()', extract(GAS, '/obj/structure/gas_works/helium_separator/proc/well'))
        self.assertIn('FLUID_TIER_SOURCE', extract(GAS, '/obj/structure/gas_works/fluid_supply_tier'))
        self.assertIn('FLUID_TIER_BUFFER', extract(GAS, '/obj/structure/gas_holder/fluid_demand_tier'))
        self.assertIn('FLUID_TIER_SINK', extract(GAS, '/obj/structure/gas_compressor/fluid_demand_tier'))
        pipes = (ROOT / 'code/modules/1713/factory_pipes.dm').read_text()
        self.assertIn('gas_works_step()\n\tgas_compressors_step()', extract(pipes, '/proc/factory_fluids_step'))

    def test_only_a_compressor_fills_a_cylinder_and_oxygen_eases_breath(self):
        self.assertIn('V.pressurised', extract(GAS, '/obj/structure/gas_works/attackby'))
        self.assertIn('V.pressurised', extract(GAS, '/obj/structure/gas_holder/attackby'))
        self.assertIn('M.adjustOxyLoss(-25)', extract(GAS, '/obj/item/weapon/reagent_containers/gas_vessel/attack'))
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8-sig')
        self.assertLess(dme.index('naval\\air_hull.dm"'), dme.index('naval\\gas_works.dm"'))

    def test_gas_sprites_are_current(self):
        for path, digest in {'icons/obj/gas_works.dmi': WORKS_SHA, 'icons/obj/gas_holder.dmi': HOLDER_SHA}.items():
            self.assertEqual(hashlib.sha256((ROOT / path).read_bytes()).hexdigest(), digest, path)
        if importlib.util.find_spec('PIL'):
            subprocess.run([sys.executable, str(ROOT / 'tests/gas_works/gas_works_sprites.py'), '--check'], check=True)


class Wiring(unittest.TestCase):
    def test_recipes_research_and_include(self):
        recipes = (ROOT / 'config/crafting/material_recipes_global.txt').read_text()
        for line in ('RECIPE: /material/wood/,airship planks,/obj/item/airship_planks,3,40,0,1,vehicle parts,126,0,0,8,null',
                     'RECIPE: /material/cloth/,airship gas cell,/obj/item/airship_gas_cell,20,200,0,1,vehicle parts,126,0,0,8,null',
                     'RECIPE: /material/wood/,airship helm,/obj/item/airship_helm_kit,10,150,0,1,vehicle parts,126,0,0,8,null',
                     'RECIPE: /material/aluminium/,aluminium airship frame,/obj/item/airship_planks/aluminium,3,60,0,1,vehicle parts,126,0,0,8,null',
                     'RECIPE: /material/steel/,steel airship frame,/obj/item/airship_planks/steel,3,60,0,1,vehicle parts,126,0,0,8,null',
                     'RECIPE: /material/steel/,airship bomb hatch,/obj/structure/airship_bomb_hatch,6,100,1,1,vehicle parts,126,0,0,8,null'):
            self.assertIn(line, recipes)
        research = (ROOT / 'code/modules/research_tree/research_node.dm').read_text()
        for path in ('airship_planks', 'airship_gas_cell', 'airship_helm_kit', 'weapon/reagent_containers/gas_vessel'):
            self.assertIn('"/obj/item/' + path + '" = "lighter_than_air_flight"', research)
        for path in ('/obj/item/airship_planks/aluminium', '/obj/item/airship_planks/steel',
                     '/obj/structure/airship_bomb_hatch', '/obj/structure/car_workshop/hangar',
                     '/obj/item/weapon/aircraft_bomb', '/obj/item/gas_hose',
                     '/obj/structure/gas_works/hydrogen_generator', '/obj/structure/gas_works/helium_separator'):
            self.assertIn(f'"{path}" = "powered_flight"', research)
            self.assertNotIn(f'"{path}" = "lighter_than_air_flight"', research)
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8-sig')
        self.assertLess(dme.index('naval\\built_hull.dm"'), dme.index('naval\\air_hull.dm"'))

    def test_wooden_airship_and_hydrogen_route_do_not_need_the_1943_capstone(self):
        research = (ROOT / 'code/modules/research_tree/research_node.dm').read_text()
        self.assertIn('"lighter_than_air_flight", "Lighter-than-Air Flight", "Industrial", 235, 4, '
                      'RESEARCH_MODE_ANALYSIS, list("wagons_ships","utilities"), 5)', research)
        self.assertIn('"powered_flight", "Powered Flight", "Industrial", 270, 5, '
                      'RESEARCH_MODE_PROTOTYPE, list("combustion"), 6,', research)
        self.assertIn('"/obj/structure/gas_works/water_gas_retort" = "utilities"', research)
        self.assertIn('RECIPE: /material/leather/,gasbag,/obj/item/weapon/reagent_containers/gas_vessel,',
                      (ROOT / 'config/crafting/material_recipes_global.txt').read_text())
        self.assertIn('make("hydrogen", 2)', extract(GAS, '/obj/structure/gas_works/water_gas_retort/work'))
        self.assertIn('gas_fill_vessel(user, V, reagents, src)', extract(GAS, '/obj/structure/gas_works/attackby'))
        self.assertIn('from = W.reagents', extract(GAS, '/obj/structure/airship_gas_cell/attackby'))

    def test_powered_flight_retains_craft_access_without_a_reverse_grant(self):
        base = ROOT / 'code/modules/research_tree'
        personal = extract((base / 'character_knowledge.dm').read_text(), '/mob/living/human/proc/knows_recipe_node')
        faction = extract((base / 'research_faction.dm').read_text(), '/obj/map_metadata/proc/is_node_done')
        self.assertIn('stat != DEAD', personal)
        self.assertIn('node_id == "lighter_than_air_flight" && ("powered_flight" in known_recipe_nodes)', personal)
        self.assertIn('node_id == "lighter_than_air_flight" && is_node_done(faction, "powered_flight")', faction)
        for source in (personal, faction):
            self.assertNotIn('node_id == "powered_flight"', source)

    def test_sprites_are_current(self):
        hashes = {'icons/obj/vehicles/airship_hull.dmi': HULL_SHA, 'icons/obj/vehicles/airship_gas_cell.dmi': CELL_SHA}
        for path, digest in hashes.items():
            self.assertEqual(hashlib.sha256((ROOT / path).read_bytes()).hexdigest(), digest, path)
        if importlib.util.find_spec('PIL'):
            subprocess.run([sys.executable, str(ROOT / 'tests/airship_hull/airship_hull_sprites.py'), '--check'], check=True)


HULL_SHA = 'ed7edae72e27c45242096ac66b84cdff2c93a782108946bc64e6d355d45561e9'
CELL_SHA = '5a4c45b76e58bb7c0369edd7d2abeb92f2b8053b2e2b2820da863fb260dd48cd'
WORKS_SHA = 'c7f25e50bae3088b453d5c519161c996cc2a0376ab6422634142da753b0a0ca1'
HOLDER_SHA = 'be79e56eeac19f57206496a6e39c58107ae956cf4b43588ee13c3e44b4e54b5f'

if __name__ == '__main__':
    unittest.main()
