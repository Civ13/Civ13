"""Offline checks for the river flood sidecar (scripts/river_flood.py)."""
import importlib.util
import sys
import tempfile
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
SPEC = importlib.util.spec_from_file_location('river_flood', ROOT / 'scripts/river_flood.py')
flood = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(flood)

L = '/turf/floor/grass'
F = '/turf/floor/beach/water'
S = '/turf/floor/beach/water/deep/saltwater'
SIDECARS = {'nomads_gaia': 2, 'nomads_europe': 1, 'nomads_jungle': 2, 'nomads_desert': 2, 'nomads_asia': 1}
MODULE = (ROOT / 'code/modules/1713/river_flood.dm').read_text(encoding='utf-8')


def valley(width=70, height=9):
    """A river along the middle row running east into a sea column, with
    banks that rise one level per tile, a ridge at x 20 on the north side,
    and a puddle in the south-west corner."""
    rows = [[L] * width for _ in range(height)]
    heights = [[0] * width for _ in range(height)]
    mid = height // 2
    for y in range(height):
        for x in range(width):
            heights[y][x] = abs(y - mid) * 1.5
        rows[y][width - 1] = S
        heights[y][width - 1] = 0
    for x in range(2, width - 1):  # rises 2 tiles from the west edge
        rows[mid][x] = F
        heights[mid][x] = 0
    for y in range(mid):
        heights[y][20] = 6  # a ridge across the north bank
    rows[height - 1][0] = F  # one-tile puddle: not a reach
    heights[height - 1][0] = 0
    return rows, heights


class BuildTest(unittest.TestCase):
    def setUp(self):
        self.rows, self.heights = valley()
        self.reaches, self.labels, self.thresholds, self.hollows, self.hollow_ids = flood.build(self.rows, self.heights)

    def test_reaches_drain_downstream_in_id_order(self):
        # 67 tiles of river cut by the 32-tile grid: three reaches.
        self.assertEqual(len(self.reaches), 3)
        for r in self.reaches:
            self.assertTrue(r['down'] == 0 or r['down'] > r['id'], r)
        self.assertEqual([r['down'] for r in self.reaches], [2, 3, 0])
        self.assertEqual(self.reaches[-1]['upstream'], sum(r['area'] for r in self.reaches))

    def test_thresholds_follow_the_ground(self):
        mid = 4
        self.assertIsNone(self.thresholds[mid][5], 'river water has no threshold')
        self.assertEqual(self.thresholds[mid - 1][5], 1.5)
        self.assertEqual(self.thresholds[mid - 3][5], 4.5)
        # Behind the ridge the river must top the ridge first.
        self.assertEqual(self.thresholds[mid - 1][19], 1.5)
        self.assertEqual(self.thresholds[0][10], 6)
        # The puddle is land as far as floods go.
        self.assertEqual(self.labels[8][0], 1)

    def test_land_by_the_sea_belongs_to_no_reach(self):
        self.assertEqual(self.labels[0][68], 0)
        self.assertIsNone(self.thresholds[0][68])

    def test_round_trip(self):
        out = Path(tempfile.mkdtemp()) / 'valley.flood.txt'
        flood.write_flood(out, 70, 9, 1, self.reaches, self.labels, self.thresholds, self.hollows, self.hollow_ids)
        self.assertEqual(flood.read_flood(out), (70, 9, 1, self.reaches, self.labels, self.thresholds))
        self.assertEqual(flood.read_hollows(out), (self.hollows, self.hollow_ids))
        text = out.read_text(encoding='ascii')
        self.assertTrue(text.startswith('civ13-river-flood 2\nsize 70 9\nz 1\nreaches 3\nr 1 2 '))


def bowl():
    """A river along the south edge and, north of it, a basin two levels deep
    inside a rim at level 3, on ground that falls toward the river."""
    width, height = 12, 10
    rows = [[L] * width for _ in range(height)]
    heights = [[1.0] * width for _ in range(height)]
    for x in range(width):
        rows[height - 1][x] = F
        heights[height - 1][x] = 0
    for y in range(1, 6):
        for x in range(3, 9):
            heights[y][x] = 3.0
    for y in range(2, 5):
        for x in range(4, 8):
            heights[y][x] = 1.0
    heights[3][5] = 1.5
    return rows, heights


class HollowTest(unittest.TestCase):
    def test_a_closed_basin_is_a_hollow(self):
        reaches, labels, thresholds, hollows, ids = flood.build(*bowl())
        self.assertEqual(len(hollows), 1)
        h = hollows[0]
        self.assertEqual((h['spill'], h['bottom'], h['area']), (3.0, 1.0, 12))
        # 11 tiles at the bottom, one half a level up, then nothing until the rim.
        self.assertEqual(h['hist'], [11, 1, 0, 0])
        self.assertGreaterEqual(h['catchment'], h['area'])
        self.assertEqual(ids[3][5], 1)
        self.assertEqual(ids[1][3], 0, 'the rim is not part of the hollow')
        self.assertEqual(ids[7][0], 0)

    def test_version_one_files_have_no_hollows(self):
        reaches, labels, thresholds, hollows, ids = flood.build(*bowl())
        out = Path(tempfile.mkdtemp()) / 'bowl.flood.txt'
        flood.write_flood(out, 12, 10, 1, reaches, labels, thresholds, hollows, ids)
        lines = out.read_text(encoding='ascii').split('\n')
        cut = lines.index('hollows 1')
        old = ['civ13-river-flood 1'] + lines[1:cut]
        out.write_text('\n'.join(old) + '\n', encoding='ascii')
        self.assertEqual(flood.read_hollows(out)[0], [])


class CommittedSidecarTest(unittest.TestCase):
    def test_sidecars_match_their_maps(self):
        from terrain_heights import read_dmm, read_heights
        for name, z in SIDECARS.items():
            with self.subTest(name):
                _, _, levels = read_dmm(ROOT / f'maps/nomads/{name}.dmm')
                _, _, heights = read_heights(ROOT / f'maps/heights/{name}.txt')
                built = flood.build(levels[z], heights[z])
                path = ROOT / f'maps/heights/{name}.flood.txt'
                width, height, fz, reaches, labels, thresholds = flood.read_flood(path)
                self.assertEqual(fz, z)
                self.assertEqual((reaches, labels, thresholds), built[:3], f'regenerate {name}.flood.txt (docs/river-flood.md)')
                self.assertEqual(flood.read_hollows(path), built[3:], f'regenerate {name}.flood.txt (docs/river-flood.md)')
                self.assertLessEqual(len(reaches), flood.MAX_REACHES)

    def test_every_map_with_flow_has_a_flood_file(self):
        for path in (ROOT / 'maps/heights').glob('*.flow.txt'):
            self.assertTrue(path.with_name(path.name.replace('.flow.txt', '.flood.txt')).exists(), path.name)


class WiringTest(unittest.TestCase):
    def test_game_reads_the_tool_format(self):
        self.assertIn(f'"{flood.HEADER}"', MODULE)
        self.assertIn(f'#define RIVER_FLOOD_ID_DIGITS "{flood.ID_DIGITS}"', MODULE)
        self.assertIn('/proc/flood_depth_at(turf/T)', MODULE)

    def test_ticks_with_the_weather_and_never_walks_tiles(self):
        weather = (ROOT / 'code/processes/weather.dm').read_text(encoding='utf-8')
        self.assertIn('\tweather_systems_step()\n\triver_flood_step()\n', weather)
        tick = MODULE.split('/datum/river_flood/proc/step_minute()', 1)[1].split('\n/', 1)[0]
        self.assertNotIn('block(', tick)
        self.assertNotIn('in world', tick)
        self.assertNotIn('label_rows', tick)

    def test_effects_read_the_flood_where_code_already_runs(self):
        read = lambda rel: (ROOT / rel).read_text(encoding='utf-8')
        self.assertIn('standing_on_snow = standing_water_delay(F)', read('code/game/mob/mob_movement.dm'))
        self.assertIn('. = standing_water_delay(F)', read('code/modules/agent_control/agent_movement.dm'))
        self.assertIn('var/water_depth = standing_water_delay(F)', read('code/modules/1713/movement_check.dm'))
        self.assertIn('if (flood_douses(src))', read('code/modules/1713/oil_fires.dm'))
        self.assertIn('flood_douses(src)', read('code/game/objects/structures/kitchen/oven.dm'))
        self.assertIn('return flood_depth_at(T) > 0', read('code/modules/1713/weather_footwear.dm'))
        self.assertIn('var/steps = river_current_steps(src)', read('code/modules/1713/river_flow.dm'))
        self.assertIn('handle_drowning()\n\t\tflood_life_tick()', read('code/game/mob/living/carbon/human/human_life.dm'))
        self.assertIn('flood_band == FLOOD_BAND_DEEP', read('code/game/mob/living/carbon/human/human_helpers.dm'))
        self.assertIn('if (flood_plant_step())\n\t\treturn', read('code/game/objects/farming.dm'))
        self.assertIn('W.flood_foul()', read('code/game/objects/structures/watercloset.dm'))
        self.assertIn('|| flood_soaks(T)', read('code/modules/1713/rain_gear.dm'))
        for rel in ('code/game/objects/structures/tree_climbing.dm', 'code/game/turfs/wall_decay.dm', 'code/modules/ecology/pollution.dm'):
            self.assertIn('flood_mark_examine(src, user)', read(rel), rel)

    def test_drawn_states_exist_in_the_sheet(self):
        from PIL import Image
        meta = Image.open(ROOT / 'icons/effects/floodwater.dmi').info['Description']
        states = {line.split('"')[1]: None for line in meta.splitlines() if line.startswith('state = ')}
        for band in range(1, 5):
            self.assertIn(f'flood{band}', states)
            self.assertIn(f'flood_edge{band}', states)
        for band in range(2, 5):
            self.assertIn(f'flood_step{band}', states)
        effects = (ROOT / 'code/modules/1713/flood_effects.dm').read_text(encoding='utf-8')
        self.assertIn('"flood[band]"', effects)
        self.assertIn('"flood_edge[band]", d', effects)
        self.assertIn('"flood_step[band]", d', effects)

    def test_ground_changes_mark_windows(self):
        ground = (ROOT / 'code/modules/1713/flood_ground.dm').read_text(encoding='utf-8')
        self.assertIn('flood_ground_changed(src) // Floodwater follows the new ground', (ROOT / 'code/modules/1713/road_tamping.dm').read_text(encoding='utf-8'))
        self.assertIn('\tF.process_windows()\n\tF.step_minute()', MODULE)
        self.assertIn('var/threshold = F.effective_threshold(T)', MODULE)
        # Walls hook New(); barriers/sandbag.dm's New() does not call ..(), so this file must come after it.
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertLess(dme.index('barriers\\sandbag.dm"'), dme.index('1713\\flood_ground.dm"'))
        window = ground.split('/datum/river_flood/proc/recompute_window(', 1)[1].split('\n/', 1)[0]
        self.assertNotIn('in world', window)
        self.assertNotIn('heapq', window)
        self.assertIn('#define FLOOD_WINDOWS_PER_TICK 6', ground)

    def test_floor_items_only_where_players_look(self):
        effects = (ROOT / 'code/modules/1713/flood_effects.dm').read_text(encoding='utf-8')
        view = effects.split('/client/proc/flood_refresh_view()', 1)[1].split('\n/', 1)[0]
        self.assertIn('flood_items_at(T, band)', view)
        self.assertEqual(effects.count('flood_items_at('), 2, 'floor items are only visited from the viewer scan')

    def test_airless_flood_precedes_flotation_and_boat_cover(self):
        helpers = (ROOT / 'code/game/mob/living/carbon/human/human_helpers.dm').read_text(encoding='utf-8')
        drowning = helpers.split('/mob/living/human/proc/handle_drowning()', 1)[1].split('\n/mob/', 1)[0]
        roof = drowning.index('if (flood_airless(T) && !seabed_diving_rating())')
        floats = drowning.index('// Floating: a lifejacket')
        flood_band = drowning.index('T.iscovered() ? FLOOD_BAND_NONE : flood_band_at(T)')
        self.assertLess(roof, floats)
        self.assertLess(floats, flood_band)
        self.assertIn('if (!tunnel_hold_breath())', drowning[roof:floats])
        self.assertIn('adjustOxyLoss(10)', drowning[roof:floats])
        self.assertNotIn('swim_rest()', drowning[roof:floats])
        self.assertIn('swim_rest()', drowning[floats:flood_band])
        self.assertEqual(drowning.count('flood_airless(T)'), 1)

    def test_crops_drown_unless_they_grow_in_water(self):
        effects = (ROOT / 'code/modules/1713/flood_effects.dm').read_text(encoding='utf-8')
        step = effects.split('/obj/structure/farming/plant/proc/flood_plant_step()', 1)[1].split('\n/', 1)[0]
        self.assertIn('!flood_tolerant && band >= FLOOD_BAND_KNEE', step)
        self.assertIn('set_dead("drowned")', step)
        self.assertIn('D.soil_nutrition + FLOOD_SILT_NUTRITION', step)
        self.assertIn('/obj/structure/farming/plant/rice\n\tflood_tolerant = TRUE', effects)

    def test_drawing_stays_in_the_viewers_window(self):
        effects = (ROOT / 'code/modules/1713/flood_effects.dm').read_text(encoding='utf-8')
        view = effects.split('/client/proc/flood_refresh_view()', 1)[1].split('\n/', 1)[0]
        self.assertNotIn('in world', view)
        self.assertNotIn('range(', view)
        self.assertIn('FLOOD_VIEW_MOVE', view)
        self.assertIn('flood_drawn_revision == flood_draw_revision', view)

    def test_water_overlays_require_current_world_los_for_both_anchors(self):
        flood = (ROOT / 'code/modules/1713/flood_effects.dm').read_text(encoding='utf-8')
        fish = (ROOT / 'code/modules/1713/fish_signs.dm').read_text(encoding='utf-8')
        projector = flood.split('/client/proc/present_water_overlays(', 1)[1].split('\n/', 1)[0]
        # A shoreline image can be drawn on visible ground adjoining water
        # that is itself hidden. Both the wet source and the image turf count.
        self.assertIn('water_overlay_tile_visible(origin, S, decisions) && V.water_overlay_tile_visible(T, S, decisions)', projector)
        self.assertIn('candidates[flood_image(D, "flood_edge[band]", d)] = T', flood)
        self.assertIn('candidates[flood_image(D, "flood_step[band]", d)] = T', flood)
        self.assertIn('fish_sign_candidates = drawn', fish)
        self.assertNotIn('images += drawn', fish)
        self.assertIn('decision_snapshot(T, S) == LOS_WORLD', flood)
        self.assertIn('T.z == centre.z', projector)
        self.assertLess(projector.index('V.begin_snapshot_pass(S)'), projector.index('next_images += I'))
        self.assertLess(projector.index('S.revision != V.revision'), projector.index('images += next_images'))
        self.assertIn('images -= water_overlay_images - next_images', projector)

    def test_water_overlays_reconcile_independently_of_sample_cadence(self):
        lifecycle = (ROOT / 'code/modules/visibility/los_lifecycle.dm').read_text(encoding='utf-8')
        flood = (ROOT / 'code/modules/1713/flood_effects.dm').read_text(encoding='utf-8')
        geometry = lifecycle.split('/client/proc/reconcile_geometric_los()', 1)[1].split('\n/proc/', 1)[0]
        self.assertIn('present_water_overlays(S)', geometry)
        self.assertIn('if(!S)', geometry)
        self.assertIn('clear_water_overlays()', geometry.split('if(!S)', 1)[1].split('if(audit_only', 1)[0])
        self.assertIn('if (flood_changed || signs_changed || geometric != client.water_overlay_geometric)', flood)
        self.assertIn('ishuman(mob) && eye == mob && !adminobs', flood)
        self.assertEqual(flood.count('client.los_context.capture(TRUE)'), 1)

    def test_flood_view_row_indices_match_the_clipped_grid(self):
        effects = (ROOT / 'code/modules/1713/flood_effects.dm').read_text(encoding='utf-8')
        view = effects.split('/client/proc/flood_refresh_view()', 1)[1].split('\n/', 1)[0]
        match = re.search(
            r'for \(var/y in y0 \+ 1 to y1 - 1\)\s+'
            r'var/row_offset = ([^\n]+)\s+'
            r'for \(var/x in x0 \+ 1 to x1 - 1\)\s+'
            r'var/band = bands\[([^\n]+)\]', view)
        self.assertIsNotNone(match, 'redraw loop must expose its row and cell index')
        row_expr, cell_expr = match.groups()
        # Interior, edges, corners and small maps exercise clipped windows.
        for maxx, maxy, cx, cy in ((100, 100, 50, 50), (100, 100, 1, 50),
                                   (100, 100, 100, 100), (8, 6, 1, 1)):
            x0, x1 = max(1, cx - 13), min(maxx, cx + 13)
            y0, y1 = max(1, cy - 13), min(maxy, cy + 13)
            w = x1 - x0 + 1
            for y in range(y0 + 1, y1):
                local = dict(y=y, y0=y0, x0=x0, w=w)
                local['row_offset'] = eval(row_expr, {'__builtins__': {}}, local)
                for x in range(x0 + 1, x1):
                    local['x'] = x
                    actual = eval(cell_expr, {'__builtins__': {}}, local)
                    expected = (y - y0) * w + (x - x0) + 1
                    self.assertEqual(actual, expected, (maxx, maxy, x, y))
                    self.assertTrue(1 <= actual <= w * (y1 - y0 + 1))

    def test_state_is_saved_and_cache_is_not(self):
        self.assertIn('key == "river_flood_cache" || key == "river_flood_loaded"', MODULE)
        self.assertIn('var/tmp/datum/river_flood/river_flood_cache', MODULE)
        contract = (ROOT / 'code/modules/persistence/durable_contract.dm').read_text(encoding='utf-8')
        self.assertIn('"river_flood_state"', contract)



class DefencesTest(unittest.TestCase):
    """Stone and Classical defences; behaviour is in defences_probe.dm."""

    def test_wiring(self):
        defences = (ROOT / 'code/modules/1713/flood_defences.dm').read_text(encoding='utf-8')
        self.assertIn('/turf/var/tmp/flood_raise = 0', defences)
        self.assertIn('. = max(0, . - T.flood_raise)', MODULE)
        ground = (ROOT / 'code/modules/1713/flood_ground.dm').read_text(encoding='utf-8')
        self.assertIn('for (var/obj/structure/sluice_gate/G in T)', ground)
        self.assertIsNone(re.search(r'(?<![_\w])spawn\(', defences))
        self.assertNotIn('in world', defences)
        self.assertIn('list("collection_seconds", "last_collection_tick", "roofs", "roofs_counted")', defences)
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertLess(dme.index('1713\\sewers.dm"'), dme.index('1713\\flood_defences.dm"'))

    def test_recipes_and_art(self):
        recipes = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
        research = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
        for name, path, node in (
                ('stilt platform', '/obj/structure/flood_platform/stilts', 'primitive_construction'),
                ('stone plinth', '/obj/structure/flood_platform/plinth', 'stone_masonry'),
                ('sluice gate', '/obj/structure/sluice_gate', 'irrigation'),
                ('shaduf', '/obj/structure/water_lift/shaduf', 'basic_agriculture'),
                ('Archimedes screw', '/obj/structure/water_lift/archimedes_screw', 'irrigation'),
                ('river gauge', '/obj/structure/river_gauge', 'basic_agriculture'),
                ('cistern', '/obj/structure/reagent_dispensers/cistern', 'paved_infrastructure'),
                ('hand bilge and cellar pump', '/obj/structure/cellar_pump/lever', 'workshops'),
                ('steam bilge and mine pump', '/obj/structure/cellar_pump/steam', 'steam_power'),
                ('sump pump', '/obj/structure/cellar_pump/sump', 'utilities'),
                ('windmill pump', '/obj/structure/water_lift/windmill', 'watermills')):
            self.assertRegex(recipes, rf'RECIPE: /material/\w+/,{name},{path},')
            self.assertIn(f'"{path}" = "{node}",', research)
        from PIL import Image
        meta = Image.open(ROOT / 'icons/obj/flood_defences.dmi').info['Description']
        states = {line.split('"')[1] for line in meta.splitlines() if line.startswith('state = ')}
        for state in ('stilts', 'plinth', 'sluice_gate', 'sluice_gate_open', 'shaduf', 'shaduf_use',
                      'archimedes_screw', 'archimedes_screw_use', 'river_gauge',
                      'cistern0', 'cistern1', 'cistern2', 'cistern3',
                      'lever_pump', 'lever_pump_use', 'mine_pump', 'mine_pump_on',
                      'windmill_pump', 'windmill_pump_on', 'sump_pump', 'sump_pump_on'):
            self.assertIn(state, states)



class CellarTest(unittest.TestCase):
    """Seepage and bailing; behaviour is in cellar_probe.dm."""

    def test_wiring(self):
        cellars = (ROOT / 'code/modules/1713/flood_cellars.dm').read_text(encoding='utf-8')
        self.assertIn("return T.z == F.cellar_z() ? F.seep_depth_at(T) : 0", MODULE)
        self.assertIn('cellar_z_cache = z_level ? multiz_level_below(z_level) : 0', cellars)
        self.assertIsNone(re.search(r'(?<![_\w])spawn\(', cellars))
        self.assertNotIn('in world', cellars)
        glass = (ROOT / 'code/modules/reagents/reagent_containers/glass.dm').read_text(encoding='utf-8')
        self.assertIn('if (try_bail(attacked, user))', glass)
        effects = (ROOT / 'code/modules/1713/flood_effects.dm').read_text(encoding='utf-8')
        self.assertIn('if (centre.z != F.z_level && centre.z != F.cellar_z())', effects)
        sewers = (ROOT / 'code/modules/1713/sewers.dm').read_text(encoding='utf-8')
        self.assertIn('for (var/obj/structure/cellar_pump/C in cellar_pumps)', sewers)
        self.assertIn('W.windmill_minute()', sewers)
        pumps = (ROOT / 'code/modules/1713/flood_pumps.dm').read_text(encoding='utf-8')
        self.assertIsNone(re.search(r'(?<![_\w])spawn\(', pumps))
        self.assertNotIn('in world', pumps)

    def test_hand_and_steam_pump_examine_names_bilge_and_land_uses(self):
        pumps = (ROOT / 'code/modules/1713/flood_pumps.dm').read_text(encoding='utf-8')
        for subtype, name in (('lever', 'hand bilge and cellar pump'), ('steam', 'steam bilge and mine pump')):
            with self.subTest(subtype=subtype):
                path = '/obj/structure/cellar_pump/' + subtype
                definition = pumps.split(path + '\n', 1)[1].split('\n/', 1)[0]
                self.assertIn(f'name = "{name}"', definition)
                examine = pumps.split(path + '/examine(', 1)[1].split('\n/', 1)[0]
                for use in ('cellar', 'mine', 'bilge'):
                    self.assertIn(use, examine)



class DugWellsTest(unittest.TestCase):
    """Player-dug wells; behaviour is in wells_probe.dm."""

    def test_wiring(self):
        wells = (ROOT / 'code/modules/1713/dug_wells.dm').read_text(encoding='utf-8')
        self.assertIn('/proc/well_water_table(turf/T)', wells)
        self.assertIn('terrain_height_at(T) - river_stage_at(T)', wells)
        self.assertIn('if (flood_depth_at(T) > 0)', wells)
        self.assertIsNone(re.search(r'(?<![_\w])spawn\(', wells))
        self.assertNotIn('in world', wells)
        self.assertNotIn('/process()', wells)
        tools = (ROOT / 'code/modules/1713/tools.dm').read_text(encoding='utf-8')
        self.assertIn('"Cesspit", "Well", "Cancel")', tools)
        self.assertIn('shovel_dig_well(user, TB)', tools)
        stack = (ROOT / 'code/game/objects/items/stacks/stack.dm').read_text(encoding='utf-8')
        self.assertIn('if (!well_build_site(get_turf(H)))', stack)
        self.assertIn('&& !well_relining(recipe.result_type, user.loc))', stack)
        self.assertIn('if (!P.dug_depth)', stack)
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertLess(dme.index('1713\\flood_defences.dm"'), dme.index('1713\\dug_wells.dm"'))

    def test_recipes_and_art(self):
        recipes = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
        research = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
        self.assertRegex(recipes, r'RECIPE: /material/wood/,timber well lining,/obj/structure/sink/well/timber,')
        self.assertIn('"/obj/structure/sink/well/timber" = "primitive_construction",', research)
        for name, path, node in (('windlass and pail', '/obj/structure/well_fitting/windlass', 'cooperage'),
                                 ('cast iron hand pump', '/obj/structure/well_fitting/pump', 'iron_tools')):
            self.assertRegex(recipes, rf'RECIPE: /material/\w+/,{name},{path},')
            self.assertIn(f'"{path}" = "{node}",', research)
            # a title with "well" in it would be held to the build-over-a-puddle rule
            self.assertNotIn('well', name)
        import json
        needs = json.loads((ROOT / 'config/craft_needs.json').read_text(encoding='utf-8'))
        self.assertEqual(needs['/obj/structure/well_fitting/windlass']['inputs'], {'/obj/item/stack/material/rope': 2})
        wells = (ROOT / 'code/modules/1713/dug_wells.dm').read_text(encoding='utf-8')
        self.assertIn('/datum/craft_guard/well_fitting/refusal(', wells)
        self.assertIn('if (locate(/obj/structure/sink/well) in get_turf(H))', wells)
        # every well can be taken apart: fitting, lining, then the hole
        self.assertIn('if (is_tool(O, TOOL_HAMMER))\n\t\twell_break(user)', wells)
        self.assertIn('if (dug_lined())', wells)
        self.assertIn('/obj/structure/sink/well/ex_act(severity)', wells)
        self.assertEqual(wells.count('log_game("[key_name(user)]'), 2)
        from PIL import Image
        meta = Image.open(ROOT / 'icons/obj/wells.dmi').info['Description']
        states = {line.split('"')[1] for line in meta.splitlines() if line.startswith('state = ')}
        # the waterhole is a puddle, which shows "puddle-splash" while in use
        for state in ('waterhole', 'waterhole_dry', 'puddle-splash', 'timber_well', 'timber_well_dry',
                      'fit_windlass', 'fit_windlass_use', 'fit_pump', 'fit_pump_use'):
            self.assertIn(state, states)


if __name__ == '__main__':
    unittest.main()
