"""Execute bicycle production control flow with explicit fake engine boundaries.

These offline projections do not establish native collision or graphical riding.
"""
from pathlib import Path
from types import SimpleNamespace as NS
import re
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests/save_movement'))
from source_adapter import extract, project

PATH = 'code/game/objects/structures/bicycle.dm'
SOURCE = (ROOT / PATH).read_text()
BASE = '/obj/structure/vehicle/bicycle'


def compile_proc(path, args, env, members=(), source=SOURCE):
    body = extract(source, path)
    pieces = re.split(r'("(?:[^"\\]|\\.)*")', body)
    for i in range(0, len(pieces), 2):
        for name in members:
            pieces[i] = re.sub(r'(?<![\w.])' + name + r'\b', 'src.' + name, pieces[i])
    body = ''.join(pieces)
    for typepath in ('/obj/item/weapon/gun/projectile', '/obj/item/ammo_magazine'):
        body = body.replace(typepath, repr(typepath))
    return project(path + '(' + args + ')\n' + body, path, args, env)


def math_procs(source=SOURCE):
    env = {'max': max, 'Clamp': lambda n, low, high: max(low, min(n, high))}
    ratio = compile_proc('/proc/bicycle_load_ratio', 'carried_weight, strength', env, source=source)
    delay = compile_proc('/proc/bicycle_step_delay', 'load_ratio', env, source=source)
    cost = compile_proc('/proc/bicycle_step_cost', 'load_ratio', env, source=source)
    return ratio, delay, cost


def weight_proc():
    env = {'max': max, 'typed_iter': lambda items, path: items,
           'istype': lambda item, path: item.kind == path}
    weight = compile_proc('/proc/bicycle_carried_weight', 'container', env)
    env['bicycle_carried_weight'] = weight
    return weight


def item(weight=0, contents=(), kind='item'):
    return NS(get_weight=lambda: weight, contents=list(contents), kind=kind)


def rider_fixture():
    b = NS(driver=None, health=100, loc='road', anchored=False, dwheel=NS(), ontop=[], gcDestroyed=False)
    h = NS(client=True, stat=0, driver_vehicle=b, driver=True, buckled=b, loc='road',
           frozen=False, legcuffed=None, l_hand=b.dwheel, r_hand=None, disabled=False,
           parts={part: NS(is_stump=lambda: False) for part in ('l_leg', 'r_leg', 'l_foot', 'r_foot')})
    h.incapacitated = lambda flags: h.disabled
    h.ssd_check = lambda: not h.client
    h.get_organ = lambda part: h.parts.get(part)
    b.driver = h
    b.dwheel.loc = h
    b.ontop = [h]
    env = dict(src=b, CONSCIOUS=0, isturf=lambda loc: loc == 'road',
               persistence_input_frozen=lambda client: h.frozen,
               INCAPACITATION_DISABLED=1, INCAPACITATION_RESTRAINED=2,
               list=lambda *args: list(args))
    ready = compile_proc(BASE + '/proc/rider_ready', '', env,
                         ('driver', 'health', 'loc', 'anchored', 'dwheel', 'ontop'))
    return b, h, ready


def move_fixture(source=SOURCE, blocked=False):
    ratio, delay, cost = math_procs(source)
    ground_env = {}
    ground_delay = compile_proc('/proc/bicycle_ground_delay', 'step_delay, rough, snowy', ground_env, source=source)
    ground_cost = compile_proc('/proc/bicycle_ground_cost', 'step_cost, rough, levels', ground_env, source=source)
    b, h, ready = rider_fixture()
    b.ground = [False, False, 0]
    b.ground_ahead = lambda start, target: dict(enumerate(b.ground, 1))
    b.slope = 0
    h.dir = 4
    h.stamina = 10
    h.weight = 0
    h.stats = {'stamina': {1: 10}}
    h.getStat = lambda stat: h.stats[stat][1]
    h.getStatCoeff = lambda stat: 1
    h.forceMove = lambda target: setattr(h, 'loc', target)
    b.moving = True
    b.pedal_next_move = 0
    b.vehicle_m_delay = 1.5
    b.allowed = True
    b.do_vehicle_check = lambda: b.allowed
    b.updated = False
    b.update_icon = lambda: setattr(b, 'updated', True)
    lease = NS(members=[b, h], released=False)
    lease.release = lambda: setattr(lease, 'released', True)
    b.claim_ride_glides = lambda direction, interval: lease
    moves = []
    def move(target, direction):
        moves.append((target, direction))
        if not blocked:
            b.loc = target
        return not blocked
    b.Move = move
    env = dict(src=b, world=NS(time=100), cardinal=[1, 2, 4, 8], max=max,
               bicycle_ground_delay=ground_delay, bicycle_ground_cost=ground_cost,
               terrain_slope_delay=lambda start, target, step: b.slope,
               Clamp=lambda n, low, high: max(low, min(n, high)),
               bicycle_load_ratio=ratio, bicycle_step_delay=delay,
               bicycle_step_cost=cost, bicycle_carried_weight=lambda actor: actor.weight,
               to_chat=lambda *args: None, SPAN_WARNING=lambda text: text,
               get_turf=lambda atom: atom.loc, get_step=lambda atom, direction: 'destination',
               typed_iter=lambda items, path: list(items))
    members = ('moving', 'pedal_next_move', 'do_vehicle_check', 'driver',
               'vehicle_m_delay', 'claim_ride_glides', 'ground_ahead', 'Move', 'loc', 'update_icon', 'gcDestroyed')
    move = compile_proc(BASE + '/do_move', 'm_dir=None, interval=None', env, members, source)
    return b, h, lease, moves, env, move


class BicycleMath(unittest.TestCase):
    def test_load_intervals_and_costs(self):
        ratio, delay, cost = math_procs()
        for weight, expected_delay, expected_cost in ((0, 1.5, .5), (29.5, 2.25, .75), (59, 3, 1), (177, 6, 2)):
            self.assertAlmostEqual(delay(ratio(weight, 1)), expected_delay)
            self.assertAlmostEqual(cost(ratio(weight, 1)), expected_cost)

    def test_monotonic_and_bounded(self):
        ratio, delay, cost = math_procs()
        previous = (0, 0)
        for weight in range(1000):
            values = delay(ratio(weight, 1)), cost(ratio(weight, 1))
            self.assertGreaterEqual(values[0], previous[0])
            self.assertGreaterEqual(values[1], previous[1])
            self.assertTrue(1.5 <= values[0] <= 6)
            self.assertTrue(.5 <= values[1] <= 2)
            previous = values

    def test_zero_negative_huge_and_strength(self):
        ratio, delay, cost = math_procs()
        self.assertEqual(delay(ratio(-10, 1)), 1.5)
        self.assertEqual(cost(ratio(10**20, -3)), 2)
        self.assertEqual(delay(ratio(10**20, -3)), 6)
        self.assertLess(delay(ratio(59, 2)), delay(ratio(59, 1)))

    def test_recursive_inventory_without_double_ammo(self):
        magazine = item(3, [item(2)], '/obj/item/ammo_magazine')
        gun = item(9, [magazine], '/obj/item/weapon/gun/projectile')
        pack = item(2, [item(1, [item(20)]), gun])
        worn = item(1, [item(4)])
        self.assertEqual(weight_proc()(item(0, [pack, worn, magazine])), 40)
        self.assertEqual(weight_proc()(item(0, [item(-20), item(4)])), 4)

    def test_removed_weight_penalty_is_detected(self):
        mutated = SOURCE.replace('1.5 * (1 + max(0, load_ratio))', '1.5')
        self.assertNotEqual(mutated, SOURCE)
        ratio, delay, _ = math_procs(mutated)
        self.assertEqual(delay(ratio(59, 1)), delay(ratio(0, 1)))


class BicycleRider(unittest.TestCase):
    def test_ready_and_disconnected(self):
        b, h, ready = rider_fixture()
        self.assertTrue(ready())
        h.client = None
        self.assertFalse(ready())

    def test_invalid_links_controls_and_status(self):
        for name, value in (('stat', 1), ('driver_vehicle', None), ('driver', False),
                            ('buckled', None), ('loc', 'elsewhere'), ('legcuffed', True),
                            ('disabled', True), ('frozen', True), ('l_hand', None)):
            with self.subTest(name=name):
                b, h, ready = rider_fixture()
                setattr(h, name, value)
                self.assertFalse(ready())
        b, h, ready = rider_fixture()
        b.ontop = []
        self.assertFalse(ready())
        b, h, ready = rider_fixture()
        b.anchored = True
        self.assertFalse(ready())

    def test_missing_or_stump_leg(self):
        b, h, ready = rider_fixture()
        del h.parts['l_leg']
        self.assertFalse(ready())
        h.parts['l_leg'] = NS(is_stump=lambda: True)
        self.assertFalse(ready())


class BicycleMove(unittest.TestCase):
    def test_success_charges_one_step_and_updates_interval(self):
        b, h, lease, moves, env, move = move_fixture()
        h.weight = 59
        self.assertTrue(move(4))
        self.assertEqual(h.loc, b.loc)
        self.assertEqual(h.stats['stamina'][1], 9)
        self.assertEqual(b.vehicle_m_delay, 3)
        self.assertEqual(b.pedal_next_move, 103)
        self.assertEqual(len(moves), 1)
        self.assertFalse(lease.released)
        self.assertIsNone(h.carriage_glide_step)

    def test_blocked_native_move_charges_no_stamina(self):
        b, h, lease, moves, env, move = move_fixture(blocked=True)
        self.assertFalse(move(4))
        self.assertEqual(h.stats['stamina'][1], 10)
        self.assertEqual(h.loc, 'road')
        self.assertTrue(lease.released)

    def test_exhaustion_never_goes_negative(self):
        b, h, lease, moves, env, move = move_fixture()
        h.stats['stamina'][1] = .49
        self.assertFalse(move(4))
        self.assertEqual(moves, [])
        self.assertEqual(h.stats['stamina'][1], .49)
        h.stats['stamina'][1] = .5
        self.assertTrue(move(4))
        self.assertEqual(h.stats['stamina'][1], 0)

    def test_cooldown_prevents_duplicate_or_brake_restart_steps(self):
        b, h, lease, moves, env, move = move_fixture()
        self.assertTrue(move(4))
        self.assertFalse(move(4))
        b.moving = False
        b.moving = True
        self.assertFalse(move(4))
        self.assertEqual(len(moves), 1)
        self.assertEqual(h.stats['stamina'][1], 9.5)

    def test_late_tick_keeps_the_schedule_but_a_long_stop_does_not_bank_time(self):
        b, h, lease, moves, env, move = move_fixture()
        b.pedal_next_move = 99.6
        self.assertTrue(move(4))
        self.assertAlmostEqual(b.pedal_next_move, 101.1)
        b, h, lease, moves, env, move = move_fixture()
        b.pedal_next_move = 50
        self.assertTrue(move(4))
        self.assertAlmostEqual(b.pedal_next_move, 101.5)
        start = extract(SOURCE, BASE + '/startmovementloop')
        self.assertIn('pedal_next_move = max(pedal_next_move, world.time)', start)

    def test_rejects_bad_terrain_invalid_direction_or_stopped(self):
        for direction, allowed, moving in ((4, False, True), (5, True, True), (4, True, False)):
            b, h, lease, moves, env, move = move_fixture()
            b.allowed, b.moving = allowed, moving
            self.assertFalse(move(direction))
            self.assertEqual(moves, [])

    def test_redirected_driver_is_not_teleported_back(self):
        b, h, lease, moves, env, move = move_fixture()
        def redirect(target, direction):
            b.loc = target
            h.loc = 'teleport'
            return True
        b.Move = redirect
        self.assertFalse(move(4))
        self.assertEqual(h.loc, 'teleport')
        self.assertTrue(lease.released)

    def test_weight_changes_are_read_each_leg(self):
        b, h, lease, moves, env, move = move_fixture()
        self.assertTrue(move(4))
        b.loc = h.loc = 'road'
        h.weight = 177
        env['world'].time = b.pedal_next_move
        self.assertTrue(move(4))
        self.assertEqual(b.vehicle_m_delay, 6)
        self.assertEqual(h.stats['stamina'][1], 7.5)


class BicycleGround(unittest.TestCase):
    def test_rough_ground_and_snow_slow_and_tire(self):
        b, h, lease, moves, env, move = move_fixture()
        b.ground = [True, True, 0]
        self.assertTrue(move(4))
        self.assertAlmostEqual(b.vehicle_m_delay, 1.5 * 1.25 + 1)
        self.assertAlmostEqual(h.stats['stamina'][1], 10 - .625)

    def test_climbing_costs_more_and_adds_slope_delay(self):
        b, h, lease, moves, env, move = move_fixture()
        b.ground = [True, False, 2]
        b.slope = 2
        self.assertTrue(move(4))
        self.assertAlmostEqual(b.vehicle_m_delay, 1.875 + 2)
        self.assertAlmostEqual(h.stats['stamina'][1], 10 - (.625 + 1))

    def test_coasting_downhill_is_free_even_when_exhausted(self):
        b, h, lease, moves, env, move = move_fixture()
        b.ground = [True, False, -2]
        b.slope = -.46875
        h.stats['stamina'][1] = 0
        self.assertTrue(move(4))
        self.assertEqual(h.stats['stamina'][1], 0)
        self.assertAlmostEqual(b.vehicle_m_delay, 1.875 - .46875)

    def test_interval_is_bounded(self):
        b, h, lease, moves, env, move = move_fixture()
        b.slope = -5
        self.assertTrue(move(4))
        self.assertEqual(b.vehicle_m_delay, 1)
        b, h, lease, moves, env, move = move_fixture()
        b.slope = 50
        self.assertTrue(move(4))
        self.assertEqual(b.vehicle_m_delay, 10)

    def test_ground_reads_the_tile_ahead(self):
        body = extract(SOURCE, BASE + '/proc/ground_ahead')
        for call in ('target.terrain_smoothed()', 'target.has_snow_cover()', 'target.terrain_floor_covered()',
                     'terrain_step_levels(start, target)'):
            self.assertIn(call, body)


class BicycleArt(unittest.TestCase):
    def test_own_sprite_sheet_is_current_and_wired(self):
        # The hosted baseline has no imaging library: pin the committed sheet
        # by hash, and redraw it for comparison only where Pillow is installed.
        import hashlib
        import importlib.util
        import subprocess
        sheet = (ROOT / 'icons/obj/vehicles/bicycle.dmi').read_bytes()
        self.assertEqual(hashlib.sha256(sheet).hexdigest(), 'bcd47e849309fa098fcf16149a3f1e678efba6c6fae4d82c959e7ce8217d621e')
        self.assertIn(b'state = "bicycle_overlay"', __import__('zlib').decompressobj().decompress(sheet[sheet.index(b'zTXtDescription') + 17:]))
        # Wheels touch the ground: the tile's bottom pixel row is drawn in every view.
        if importlib.util.find_spec('PIL'):
            from PIL import Image
            art = Image.open(ROOT / 'icons/obj/vehicles/bicycle.dmi').convert('RGBA')
            for i in range(4):
                tile = art.crop(((i % 3) * 32, (i // 3) * 32, (i % 3) * 32 + 32, (i // 3) * 32 + 32))
                self.assertTrue(any(tile.getpixel((x, 31))[3] for x in range(32)), i)
        if importlib.util.find_spec('PIL'):
            subprocess.run([sys.executable, str(ROOT / 'tests/pedal_bicycle/sprites.py'), '--check'], check=True)
        self.assertIn("icon = 'icons/obj/vehicles/bicycle.dmi'", SOURCE)
        self.assertNotIn('motorcycle_frame', SOURCE)
        overlay = extract(SOURCE, BASE + '/update_overlay')
        self.assertIn('overlays -= rider_overlay', overlay)
        self.assertIn('if (driver)', overlay)


class BicycleWiring(unittest.TestCase):
    def test_timer_and_lifecycle_contracts(self):
        start = extract(SOURCE, BASE + '/startmovementloop')
        self.assertIn('moving || pedal_busy || !rider_ready()', start)
        self.assertIn('pedal_next_move - world.time', start)
        stop = extract(SOURCE, BASE + '/stopmovementloop')
        self.assertIn('deltimer(pedal_timer)', stop)
        self.assertIn('release_carriage_glides()', stop)
        self.assertNotIn('pedal_next_move =', stop)
        for proc in ('/unbuckle_mob', '/controls_released'):
            self.assertIn('stopmovementloop()', extract(SOURCE, BASE + proc))
        self.assertIn('deltimer(pedal_safety_timer)', extract(SOURCE, BASE + '/Destroy'))
        save = extract(SOURCE, BASE + '/persistence_runtime_var')
        for field in ('pedal_timer', 'pedal_safety_timer', 'pedal_next_move', 'pedal_busy', 'rider_overlay', 'moving', 'movement_processes'):
            self.assertIn('"' + field + '"', save)

    def test_restore_does_not_duplicate_controls_or_resume_motion(self):
        constructor = extract(SOURCE, BASE + '/New')
        self.assertLess(constructor.index('if (!persistence_saved_atom_construction)'),
                        constructor.index('dwheel = new'))
        safety = extract(SOURCE, BASE + '/safety_check')
        self.assertIn('gcDestroyed || persistence_saved_atom_construction', safety)
        restore = extract(SOURCE, BASE + '/persistence_restore_finished')
        self.assertIn('stopmovementloop()', restore)
        self.assertIn('dwheel.origin = src', restore)
        self.assertIn('if (!pedal_safety_timer)', restore)

    def test_ground_collision_and_grace_guards(self):
        check = extract(SOURCE, BASE + '/do_vehicle_check')
        for guard in ('/turf/floor/broken_floor', '/turf/floor/beach/water', '/turf/floor/trench/flooded',
                      'map.check_caribbean_block(driver, T)', 'map.caribbean_blocking_area_types.Find(A.type)'):
            self.assertIn(guard, check)
        body = extract(SOURCE, BASE + '/do_move')
        self.assertIn('Move(target, m_dir)', body)
        self.assertNotIn('forceMove(get_step', body)
        self.assertNotIn('adjustBruteLoss', SOURCE)

    def test_boarding_revalidates_after_wait(self):
        board = extract(SOURCE, BASE + '/MouseDrop_T')
        before, after = board.split('if (!do_after(user, 20, src))')
        for guard in ('user.buckled', 'user.driver', 'user.Adjacent(src)', 'user.incapacitated()'):
            self.assertIn(guard, before)
            self.assertIn(guard, after)
        self.assertIn('if (!buckle_mob(user))', after)

    def test_recipe_and_research_and_include(self):
        self.assertIn('code\\game\\objects\\structures\\bicycle.dm', (ROOT / 'civ13.dme').read_text())
        self.assertIn('RECIPE: /material/steel/,pedal bicycle,/obj/structure/vehicle/bicycle,12,200,1,1,vehicle parts,95,0,0,8,null',
                      (ROOT / 'config/crafting/material_recipes_global.txt').read_text())
        self.assertIn('"/obj/structure/vehicle/bicycle" = "factories"',
                      (ROOT / 'code/modules/research_tree/research_node.dm').read_text())


if __name__ == '__main__':
    unittest.main()
