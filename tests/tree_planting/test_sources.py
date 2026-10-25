"""Offline source execution with synthetic engine boundaries, not native DM proof."""
from pathlib import Path
import re
import struct
import unittest
import zlib
from types import SimpleNamespace as State
import importlib.util
import json

ROOT = Path(__file__).resolve().parents[2]
FARM = (ROOT / 'code/game/objects/farming.dm').read_text(encoding='utf-8')
TREE = '/obj/structure/farming/plant/tree/'


def proc(source, signature):
    start = source.index(signature)
    match = re.search(r'\n/[^/*]', source[start + len(signature):])
    end = start + len(signature) + match.start() if match else len(source)
    return source[start:end].rstrip()


def scheduler(source=FARM):
    """Translate the actual scheduler body; reject unsupported statements.

    Resource methods, spatial admission, native constructor and GC are injected.
    Tests assert their order and effects separately from native fixture acceptance.
    """
    body = proc(source, TREE + 'process_interval(').splitlines()[1:]
    fields = ('last_growth_tick', 'growth_time_left', 'gc_destroyed', 'gcDestroyed',
              'vstatic', 'stage', 'readyStageMax', 'readyStageMin', 'loc', 'radiation', 'icon_state')
    methods = ('soil_nutrition_proc', 'water_proc', 'growing_season', 'stageGrowth', 'visible_message')
    lines = ['def tick(self, configured_seconds=2):']
    for raw in body:
        text = raw.split('//', 1)[0].rstrip()
        if not text.strip():
            continue
        depth = len(text) - len(text.lstrip('\t'))
        text = text.strip()
        if text.startswith('var/obj/structure/wild/tree/live_tree/T = new(loc)'):
            text = 'T = mature(self.loc)'
        elif text.startswith('var/'):
            text = re.sub(r'^var/(\w+)', r'\1', text)
        if text.startswith('if ('):
            text = 'if ' + text[4:-1] + ':'
        if text.startswith('icon_state = '):
            text = 'icon_state = "tree-grow" + str(min(stage, readyStageMin - 1))'
        text = text.replace('||', ' or ').replace('&&', ' and ')
        text = re.sub(r'!(?!=)', 'not ', text)
        # Only unquoted tokens are fields/methods; T.radiation is a different owner.
        pieces = re.split(r'("[^"\n]*")', text)
        for index in range(0, len(pieces), 2):
            pieces[index] = re.sub(r'(?<![\w.])(' + '|'.join(fields + methods) + r')\b',
                                   r'self.\1', pieces[index])
        text = ''.join(pieces).replace('qdel(src)', 'retire(self)').replace('src)', 'self)')
        lines.append('    ' * depth + text)
    env = dict(world=State(time=100), persistence_active_operation=None,
               PROCESS_KILL='kill', isturf=lambda loc: loc == 'soil',
               tree_planting_error=lambda loc, plant: plant.blocked,
               SPAN_NOTICE=lambda text: text)
    env['mature'] = lambda loc: env.setdefault('trees', []).append(State(loc=loc, change_season=lambda: None)) or env['trees'][-1]
    env['retire'] = lambda plant: setattr(plant, 'retired', True)
    exec(compile('\n'.join(lines), '<production-tree-scheduler>', 'exec'), env)
    return env['tick'], env


def seedling(**overrides):
    result = State(last_growth_tick=80, growth_time_left=600, stage=1,
                   readyStageMin=7, readyStageMax=10, gc_destroyed=False,
                   gcDestroyed=False, vstatic=False, loc='soil', radiation=3,
                   icon_state='tree-grow1', blocked=False, fertile=True,
                   season_ok=True, retired=False, calls=[])
    result.soil_nutrition_proc = lambda: result.calls.append('soil')
    result.water_proc = lambda: result.calls.append('water')
    result.growing_season = lambda: result.season_ok
    result.stageGrowth = lambda: setattr(result, 'stage', result.stage + 1)
    result.visible_message = lambda message: result.calls.append('mature')
    for key, value in overrides.items():
        setattr(result, key, value)
    return result


class Trees(unittest.TestCase):
    def test_native_controls_mutate_generated_source_only(self):
        spec = importlib.util.spec_from_file_location('tree_native_runner', ROOT / 'tests/tree_planting/run.py')
        runner = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(runner)
        for name, (relative, old, new, expected) in runner.CONTROLS.items():
            original = (ROOT / relative).read_bytes()
            generated = runner.prepare('.tree_offline_probe', name)
            self.assertIn(new, generated['_control.dm'])
            self.assertNotEqual(generated['_control.dm'], original.decode('utf-8').replace('\r\n', '\n'))
            self.assertEqual((ROOT / relative).read_bytes(), original)
            self.assertIn('.tree_offline_probe_control.dm', generated['.dme'])
            self.assertTrue(expected.startswith('FAIL: '))

    def test_native_restart_scope_and_runtime_supervision(self):
        probe = (ROOT / 'tests/tree_planting/probe.dm').read_text()
        self.assertNotRegex(probe, r'\bdel\((?:blocker|P|dry)\)')
        for marker in ('map_storage.BuildVarDirectory', 'map_storage.Load_Entry',
                       'processes.obj.fire()', 'P.after_load()',
                       'fresh-process restored tree matures once through production dispatch',
                       'same-tick dispatch cannot double-charge tree'):
            self.assertIn(marker, probe)
        runner = (ROOT / 'tests/tree_planting/run.py').read_text()
        self.assertIn('from native_fixture import Session, no_port_args, read_bounded, run_native', runner)
        self.assertNotIn('subprocess.run(', runner)
        self.assertIn("('reader', 'PASS: tree restart reader and production object dispatch')", runner)

    def test_atlas_uses_mature_tree_route_without_seed_refund(self):
        source = json.loads((ROOT / 'scripts/atlas/resource-sources.json').read_text())
        routes = source['mechanisms']
        route = next(route for route in routes if route['name'] == 'Grow a timber tree')
        self.assertIn('/obj/structure/wild/tree/live_tree', route['outputs'])
        self.assertNotIn('/obj/item/stack/farming/seeds/tree', route['outputs'])
        self.assertFalse(any(route['name'] == 'Harvest tree' for route in routes))
        game = json.loads((ROOT / 'UI/crafting-atlas.json').read_text())
        seed_routes = game['acquisition']['/obj/item/stack/farming/seeds/tree']
        self.assertTrue(any(route['name'] == 'Forage random seeds from small bushes' or
                            'small bush' in ' '.join(route['steps']).lower() for route in seed_routes))
        tree_routes = game['acquisition']['/obj/structure/wild/tree/live_tree']
        self.assertTrue(any(route['name'] == 'Grow a timber tree' for route in tree_routes))

    def test_declared_climate_and_season_together(self):
        body = proc(FARM, TREE + 'proc/growing_season()')
        expression = body.split('\treturn ', 1)[1].replace('&&', ' and ')
        for climate in ('temperate', 'jungle', 'desert', 'taiga', 'unknown'):
            for season in ('SUMMER', 'WINTER', 'Wet Season', 'Dry Season'):
                env = dict(A=State(climate=climate), biomes=['temperate', 'jungle', 'desert', 'taiga'],
                           seasons=['SUMMER', 'SPRING', 'FALL', 'Wet Season', 'Dry Season'], season=season)
                self.assertEqual(bool(eval(expression, env)), climate != 'unknown' and season != 'WINTER')

    def test_existing_water_helper_with_tree_capacity(self):
        spec = importlib.util.spec_from_file_location('tree_water_adapter', ROOT / 'tests/local_discovery/source_adapter.py')
        adapter = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(adapter)
        code = adapter.compile_proc(proc(FARM, '/obj/structure/farming/plant/proc/water_proc()'), water=True)
        plant = adapter.entity('/obj/structure/farming/plant/tree')
        for weather, initial, expected, death in (('', 80, 65, None), ('', 1, -14, 'dry'),
                                                 ('rain', 75, 80, None), ('snow_storm', 80, 80, 'frozen'),
                                                 ('sandstorm', 80, 80, 'destroyed')):
            state = dict(src=plant, loc=plant, area=State(icon_state=weather, climate='temperate'),
                         water=initial, max_water=80, map=State(heat_wave=False), stage=6, death=None)
            result = adapter.execute(code, **state)
            self.assertEqual((result[1], result[3]), (expected, death))

    def test_shared_admission_production_predicates(self):
        body = proc(FARM, '/proc/tree_planting_error(')
        lines = ['def admission(T, seedling=None):']
        for raw in body.splitlines()[1:]:
            text = raw.strip()
            if not text or text.startswith('//'):
                continue
            depth = len(raw) - len(raw.lstrip('\t'))
            text = re.sub(r'^var/area/A', 'A', text)
            text = text.replace('for (var/atom/movable/blocker in T)', 'for blocker in T.occupants:')
            text = text.replace('(locate(/obj/roof) in T)', 'T.roof')
            text = re.sub(r'(?<![\w])/(?:\w+/)*\w+', lambda match: repr(match[0]), text)
            text = text.replace('||', ' or ').replace('&&', ' and ')
            text = re.sub(r'!(?!=)', 'not ', text)
            if text.startswith('if ('):
                text = 'if ' + text[4:-1] + ':'
            lines.append('    ' * depth + text)
        env = dict(AREA_OUTSIDE=0, null=None, get_area=lambda T: T.area,
                   istype=lambda item, path: item is not None and item.kind.startswith(path))
        exec(compile('\n'.join(lines), '<production-tree-admission>', 'exec'), env)
        check = env['admission']
        site = State(kind='/turf/floor/dirt/ploughed', is_plowed=True, density=False,
                     area=State(location=0, is_void_area=False), occupants=[], roof=False)
        self.assertIsNone(check(site))
        for key, invalid in (('kind', '/turf/floor/dirt'), ('is_plowed', False), ('density', True), ('roof', True)):
            before = getattr(site, key)
            setattr(site, key, invalid)
            self.assertIsNotNone(check(site), key)
            setattr(site, key, before)
        for occupant in (State(kind='/obj/structure/wild/tree', density=True),
                         State(kind='/mob/living/human', density=False),
                         State(kind='/obj/structure/farming/plant/tree', density=False)):
            site.occupants = [occupant]
            self.assertIsNotNone(check(site))
        self.assertIsNone(check(site, site.occupants[0]), 'the seedling must not block itself')
        site.occupants = [State(kind='/obj/item/stack/material/wood', density=False)]
        self.assertIsNone(check(site), 'loose resources do not block growth')
        site.area.location = 1
        self.assertIsNotNone(check(site))
        site.area.location = 0
        site.area.is_void_area = True
        self.assertIsNotNone(check(site))

    def test_interval_duplicate_service_and_lag_are_bounded(self):
        tick, env = scheduler()
        plant = seedling()
        tick(plant)
        self.assertEqual(plant.growth_time_left, 580)
        tick(plant)
        self.assertEqual(plant.growth_time_left, 580)
        env['world'].time += 50000
        tick(plant)
        self.assertEqual(plant.growth_time_left, 560)
        self.assertEqual(plant.calls, [])

    def test_six_tended_stages_make_one_existing_tree(self):
        tick, env = scheduler()
        plant = seedling()
        for count in range(180):
            env['world'].time = 100 + count * 20
            tick(plant)
        self.assertEqual(plant.stage, 7)
        self.assertTrue(plant.retired)
        self.assertEqual(len(env['trees']), 1)
        self.assertEqual(env['trees'][0].radiation, 3)
        self.assertEqual(plant.calls, ['soil', 'water'] * 6 + ['mature'])

    def test_season_and_storm_death_prevent_maturation(self):
        tick, env = scheduler()
        plant = seedling(growth_time_left=1, stage=6, season_ok=False)
        tick(plant)
        self.assertEqual(plant.stage, 6)
        self.assertEqual(plant.calls, ['soil', 'water'])
        plant = seedling(growth_time_left=1, stage=6)
        plant.water_proc = lambda: setattr(plant, 'stage', 11)
        self.assertEqual(tick(plant), 'kill')
        self.assertNotIn('trees', env)

    def test_space_import_export_and_dead_props_do_not_mutate(self):
        for option in ({'blocked': True}, {'loc': None}, {'vstatic': True},
                       {'gc_destroyed': True}, {'gcDestroyed': True}, {'stage': 11}):
            tick, env = scheduler()
            plant = seedling(growth_time_left=1, **option)
            tick(plant)
            self.assertEqual(plant.growth_time_left, 1)
            self.assertEqual(plant.calls, [])
        tick, env = scheduler()
        plant = seedling(growth_time_left=1)
        env['persistence_active_operation'] = State(kind='load')
        tick(plant)
        self.assertEqual(plant.calls, [])
        env['persistence_active_operation'].kind = 'save'
        tick(plant)
        self.assertEqual(plant.growth_time_left, 1)

    def test_partial_stage_reload_and_legacy_ready_stage(self):
        tick, env = scheduler()
        plant = seedling(stage=4, growth_time_left=277, last_growth_tick=100)
        tick(plant)  # first service after after_load receives zero elapsed
        self.assertEqual((plant.stage, plant.growth_time_left), (4, 277))
        env['world'].time += 20
        tick(plant)
        self.assertEqual((plant.stage, plant.growth_time_left), (4, 257))
        legacy = seedling(stage=7, growth_time_left=1)
        tick(legacy)
        self.assertTrue(legacy.retired)

    def test_ownership_save_and_admission_contracts(self):
        growth = proc(FARM, TREE + 'growth()')
        self.assertIn('processing_objects |= src', growth)
        for method in ('growth()', 'process_interval(', 'after_load()'):
            self.assertNotRegex(proc(FARM, TREE + method), r'\b(?:spawn|sleep)\(')
        restored = proc(FARM, TREE + 'after_load()')
        self.assertIn('last_growth_tick = world.time', restored)
        self.assertNotIn('growth_time_left =', restored)
        self.assertNotIn('stage =', restored)
        runtime = proc(FARM, TREE + 'persistence_runtime_var(')
        self.assertIn('key == "last_growth_tick" || ..()', runtime)
        for field in ('growth_time_left', 'stage', 'water', 'plant_nutrition'):
            self.assertNotIn('"' + field + '"', runtime)
        for method in ('Destroy()', 'Del()'):
            self.assertIn('processing_objects -= src', proc(FARM, TREE + method))
        admission = proc(FARM, '/proc/tree_planting_error(')
        for guard in ('/turf/floor/dirt/ploughed', '!T.is_plowed', 'T.density',
                      'AREA_OUTSIDE', 'A.is_void_area', '/obj/roof', 'blocker.density',
                      '/mob/living', '/obj/structure/farming/plant'):
            self.assertIn(guard, admission)
        floor = (ROOT / 'code/game/turfs/floor_attackby.dm').read_text()
        start = floor.index('else if (istype(C, /obj/item/stack/farming/seeds)')
        end = floor.index('else if (istype(C, /obj/item/weapon/plough))', start)
        planting = floor[start:end]
        self.assertLess(planting.index('TS.planting_error(src)'), planting.index('H.adaptStat'))
        self.assertLess(planting.index('TS.planting_error(src)'), planting.index('TS.spawn_plant(src)'))
        self.assertLess(planting.index('TS.spawn_plant(src)'), planting.index('C.amount -= 1'))

    def test_existing_seed_supply_and_art(self):
        wild = (ROOT / 'code/game/objects/structures/wild.dm').read_text()
        self.assertIn('typesof(/obj/item/stack/farming/seeds)', wild)
        self.assertIn('var/obj/item/stack/farming/seeds/NS = pickseed()', wild)
        self.assertIn('/obj/item/stack/farming/seeds/tree = 4',
                      (ROOT / 'code/modules/1713/crates.dm').read_text())
        data = (ROOT / 'icons/farming/plants.dmi').read_bytes()
        offset, description = 8, ''
        while offset < len(data):
            size, kind = struct.unpack('>I4s', data[offset:offset + 8])
            chunk = data[offset + 8:offset + 8 + size]
            if kind == b'zTXt' and chunk.startswith(b'Description\x00\x00'):
                description = zlib.decompress(chunk[len(b'Description\x00\x00'):]).decode()
            offset += size + 12
        for stage in range(1, 7):
            self.assertIn('state = "tree-grow' + str(stage) + '"', description)
        self.assertIn('state = "tree-dead"', description)

    def test_generated_source_mutants_break_the_oracle(self):
        changes = [('growth_time_left - elapsed', 'growth_time_left - 0'),
                   ('if (persistence_active_operation)', 'if (FALSE)'),
                   ('if (growing_season() && stage < readyStageMin)', 'if (stage < readyStageMin)')]
        for old, new in changes:
            outcomes = []
            for source in (FARM, FARM.replace(old, new)):
                tick, env = scheduler(source)
                env['FALSE'] = False
                plant = seedling(growth_time_left=1, season_ok=False)
                if 'persistence' in old:
                    env['persistence_active_operation'] = State(kind='load')
                    plant.season_ok = True
                tick(plant)
                outcomes.append((plant.stage, plant.growth_time_left, plant.calls))
            self.assertNotEqual(*outcomes, msg=old)


if __name__ == '__main__':
    unittest.main()
