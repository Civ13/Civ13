"""Restricted production-body projections; no native engine, renderer or savefile."""
from pathlib import Path
import re
import subprocess
from types import SimpleNamespace as NS
import unittest

from source_contract import without_season_snow

ROOT = Path(__file__).resolve().parents[2]
FILE = ROOT / 'code/modules/1713/snowfall_ground.dm'
SOURCE = FILE.read_text() + (ROOT / 'code/processes/snowfall_ground.dm').read_text()
BASE = 'fa363b8a01ed7d936c10a6303ce1be4c26d82ab0'


def body(source, signature):
    return re.search('^' + re.escape(signature) + r'\n(.*?)(?=^/|\Z)', source, re.M | re.S).group(1)


def project(signature):
    instructions = {
        'if (persistence_save_in_progress || persistence_active_operation || persistence_load_recovery_required || !snowfall_ground_eligible() || locate(x, y, z) != src)':
            'if self.blocked or not self.eligible() or not self.current:',
        'if (persistence_save_in_progress || persistence_active_operation || persistence_load_recovery_required || locate(x, y, z) != src)':
            'if self.blocked or not self.current:',
        'return': 'return', 'return FALSE': 'return False', 'return TRUE': 'return True',
        'if (isnull(expected_generation) || isnull(generated_source) || expected_generation != snowfall_ground_generation)':
            'if expected_generation is None or generated_source is None or expected_generation != self.generation:',
        'if (isnull(generated_source))': 'if generated_source is None:',
        'generated_source = weather_snow > 0': 'generated_source = self.weather_snow > 0',
        'if (generated_source)': 'if generated_source:',
        'return weather_snow': 'return self.weather_snow',
        'return icon == \'icons/turf/snow.dmi\' ? available_snow : 0': 'return self.available_snow if self.native_snow else 0',
        'if (weather_snow > 0 || icon != \'icons/turf/snow.dmi\' || available_snow <= 0)':
            'if self.weather_snow > 0 or not self.native_snow or self.available_snow <= 0:',
        'var/had_snow = weather_snow > 0': 'had_snow = self.weather_snow > 0',
        'if (had_snow != (weather_snow > 0))': 'if had_snow != (self.weather_snow > 0):',
        'var/local_c = get_temp(src)': 'local_c = self.temperature()',
        'if (local_c > SNOWFALL_MELT_C)': 'if local_c > 2:',
        'weather_snow = 0': 'self.weather_snow = 0',
        'else if (accumulate && snowing && local_c <= SNOWFALL_STICK_C && snowfall_ground_exposed())':
            'elif accumulate and snowing and local_c <= 0 and self.exposed():',
        'var/area/A = get_area(src)': 'A = self.area',
        'var/precipitation = replacetext("[A.icon_state]", "rad_", "")':
            'precipitation = A.icon_state.replace("rad_", "")',
        'var/snowing = (A.weather == WEATHER_WET || A.weather == WEATHER_EXTREME) && A.weather_intensity > 0 && (precipitation in list("snow1", "snow2", "snow_storm"))':
            'snowing = A.weather in (2, 3) and A.weather_intensity > 0 and precipitation in ("snow1", "snow2", "snow_storm")',
        'if (weather_snow <= 0 && !snowing)': 'if self.weather_snow <= 0 and not snowing:',
        'weather_snow = min(SNOWFALL_MAX_UNITS, weather_snow + 1)': 'self.weather_snow = min(2, self.weather_snow + 1)',
        'snowfall_ground_icon()': 'self.icon()',
        'return type == /turf/floor/dirt || type == /turf/floor/grass': 'return self.kind in ("dirt", "grass")',
        'if (!istype(A, /area/caribbean) || A.location != AREA_OUTSIDE || (locate(/obj/roof) in src) || (locate(/obj/covers) in src))':
            'if not A.caribbean or not A.outside or self.roof or self.floor_cover:',
        'var/turf/above = GetAbove(src)': 'above = self.above',
        'while (above)': 'while above:',
        'if (!istype(above, /turf/sky) && !istype(above, /turf/floor/broken_floor) && !istype(above, /turf/floor/space))':
            'if above.kind not in ("sky", "broken_floor", "space"):',
        'if ((locate(/obj/roof) in above) || (locate(/obj/covers) in above))': 'if above.roof or above.floor_cover:',
        'above = GetAbove(above)': 'above = above.above',
        'return weather_snow > 0 || icon == \'icons/turf/snow.dmi\'': 'return self.weather_snow > 0 or self.native_snow',
        'return weather_snow > 0 ? weather_snow : available_snow': 'return self.weather_snow if self.weather_snow > 0 else self.available_snow',
        'if (weather_snow > 0)': 'if self.weather_snow > 0:',
        'snowfall_ground_check(FALSE)': 'self.check(False)',
        'if (weather_snow <= 0)': 'if self.weather_snow <= 0:',
        'weather_snow--': 'self.weather_snow -= 1',
        'if (available_snow <= 0)': 'if self.available_snow <= 0:',
        'available_snow--': 'self.available_snow -= 1',
        '..()': 'pass',
        'weather_snow = snowfall_ground_eligible() && isnum(weather_snow) ? clamp(round(weather_snow), 0, SNOWFALL_MAX_UNITS) : 0':
            'self.weather_snow = min(2, max(0, round(self.weather_snow))) if self.eligible() and isinstance(self.weather_snow, (int, float)) else 0',
        'snowfall_ground_register()': 'self.register()',
        'if (snowfall_ground_eligible())': 'if self.eligible():',
        'snowfall_ground_generation = ++next_snowfall_ground_generation': 'self.generation += 1',
    }
    lines = ['def execute(self, accumulate=True, expected_generation=None, generated_source=None):']
    for raw in body(SOURCE, signature).splitlines():
        raw = raw.split('//', 1)[0].rstrip()
        if not raw.strip():
            continue
        depth = len(raw) - len(raw.lstrip('\t'))
        lines.append('    ' * depth + instructions[raw.strip()])
    env = {}
    exec('\n'.join(lines), env)
    return env['execute']


class Tile:
    funcs = {name: project(signature) for name, signature in {
        'check': '/turf/proc/snowfall_ground_check(accumulate = TRUE)',
        'eligible': '/turf/proc/snowfall_ground_eligible()',
        'exposed': '/turf/proc/snowfall_ground_exposed()',
        'has_snow': '/turf/proc/has_snow_cover()',
        'units': '/turf/proc/snow_units(generated_source = null)',
        'take': '/turf/proc/take_snow(expected_generation = null, generated_source = null)',
        'load': '/turf/floor/after_load()',
    }.items()}

    def __init__(self, kind='grass', c=-10, precip='snow2'):
        self.kind, self.c, self.weather_snow = kind, c, 0
        self.blocked, self.current, self.roof, self.floor_cover = False, True, False, False
        self.area = NS(caribbean=True, outside=True, weather=2, weather_intensity=1, icon_state=precip)
        self.above, self.native_snow, self.available_snow = None, False, 0
        self.appearance, self.images, self.registered, self.calls = [], None, False, 0
        self.soil, self.loose_dirt, self.contents = 83, 3, ['well', 'player']
        self.heat = []
        self.generation = 1
        self.replacements = []

    def __getattr__(self, key):
        if key in self.funcs:
            if key == 'take':
                return lambda expected_generation=None, generated_source=None: self.funcs[key](self, expected_generation=expected_generation, generated_source=generated_source)
            if key == 'units':
                return lambda generated_source=None: self.funcs[key](self, generated_source=generated_source)
            return lambda *args: self.funcs[key](self, *args)
        raise AttributeError(key)

    def icon(self):
        # Image/list renderer adapter, not BYOND image identity/rendering evidence.
        self.images = 'snow image' if self.weather_snow else None
        self.appearance = [self.images] if self.images else []

    def register(self):
        self.registered = self.eligible()

    def replace(self, kind):
        self.replacements.append(kind)
        self.kind = kind

    def temperature(self):
        # Project the actual shared heat-source tail. Climate prefix is injected.
        text = (ROOT / 'code/modules/1713/weather.dm').read_text()
        tail = text[text.index('\tif (loc_temp < 22)\n\t\tfor (var/obj/structure/brazier'):]
        tail = tail.split('\n\treturn loc_temp', 1)[0]
        c = self.c
        self.calls += 1
        loops = re.findall(r'for \(var/obj/structure/([^/]+(?:/fireplace)?)/(\w+) in range\((\d), A\)\)\n\t\t\tif \(\2.on\)\n\t\t\t\tloc_temp = 22\n\t\t\t\tbreak', tail)
        if len(loops) != 4:
            raise AssertionError('production heat tail changed')
        for kind, _, radius in loops:
            if c < 22 and any(h.kind == kind and h.on and h.distance <= int(radius) for h in self.heat):
                c = 22
        return c


def shovel_action(hand=False):
    """Execute the actual normal-intent snow branch with an injected wait/actor."""
    text = (ROOT / 'code/game/turfs/floor_attackby.dm').read_text()
    indentation = '\t' * (3 if hand else 4)
    start = re.search('^' + indentation + re.escape('if (T.has_snow_cover() && istype(H))'), text, re.M).start()
    end = text.index('\n' + indentation + 'else if ', start)
    operations = {
        'if (T.has_snow_cover() && istype(H))': 'if T.has_snow():',
        'if (T.snow_units(generated_source) <= 0)': 'if T.units(generated_source) <= 0:',
        'return': 'return',
        'H.shoveling = TRUE': 'H.shoveling = True', 'H.shoveling = FALSE': 'H.shoveling = False',
        'if (!do_after(user, (60/(H.getStatCoeff("strength"))/SH.usespeed)))': 'if not wait(T):',
        'if (!do_after(user, rand(25,30)))': 'if not wait(T):',
        'if (!T || T.snow_units(generated_source) <= 0)': 'if T is None or T.units(generated_source) <= 0:',
        'if (!T.take_snow(snow_generation, generated_source))': 'if not T.take(snow_generation, generated_source):',
        'new /obj/item/weapon/snowwall(T)': 'piles.append(T)',
        'if (istype(T, /turf/floor/winter/grass))': 'if T.kind == "winter/grass":',
        'T.ChangeTurf(/turf/floor/grass)': 'T.replace("grass")',
        'else if (istype(T, /turf/floor/dirt/winter))': 'elif T.kind == "dirt/winter":',
        'T.ChangeTurf(/turf/floor/dirt)': 'T.replace("dirt")',
    }
    lines = ['def execute(T, H, wait, piles):', '    snow_generation = T.generation', '    generated_source = T.weather_snow > 0']
    for raw in text[start:end].splitlines():
        if not raw.strip(): continue
        depth = len(raw) - len(raw.lstrip('\t')) - (len(indentation) - 1)
        code = raw.strip()
        if code.startswith('H.adaptStat('):
            translated = 'H.strength = getattr(H, "strength", 0) + 1'
        elif code.startswith('user.visible_message(') and (' shovels snow into a pile.' in code or ' collects the snow into a pile.' in code):
            translated = 'H.success = getattr(H, "success", 0) + 1'
        elif code.startswith(('to_chat(', 'user.visible_message(', 'playsound(')):
            translated = 'pass' # Transport adapters only; success/stat effects are tracked.
        else: translated = operations[code]
        lines.append('    ' * depth + translated)
    env = {}; exec('\n'.join(lines), env)
    return env['execute']


class SnowTests(unittest.TestCase):
    def test_generated_wait_cannot_fall_back_after_clear_or_melt_and_never_rewards_rejection(self):
        # Ordinary dirt defaults to legacy stock zero. Two is an injected control.
        for hand in (False, True):
            run = shovel_action(hand)
            for stock in (0, 2):
                for event in ('cleared', 'melted', 'warms_inside_debit'):
                    t = Tile(kind='dirt'); t.weather_snow = 1; t.available_snow = stock
                    actor, piles = NS(shoveling=False, strength=0, success=0), []
                    def wait(tile):
                        if event == 'cleared': self.assertTrue(tile.take(tile.generation, True))
                        else:
                            tile.c = 22
                            if event == 'melted': tile.check()
                        return True
                    run(t, actor, wait, piles)
                    self.assertEqual((piles, actor.strength, actor.success), ([], 0, 0), (hand, stock, event))
                    self.assertEqual((t.weather_snow, t.available_snow, t.soil, t.loose_dirt), (0, stock, 83, 3))

    def test_two_legitimate_collectors_can_each_take_one_unit_with_one_cover_lifetime(self):
        for hand in (False, True):
            t = Tile(kind='dirt'); t.check(); generation = t.generation
            t.check(); self.assertEqual(t.generation, generation, 'positive unit increase changed lifetime')
            run = shovel_action(hand)
            a, b, piles = NS(shoveling=False), NS(shoveling=False), []
            def wait(tile):
                run(tile, b, lambda target: True, piles)
                self.assertEqual((tile.weather_snow, tile.generation), (1, generation))
                return True
            run(t, a, wait, piles)
            self.assertEqual((len(piles), t.weather_snow), (2, 0))
            self.assertNotEqual(t.generation, generation)
            self.assertEqual((a.strength, a.success, b.strength, b.success), (1, 1, 1, 1))

    def test_clear_and_reaccumulate_invalidates_the_old_wait_in_both_handlers(self):
        for hand in (False, True):
            t = Tile(kind='dirt'); t.check()
            a, b, piles = NS(shoveling=False, strength=0, success=0), NS(shoveling=False), []
            run = shovel_action(hand)
            def wait(tile):
                run(tile, b, lambda target: True, piles)
                self.assertEqual(tile.weather_snow, 0)
                tile.check() # Actual eligible snowfall starts a new layer.
                return True
            run(t, a, wait, piles)
            self.assertEqual((len(piles), t.weather_snow, a.strength, a.success), (1, 1, 0, 0))

    def test_source_identity_is_required_and_bare_ground_hides_injected_legacy_stock(self):
        t = Tile(kind='dirt'); t.available_snow = 2
        self.assertEqual((t.units(), t.units(True), t.units(False)), (0, 0, 0))
        self.assertFalse(t.take(t.generation, False)); self.assertEqual(t.available_snow, 2)
        t.check()
        self.assertFalse(t.take(t.generation))
        self.assertFalse(t.take(None, True))
        self.assertEqual(t.weather_snow, 1)

    def test_actual_shovel_branch_clears_generated_cover_to_same_dirt_without_repeat_yields(self):
        run = shovel_action()
        t = Tile(kind='dirt'); t.check(); t.check()
        before = (id(t), t.kind, t.soil, t.loose_dirt, t.contents.copy())
        actor, piles = NS(shoveling=False), []
        for _ in range(3): run(t, actor, lambda tile: True, piles)
        self.assertEqual((t.weather_snow, len(piles), t.replacements), (0, 2, []))
        self.assertEqual((id(t), t.kind, t.soil, t.loose_dirt, t.contents), before)
        t.area.icon_state = ''; t.check(); run(t, actor, lambda tile: True, piles)
        self.assertEqual(len(piles), 2, 'cleared cover regenerated without snowfall')
        t.area.icon_state = 'snow2'; t.check(); run(t, actor, lambda tile: True, piles)
        self.assertEqual(len(piles), 3)

    def test_actual_shovel_wait_interruption_replacement_and_reload_cannot_yield(self):
        run = shovel_action()
        for change in ('interrupted', 'replacement', 'reload', 'heat', 'savehold'):
            t = Tile(kind='dirt'); t.weather_snow = 2
            actor, piles = NS(shoveling=False), []
            def wait(tile):
                if change == 'replacement': tile.generation += 1
                if change == 'reload': tile.load()
                if change == 'heat': tile.c = 22
                if change == 'savehold': tile.blocked = True
                return change != 'interrupted'
            run(t, actor, wait, piles)
            self.assertEqual((piles, t.replacements, actor.shoveling), ([], [], False), change)
            self.assertEqual((t.kind, t.soil, t.loose_dirt, t.contents), ('dirt', 83, 3, ['well', 'player']))
            self.assertEqual(t.weather_snow, 0 if change == 'heat' else 2)

    def test_actual_shovel_authored_snow_retains_existing_explicit_terrain_behavior(self):
        t = Tile(kind='dirt/winter'); t.native_snow = True; t.available_snow = 1
        piles = []; shovel_action()(t, NS(shoveling=False), lambda tile: True, piles)
        self.assertEqual((len(piles), t.replacements), (1, ['dirt']))

    def test_actual_process_batch_deadline_tick_budget_and_replaced_candidate(self):
        operations = {
            'if (persistence_save_in_progress || persistence_active_operation || persistence_load_recovery_required || world.time < snowfall_ground_next)': 'if g.blocked or g.now < g.next:',
            'return': 'return',
            'snowfall_ground_next = world.time + SNOWFALL_GROUND_INTERVAL': 'g.next = g.now + 20',
            'var/checks = min(SNOWFALL_GROUND_BATCH, snowfall_ground.len)': 'checks = min(256, len(g.tiles))',
            'while (checks-- > 0 && snowfall_ground.len)': 'while checks > 0 and g.tiles:',
            'if (snowfall_ground_cursor > snowfall_ground.len)': 'if g.cursor > len(g.tiles):',
            'snowfall_ground_cursor = 1': 'g.cursor = 1',
            'var/turf/T = snowfall_ground[snowfall_ground_cursor]': 'T = g.tiles[g.cursor - 1]',
            'var/index = snowfall_ground_cursor': 'index = g.cursor',
            'if (T && T.snowfall_ground_index == index)': 'if T and T.index == index:',
            'T.snowfall_ground_check()': 'T.check()',
            'snowfall_ground_cursor++': 'g.cursor += 1',
            'if (world.tick_usage >= 20)': 'if g.tick_usage >= 20:', 'break': 'break',
        }
        lines = ['def execute(g):']
        for raw in body(SOURCE, '/process/snowfall_ground/fire()').splitlines():
            if not raw.strip(): continue
            depth = len(raw) - len(raw.lstrip('\t'))
            lines.append('    ' * depth + operations[raw.strip()])
            if raw.strip().startswith('while '): lines.append('    ' * (depth + 1) + 'checks -= 1')
        env = {}; exec('\n'.join(lines), env); run = env['execute']
        tiles = [Tile() for _ in range(600)]
        for index, t in enumerate(tiles, 1): t.index = index
        g = NS(blocked=False, now=100, next=0, cursor=1, tiles=tiles, tick_usage=0)
        run(g); self.assertEqual(sum(t.weather_snow for t in tiles), 256)
        run(g); self.assertEqual(sum(t.weather_snow for t in tiles), 256, 'duplicate callback accrued again')
        g.now += 20; g.tick_usage = 20; run(g)
        self.assertEqual(sum(t.weather_snow for t in tiles), 257)
        g.now += 20; g.blocked = True; run(g)
        self.assertEqual(sum(t.weather_snow for t in tiles), 257)
        g.blocked = False; g.cursor = 1; tiles[0].current = False; run(g)
        self.assertEqual(tiles[0].weather_snow, 1, 'stale tile accrued')

    def test_cold_without_snowfall_never_creates_snow(self):
        for icon in ('', 'rain2', 'sandstorm', 'monsoon'):
            t = Tile(precip=icon)
            for _ in range(3): t.check()
            self.assertEqual((t.weather_snow, t.appearance), (0, []))
            self.assertEqual(t.calls, 0, 'clear ground performed unnecessary thermal queries')
        t = Tile(); t.area.weather = 1; t.check()
        self.assertEqual(t.weather_snow, 0)

    def test_actual_precipitation_and_local_temperature_boundaries(self):
        for icon in ('snow1', 'snow2', 'snow_storm', 'rad_snow2'):
            for c, expected in ((0, 1), (-20, 1), (0.1, 0), (2, 0), (3, 0)):
                t = Tile(c=c, precip=icon); t.check()
                self.assertEqual(t.weather_snow, expected, (icon, c))
        t = Tile(); t.area.weather_intensity = 0; t.check(); self.assertEqual(t.weather_snow, 0)

    def test_roofs_indoor_cover_and_connected_upper_floors_prevent_sticking(self):
        for obstacle in ('roof', 'floor_cover', 'inside', 'ceiling', 'upper_roof'):
            t = Tile()
            if obstacle in ('roof', 'floor_cover'): setattr(t, obstacle, True)
            elif obstacle == 'inside': t.area.outside = False
            else:
                t.above = NS(kind='sky' if obstacle == 'upper_roof' else 'floor', roof=obstacle == 'upper_roof', floor_cover=False, above=None)
            t.check(); self.assertEqual(t.weather_snow, 0, obstacle)
        t = Tile(); t.above = NS(kind='broken_floor', roof=False, floor_cover=False, above=None)
        t.check(); self.assertEqual(t.weather_snow, 1)

    def test_actual_heat_tail_prevents_sticking_and_melts_existing_generated_cover(self):
        for kind, radius in (('brazier', 3), ('heatsource', 3), ('oven/fireplace', 1), ('engine', 1)):
            t = Tile(); t.heat = [NS(kind=kind, on=True, distance=radius)]
            t.check(); self.assertEqual(t.weather_snow, 0)
            t.weather_snow = 2; t.check(); self.assertEqual(t.weather_snow, 0)
            t.heat[0].on = False; t.check(); self.assertEqual(t.weather_snow, 1)
            t.heat[0].on = True; t.heat[0].distance += 1; t.check(); self.assertEqual(t.weather_snow, 2)

    def test_thaw_refreeze_requires_new_snowfall_and_preserves_substrate(self):
        t = Tile(); before = (t.kind, t.soil, t.loose_dirt, t.contents.copy())
        t.check(); t.check(); t.check(); self.assertEqual(t.weather_snow, 2)
        t.c = 2; t.area.icon_state = ''; t.check(); self.assertEqual(t.weather_snow, 2)
        t.c = 2.1; t.check(); self.assertEqual(t.weather_snow, 0)
        t.c = -10; t.check(); self.assertEqual(t.weather_snow, 0)
        t.area.icon_state = 'snow2'; t.check(); self.assertEqual(t.weather_snow, 1)
        self.assertEqual((t.kind, t.soil, t.loose_dirt, t.contents), before)

    def test_authored_snow_and_unlisted_soil_are_untouched(self):
        for kind in ('winter', 'dirt/winter', 'winter/grass', 'ploughed', 'ice', 'burned', 'sand'):
            t = Tile(kind=kind, c=30); t.native_snow = True; t.available_snow = 2
            t.check(); self.assertEqual((t.kind, t.available_snow, t.weather_snow), (kind, 2, 0))
            self.assertTrue(t.has_snow())

    def test_harvest_uses_generated_units_without_soil_debit_or_overdraw(self):
        t = Tile(); t.check(); self.assertTrue(t.has_snow()); self.assertTrue(t.take(t.generation, True))
        self.assertFalse(t.take(t.generation, True)); self.assertFalse(t.has_snow())
        self.assertEqual((t.kind, t.soil, t.loose_dirt), ('grass', 83, 3))
        t.check(); t.c = 30; self.assertFalse(t.take(t.generation, True)); self.assertEqual(t.weather_snow, 0)
        old = Tile(kind='winter'); old.native_snow = True; old.available_snow = 2
        self.assertTrue(old.take(old.generation, False)); self.assertEqual(old.available_snow, 1)

    def test_save_load_rebuilds_only_generated_cover_and_never_samples_weather(self):
        t = Tile(); t.check(); payload = {'weather_snow': t.weather_snow}
        restored = Tile(c=30, precip=''); restored.weather_snow = payload['weather_snow']; restored.load()
        self.assertEqual((restored.weather_snow, restored.appearance, restored.calls, restored.registered), (1, ['snow image'], 0, True))
        restored.load(); self.assertEqual(restored.appearance, ['snow image'])
        restored.check(); self.assertEqual(restored.weather_snow, 0)
        for raw, expected in ((-5, 0), (99, 2), ('bad', 0), (None, 0)):
            restored.weather_snow = raw; restored.load(); self.assertEqual(restored.weather_snow, expected)
        loader = (ROOT / 'code/modules/persistence/loading.dm').read_text()
        self.assertLess(loader.index('restored_turf.weather_snow = 0'), loader.index('if(!object)'))
        self.assertIn('if (weather_snow > 0)\n\t\t. |= "weather_snow"', SOURCE)
        runtime = (ROOT / 'code/modules/persistence/functions.dm').read_text()
        self.assertIn('key == "snowfall_ground_index" || key == "snowfall_ground_generation" || key == "weather_snow_overlay"', runtime)

    def test_stale_tiles_and_persistence_hold_do_not_mutate_or_debit(self):
        for field in ('blocked', 'current'):
            t = Tile(); t.weather_snow = 2; setattr(t, field, field == 'blocked')
            t.check(); self.assertFalse(t.take(t.generation, True)); self.assertEqual((t.weather_snow, t.calls), (2, 0))
        self.assertIn('persistence_active_operation', SOURCE)
        self.assertIn('persistence_load_recovery_required', SOURCE)

    def test_pre_wait_generation_cannot_consume_replacement_or_restored_layer(self):
        t = Tile(); t.check(); generation = t.generation
        t.generation += 1
        self.assertFalse(t.take(generation, True)); self.assertEqual(t.weather_snow, 1)
        generation = t.generation; t.load()
        self.assertFalse(t.take(generation, True)); self.assertEqual(t.weather_snow, 1)
        self.assertTrue(t.take(t.generation, True)); self.assertEqual(t.weather_snow, 0)

    def test_no_season_or_weather_callback_accrual(self):
        for file in ('code/modules/1713/weather.dm', 'code/processes/weather.dm', 'code/modules/persistence/durable_environment.dm'):
            current = (ROOT / file).read_text()
            # Whole-file PR scope is review evidence, not a permanent freeze on
            # unrelated zone/weather work. Only the snow-accrual boundary belongs here.
            self.assertNotIn('snowfall_ground_check', current)
        for file in ('_map_metadata.dm', 'colonia.dm', 'pepelsibirsk.dm', 'nomads/nomads_ice_age.dm'):
            text = (ROOT / 'code/game/objects/map_metadata' / file).read_text()
            self.assertNotRegex(text, r'ChangeTurf\(/turf/floor/(?:dirt/)?winter')

    def test_gameplay_consumers_and_single_owned_overlay_are_wired(self):
        for file in ('code/game/mob/mob_movement.dm', 'code/game/mob/living/carbon/human/species/species.dm', 'code/game/turfs/turf.dm'):
            self.assertIn('has_snow_cover()', (ROOT / file).read_text())
        attacks = (ROOT / 'code/game/turfs/floor_attackby.dm').read_text()
        self.assertEqual(attacks.count('if (!T.take_snow(snow_generation, generated_source))'), 2)
        self.assertEqual(attacks.count('var/snow_generation = T.snowfall_ground_generation'), 2)
        self.assertEqual(attacks.count('if (!T || T.weather_snow > 0)'), 3)
        self.assertEqual(attacks.count('T.has_snow_cover()'), 2)
        self.assertEqual(attacks.count('if (has_snow_cover() ||'), 2)
        self.assertIn('Clear the snow before working the ground.', attacks)
        image = body(SOURCE, '/turf/proc/snowfall_ground_icon()')
        self.assertIn('overlays -= weather_snow_overlay', image)
        self.assertNotIn('overlays.Cut', image)
        self.assertIn("image('icons/turf/snow.dmi'", image)

    def test_registry_lifecycle_and_bounded_process_source_contract(self):
        fire = body(SOURCE, '/process/snowfall_ground/fire()')
        self.assertIn('min(SNOWFALL_GROUND_BATCH, snowfall_ground.len)', fire)
        self.assertIn('world.time < snowfall_ground_next', fire)
        self.assertIn('world.tick_usage >= 20', fire)
        self.assertIn('/turf/floor/Del()\n\tsnowfall_ground_unregister()', SOURCE)
        unregister = body(SOURCE, '/turf/proc/snowfall_ground_unregister()')
        self.assertIn('snowfall_ground[snowfall_ground_index] = last_ground', unregister)
        self.assertIn('last_ground.snowfall_ground_index = snowfall_ground_index', unregister)
        self.assertNotIn('spawn(', SOURCE); self.assertNotIn(' in world', SOURCE); self.assertNotIn('.Copy(', SOURCE)
        icon = (ROOT / 'code/game/turfs/floor_icon.dm').read_text()
        self.assertEqual(icon.count('snowfall_ground_register()'), 1)
        self.assertEqual(icon.count('snowfall_ground_icon()'), 1)

    def test_removed_historical_loops_are_exact_snow_scope_not_water_or_dates(self):
        for file, count in (('_map_metadata.dm', 16), ('colonia.dm', 16), ('pepelsibirsk.dm', 12), ('nomads/nomads_ice_age.dm', 4)):
            path = 'code/game/objects/map_metadata/' + file
            old = subprocess.check_output(['git', 'show', BASE + ':' + path], cwd=ROOT, text=True)
            projected, removed = without_season_snow(old)
            self.assertEqual(len(removed), count)
            for block in removed:
                self.assertNotIn('/water/', block); self.assertNotIn('record_abandonment', block)
                self.assertNotIn('change_weather', block); self.assertNotIn('seasons()', block)
            current = (ROOT / path).read_text()
            if file == '_map_metadata.dm':
                start = projected.index('\tvar/list/changes = list(', projected.index('/obj/map_metadata/proc/season_reconcile_warm'))
                end = projected.index('\tvar/season_work = 0', start)
                projected = projected[:start] + projected[end:]
                projected = projected.replace("// Winter's probabilistic freeze assumes Fall's existing earlier cold work.", '// Retain the reviewed flow admission; new cold-entry edges need separate review.')
                projected = projected.replace('// Default cycle retains its exact payloads and delayed cleanup.', '// No additional cleanup on canonical edges.')
            # Compare only procedures deliberately changed by snow removal.
            # Author metadata, zone/elevation fields and other methods may evolve.
            changed_procedures = 0
            for signature in re.findall(r'^(/[^/\n][^\n]*\([^\n]*\))\n', old, re.M):
                if body(old, signature) != body(projected, signature):
                    changed_procedures += 1
                    self.assertEqual(body(current, signature), body(projected, signature), signature)
            self.assertGreater(changed_procedures, 0)


if __name__ == '__main__': unittest.main()
