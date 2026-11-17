"""Source contracts for walkable platform cars. Never launches BYOND."""
from pathlib import Path
import re
import struct
import sys
import zlib
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import run  # noqa: E402

SOURCE = (ROOT / 'code/modules/1713/train_platforms.dm').read_text(encoding='utf-8')
WARFARE = (ROOT / 'code/modules/1713/train_warfare.dm').read_text(encoding='utf-8')
LOCOS = (ROOT / 'code/modules/1713/train_locomotives.dm').read_text(encoding='utf-8')
WAREHOUSE = (ROOT / 'code/modules/1713/rail_warehouse.dm').read_text(encoding='utf-8')
TRAINS = (ROOT / 'code/modules/1713/trains.dm').read_text(encoding='utf-8')
RECIPES = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
NODES = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
PLATFORMS = (ROOT / 'code/modules/1713/train_platforms.dm').read_text(encoding='utf-8')
KITS = ['/obj/structure/train_car_kit', '/obj/structure/train_car_kit/coach', '/obj/structure/train_car_kit/sleeper',
        '/obj/structure/train_car_kit/dining', '/obj/structure/train_car_kit/storage',
        '/obj/structure/train_car_kit/railgun', '/obj/structure/train_car_kit/armored',
        '/obj/structure/train_car_kit/flak', '/obj/structure/train_car_kit/long_flatbed',
        '/obj/structure/train_car_kit/open_wagon', '/obj/structure/train_car_kit/boxcar',
        '/obj/structure/train_car_kit/bogie_coach', '/obj/structure/train_car_kit/brake_van']


def dmi_description(path):
    """The DMI metadata from a PNG's zTXt/tEXt chunk, without image libraries."""
    data = path.read_bytes()
    pos = 8
    while pos < len(data):
        length = struct.unpack('>I', data[pos:pos + 4])[0]
        kind = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if kind in (b'zTXt', b'tEXt') and body.startswith(b'Description\0'):
            rest = body[len(b'Description\0'):]
            return (zlib.decompress(rest[1:]) if kind == b'zTXt' else rest).decode('utf-8')
    return ''


class TrainPlatformSourceTests(unittest.TestCase):
    def test_included_once(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertEqual(dme.count('#include "code\\modules\\1713\\train_platforms.dm"'), 1)
        self.assertEqual(dme.count('#include "code\\modules\\1713\\train_warfare.dm"'), 1)
        self.assertEqual(dme.count('#include "code\\modules\\1713\\rail_warehouse.dm"'), 1)

    def test_parts_are_rebuilt_not_saved(self):
        part = SOURCE[SOURCE.index('\n/obj/structure/train_part\n'):]
        self.assertIn('should_save = FALSE', part[:part.index('\n/obj/structure/train_part/')])
        self.assertIn('var/tmp/list/deck_parts', SOURCE)
        self.assertRegex(SOURCE, r'/obj/structure/trains/platform/after_load\(\)\n\t\.\.\(\)\n\tapply_layout\(\)')

    def test_locomotive_checks_clearance_before_moving(self):
        body = TRAINS[TRAINS.index('/obj/structure/trains/proc/process_rail_movement('):]
        self.assertLess(body.index('train_consist_obstacle(src, tgtt, fdir)'), body.index('if (!src.Move(tgtt, fdir))'))

    def test_every_kit_is_craftable_and_researched(self):
        for kit in KITS:
            self.assertRegex(RECIPES, r'(?m)^RECIPE: /material/(iron|steel)/,[a-z ]+ kit,%s,' % re.escape(kit))
            self.assertRegex(NODES, r'"%s" = "(rail_steam|assembly_line|field_artillery|automatic_weapons)"' % re.escape(kit))
        for kit, node in (('loco_steam', 'rail_steam'), ('loco_diesel', 'combustion'), ('loco_armored', 'field_artillery')):
            path = '/obj/structure/train_car_kit/' + kit
            self.assertRegex(RECIPES, r'(?m)^RECIPE: /material/steel/,heavy [a-z]+ locomotive kit,%s,' % re.escape(path))
            self.assertIn('"%s" = "%s"' % (path, node), NODES)
            self.assertRegex(LOCOS, r'/obj/structure/train_car_kit/%s\n\tname = "heavy [a-z]+ locomotive kit"\n\tcar_kind = "%s"' % (kit, kit))

    def test_couplings_are_parts_at_each_car_end(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertEqual(dme.count('#include "code\\modules\\1713\\train_couplings.dm"'), 1)
        couplings = (ROOT / 'code/modules/1713/train_couplings.dm').read_text(encoding='utf-8')
        # Saved per car end, shown through vis_contents and never saved themselves.
        self.assertIn('\tvar/front_coupling = TRAIN_COUPLING_HEALTH\n\tvar/rear_coupling = TRAIN_COUPLING_HEALTH\n', couplings)
        self.assertIn('/obj/effect/train_coupler\n', couplings)
        self.assertIn('\tshould_save = FALSE\n\tvis_flags = VIS_INHERIT_DIR\n', couplings)
        # A link needs both couplings whole, and explosions strain them.
        self.assertIn('if (coupling_at(coupling_end_ahead(ahead)) <= 0)', TRAINS)
        self.assertIn('/obj/structure/trains/platform/ex_act(severity)\n\tblast_couplings(severity)\n', WARFARE)
        self.assertIn('RECIPE: /material/iron/,train coupling,/obj/item/train_coupling,4,80,0,0,trains,101,', RECIPES)

    def test_steam_engines_have_a_boiler(self):
        # Built filled and in steam, so saved engines and fixtures keep running.
        self.assertIn('\tvar/water = 240 // in the tank\n\tvar/max_water = 240\n', TRAINS)
        self.assertIn('\tvar/pressure = 100 // percent of working pressure\n', TRAINS)
        self.assertIn('\tvar/injector = TRUE', TRAINS)
        # Pressure limits speed and a helper's pull; neglect drops the plug, nothing explodes.
        self.assertIn('* min(1, pull_ratio()) * steam_factor() * throttle / LOCO_NOTCHES', TRAINS)
        self.assertIn('consist_power += L.haul * L.wear_factor() * ((L == src) ? 1 : L.steam_factor())', TRAINS)
        self.assertIn('/obj/structure/trains/locomotive/coal/proc/drop_plug()', TRAINS)
        self.assertNotIn('explosion(', TRAINS)
        self.assertIn('RECIPE: /material/lead/,fusible plug,/obj/item/fusible_plug,1,60,0,0,trains,101,', RECIPES)

    def test_tenders_are_shovelled_and_water_comes_from_towers(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertEqual(dme.count('#include "code\\modules\\1713\\train_water.dm"'), 1)
        water = (ROOT / 'code/modules/1713/train_water.dm').read_text(encoding='utf-8')
        # The firebox is fed by hand: the automatic tender feed is gone.
        self.assertNotIn('feed_from', TRAINS)
        self.assertIn('/obj/structure/trains/locomotive/coal/proc/shovel_coal(mob/user)', water)
        self.assertIn('\tif (is_tool(W, TOOL_SHOVEL))\n\t\tboiler_tick()\n\t\tshovel_coal(user)\n', TRAINS)
        # The walkable tender is a one-piece body without an engine.
        self.assertIn('\tlayouts["tender"] = list(', LOCOS)
        self.assertIn('/obj/structure/train_car_kit/tender\n\tname = "tender kit"\n\tcar_kind = "tender"\n', LOCOS)
        for line in ('RECIPE: /material/iron/,tender kit,/obj/structure/train_car_kit/tender,24,400,1,1,trains,101,',
                     'RECIPE: /material/iron/,water crane,/obj/structure/rail_water,8,200,1,1,trains,101,',
                     'RECIPE: /material/wood/,water tower,/obj/structure/rail_water/tower,30,300,1,1,trains,101,'):
            self.assertIn(line, RECIPES)

    def test_heavy_locomotives_drive_like_the_one_tile_engines(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertEqual(dme.count('#include "code\\modules\\1713\\train_locomotives.dm"'), 1)
        # The engine section is a locomotive, so throttle, load and reversing are shared code.
        for path in ('locomotive/coal/heavy', 'locomotive/heavy_diesel', 'locomotive/coal/armored/heavy'):
            self.assertIn('/obj/structure/trains/%s\n\tname = "heavy ' % path, LOCOS)
        self.assertNotIn('proc/drive(', LOCOS)
        # Only the main-line engine has a speed of its own.
        self.assertEqual(LOCOS.count('max_train_speed'), 1)
        self.assertIn('\ttrain_speed = 1.4\n\tmax_train_speed = 1.4\n', LOCOS)
        # Body tiles are rebuilt, never saved, and the clearance check covers the engine's side tiles.
        self.assertIn('var/tmp/list/body_parts', LOCOS)
        self.assertRegex(LOCOS, r'/obj/structure/trains/locomotive/after_load\(\)\n\t\.\.\(\)\n\tif \(body_kind\)\n\t\tbuild_body\(\)')
        self.assertEqual(SOURCE.count('if (car.wide_body())'), 3)
        self.assertRegex(RECIPES, r'(?m)^RECIPE: /material/steel/,armored locomotive,/obj/structure/trains/locomotive/coal/armored,')

    def test_steam_cabs_have_three_stations_and_the_main_line_engine_a_tender(self):
        # Driver's stand, firebox door and fireman's side: one to each cab tile.
        self.assertIn('\treturn i ? list("fireman", "fire", "driver")[i] : null\n', LOCOS)
        for kind in ('steam', 'armored', 'mainline'):
            layout = LOCOS[LOCOS.index('layouts["loco_%s"]' % kind):]
            self.assertIn('"stations" = TRUE', layout[:layout.index('"segments"')])
        diesel = LOCOS[LOCOS.index('layouts["loco_diesel"]'):]
        self.assertNotIn('"stations"', diesel[:diesel.index('"segments"')])
        # The menu and each control are checked against where the user stands.
        self.assertIn('\tvar/list/choices = station_controls(station)\n', TRAINS)
        self.assertIn('\tif (!(choice in station_controls(cab_station(user))))\n\t\treturn\n', TRAINS)
        self.assertIn('\tif ((is_tool(W, TOOL_SHOVEL) || fuel_value(W)) && !at_firebox(user))\n', TRAINS)
        # Six sections with the cab last; coal and water ride in the tender.
        mainline = LOCOS[LOCOS.index('layouts["loco_mainline"]'):LOCOS.index('layouts["tender"]')]
        self.assertIn('"cab" = 6', mainline)
        self.assertEqual(mainline.count('"solid" = 2'), 5)
        self.assertIn('/obj/structure/trains/locomotive/coal/mainline\n\tname = "main-line steam locomotive"\n\tbody_kind = "mainline"\n', LOCOS)
        self.assertIn('/obj/structure/train_car_kit/loco_mainline\n\tname = "main-line steam locomotive kit"\n\tcar_kind = "loco_mainline"\n', LOCOS)
        self.assertIn('RECIPE: /material/steel/,main-line steam locomotive kit,/obj/structure/train_car_kit/loco_mainline,90,600,1,1,trains,101,', RECIPES)
        self.assertIn('"/obj/structure/train_car_kit/loco_mainline" = "rail_steam"', NODES)
        self.assertNotIn('range(4, src)', LOCOS)

    def test_kit_names_are_compiled_defaults(self):
        # Restored kits must not rename themselves in a constructor.
        self.assertNotIn('/obj/structure/train_car_kit/New(', SOURCE)
        self.assertNotIn('/obj/structure/train_car_kit/New(', WARFARE)
        for kind in ('coach', 'sleeper', 'dining', 'storage', 'railgun', 'armored', 'flak', 'long_flatbed',
                     'open_wagon', 'boxcar', 'bogie_coach'):
            self.assertRegex(SOURCE + WARFARE, r'/obj/structure/train_car_kit/%s\n\tname = "[a-z ]+ kit"\n\tcar_kind = "%s"' % (kind, kind))

    def test_icon_states_exist(self):
        desc = dmi_description(ROOT / 'icons/obj/vehicles/train_platforms.dmi')
        states = set(re.findall(r'state = "([^"]+)"', desc))
        for kind in ('wood', 'floor', 'carpet', 'steel', 'boards'):
            self.assertIn('deck_center_' + kind, states)
            self.assertIn('deck_side_' + kind, states)
        for style in ('wall', 'window', 'door', 'door_open', 'inner_door', 'inner_door_open', 'partition', 'rail',
                      'plank', 'freight_door', 'freight_door_open', 'side', 'drop_door', 'drop_door_open'):
            self.assertIn('edge_' + style, states)
        for state in ('car_kit', 'edge_armor', 'edge_armor_door', 'edge_armor_door_open', 'brace_up', 'brace_down',
                      'wreck', 'loco_armor'):
            self.assertIn(state, states)
        # Headstocks ride on the end segments and their deck tiles; outriggers show while braced.
        for state in ('end_fl', 'end_fc', 'end_fr', 'end_bl', 'end_bc', 'end_br', 'outrigger'):
            self.assertIn(state, states)
        self.assertIn('overlays += "end_[end_row]c"', SOURCE)
        self.assertIn('D.overlays += "end_[end_row][side == TRAIN_LEFT ? "l" : "r"]"', SOURCE)
        self.assertIn('image(icon, "outrigger", dir = out', SOURCE)
        brace = WARFARE[WARFARE.index('/obj/structure/railway_gun_brace/proc/set_braced('):]
        self.assertLess(brace.index('S.braced = !!state'), brace.index('S.update_car_overlays()'))
        # Roof and 3x4 locomotive art, three tiles wide (left, rail tile, right).
        for kind in ('coach', 'steel', 'armor'):
            for row in 'fmb':
                for col in 'lcr':
                    self.assertIn('roof_%s_%s%s' % (kind, row, col), states)
        for loco in ('steam', 'diesel', 'armored'):
            for col in 'lcr':
                self.assertIn('roof_loco_%s_%s' % (loco, col), states)
                for seg in '1234':
                    self.assertIn('loco_%s_%s%s' % (loco, seg, col), states)
        for block in desc.split('state = ')[1:]:
            self.assertRegex(block, r'dirs = [14]\n\tframes = 1')

    def test_committed_sheets_match_the_drawing_script(self):
        import subprocess
        try:
            import PIL  # noqa: F401
        except ImportError:
            self.skipTest('Pillow is not installed')
        result = subprocess.run([sys.executable, str(ROOT / 'tests/sprites/create_trains.py'), '--check'],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_fast_trains_crash_instead_of_bumping(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertEqual(dme.count('#include "code\\modules\\1713\\train_crashes.dm"'), 1)
        crashes = (ROOT / 'code/modules/1713/train_crashes.dm').read_text(encoding='utf-8')
        hit = TRAINS[TRAINS.index('/obj/structure/trains/proc/rail_hit('):TRAINS.index('/obj/structure/trains/proc/car_load_weight()')]
        # Another train, a solid object and a blocked deck all end in train_crash().
        self.assertEqual(hit.count('train_crash('), 4)
        self.assertLess(hit.index('if (train_crash(TF, impact, fdir))'), hit.index('hits \\the [TF]!'))
        self.assertIn('tail.train_crash(clearance, impact, fdir)', TRAINS)
        # Only a running train crashes, and never into its own cars.
        crash = crashes[crashes.index('/obj/structure/trains/proc/train_crash('):]
        self.assertLess(crash.index('if (impact < TRAIN_CRASH_IMPACT)'), crash.index('if (hit in cars)'))
        self.assertLess(crash.index('if (hit in cars)'), crash.index('if (L.rail_speed > 0)'))
        self.assertLess(crash.index('if (!running)'), crash.index('visible_message('))
        self.assertIn('#define TRAIN_CRASH_IMPACT 0.75', crashes)
        # Derailed stock reuses the wrecked and broken down states a welder mends.
        self.assertIn('/obj/structure/trains/platform/derail()', crashes)
        self.assertIn('\twrecked = TRUE\n\tapply_layout()', crashes)
        self.assertIn('\tbroken_down = TRUE\n', crashes)

    def test_brakes_hold_a_share_of_the_train(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertEqual(dme.count('#include "code\\modules\\1713\\train_brakes.dm"'), 1)
        brakes = (ROOT / 'code/modules/1713/train_brakes.dm').read_text(encoding='utf-8')
        # Saved per car; the engine's own brake state stays tmp.
        self.assertIn('/obj/structure/trains\n\tvar/handbrake = FALSE\n', brakes)
        self.assertIn('var/tmp/braking = FALSE', TRAINS)
        # The drive loop slows by the braked share, and handbrakes drag the pull.
        drive = TRAINS[TRAINS.index('/obj/structure/trains/locomotive/proc/drive()'):]
        self.assertIn('/ heft + brake_decel()', drive)
        self.assertIn('return consist_power / max(1, drag_weight())', TRAINS)
        self.assertIn('if (car.handbrake || car.axle_seized)\n\t\t\tconsist_braked += car_weight', TRAINS)
        self.assertIn('return TRAIN_BRAKE_DECEL * min(1, held / max(1, weight))', brakes)
        # By hand only on a standing train; a push never moves a braked one.
        hand = brakes[brakes.index('/obj/structure/trains/proc/work_handbrake('):]
        self.assertLess(hand.index('if (train_rolling())'), hand.index('do_after('))
        bumped = TRAINS[TRAINS.index('/obj/structure/trains/Bumped('):]
        self.assertLess(bumped.index('if (train_handbrakes())'), bumped.index('if (rail_canmove(AM.dir))'))
        # The brake van is ballasted and comes with its wheel.
        self.assertIn('"roof" = "boxcar", "weight" = 1,', SOURCE)
        self.assertIn('"fit" = list(/obj/structure/train_brake_wheel, null, /obj/structure/bed/chair/comfy/blue)', SOURCE)
        self.assertRegex(RECIPES, r'(?m)^RECIPE: /material/iron/,brake wheel,/obj/structure/train_brake_wheel,')
        self.assertIn('"/obj/structure/train_brake_wheel" = "rail_steam"', NODES)
        states = dmi_description(ROOT / 'icons/obj/vehicles/train_platforms.dmi')
        for state in ('brake_wheel', 'brake_wheel_on'):
            self.assertIn('state = "%s"' % state, states)

    def test_parted_and_struck_cars_roll_on(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertEqual(dme.count('#include "code\\modules\\1713\\train_rolling.dm"'), 1)
        rolling = (ROOT / 'code/modules/1713/train_rolling.dm').read_text(encoding='utf-8')
        couplings = (ROOT / 'code/modules/1713/train_couplings.dm').read_text(encoding='utf-8')
        # The motion is read before the link goes, by a break and by hand.
        for source, start in ((couplings, '/obj/structure/trains/proc/part_at('), (TRAINS, '/obj/structure/trains/proc/couple_end(')):
            body = source[source.index(start):]
            self.assertLess(body.index('var/list/motion = train_motion()'), body.index('connected = null'))
            self.assertLess(body.index('settle_train_order()'), body.index('parted_rolls(other, motion, way, other_way)'))
        # Rolling state never reaches a save, and the loop runs on a timer.
        self.assertIn('\tvar/tmp/roll_speed = 0', rolling)
        self.assertIn('addtimer(CALLBACK(src, PROC_REF(roll_loop)), delay)', rolling)
        self.assertNotIn('spawn(', rolling)
        # A crash counts a rolling train as running, and stops it.
        crashes = (ROOT / 'code/modules/1713/train_crashes.dm').read_text(encoding='utf-8')
        self.assertIn('var/running = roll_head.roll_speed > 0', crashes)
        self.assertIn('roll_head.stop_rolling()', crashes)
        hit = TRAINS[TRAINS.index('/obj/structure/trains/proc/rail_hit('):]
        self.assertEqual(hit[:hit.index('for (var/obj/O in tgtt)')].count('TF.shoved(strike, fdir)'), 2)

    def test_wheels_slip_without_grip(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertEqual(dme.count('#include "code\\modules\\1713\\train_adhesion.dm"'), 1)
        adhesion = (ROOT / 'code/modules/1713/train_adhesion.dm').read_text(encoding='utf-8')
        self.assertIn('return throttle_share() > TRAIN_ADHESION * grip * pull_ratio()', adhesion)
        # The sandbox is saved; what is falling under the wheels is not.
        self.assertIn('\tvar/sand = TRAIN_SAND_MAX', adhesion)
        self.assertIn('\tvar/tmp/sanding = 0', adhesion)
        drive = TRAINS[TRAINS.index('/obj/structure/trains/locomotive/proc/drive()'):]
        self.assertLess(drive.index('if (wheels_slip())'), drive.index('rail_speed = min(target, max(rail_speed, 0.5)'))
        self.assertIn('choices += list("Throttle up", "Throttle down", "Brake", "Sand the rails")', TRAINS)

    def test_railway_gun_sheet(self):
        gun = dmi_description(ROOT / 'icons/obj/vehicles/railway_gun.dmi')
        self.assertIn('state = "railway_gun"', gun)

    def test_railway_gun_needs_a_braced_car(self):
        topic = WARFARE[WARFARE.index('/obj/structure/cannon/modern/railway/Topic('):]
        self.assertLess(topic.index('fire_problem()'), topic.index('return ..()'))
        consist = SOURCE[SOURCE.index('/proc/train_consist_obstacle('):]
        consist = consist[:consist.index('\n/', 1)]
        self.assertIn('braced', consist)
        self.assertIn('wrecked', consist)

    def test_rail_warehouse_is_craftable_and_keeps_cargo_in_contents(self):
        self.assertRegex(RECIPES, r'(?m)^RECIPE: /material/iron/,rail warehouse office,/obj/structure/rail_warehouse,')
        self.assertIn('"/obj/structure/rail_warehouse" = "rail_steam"', NODES)
        # Stored units are nested contents of the post, so world saves carry them.
        self.assertIn('var/obj/structure/rail_stored_unit/U = new(src)', WAREHOUSE)
        self.assertNotIn('should_save = FALSE', WAREHOUSE)
        # A stored platform segment has no deck until it rolls out again.
        layout = SOURCE[SOURCE.index('/obj/structure/trains/platform/proc/apply_layout()'):]
        self.assertLess(layout.index('if (!isturf(loc))'), layout.index('deck_parts = list()'))

    def test_shunting_buffers_up_and_automatic_couplers_lock(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertEqual(dme.count('#include "code\\modules\\1713\\train_shunting.dm"'), 1)
        shunting = (ROOT / 'code/modules/1713/train_shunting.dm').read_text(encoding='utf-8')
        couplings = (ROOT / 'code/modules/1713/train_couplings.dm').read_text(encoding='utf-8')
        # Which ends carry an automatic coupler is saved with the car.
        self.assertIn('\tvar/front_auto = FALSE', shunting)
        self.assertIn('\tvar/rear_auto = FALSE', shunting)
        # A contact that is not a crash may buffer up before anything is marked.
        hit = TRAINS[TRAINS.index('/obj/structure/trains/proc/rail_hit('):]
        self.assertLess(hit.index('if (train_crash(TF, impact, fdir))'), hit.index('if (buffer_up(TF, strike))'))
        self.assertLess(hit.index('if (buffer_up(TF, strike))'), hit.index('health -= round(5 * impact)'))
        # Coupling by hand and by contact make the link the same way.
        self.assertIn('if (!join_trains(ahead, TR, their_front))', TRAINS)
        self.assertIn('join_trains(coupling_end_ahead(mine), TF,', shunting)
        # The lever skips the wait, never the rule about a tight coupling.
        use = couplings[couplings.index('/obj/structure/trains/proc/coupler_use('):]
        self.assertLess(use.index('if (train_under_power())'), use.index('if (lever_uncouples(front))'))
        self.assertIn('RECIPE: /material/steel/,automatic coupler,/obj/item/train_coupling/automatic,6,120,0,0,trains,140,', RECIPES)
        self.assertIn('"/obj/item/train_coupling/automatic" = "assembly_line"', NODES)
        states = dmi_description(ROOT / 'icons/obj/vehicles/train_platforms.dmi')
        for state in ('knuckle_f_free', 'knuckle_b_free', 'knuckle_f_linked', 'knuckle_b_linked',
                      'knuckle_f_broken', 'knuckle_b_broken', 'knuckle_item'):
            self.assertIn('state = "%s"' % state, states)

    def test_servicing_wears_with_distance_and_never_ticks(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertEqual(dme.count('#include "code\\modules\\1713\\train_servicing.dm"'), 1)
        servicing = (ROOT / 'code/modules/1713/train_servicing.dm').read_text(encoding='utf-8')
        rolling = (ROOT / 'code/modules/1713/train_rolling.dm').read_text(encoding='utf-8')
        # Wear is saved with the car and counted where the train is added up.
        self.assertIn('\tvar/axle_oil = TRAIN_OIL_FULL\n\tvar/axle_seized = FALSE\n', servicing)
        self.assertIn('\tvar/clinker = 0', servicing)
        refresh = TRAINS[TRAINS.index('/obj/structure/trains/locomotive/proc/refresh_consist('):]
        self.assertLess(refresh.index('car.wear_axles(steps_since)'), refresh.index('if (car.handbrake || car.axle_seized)'))
        self.assertIn('car.wear_axles(roll_since)', rolling)
        self.assertIsNone(re.search(r'(?<!\w)(spawn|addtimer|sleep|while) ?\(', servicing))
        # A weapon-typed oil vessel must not be taken for a blow on a wagon.
        for kind in ('storage', 'transport'):
            body = TRAINS[TRAINS.index('/obj/structure/trains/%s/attackby(' % kind):]
            self.assertLess(body.index('if (service_use(W, user))'), body.index('..()'))
        # The fire: clinker comes with the work and takes from the fire.
        self.assertIn('* clinker_factor()', TRAINS)
        self.assertIn('\tmake_clinker(notch, weight, tiles)\n', TRAINS)
        for path, cost in (('/obj/item/train_fire_rake', 'fire rake,/obj/item/train_fire_rake,2,'),
                           ('/obj/structure/rail_ash_pit', 'ash pit,/obj/structure/rail_ash_pit,6,')):
            self.assertIn('RECIPE: /material/iron/,' + cost, RECIPES)
            self.assertIn('"%s" = "rail_steam"' % path, NODES)
        states = dmi_description(ROOT / 'icons/obj/vehicles/train_platforms.dmi')
        for state in ('ash_pit', 'ash_pit_ash', 'ash_pit_full', 'fire_rake'):
            self.assertIn('state = "%s"' % state, states)

    def test_deeper_servicing_and_the_depot(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertEqual(dme.count('#include "code\\modules\\1713\\train_depot.dm"'), 1)
        servicing = (ROOT / 'code/modules/1713/train_servicing.dm').read_text(encoding='utf-8')
        depot = (ROOT / 'code/modules/1713/train_depot.dm').read_text(encoding='utf-8')
        rolling = (ROOT / 'code/modules/1713/train_rolling.dm').read_text(encoding='utf-8')
        # Saved with the car or engine.
        self.assertIn('\tvar/brake_shoes = TRAIN_SHOES_FULL\n', servicing)
        self.assertIn('\tvar/mileage = 0', servicing)
        self.assertIn('\tvar/scale = 0', servicing)
        # Counted where the train is added up; worn shoes hold less.
        refresh = TRAINS[TRAINS.index('/obj/structure/trains/locomotive/proc/refresh_consist('):]
        self.assertLess(refresh.index('car.wear_shoes(steps_since)'), refresh.index('consist_braked += car_weight * car.brake_hold()'))
        self.assertIn('consist_own += car_weight * car.brake_hold()', refresh)
        self.assertIn('L.wear_engine(steps_since)', refresh)
        self.assertIn('car.wear_shoes(roll_since)', rolling)
        self.assertIn('roll_braked += weight * car.brake_hold()', rolling)
        # The last tiles of a run count as well.
        drive = TRAINS[TRAINS.index('/obj/structure/trains/locomotive/proc/drive()'):]
        self.assertLess(drive.index('refresh_consist(since)\n\t\trail_speed = 0'), drive.index('driving = FALSE'))
        # Scale comes with the water boiled and takes from the fire.
        self.assertIn('* clinker_factor() * scale_factor()', TRAINS)
        self.assertIn('\tmake_scale(boiled)\n', TRAINS)
        self.assertIn('choices += "Wash out the boiler"', TRAINS)
        # No override of a proc trains.dm defines on the same type, and nothing ticks.
        self.assertNotIn('/obj/structure/trains/locomotive/examine(', servicing)
        for text in (depot, servicing):
            self.assertIsNone(re.search(r'(?<!\w)(spawn|addtimer|sleep|while) ?\(', text))
        for path, recipe in (('/obj/item/train_brake_shoes', '/material/iron/,set of brake shoes,/obj/item/train_brake_shoes,3,'),
                             ('/obj/structure/rail_depot/coal_stage', '/material/wood/,coaling stage,/obj/structure/rail_depot/coal_stage,20,'),
                             ('/obj/structure/rail_depot/sand_bin', '/material/wood/,sand bin,/obj/structure/rail_depot/sand_bin,8,')):
            self.assertIn('RECIPE: ' + recipe, RECIPES)
            self.assertIn('"%s" = "rail_steam"' % path, NODES)
        self.assertIn('state = "brake_shoes"', dmi_description(ROOT / 'icons/obj/vehicles/train_platforms.dmi'))
        water = dmi_description(ROOT / 'icons/obj/vehicles/rail_water.dmi')
        for state in ('coal_stage_empty', 'coal_stage', 'coal_stage_full', 'sand_bin_empty', 'sand_bin'):
            self.assertIn('state = "%s"' % state, water)

    def test_snow_slows_trains_and_a_plough_clears_it(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertEqual(dme.count('#include "code\\modules\\1713\\train_snow.dm"'), 1)
        snow = (ROOT / 'code/modules/1713/train_snow.dm').read_text(encoding='utf-8')
        couplings = (ROOT / 'code/modules/1713/train_couplings.dm').read_text(encoding='utf-8')
        self.assertIn('\tvar/front_plough = FALSE\n\tvar/rear_plough = FALSE\n', snow)
        # One tile is looked at for each tile run, and nothing ticks.
        drive = TRAINS[TRAINS.index('/obj/structure/trains/locomotive/proc/drive()'):]
        self.assertEqual(drive.count('meet_snow()'), 1)
        self.assertIn('top * lead_factor * snow_factor * ', TRAINS)
        self.assertIn('drive_tail = cars.len ? cars[cars.len] : src', TRAINS)
        self.assertIsNone(re.search(r'(?<!\w)(spawn|addtimer|sleep|while|range|view) ?\(', snow))
        # The plough is worked at the coupling, before the coupling itself.
        use = couplings[couplings.index('/obj/structure/trains/proc/coupler_use('):]
        self.assertLess(use.index('if (plough_use(user, front, W))'), use.index('var/v = coupling_at(front)'))
        self.assertIn("image('icons/obj/vehicles/train_plough.dmi', front ? \"plough_f\" : \"plough_b\")", couplings)
        self.assertIn('RECIPE: /material/iron/,snowplough,/obj/item/train_snowplough,10,', RECIPES)
        self.assertIn('"/obj/item/train_snowplough" = "rail_steam"', NODES)
        states = dmi_description(ROOT / 'icons/obj/vehicles/train_plough.dmi')
        for state in ('plough_f', 'plough_b'):
            self.assertIn('state = "%s"' % state, states)
        self.assertIn('state = "plough_item"', dmi_description(ROOT / 'icons/obj/vehicles/train_platforms.dmi'))

    def test_bulk_freight_is_a_count_on_the_car(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertEqual(dme.count('#include "code\\modules\\1713\\train_freight.dm"'), 1)
        freight = (ROOT / 'code/modules/1713/train_freight.dm').read_text(encoding='utf-8')
        self.assertIn('\tvar/bulk_path = null', freight)
        self.assertIn('\tvar/bulk_amount = 0', freight)
        self.assertIn('"center" = "boards", "side" = "boards", "bulk" = 600,', PLATFORMS)
        self.assertIn('"center" = "hopper", "side" = "hopper", "bulk" = 800, "hopper" = TRUE,', PLATFORMS)
        # The load weighs on the car, shows on every section and keeps it from being packed.
        self.assertIn('+ bulk_weight()\n', PLATFORMS)
        self.assertIn('var/image/heap = bulk_overlay()', PLATFORMS)
        self.assertIn('return "Unload the car first."', PLATFORMS)
        attack = PLATFORMS[PLATFORMS.index('/obj/structure/trains/platform/attackby('):]
        self.assertLess(attack.index('if (bulk_use(W, user))'), attack.index('car_engine()'))
        # A section draws its heap from its own copy: no search while the train moves.
        overlay = freight[freight.index('/obj/structure/trains/platform/proc/bulk_overlay('):]
        overlay = overlay[:overlay.index('\n\n')]
        self.assertNotIn('car_segments', overlay)
        self.assertIsNone(re.search(r'(?<!\w)(spawn|addtimer|sleep) ?\(', freight))
        for path, recipe in (('/obj/structure/train_car_kit/hopper', 'hopper wagon kit,/obj/structure/train_car_kit/hopper,28,'),
                             ('/obj/structure/train_hopper_lever', 'hopper door lever,/obj/structure/train_hopper_lever,4,'),
                             ('/obj/structure/rail_drop_pit', 'drop pit,/obj/structure/rail_drop_pit,8,')):
            self.assertIn('RECIPE: /material/iron/,' + recipe, RECIPES)
            self.assertIn('"%s" = "rail_steam"' % path, NODES)
        states = dmi_description(ROOT / 'icons/obj/vehicles/train_platforms.dmi')
        for state in ('edge_hopper', 'deck_center_hopper', 'deck_side_hopper', 'drop_pit', 'drop_pit_coal', 'drop_pit_ore', 'drop_pit_sand'):
            self.assertIn('state = "%s"' % state, states)
        loads = dmi_description(ROOT / 'icons/obj/vehicles/train_loads.dmi')
        for tone in ('coal', 'ore', 'sand'):
            for fill in (1, 2):
                self.assertIn('state = "heap_%s_%d"' % (tone, fill), loads)

    def test_native_fixture_preparation(self):
        generated = run.sources()
        self.assertIn('#include "tests/train_platforms/probe.dm"', generated[run.PREFIX + '.dme'])
        self.assertNotRegex(generated[run.PREFIX + '.dme'], r'(?m)^#include ".*\.dmm"')


if __name__ == '__main__':
    unittest.main()
