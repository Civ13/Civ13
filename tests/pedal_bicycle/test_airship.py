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
        for key in ('aloft', 'changing_height', 'shadow', 'shadow_turf', 'ground_view', 'ground_view_far', 'ground_view_anchor'):
            self.assertIn('"' + key + '"', runtime)
            self.assertRegex(SOURCE, r'var/(tmp/)?[\w/]*\b' + key + r'\b')


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


if __name__ == '__main__':
    unittest.main()
