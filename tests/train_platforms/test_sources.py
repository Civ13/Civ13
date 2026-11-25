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
        self.assertIn('\tvar/list/choices = E.station_controls(station)\n', TRAINS)
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
        self.assertEqual(hit.count('train_crash('), 5)
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
        self.assertIn('rail_speed - stopping_decel(target, heft)', drive)
        self.assertIn('/ max(1, heft) + brake_decel()', brakes)
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
        self.assertLess(drive.index('if (wheels_slip())'), drive.index('rail_speed = min(target, train_speed_gain(rail_speed'))
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
        # A heavy locomotive is stored whole and rebuilt when it rolls out.
        self.assertNotIn('too long to put away', WAREHOUSE)
        self.assertIn('E.clear_body()', WAREHOUSE)
        self.assertIn('engine.build_body()', WAREHOUSE)
        self.assertIn('coupled.coupling_at(coupled.reversed) > 0 && front.coupling_at(TRUE) > 0', WAREHOUSE)
        # A stored platform segment has no deck until it rolls out again.
        layout = SOURCE[SOURCE.index('/obj/structure/trains/platform/proc/apply_layout()'):]
        self.assertLess(layout.index('if (!isturf(loc))'), layout.index('deck_parts = list()'))

    def test_warehouse_keeps_same_named_choices_mapped_to_their_exact_units(self):
        menu = WAREHOUSE.split('/proc/put_away_options(list/units)', 1)[1].split('\n\n', 1)[0]
        self.assertIn('options["Put away [i].', menu)
        self.assertIn('(track [front.x], [front.y])"] = unit', menu)
        attack = WAREHOUSE.split('/obj/structure/rail_warehouse/attack_hand(', 1)[1]
        self.assertIn('var/list/options = put_away_options(rear)', attack)
        self.assertIn('options["Put away the whole train"] = "all"', attack)
        self.assertIn('options["Couple on [i]. [U.unit_name]"] = U', attack)
        self.assertIn('var/action = options[choice]', attack)
        self.assertIn('put_away(H, islist(action) ? action : null, action == "all")', attack)

    def test_warehouse_rechecks_the_current_rear_before_storing(self):
        validation = WAREHOUSE.split('/proc/store_problem(list/unit)', 1)[1].split('\n\n', 1)[0]
        self.assertIn('rail_warehouse_end(unit, FALSE)', validation)
        self.assertIn('if (QDELETED(rear))', validation)
        self.assertIn('if (rear.connected)', validation)
        action = WAREHOUSE.split('/proc/put_away(', 1)[1].split('\n\n', 1)[0]
        self.assertLess(action.index('store_problem(unit)'), action.index('store_unit(unit)'))
        self.assertIn('if (!all)\n\t\t\tbreak\n\t\tunit = null', action)

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
        self.assertIn('+ bulk_weight() + tank_weight()\n', PLATFORMS)
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

    def test_tank_car_carries_one_liquid_as_a_count(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertEqual(dme.count('#include "code\\modules\\1713\\train_tank.dm"'), 1)
        tank = (ROOT / 'code/modules/1713/train_tank.dm').read_text(encoding='utf-8')
        water = (ROOT / 'code/modules/1713/train_water.dm').read_text(encoding='utf-8')
        self.assertIn('\tvar/tank_reagent = null', tank)
        self.assertIn('\tvar/tank_amount = 0', tank)
        self.assertIn('"center" = "steel", "side" = "boards", "tank" = 3600,', PLATFORMS)
        self.assertEqual(PLATFORMS.count('"solid" = 1, "tank" = '), 4)
        self.assertIn('fit" = list(/obj/structure/train_tank_valve, null, null)', PLATFORMS)
        # The tank is solid on a car that is no locomotive body.
        self.assertIn('var/solid = segment_layout()["solid"]', PLATFORMS)
        self.assertIn('var/image/shell = tank_overlay()', PLATFORMS)
        self.assertIn('return "Drain the tank first."', PLATFORMS)
        attack = PLATFORMS[PLATFORMS.index('/obj/structure/trains/platform/attackby('):]
        self.assertLess(attack.index('if (tank_use(W, user))'), attack.index('car_engine()'))
        # A section draws its tank from its own layout: no search while the train moves.
        overlay = tank[tank.index('/obj/structure/trains/platform/proc/tank_overlay('):]
        overlay = overlay[:overlay.index('\n\n')]
        self.assertNotIn('car_segments', overlay)
        self.assertIsNone(re.search(r'(?<!\w)(spawn|addtimer|sleep) ?\(', tank))
        # A water tower or crane fills a tank car the way it fills a tender.
        self.assertIn('if (P.tank_takes("water"))', water)
        self.assertIn('gave = P.tank_fill("water", T.water)', water)
        for path, recipe in (('/obj/structure/train_car_kit/tank_car', 'tank car kit,/obj/structure/train_car_kit/tank_car,30,'),
                             ('/obj/structure/train_tank_valve', 'tank valve,/obj/structure/train_tank_valve,4,')):
            self.assertIn('RECIPE: /material/iron/,' + recipe, RECIPES)
            self.assertIn('"%s" = "rail_steam"' % path, NODES)
        self.assertIn('state = "tank_valve"', dmi_description(ROOT / 'icons/obj/vehicles/train_platforms.dmi'))
        loads = dmi_description(ROOT / 'icons/obj/vehicles/train_loads.dmi')
        for part in 'fmdb':
            self.assertIn('state = "tank_%s"' % part, loads)

    def test_special_stock_and_the_ice_car(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertEqual(dme.count('#include "code\\modules\\1713\\train_stock.dm"'), 1)
        stock = (ROOT / 'code/modules/1713/train_stock.dm').read_text(encoding='utf-8')
        ice = (ROOT / 'code/modules/1713/small_ancient.dm').read_text(encoding='utf-8')
        food = (ROOT / 'code/modules/reagents/reagent_containers/food.dm').read_text(encoding='utf-8')
        for kind in ('stock_car', 'ice_car', 'mail_van', 'bogie_sleeper', 'bogie_dining'):
            self.assertIn('layouts["%s"] = list(' % kind, PLATFORMS)
            self.assertIn('/obj/structure/train_car_kit/%s\n' % kind, stock)
        self.assertIn('"center" = "straw", "side" = "straw", "roof" = "stock",', PLATFORMS)
        self.assertIn('"center" = "boards", "side" = "boards", "roof" = "reefer",', PLATFORMS)
        self.assertIn('|| style == "slat_door" || style == "cold_door"', PLATFORMS)
        # The bunker and the lockers are ice houses, so food kept in them
        # takes the ice house's decay step with no new branch in food.dm.
        self.assertIn('/obj/structure/closet/ice_house/reefer\n', stock)
        self.assertIn('/obj/structure/closet/ice_house/cold_locker\n', stock)
        self.assertIn('else if (istype(loc, /obj/structure/closet/ice_house))', food)
        self.assertIn('decaytimer += IH.is_cold() ? 50 : 300', food)
        self.assertNotIn('train_', food)
        self.assertIn('var/melt_after = slow_melt() ? ICE_HOUSE_MELT_SECONDS_UNDERGROUND : ICE_HOUSE_MELT_SECONDS', ice)
        self.assertIn('/obj/structure/closet/ice_house/proc/slow_melt()\n\treturn underground()', ice)
        # A locker keeps the bunker it found: no search each time food asks.
        cold = stock[stock.index('/obj/structure/closet/ice_house/cold_locker/is_cold('):]
        cold = cold[:cold.index('\n\n')]
        self.assertNotIn('range(', cold)
        self.assertIn('if (feed && !QDELETED(feed) && feed.z == z && get_dist(src, feed) <= COLD_LOCKER_REACH)\n\t\treturn feed', stock)
        self.assertIsNone(re.search(r'(?<!\w)(spawn|addtimer|sleep) ?\(', stock))
        for path, recipe, node in (
                ('stock_car', '/material/iron/,stock car kit,/obj/structure/train_car_kit/stock_car,30,', 'rail_steam'),
                ('ice_car', '/material/iron/,ice car kit,/obj/structure/train_car_kit/ice_car,34,', 'rail_steam'),
                ('mail_van', '/material/iron/,baggage and mail van kit,/obj/structure/train_car_kit/mail_van,30,', 'rail_steam'),
                ('bogie_sleeper', '/material/steel/,bogie sleeper car kit,/obj/structure/train_car_kit/bogie_sleeper,30,', 'assembly_line'),
                ('bogie_dining', '/material/steel/,bogie dining car kit,/obj/structure/train_car_kit/bogie_dining,30,', 'assembly_line')):
            self.assertIn('RECIPE: ' + recipe, RECIPES)
            self.assertIn('"/obj/structure/train_car_kit/%s" = "%s"' % (path, node), NODES)
        states = dmi_description(ROOT / 'icons/obj/vehicles/train_platforms.dmi')
        for state in ('edge_slat', 'edge_slat_door', 'edge_slat_door_open', 'edge_cold', 'edge_cold_door', 'edge_cold_door_open',
                      'deck_center_straw', 'deck_side_straw', 'roof_stock_fl', 'roof_reefer_fl', 'ice_bunker', 'ice_bunker_open',
                      'cold_locker', 'cold_locker_open'):
            self.assertIn('state = "%s"' % state, states)

    def test_crane_car_lifts_only_when_braced(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertEqual(dme.count('#include "code\\modules\\1713\\train_crane.dm"'), 1)
        crane = (ROOT / 'code/modules/1713/train_crane.dm').read_text(encoding='utf-8')
        lifting = (ROOT / 'code/modules/1713/lifting_machines.dm').read_text(encoding='utf-8')
        rail = '/obj/structure/workshop_machine/shear_legs/crane/steam/rail'
        self.assertIn(rail + '\n', crane)
        self.assertIn('layouts["crane_car"] = list(', PLATFORMS)
        self.assertIn('"fit" = list(null, %s, null)' % rail, PLATFORMS)
        self.assertIn('"fit" = list(/obj/structure/railway_gun_brace, null, null)', PLATFORMS)
        # Every way into a haul asks for the outriggers first.
        for proc in ('MouseDrop_T(', 'attack_hand('):
            body = crane[crane.index(rail + '/' + proc):]
            body = body[:body.index('\n\n')]
            self.assertLess(body.index('rail_problem()'), body.index('return ..()'))
        self.assertIn(rail + '/hauler_ready(mob/living/human/H)\n\treturn ..() && !rail_problem()', crane)
        self.assertIn('if (!P.braced)', crane)
        # The hoists share one reach hook; only the rail crane slings at a distance.
        self.assertIn('/obj/structure/workshop_machine/shear_legs/proc/sling_reach()\n\treturn 1', lifting)
        self.assertEqual(lifting.count('get_dist(src, dropping) > sling_reach()'), 2)
        self.assertIn(rail + '/sling_reach()\n\treturn reach', crane)
        goods = (ROOT / 'code/modules/1713/train_goods.dm').read_text(encoding='utf-8')
        self.assertIn('return train_crane_swings(src, load, choices, mine.car_id)', crane)
        self.assertIn('if ((own_car && P.car_id == own_car) || P.density || (on && on.car_id == P.car_id))', goods)
        self.assertIsNone(re.search(r'(?<!\w)(spawn|addtimer|sleep) ?\(', crane))
        self.assertIn('RECIPE: /material/iron/,crane car kit,/obj/structure/train_car_kit/crane_car,40,', RECIPES)
        self.assertIn('RECIPE: /material/iron/,rail crane,%s,20,' % rail, RECIPES)
        self.assertIn('"/obj/structure/train_car_kit/crane_car" = "rail_steam"', NODES)
        self.assertIn('"%s" = "rail_steam"' % rail, NODES)
        loads = dmi_description(ROOT / 'icons/obj/vehicles/train_loads.dmi')
        for state in ('rail_crane', 'rail_crane_haul'):
            self.assertIn('state = "%s"' % state, loads)

    def test_diesels_work_in_multiple_with_a_deadman(self):
        diesel = (ROOT / 'code/modules/1713/train_diesel.dm').read_text(encoding='utf-8')
        self.assertIn('#include "code\\modules\\1713\\train_diesel.dm"', (ROOT / 'civ13.dme').read_text(encoding='utf-8'))
        # the two-cab engine is a layout with a second cab and its own kit
        layout = LOCOS[LOCOS.index('layouts["loco_dieselmain"]'):LOCOS.index('layouts["tender"]')]
        self.assertIn('"cab" = 1, "cab2" = 6, "roof" = "loco_dieselmain"', layout)
        self.assertEqual(layout.count('"solid" = 1'), 4)
        self.assertIn('list("edges" = cab_end, "solid" = 0)', layout)
        self.assertIn('/obj/structure/train_car_kit/loco_dieselmain\n\tname = "main-line diesel locomotive kit"\n\tcar_kind = "loco_dieselmain"\n', LOCOS)
        self.assertIn('/obj/structure/trains/locomotive/heavy_diesel/mainline\n\tname = "main-line diesel locomotive"', diesel)
        self.assertIn('"/obj/structure/train_car_kit/loco_dieselmain" = "combustion"', NODES)
        self.assertIn('RECIPE: /material/steel/,main-line diesel locomotive kit,/obj/structure/train_car_kit/loco_dieselmain,100,', RECIPES)
        decks = (ROOT / 'code/modules/1713/machinery/modular_vehicles/vehicle_decks.dm').read_text(encoding='utf-8')
        self.assertIn('seg_index != L["cab"] && seg_index != L["cab2"]', decks)
        # no new loops: linking, the brake and the dead-man ride on the drive loop
        for word in ('spawn(', 'sleep(', 'while ('):
            self.assertNotIn(word, diesel)
        self.assertIn('\tlinked = linked_units(cars)\n', TRAINS)
        self.assertIn('(linked && car.car_id && linked[car.car_id])', TRAINS)
        loop = TRAINS[TRAINS.index('/obj/structure/trains/locomotive/proc/drive()'):]
        self.assertIn('\t\t\t\trefresh_consist(since)\n\t\t\t\tsince = 0\n', loop)
        self.assertIn('\t\t\t\tdeadman_watch()\n', loop)
        self.assertIn('var/obj/structure/trains/locomotive/E = linked_driver()', TRAINS)
        self.assertIn('if (H.stat == CONSCIOUS && !H.incapacitated())', diesel)
        states = set(re.findall(r'state = "([^"]+)"', dmi_description(ROOT / 'icons/obj/vehicles/train_platforms.dmi')))
        for seg in '123456':
            for col in 'lcr':
                self.assertIn('loco_dieselmain_%s%s' % (seg, col), states)
        for col in 'lcr':
            self.assertIn('roof_loco_dieselmain_%s' % col, states)
            self.assertIn('roof_loco_dieselmain_b%s' % col, states)

    def test_conductor_tools_lock_list_ticket_and_signal(self):
        conductor = (ROOT / 'code/modules/1713/train_conductor.dm').read_text(encoding='utf-8')
        self.assertIn('#include "code\\modules\\1713\\train_conductor.dm"', (ROOT / 'civ13.dme').read_text(encoding='utf-8'))
        # locks are a saved bit per door, and never shut anyone in
        self.assertIn('\tvar/locked_doors = 0 // bit per edge index, like open_doors\n', conductor)
        self.assertIn('\treturn is_locked() && !(user && user.loc == loc)\n', conductor)
        hand = PLATFORMS[PLATFORMS.index('/obj/structure/train_part/edge/attack_hand(mob/user)'):]
        self.assertLess(hand.index('if (locked_against(user))'), hand.index('set_open(!open)'))
        self.assertIn('is_tool(W, TOOL_CROWBAR) && is_locked()', conductor)
        # nothing here sells, buys or ticks
        for word in ('spawn(', 'sleep(', 'while (', 'process(', 'money', 'coin'):
            self.assertNotIn(word, conductor)
        states = set(re.findall(r'state = "([^"]+)"', dmi_description(ROOT / 'icons/obj/vehicles/train_platforms.dmi')))
        for path, recipe, state in (
                ('/obj/item/train_key', '/material/iron/,carriage key,/obj/item/train_key,1,', 'carriage_key'),
                ('/obj/item/train_ticket_punch', '/material/iron/,ticket punch,/obj/item/train_ticket_punch,1,', 'ticket_punch'),
                ('/obj/item/train_ticket_book', '/material/leather/,ticket book,/obj/item/train_ticket_book,1,', 'ticket_book'),
                ('/obj/item/train_list', "/material/leather/,guard's journal,/obj/item/train_list,1,", 'guard_journal'),
                ('/obj/item/train_flags', '/material/cloth/,pair of signal flags,/obj/item/train_flags,2,', 'signal_flags')):
            self.assertIn('RECIPE: ' + recipe, RECIPES)
            self.assertIn('"%s" = "rail_steam"' % path, NODES)
            self.assertIn('icon_state = "%s"' % state, conductor)
            self.assertIn(state, states)
        self.assertIn('ticket', states)
        self.assertIn('ticket_punched', states)

    def test_signals_frames_and_tokens(self):
        signals = (ROOT / 'code/modules/1713/train_signals.dm').read_text(encoding='utf-8')
        self.assertIn('#include "code\\modules\\1713\\train_signals.dm"', (ROOT / 'civ13.dme').read_text(encoding='utf-8'))
        # the cab reads the line when it starts and each time the train is counted
        drive = TRAINS[TRAINS.index('/obj/structure/trains/locomotive/proc/drive()'):]
        drive = drive[:drive.index('/obj/structure/trains/locomotive/proc/process_rail_forward()')]
        self.assertEqual(drive.count('lineside_watch()'), 2)
        self.assertLess(drive.index('lineside_seen = null'), drive.index('spawn(0)'))
        self.assertLess(drive.index('deadman_watch()'), drive.rindex('lineside_watch()'))
        # a wired signal or switch does not move by hand
        self.assertIn('if (worked_by && train_frame_by_id(worked_by, src))', signals)
        lever = TRAINS[TRAINS.index('/obj/structure/train_lever/attack_hand('):]
        self.assertLess(lever.index('train_frame_by_id(worked_by, src)'), lever.index('throw_switch("split")'))
        # a signal always goes back to danger; the token is one object
        self.assertIn('\t\tif (S.clear)\n\t\t\treturn null // a signal always goes back to danger\n', signals)
        self.assertIn('\tif (train_token_out(section))\n', signals)
        for word in ('spawn(', 'sleep(', 'while (', 'process('):
            self.assertNotIn(word, signals)
        states = set(re.findall(r'state = "([^"]+)"', dmi_description(ROOT / 'icons/obj/vehicles/train_platforms.dmi')))
        for path, recipe, state in (
                ('/obj/structure/train_lineside/signal', '/material/iron/,semaphore signal,/obj/structure/train_lineside/signal,4,', 'signal_danger'),
                ('/obj/structure/train_lever_frame', '/material/iron/,lever frame,/obj/structure/train_lever_frame,10,', 'lever_frame'),
                ('/obj/structure/train_token_instrument', '/material/iron/,token instrument,/obj/structure/train_token_instrument,8,', 'token_instrument'),
                ('/obj/item/train_signal_wire', '/material/iron/,coil of signal wire,/obj/item/train_signal_wire,2,', 'signal_wire'),
                ('/obj/structure/train_lineside/board', '/material/wood/,section board,/obj/structure/train_lineside/board,3,', 'section_board')):
            self.assertIn('RECIPE: ' + recipe, RECIPES)
            self.assertIn('"%s" = "rail_steam"' % path, NODES)
            self.assertIn('icon_state = "%s"' % state, signals)
            self.assertIn(state, states)
        self.assertIn('signal_clear', states)
        self.assertIn('train_token', states)

    def test_trains_leave_the_rails_and_are_rerailed(self):
        derail = (ROOT / 'code/modules/1713/train_derail.dm').read_text(encoding='utf-8')
        self.assertIn('#include "code\\modules\\1713\\train_derail.dm"', (ROOT / 'civ13.dme').read_text(encoding='utf-8'))
        self.assertIn('#define TRAIN_CURVE_SPEED 3 ', derail)
        self.assertIn('#define TRAIN_OVERRUN_SPEED 2 ', derail)
        # the first notch of the fastest engine is under the curve limit
        fastest = min(float(v) for v in re.findall(r'max_train_speed = ([0-9.]+)', LOCOS + TRAINS))
        self.assertLess(10 / fastest / 3, 3)
        drive = TRAINS[TRAINS.index('/obj/structure/trains/locomotive/proc/drive()'):]
        drive = drive[:drive.index('/obj/structure/trains/locomotive/proc/process_rail_forward()')]
        self.assertLess(drive.index('overrun_check()'), drive.index('if (curve_check(lead, lead_dir, lead_from))'))
        self.assertIn('\treturn broken_down || derailed\n', TRAINS)
        self.assertIn('if (P.wrecked || P.braced || P.derailed)', PLATFORMS)
        servicing = (ROOT / 'code/modules/1713/train_servicing.dm').read_text(encoding='utf-8')
        self.assertIn('\tif (istype(W, /obj/item/train_jack))\n\t\treturn jack_use(W, user)\n', servicing)
        for word in ('spawn(', 'sleep(', 'while (', 'process('):
            self.assertNotIn(word, derail)
        states = set(re.findall(r'state = "([^"]+)"', dmi_description(ROOT / 'icons/obj/vehicles/train_platforms.dmi')))
        self.assertIn('RECIPE: /material/iron/,rerailing jack,/obj/item/train_jack,6,', RECIPES)
        self.assertIn('"/obj/item/train_jack" = "rail_steam"', NODES)
        self.assertIn('derailed', states)
        self.assertIn('rerail_jack', states)

    def test_turntable_is_a_pivot_with_bridge_rails(self):
        table = (ROOT / 'code/modules/1713/train_turntable.dm').read_text(encoding='utf-8')
        platforms = (ROOT / 'code/modules/1713/train_platforms.dm').read_text(encoding='utf-8')
        self.assertIn('#include "code\\modules\\1713\\train_turntable.dm"', (ROOT / 'civ13.dme').read_text(encoding='utf-8'))
        # the bridge is rails to a train, but not track a player bends or lifts
        self.assertIn('/obj/structure/rails/turntable\n', table)
        self.assertIn('/obj/structure/rails/turntable/pry_apart()\n\treturn null', table)
        # it turns only what is whole on the bridge, with the pit clear
        swing = table[table.index('/obj/structure/train_turntable/proc/swing(angle)'):]
        swing = swing[:swing.index('/obj/structure/train_turntable/proc/in_reach(')]
        self.assertIn('turn_problem()', swing)
        self.assertLess(swing.index('cargo[AM] = rotated(T, angle)'), swing.index('TR.train_shift(places[TR], FALSE)'))
        self.assertIn('P.place_parts(P.loc, P.dir)', swing)
        self.assertIn('E.place_body()', swing)
        self.assertIn('which is not on the table', table)
        self.assertIn('is standing in the pit', table)
        # the pivot and its pit are never deck cargo
        self.assertIn('istype(AM, /obj/structure/train_turntable)', platforms)
        for word in ('spawn(', 'sleep(', 'while (', 'process('):
            self.assertNotIn(word, table)
        for name in ('TURNTABLE_TIME', 'TURNTABLE_WEIGHT_TIME', 'TURNTABLE_TIME_MAX'):
            self.assertIn('#undef ' + name, table)
        states = set(re.findall(r'state = "([^"]+)"', dmi_description(ROOT / 'icons/obj/vehicles/train_platforms.dmi')))
        for state in ('turntable_deck', 'turntable_girders', 'turntable_pivot'):
            self.assertIn('"%s"' % state, table)
            self.assertIn(state, states)
        for sheet, size in (('train_turntable.dmi', 160), ('train_turntable_large.dmi', 352)):
            text = dmi_description(ROOT / 'icons/obj/vehicles' / sheet)
            self.assertIn('state = "pit"', text)
            self.assertIn('width = %d' % size, text)
            self.assertIn("'icons/obj/vehicles/%s'" % sheet, table)
        for path, recipe in (
                ('/obj/structure/train_turntable', '/material/iron/,turntable,/obj/structure/train_turntable,20,'),
                ('/obj/structure/train_turntable/large', '/material/iron/,large turntable,/obj/structure/train_turntable/large,40,')):
            self.assertIn('RECIPE: ' + recipe, RECIPES)
            self.assertIn('"%s" = "rail_steam"' % path, NODES)

    def test_track_wear_is_a_count_on_the_rail(self):
        wear = (ROOT / 'code/modules/1713/train_trackwear.dm').read_text(encoding='utf-8')
        laying = (ROOT / 'code/modules/1713/track_laying.dm').read_text(encoding='utf-8')
        self.assertIn('#include "code\\modules\\1713\\train_trackwear.dm"', (ROOT / 'civ13.dme').read_text(encoding='utf-8'))
        # the drive loop asks once a step, after the snow
        drive = TRAINS[TRAINS.index('/obj/structure/trains/locomotive/proc/drive()'):]
        self.assertLess(drive.index('meet_snow()'), drive.index('if (meet_track())'))
        self.assertEqual(TRAINS.count('meet_track()'), 1)
        # platelaying is asked first by the rails' own attackby, not overridden
        attack = laying[laying.index('/obj/structure/rails/attackby(obj/item/W, mob/user)'):]
        self.assertLess(attack.index('if (track_maintain(W, user))'), attack.index('is_tool(W, TOOL_HAMMER)'))
        self.assertNotIn('/obj/structure/rails/attackby', wear)
        # nothing decays on a timer, and the limits match the documented ones
        for word in ('spawn(', 'sleep(', 'while (', 'process(', 'world.time'):
            self.assertNotIn(word, wear)
        for name, value in (('TRACK_WEAR_RATE', '0.01'), ('TRACK_ROUGH', '25'), ('TRACK_WORN', '50'), ('TRACK_BAD', '80'),
                            ('TRACK_WORN_SPEED', '5'), ('TRACK_BAD_SPEED', '2'), ('TRACK_PACK', '30')):
            self.assertRegex(wear, r'#define %s %s\b' % (name, re.escape(value)))
            self.assertIn('#undef ' + name, wear)
        states = set(re.findall(r'state = "([^"]+)"', dmi_description(ROOT / 'icons/obj/vehicles/train_platforms.dmi')))
        for state in ('track_worn', 'track_bad'):
            self.assertIn('"%s"' % state, wear)
            self.assertIn(state, states)

    def test_freight_handling_is_worked_by_players(self):
        goods = (ROOT / 'code/modules/1713/train_goods.dm').read_text(encoding='utf-8')
        crane = (ROOT / 'code/modules/1713/train_crane.dm').read_text(encoding='utf-8')
        self.assertIn('#include "code\\modules\\1713\\train_goods.dm"', (ROOT / 'civ13.dme').read_text(encoding='utf-8'))
        # the pen is asked first by the train's own attackby, not overridden
        servicing = (ROOT / 'code/modules/1713/train_servicing.dm').read_text(encoding='utf-8')
        self.assertIn('card_use(', servicing)
        self.assertNotIn('/obj/structure/trains/attackby', goods)
        self.assertIn('card_line()', (ROOT / 'code/modules/1713/train_couplings.dm').read_text(encoding='utf-8'))
        self.assertIn('car.card_text()', (ROOT / 'code/modules/1713/train_conductor.dm').read_text(encoding='utf-8'))
        # both cranes share one set of swings
        self.assertIn('train_crane_swings(src, load, ..(), null)', goods)
        self.assertIn('train_crane_swings(src, load, choices, mine.car_id)', crane)
        # yard fixtures stay put under a train
        self.assertIn('/obj/structure/train_livestock_ramp', PLATFORMS)
        # nothing runs on a timer and nothing is bought or sold
        for word in ('spawn(', 'sleep(', 'while (true', 'process(', 'world.time', 'money', 'coin'):
            self.assertNotIn(word, goods.split('// Nothing here buys or sells', 1)[1])
        for name, value in (('LOADING_STAGE_MAX', '3000'), ('LOADING_STAGE_TIME', '40'), ('LIVESTOCK_RAMP_REACH', '3'),
                            ('LIVESTOCK_RAMP_TIME', '40'), ('TRAIN_CARD_LENGTH', '40')):
            self.assertRegex(goods, r'#define %s %s\b' % (name, re.escape(value)))
            self.assertIn('#undef ' + name, goods)
        recipes = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
        nodes = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
        for path in ('/obj/structure/rail_depot/loading_stage', '/obj/structure/workshop_machine/shear_legs/crane/goods',
                     '/obj/structure/train_livestock_ramp'):
            self.assertIn(',%s,' % path, recipes)
            self.assertIn('"%s" = "rail_steam"' % path, nodes)
        yard = set(re.findall(r'state = "([^"]+)"', dmi_description(ROOT / 'icons/obj/vehicles/train_platforms.dmi')))
        depot = set(re.findall(r'state = "([^"]+)"', dmi_description(ROOT / 'icons/obj/vehicles/rail_water.dmi')))
        self.assertLessEqual({'goods_crane', 'goods_crane_haul', 'livestock_ramp'}, yard)
        self.assertLessEqual({'loading_stage_empty', 'loading_stage_coal', 'loading_stage_ore', 'loading_stage_sand'}, depot)

    def test_early_rails_hand_car_animals_and_wooden_track(self):
        early = (ROOT / 'code/modules/1713/train_early.dm').read_text(encoding='utf-8')
        laying = (ROOT / 'code/modules/1713/track_laying.dm').read_text(encoding='utf-8')
        wear = (ROOT / 'code/modules/1713/train_trackwear.dm').read_text(encoding='utf-8')
        hitch = (ROOT / 'code/game/objects/structures/cart_hitch.dm').read_text(encoding='utf-8')
        couplings = (ROOT / 'code/modules/1713/train_couplings.dm').read_text(encoding='utf-8')
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertIn('#include "code\\modules\\1713\\train_early.dm"', dme)
        # the tint is shared by two files, so it is a define of its own
        self.assertIn('#include "code\\__defines\\trains.dm"', dme)
        self.assertIn('#define WOODEN_RAIL_COLOR', (ROOT / 'code/__defines/trains.dm').read_text(encoding='utf-8'))
        self.assertNotIn('#define WOODEN_RAIL_COLOR', early)
        # the hand car rolls free like any car: no loop of its own
        self.assertIn('return start_rolling(min(limit, max(speed, 0.3) + push), way)', early)
        self.assertIsNone(re.search(r'(?<!\w)(spawn|addtimer|sleep) ?\(', early))
        # a harness follows the animal through the moved event and is not saved
        self.assertIn('GLOB.moved_event.register(A, src, /obj/structure/trains/proc/draft_moved)', early)
        self.assertIn('GLOB.moved_event.unregister(A, src, /obj/structure/trains/proc/draft_moved)', early)
        self.assertIn('var/tmp/mob/living/simple_animal/draft_animal', early)
        self.assertIn('var/tmp/obj/structure/trains/hitched_train', early)
        self.assertIn('key == "hitched_train"', hitch)
        self.assertIn('return hitched_train.draft_drag(src)', hitch)
        self.assertIn('car.player_harness(user, src)', hitch)
        # the train's own Destroy and examine ask; nothing is overridden twice
        self.assertIn('\tclear_couplers()\n\tunharness()\n', couplings)
        self.assertIn('var/draft = draft_line()', couplings)
        for proc in ('/obj/structure/trains/Destroy', '/obj/structure/trains/examine', '/obj/structure/rails/after_load',
                     '/obj/structure/rails/examine', '/mob/living/simple_animal/MouseDrop_T'):
            self.assertNotIn(proc + '(', early)
        # wooden rails go down, come up and wear through the existing track code
        self.assertIn('wooden = wood\n\tplace_rails()', laying)
        self.assertIn('R.set_wooden(w)', laying)
        self.assertIn('bent.set_wooden(was_wooden)', laying)
        self.assertIn('B.wooden = wooden', laying)
        self.assertIn('if (wooden)\n\t\tamount *= TRACK_WOODEN_WEAR', wear)
        self.assertIn('set_wooden(wooden)\n\tshow_wear()', wear)
        for name in ('HANDCAR_PUMP_TIME', 'HANDCAR_CREW_TIME', 'HANDCAR_PUSH', 'HANDCAR_SPEED', 'HANDCAR_CREW_SPEED',
                     'HANDCAR_LOAD', 'TRAIN_DRAFT_LOAD', 'TRAIN_DRAFT_SLACK', 'TRAIN_HARNESS_TIME'):
            self.assertIn('#define ' + name, early)
            self.assertIn('#undef ' + name, early)
        for path, node in (('/obj/structure/trains/transport/handcar', 'rail_steam'),
                           ('/obj/structure/trains/storage/chaldron', 'wagons_ships'),
                           ('/obj/item/stack/rail_lengths/wooden', 'wagons_ships'),
                           ('/obj/item/stack/rail_sleepers', 'wagons_ships')):
            self.assertIn(',%s,' % path, RECIPES)
            self.assertIn('"%s" = "%s"' % (path, node), NODES)
        states = set(re.findall(r'state = "([^"]+)"', dmi_description(ROOT / 'icons/obj/vehicles/train_platforms.dmi')))
        self.assertLessEqual({'handcar', 'chaldron'}, states)

    def test_track_works_buffer_stops_and_crossings(self):
        works = (ROOT / 'code/modules/1713/train_trackworks.dm').read_text(encoding='utf-8')
        signals = (ROOT / 'code/modules/1713/train_signals.dm').read_text(encoding='utf-8')
        self.assertIn('#include "code\\modules\\1713\\train_trackworks.dm"', (ROOT / 'civ13.dme').read_text(encoding='utf-8'))
        # the stop is asked before the ordinary crash on a solid object
        hit = TRAINS[TRAINS.index('/obj/structure/trains/proc/rail_hit('):]
        hit = hit[:hit.index('/obj/structure/trains/proc/process_rail_movement(')]
        self.assertLess(hit.index('if (stop.hold(impact))'), hit.index('is_structure_impact_part(O)'))
        self.assertLess(hit.index('if (stop.hold(impact))'), hit.index('stop.smash()'))
        # gates are lineside posts: cabs read them, frames lock them
        self.assertIn('/obj/structure/train_lineside/gate/speaks_to(heading)', works)
        self.assertIn('for (var/obj/structure/train_lineside/gate/G in train_lineside)', signals)
        self.assertIn('if (!G.shut && train_signal_over_gate(S, G))', signals)
        self.assertIn('if (S.clear && train_signal_over_gate(S, G))', signals)
        self.assertIn('if (crossing_frame())', works)
        for word in ('spawn(', 'sleep(', 'while (', 'process('):
            self.assertNotIn(word, works)
        for name in ('TRAIN_BUFFER_HOLD', 'TRAIN_GATE_TIME', 'TRAIN_GATE_REACH'):
            self.assertIn('#undef ' + name, works)
        states = set(re.findall(r'state = "([^"]+)"', dmi_description(ROOT / 'icons/obj/vehicles/train_platforms.dmi')))
        for path, recipe, state in (
                ('/obj/structure/train_buffer_stop', '/material/iron/,buffer stop,/obj/structure/train_buffer_stop,4,', 'buffer_stop'),
                ('/obj/structure/train_crossing_boards', '/material/wood/,crossing boards,/obj/structure/train_crossing_boards,2,', 'crossing_boards'),
                ('/obj/structure/train_lineside/gate', '/material/wood/,crossing gate,/obj/structure/train_lineside/gate,4,', 'crossing_gate_open')):
            self.assertIn('RECIPE: ' + recipe, RECIPES)
            self.assertIn('"%s" = "rail_steam"' % path, NODES)
            self.assertIn('icon_state = "%s"' % state, works)
            self.assertIn(state, states)
        self.assertIn('crossing_gate_shut', states)

    def test_stations_whistles_and_lamps(self):
        stations = (ROOT / 'code/modules/1713/train_stations.dm').read_text(encoding='utf-8')
        signals = (ROOT / 'code/modules/1713/train_signals.dm').read_text(encoding='utf-8')
        self.assertIn('#include "code\\modules\\1713\\train_stations.dm"', (ROOT / 'civ13.dme').read_text(encoding='utf-8'))
        # the night rule is counted with the train, not every step
        self.assertEqual(TRAINS.count('night_factor()'), 1)
        self.assertIn('\tlead_factor = leading_factor(cars) * night_factor()\n', TRAINS)
        self.assertEqual(TRAINS.count('set_light(lamp_range)'), 2)
        self.assertNotIn('set_light(2)', TRAINS)
        self.assertIn('if ("Sound the whistle", "Sound the horn")', TRAINS)
        # a name board speaks both ways
        self.assertIn('if (!S.speaks_to(heading) || !isturf(S.loc))', signals)
        conductor = (ROOT / 'code/modules/1713/train_conductor.dm').read_text(encoding='utf-8')
        self.assertIn('heading += train_tail_lamp_text(cars)', conductor)
        for word in ('spawn(', 'sleep(', 'while (', 'process('):
            self.assertNotIn(word, stations)
        states = set(re.findall(r'state = "([^"]+)"', dmi_description(ROOT / 'icons/obj/vehicles/train_platforms.dmi')))
        for path, recipe, state in (
                ('/obj/item/train_lamp', '/material/iron/,hand lamp,/obj/item/train_lamp,2,', 'hand_lamp'),
                ('/obj/structure/train_lineside/station', '/material/wood/,station name board,/obj/structure/train_lineside/station,4,', 'station_board')):
            self.assertIn('RECIPE: ' + recipe, RECIPES)
            self.assertIn('"%s" = "rail_steam"' % path, NODES)
            self.assertIn('icon_state = "%s"' % state, stations)
            self.assertIn(state, states)
        for shade in ('white', 'red', 'green'):
            self.assertIn('hand_lamp_' + shade, states)

    def test_electric_traction_draws_from_the_grid(self):
        electric = (ROOT / 'code/modules/1713/train_electric.dm').read_text(encoding='utf-8')
        platforms = (ROOT / 'code/modules/1713/train_platforms.dm').read_text(encoding='utf-8')
        decks = (ROOT / 'code/modules/1713/machinery/modular_vehicles/vehicle_decks.dm').read_text(encoding='utf-8')
        self.assertIn('#include "code\\modules\\1713\\train_electric.dm"', (ROOT / 'civ13.dme').read_text(encoding='utf-8'))
        # the layouts join the others through one call, not a second layout proc
        self.assertIn('\t\ttrain_locomotive_layouts(layouts)\n\t\ttrain_electric_layouts(layouts)\n', platforms)
        for kind, cab2 in (('electric', 4), ('tram', 4)):
            self.assertIn('"body" = "%s", "cab" = 1, "cab2" = %d, "roof" = "loco_%s"' % (kind, cab2, kind), electric)
        # no fuel: the engine never burns, never stalls dry, and asks the line instead
        self.assertIn('\tmax_fuel = 0\n\tfuel = 1\n', electric)
        self.assertIn('/obj/structure/trains/locomotive/electric/fuel_per_tile(notch, weight)\n\treturn 0\n', electric)
        self.assertIn('/obj/structure/trains/locomotive/electric/steam_factor()\n\treturn line_check() ? 1 : 0\n', electric)
        # the base engine asks through hooks; nothing of it is overridden from this file
        self.assertIn("<span class = 'warning'>[no_power_text()]</span>", TRAINS)
        self.assertIn('\t\tset_light(0)\n\t\tdrive_ended()\n', TRAINS)
        for proc in ('/obj/structure/trains/locomotive/work_control', '/obj/structure/trains/locomotive/drive(',
                     '/obj/structure/trains/locomotive/refresh_consist', '/obj/structure/trains/platform/'):
            self.assertNotIn(proc, electric)
        # the line is a consumer of the cable grid: no loop, no timer of its own
        self.assertIn('if (M.draw_cable_power())', electric)
        self.assertIsNone(re.search(r'(?<!\w)(spawn|addtimer|sleep|while) ?\(', electric.replace('while (pending.len)', '')))
        self.assertIn('power_point_moved()', electric)
        # a line that cannot carry one more engine refuses that engine only
        self.assertIn('\tdrawing -= L\n\tdrawn_at -= L\n\tenergise()\n\treturn FALSE\n', electric)
        # every section of the tram that people ride in has a roof of its own
        self.assertIn('seg_index != L["cab2"] && segment_layout()["solid"])', decks)
        self.assertIn('(seg_index == L["cab"] ? "" : "m")', decks)
        self.assertIn('train_catenary_strike(H, back_dir)', decks)
        # file-local defines are undefined again
        for name in re.findall(r'(?m)^#define (\w+)', electric):
            self.assertIn('#undef ' + name, electric)
        for path, recipe in (
                ('/obj/structure/train_catenary', '/material/steel/,overhead line mast,/obj/structure/train_catenary,4,'),
                ('/obj/structure/train_car_kit/loco_electric', '/material/steel/,electric locomotive kit,/obj/structure/train_car_kit/loco_electric,55,'),
                ('/obj/structure/train_car_kit/loco_tram', '/material/steel/,tram kit,/obj/structure/train_car_kit/loco_tram,30,')):
            self.assertIn('RECIPE: ' + recipe, RECIPES)
            self.assertIn('"%s" = "electricity"' % path, NODES)
        states = set(re.findall(r'state = "([^"]+)"', dmi_description(ROOT / 'icons/obj/vehicles/train_platforms.dmi')))
        for kind in ('electric', 'tram'):
            for seg in '1234':
                for col in 'lcr':
                    self.assertIn('loco_%s_%s%s' % (kind, seg, col), states)
            for col in 'lcr':
                self.assertIn('roof_loco_%s_%s' % (kind, col), states)
                self.assertIn('roof_loco_%s_b%s' % (kind, col), states)
        for col in 'lcr':
            self.assertIn('roof_loco_tram_m' + col, states)
        for state in ('catenary_mast', 'catenary_arm', 'catenary_hanger', 'catenary_wire'):
            self.assertIn(state, states)
            self.assertIn('"%s"' % state, electric)

    def test_native_fixture_preparation(self):
        generated = run.sources()
        self.assertIn('#include "tests/train_platforms/probe.dm"', generated[run.PREFIX + '.dme'])
        self.assertNotRegex(generated[run.PREFIX + '.dme'], r'(?m)^#include ".*\.dmm"')


if __name__ == '__main__':
    unittest.main()
