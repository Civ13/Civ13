"""Offline checks for the river flood sidecar (scripts/river_flood.py)."""
import importlib.util
import sys
import tempfile
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
        self.reaches, self.labels, self.thresholds = flood.build(self.rows, self.heights)

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
        flood.write_flood(out, 70, 9, 1, self.reaches, self.labels, self.thresholds)
        self.assertEqual(flood.read_flood(out), (70, 9, 1, self.reaches, self.labels, self.thresholds))
        text = out.read_text(encoding='ascii')
        self.assertTrue(text.startswith('civ13-river-flood 1\nsize 70 9\nz 1\nreaches 3\nr 1 2 '))


class CommittedSidecarTest(unittest.TestCase):
    def test_sidecars_match_their_maps(self):
        from terrain_heights import read_dmm, read_heights
        for name, z in SIDECARS.items():
            with self.subTest(name):
                _, _, levels = read_dmm(ROOT / f'maps/nomads/{name}.dmm')
                _, _, heights = read_heights(ROOT / f'maps/heights/{name}.txt')
                built = flood.build(levels[z], heights[z])
                width, height, fz, reaches, labels, thresholds = flood.read_flood(ROOT / f'maps/heights/{name}.flood.txt')
                self.assertEqual(fz, z)
                self.assertEqual((reaches, labels, thresholds), built, f'regenerate {name}.flood.txt (docs/river-flood.md)')
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

    def test_drawing_stays_in_the_viewers_window(self):
        effects = (ROOT / 'code/modules/1713/flood_effects.dm').read_text(encoding='utf-8')
        view = effects.split('/client/proc/flood_refresh_view()', 1)[1].split('\n/', 1)[0]
        self.assertNotIn('in world', view)
        self.assertNotIn('range(', view)
        self.assertIn('FLOOD_VIEW_MOVE', view)
        self.assertIn('flood_drawn_revision == flood_draw_revision', view)

    def test_state_is_saved_and_cache_is_not(self):
        self.assertIn('key == "river_flood_cache" || key == "river_flood_loaded"', MODULE)
        self.assertIn('var/tmp/datum/river_flood/river_flood_cache', MODULE)
        contract = (ROOT / 'code/modules/persistence/durable_contract.dm').read_text(encoding='utf-8')
        self.assertIn('"river_flood_state"', contract)


if __name__ == '__main__':
    unittest.main()
