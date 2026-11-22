"""Pedal airship: lift limit, pace, and the wiring the native probe relies on.

Offline source checks only; rising, flying and sinking are covered natively by
tests/pedal_bicycle/ride.py --probe airship_probe.dm.
"""
import hashlib
import importlib.util
from pathlib import Path
import subprocess
import sys
import unittest
import zlib

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests/save_movement'))
sys.path.insert(0, str(ROOT / 'tests/pedal_bicycle'))
from source_adapter import extract, project
from test_bicycle import math_procs

SOURCE = (ROOT / 'code/game/objects/structures/pedal_airship.dm').read_text()
BICYCLE = (ROOT / 'code/game/objects/structures/bicycle.dm').read_text()
AIRCRAFT = (ROOT / 'code/modules/1713/machinery/modular_vehicles/aircraft/aircraft.dm').read_text()
COMBAT = (ROOT / 'code/game/objects/structures/pedal_airship_combat.dm').read_text()
BASE = '/obj/structure/vehicle/bicycle/airship'


class Lift(unittest.TestCase):
    def test_lifts_up_to_carrying_capacity_and_no_more(self):
        body = extract(SOURCE, '/proc/pedal_airship_can_lift').replace('PEDAL_AIRSHIP_LIFT_LIMIT', '1')
        can_lift = project('/proc/pedal_airship_can_lift(load_ratio)\n' + body, '/proc/pedal_airship_can_lift', 'load_ratio', {})
        self.assertIn('#define PEDAL_AIRSHIP_LIFT_LIMIT 1\n', SOURCE)
        ratio, _, _ = math_procs()
        self.assertTrue(can_lift(ratio(0, 1)))
        self.assertTrue(can_lift(ratio(59, 1)))
        self.assertFalse(can_lift(ratio(60, 1)))
        # A stronger rider lifts more.
        self.assertTrue(can_lift(ratio(60, 2)))

    def test_pace_is_slower_than_the_bicycle_and_scales_with_load(self):
        _, delay, _ = math_procs()
        self.assertIn('pedal_fastest = 3\n', SOURCE)
        self.assertIn('pedal_slowest = 12\n', SOURCE)
        self.assertEqual(delay(0, 3, 12), 3)
        self.assertEqual(delay(0.5, 3, 12), 4.5)
        self.assertEqual(delay(1, 3, 12), 6)
        self.assertIn('bicycle_step_delay(load_ratio, pedal_fastest, pedal_slowest)', BICYCLE)

    def test_rise_checks_run_again_after_the_wait(self):
        body = extract(SOURCE, BASE + '/proc/ascend')
        wait = body.index('do_after(H, PEDAL_AIRSHIP_RISE_TIME, src)')
        for check in ('pedal_airship_can_lift(', 'pedal_airship_open_air(sky)', 'rider_ready()', '/obj/roof'):
            self.assertIn(check, body[:wait], check)
            self.assertIn(check, body[wait:], check)
        self.assertLess(body.index('set_aloft(TRUE)'), body.index('float_to(sky)'))
        body = extract(SOURCE, BASE + '/proc/descend')
        wait = body.index('do_after(H, PEDAL_AIRSHIP_SINK_TIME, src)')
        self.assertIn('landing_block(G)', body[:wait])
        self.assertIn('landing_block(G)', body[wait:])


class Air(unittest.TestCase):
    def test_open_air_holds_only_an_airship_aloft_and_its_riders(self):
        holds = extract(AIRCRAFT, '/proc/aircraft_holds')
        self.assertIn('aloft_pedal_airships.len && pedal_airship_holds(T, A)', holds)
        self.assertLess(holds.index('pedal_airship_holds'), holds.index('!airborne_aircraft.len'))
        body = extract(SOURCE, '/proc/pedal_airship_holds')
        self.assertIn('S.aloft && (A == S || (A in S.ontop))', body)

    def test_flies_only_over_open_air_and_not_from_the_ground(self):
        check = extract(SOURCE, BASE + '/do_vehicle_check')
        self.assertIn('!aloft', check)
        self.assertIn('pedal_airship_open_air(T)', check)
        start = extract(SOURCE, BASE + '/startmovementloop')
        self.assertLess(start.index('if (!aloft)'), start.index('..()'))
        air = extract(SOURCE, '/proc/pedal_airship_open_air')
        self.assertIn('/turf/sky/building', air)
        self.assertIn('/obj/covers', air)
        self.assertIn('return list(FALSE, FALSE, 0)', extract(SOURCE, BASE + '/ground_ahead'))
        self.assertIn('return 0', extract(SOURCE, BASE + '/slope_delay'))

    def test_never_leaves_a_rider_in_the_air(self):
        for path in ('/unbuckle_mob', '/driver_died', '/safety_check'):
            self.assertIn('set_down()', extract(SOURCE, BASE + path), path)
        self.assertIn('PROC_REF(set_down)', extract(SOURCE, BASE + '/persistence_restore_finished'))
        self.assertIn('unbuckle_mob()', extract(BICYCLE, '/obj/structure/vehicle/bicycle/Destroy'))
        self.assertIn('if (aloft && (user in ontop))', extract(SOURCE, BASE + '/attack_hand'))
        down = extract(SOURCE, BASE + '/proc/set_down')
        self.assertNotIn('apply_damage', SOURCE)
        self.assertIn('stranded', down)
        self.assertNotIn('spawn(', SOURCE)

    def test_landing_needs_dry_clear_ground(self):
        block = extract(SOURCE, BASE + '/proc/landing_block')
        for check in ('aircraft_rough_ground()', '/turf/floor/broken_floor', 'O.density', 'L.density'):
            self.assertIn(check, block)

    def test_flight_visuals_are_never_saved(self):
        runtime = extract(SOURCE, BASE + '/persistence_runtime_var')
        for key in ('aloft', 'changing_height', 'shadow', 'shadow_turf'):
            self.assertIn('"' + key + '"', runtime)
            self.assertRegex(SOURCE, r'var/(tmp/)?[\w/]*\b' + key + r'\b')

    def test_rider_sees_the_ground_through_the_open_air_view(self):
        # The ground below is the open-air view's (open_air_view.dm); a second
        # view of ground turfs in vis_contents drew over it washed out and kept
        # resending those turfs to every client in sight.
        for path in (SOURCE, (ROOT / 'code/modules/1713/machinery/modular_vehicles/aircraft/aircraft_view.dm').read_text(),
                     (ROOT / 'code/modules/naval/air_hull.dm').read_text()):
            self.assertNotIn('ground_view', path)
            self.assertNotIn('aircraft_ground_view', path)


class ArtAndWiring(unittest.TestCase):
    def test_own_sprite_sheet_is_current_and_wired(self):
        # The hosted baseline has no imaging library: pin the committed sheet
        # by hash, and redraw it for comparison only where Pillow is installed.
        sheet = (ROOT / 'icons/obj/vehicles/pedal_airship.dmi').read_bytes()
        self.assertEqual(hashlib.sha256(sheet).hexdigest(), '553d735435d14e415cbc70c8ce0b64a631342ecaaee979893a75fef01b0bfc3d')
        description = zlib.decompressobj().decompress(sheet[sheet.index(b'zTXtDescription') + 17:])
        self.assertIn(b'width = 64', description)
        self.assertIn(b'state = "airship"\n\tdirs = 4', description)
        self.assertIn(b'state = "airship_overlay"\n\tdirs = 4', description)
        if importlib.util.find_spec('PIL'):
            from PIL import Image
            art = Image.open(ROOT / 'icons/obj/vehicles/pedal_airship.dmi').convert('RGBA')
            # Landed, the basket rests on the ground: the bottom pixel row is drawn in every view.
            for i in range(8):
                x, y = (i % 4) * 64, (i // 4) * 64
                self.assertTrue(any(art.getpixel((x + dx, y + 63))[3] for dx in range(64)), i)
            subprocess.run([sys.executable, str(ROOT / 'tests/pedal_bicycle/airship_sprites.py'), '--check'], check=True)
        self.assertIn("icon = 'icons/obj/vehicles/pedal_airship.dmi'", SOURCE)
        self.assertIn('overlay_state = "airship_overlay"', SOURCE)
        self.assertIn('pixel_x = -16', SOURCE)
        self.assertIn('rider_overlay = image(icon, overlay_state)', BICYCLE)

    def test_recipe_and_research_and_include(self):
        self.assertIn('RECIPE: /material/cloth/,pedal airship,/obj/structure/vehicle/bicycle/airship,30,300,1,1,vehicle parts,95,0,0,8,null',
                      (ROOT / 'config/crafting/material_recipes_global.txt').read_text())
        self.assertIn('"/obj/structure/vehicle/bicycle/airship" = "factories"',
                      (ROOT / 'code/modules/research_tree/research_node.dm').read_text())
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8-sig')
        self.assertIn('#include "code\\game\\objects\\structures\\pedal_airship.dm"', dme)

    def test_controls_are_the_airships_own(self):
        self.assertIn('control_type = /obj/item/vehicleparts/wheel/handle/bicycle/airship', SOURCE)
        self.assertIn('B.secondary_control(H)', BICYCLE)
        control = extract(SOURCE, BASE + '/secondary_control')
        self.assertLess(control.index('if (moving)'), control.index('descend(H)'))
        self.assertIn('ascend(H)', control)


class GroundFire(unittest.TestCase):
    def test_projectiles_crossing_the_shadow_can_strike_it(self):
        handle = extract((ROOT / 'code/modules/projectiles/projectile.dm').read_text(), '/obj/item/projectile/proc/handleTurf')
        self.assertIn('(airborne_aircraft.len || aloft_pedal_airships.len || air_hull_crafts.len) && T != starting', handle)
        self.assertLess(handle.index('airborne_overhead_hit(src, T)'), handle.index('height_enter(T)'))
        lob = extract((ROOT / 'code/modules/projectiles/projectile_lob.dm').read_text(), '/obj/item/projectile/proc/lob_enter')
        self.assertLess(lob.index('pedal_airship_overhead_fire(src, T)'), lob.index('lob_land(T)'))
        fire = extract(COMBAT, '/proc/pedal_airship_overhead_fire')
        for check in ('P.is_shrapnel', 'S.ground_turf() != T', '(P.firer in S.ontop)', 'prob(PEDAL_AIRSHIP_HIT_CHANCE)'):
            self.assertIn(check, fire)

    def test_holes_cost_lift_and_bring_it_down(self):
        self.assertIn('#define PEDAL_AIRSHIP_SINK_HOLES 4\n', COMBAT)
        self.assertIn('#define PEDAL_AIRSHIP_HOLE_LIFT 0.2\n', COMBAT)
        rise = extract(SOURCE, BASE + '/proc/ascend')
        wait = rise.index('do_after(H, PEDAL_AIRSHIP_RISE_TIME, src)')
        for part in (rise[:wait], rise[wait:]):
            self.assertIn('bag_too_holed()', part)
            self.assertIn('/ max(0.01, bag_lift())', part)
        self.assertIn('set_down()', extract(COMBAT, BASE + '/proc/hole_bag'))
        burn = extract(COMBAT, BASE + '/proc/ignite_bag')
        self.assertLess(burn.index('set_down()'), burn.index('adjustBruteLoss'))
        self.assertIn('IgniteMob()', burn)

    def test_cloth_patches_on_the_ground_only(self):
        patch = extract(COMBAT, BASE + '/proc/patch_bag')
        self.assertLess(patch.index('if (aloft)'), patch.index('do_after('))
        self.assertIn('C.use(1)', patch[patch.index('do_after('):])
        self.assertIn('patch_bag(W, user)', extract(SOURCE, BASE + '/attackby'))
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8-sig')
        self.assertLess(dme.index('pedal_airship.dm"'), dme.index('pedal_airship_combat.dm"'))


class Gondola(unittest.TestCase):
    def test_shots_and_throws_at_the_ground_start_under_the_gondola(self):
        launch = extract((ROOT / 'code/modules/projectiles/projectile.dm').read_text(), '/obj/item/projectile/proc/launch')
        self.assertLess(launch.index('airborne_launch_turf(user, targloc)'), launch.index('starting = curloc'))
        throw = extract((ROOT / 'code/game/mob/living/carbon/carbon.dm').read_text(), '/mob/living/human/throw_item')
        self.assertLess(throw.index('airborne_launch_turf(src, target)'), throw.index('item.throw_at('))
        plan = extract((ROOT / 'code/modules/projectiles/projectile_heights.dm').read_text(), '/obj/item/projectile/proc/height_plan')
        self.assertIn('pedal_airship_rider_shot(firer, start)', plan)
        turf = extract(COMBAT, '/proc/airborne_launch_turf')
        self.assertIn('T.z != G.z', turf)
        rider = extract(COMBAT, '/proc/aloft_airship_ridden_by')
        self.assertIn('!S.aloft || !(user in S.ontop)', rider)

    def test_dropped_bottles_burst(self):
        fall = extract((ROOT / 'code/game/objects/building_levels.dm').read_text(), '/turf/sky/building/Entered')
        self.assertLess(fall.index('falling_item_strike(A, below)'), fall.index('landed_from_fall(below)'))
        burst = extract(COMBAT, '/obj/item/weapon/reagent_containers/food/drinks/bottle/landed_from_fall')
        self.assertLess(burst.index('calculate_alcohol_power()'), burst.index('reagents.splash('))
        self.assertIn('shatter(T, against, power)', burst)


if __name__ == '__main__':
    unittest.main()
