"""Offline checks for terrain heights: the generator tool and the movement hook.

The native probe (run.py) covers the game's parser, lookup and slope cost.
"""
from pathlib import Path
import importlib.util
import json
import re
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('terrain_heights', ROOT / 'scripts/terrain_heights.py')
tool = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(tool)
MOVEMENT = (ROOT / 'code/game/mob/mob_movement.dm').read_text(encoding='utf-8')
MODULE = (ROOT / 'code/modules/1713/terrain_height.dm').read_text(encoding='utf-8')

# 10x6 level: sea on the west, a beach, grass, and a rock ridge on the east.
TINY_DMM = '''"a" = (/turf/floor/beach/water/deep/saltwater,/area/caribbean/sea/sea)
"b" = (/turf/floor/beach/sand,/area/caribbean/nomads/forest)
"c" = (/turf/floor/grass,/area/caribbean/nomads/forest)
"d" = (/turf/wall/rockwall,/area/caribbean/nomads/forest)

(1,1,1) = {"
aabcccccdd
aabcccccdd
aabcccccdd
aabcccccdd
aabcccccdd
aabcccccdd
"}
'''


class Generator(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        (self.tmp / 'tiny.dmm').write_text(TINY_DMM, encoding='utf-8')

    def generate(self, seed=13):
        out = self.tmp / f'tiny-{seed}.txt'
        tool.main(['generate', '--map', str(self.tmp / 'tiny.dmm'), '--z', '1', '--out', str(out), '--seed', str(seed)])
        return out

    def test_round_trip_and_format(self):
        out = self.generate()
        text = out.read_text(encoding='ascii')
        self.assertTrue(text.startswith('civ13-terrain-heights 1\nsize 10 6\nz 1\n'))
        self.assertNotIn('\r', text)
        maxx, maxy, levels = tool.read_heights(out)
        self.assertEqual((maxx, maxy, list(levels)), (10, 6, [1]))
        rows = levels[1]
        self.assertTrue(all(v == 0 for row in rows for v in row[:2]), 'water stays at 0')
        self.assertTrue(all(row[2] <= 1 for row in rows), 'beach is at most 1')
        for y in range(6):
            for x in range(10):
                for nx, ny in ((x + 1, y), (x, y + 1)):
                    if nx < 10 and ny < 6:
                        self.assertLessEqual(abs(rows[y][x] - rows[ny][nx]), tool.MAX_NEIGHBOUR_STEP)

    def test_design_reads_the_terrain(self):
        spec = self.tmp / 'spec.json'
        spec.write_text(json.dumps({'ridges': [{'points': [[5, 1], [5, 6]], 'height': 5, 'steep_side': 'left'}],
                                    'flat': [{'x1': 7, 'y1': 3, 'x2': 7, 'y2': 4, 'height': 2}]}), encoding='utf-8')
        out = self.tmp / 'design.txt'
        tool.main(['design', '--map', str(self.tmp / 'tiny.dmm'), '--z', '1', '--out', str(out), '--spec', str(spec)])
        maxx, maxy, levels = tool.read_heights(out)
        rows = levels[1]
        self.assertTrue(all(row[0] == row[1] == 0 for row in rows), 'water stays at 0')
        self.assertTrue(all(row[2] <= 1 for row in rows), 'beach stays at most 1')
        self.assertTrue(all(row[8] >= tool.DESIGN_DEFAULTS['highland_base'] for row in rows), 'rock walls are highland')
        self.assertTrue(all(row[4] >= 4 for row in rows), 'the ridge spine is raised')
        self.assertEqual({rows[maxy - 3][6], rows[maxy - 4][6]}, {2}, 'flat rectangles are honoured')
        for y in range(maxy):
            for x in range(2, 8):
                for nx, ny in ((x + 1, y), (x, y + 1)):
                    if nx < 8 and ny < maxy:
                        self.assertLessEqual(abs(rows[y][x] - rows[ny][nx]), tool.DESIGN_MAX_STEP)
        self.assertEqual(out.read_text(), out.read_text())

    def test_seeded_and_deterministic(self):
        self.assertEqual(self.generate(5).read_text(), self.generate(5).read_text())

    def test_check_and_bad_files(self):
        out = self.generate()
        tool.main(['check', '--heights', str(out), '--map', str(self.tmp / 'tiny.dmm')])
        bad = self.tmp / 'bad.txt'
        for text in ('civ13-terrain-heights 2\nsize 1 1\nz 1\n0\n',
                     'civ13-terrain-heights 1\nsize 2 1\nz 1\n0\n',
                     'civ13-terrain-heights 1\nsize 1 1\nz 1\nA\n',
                     'civ13-terrain-heights 1\nsize 1 1\nz 1\n0\nz 1\n0\n'):
            bad.write_text(text, encoding='ascii')
            with self.assertRaises(ValueError):
                tool.read_heights(bad)

    def test_png_round_trip(self):
        try:
            import PIL  # noqa: F401
        except ImportError:
            self.skipTest('Pillow not installed')
        out = self.generate()
        png = self.tmp / 'tiny.png'
        tool.main(['to-png', '--heights', str(out), '--z', '1', '--out', str(png)])
        copy = self.tmp / 'copy.txt'
        tool.main(['from-png', '--png', str(png), '--z', '1', '--out', str(copy)])
        self.assertEqual(tool.read_heights(copy), tool.read_heights(out))


class Shading(unittest.TestCase):
    def test_baked_sprites_match_the_tool(self):
        import numpy
        from PIL import Image
        dmi = Image.open(ROOT / 'icons/turf/terrain_shade.dmi')
        states = re.findall(r'state = "(\w+)"', dmi.info['Description'])
        self.assertEqual(states, tool.shade_states())
        self.assertNotIn('cccc', states)
        sheet = numpy.asarray(dmi.convert('RGBA'))
        for i, key in enumerate(states):
            y, x = divmod(i, 25)
            numpy.testing.assert_array_equal(sheet[y * 32:(y + 1) * 32, x * 32:(x + 1) * 32], tool.shade_pixels(numpy, key), key)

    def test_flat_ground_is_unlit_and_slopes_face_the_light(self):
        import numpy
        flat = tool.corner_lights(numpy, [[3] * 6] * 6)
        self.assertTrue((flat == 0).all())
        # Rising to the east faces west, towards the north-west light.
        east = tool.corner_lights(numpy, [[x for x in range(6)] for _ in range(6)])
        self.assertGreater(east[3, 3], 0)
        west = tool.corner_lights(numpy, [[5 - x for x in range(6)] for _ in range(6)])
        self.assertLess(west[3, 3], 0)

    def test_neighbouring_tiles_share_corner_lights(self):
        import numpy
        sprite_a = tool.shade_pixels(numpy, 'ceac')
        sprite_b = tool.shade_pixels(numpy, 'ecca')
        # a's east edge corners (e, c) equal b's west edge corners (e, c): edge columns nearly match.
        self.assertLessEqual(numpy.abs(sprite_a[:, -1, 3].astype(int) - sprite_b[:, 0, 3].astype(int)).max(), 12)

    def test_gaia_heights_match_the_map(self):
        tool.main(['check', '--heights', str(ROOT / 'maps/heights/nomads_gaia.txt'), '--map', str(ROOT / 'maps/nomads/nomads_gaia.dmm')])
        gaia = (ROOT / 'code/game/objects/map_metadata/nomads/nomads_gaia.dm').read_text(encoding='utf-8')
        self.assertIn('terrain_height_file = "maps/heights/nomads_gaia.txt"', gaia)

    def test_gaia_heights_are_designed(self):
        """Gaia's file comes from the design command: steep grades, but never more than the game counts."""
        maxx, maxy, levels = tool.read_heights(ROOT / 'maps/heights/nomads_gaia.txt')
        _, _, turfs = tool.read_dmm(ROOT / 'maps/nomads/nomads_gaia.dmm')
        rows, turf_rows = levels[2], turfs[2]
        self.assertTrue(json.loads((ROOT / 'maps/heights/nomads_gaia.design.json').read_text(encoding='utf-8'))['ridges'])
        walkable = [[not (t.startswith('/turf/wall') or 'water' in t) for t in row] for row in turf_rows]
        steps = [0] * (tool.MAX_LEVEL + 1)
        for y in range(maxy):
            for x in range(maxx):
                if 'water' in turf_rows[y][x]:
                    self.assertEqual(rows[y][x], 0, f'water at {x + 1},{maxy - y} must be 0')
                if not walkable[y][x]:
                    continue
                for nx, ny in ((x + 1, y), (x, y + 1)):
                    if nx < maxx and ny < maxy and walkable[ny][nx]:
                        steps[abs(rows[y][x] - rows[ny][nx])] += 1
        self.assertEqual(sum(steps[tool.DESIGN_MAX_STEP + 1:]), 0, 'no walkable step is steeper than the game counts')
        self.assertGreater(steps[3] + steps[4], 2000, 'Gaia has real steep grades')
        self.assertGreaterEqual(max(v for row in rows for v in row), 13, 'highlands reach the upper levels')


class Wiring(unittest.TestCase):
    def test_client_move_adds_slope_cost_for_walking_living_mobs(self):
        hook = re.search(r'\n\t\t// Hills:.*\n\t\tif \(mob_is_living && !mob\.buckled && isturf\(mob_loc\) && isturf\(n\)\)\n'
                         r'\t\t\tmove_delay \+= terrain_slope_delay\(mob_loc, n, move_delay - world\.time\)\n', MOVEMENT)
        self.assertIsNotNone(hook)
        # After the intent costs, so the downhill cap sees the whole step delay.
        self.assertLess(MOVEMENT.index('if ("proning")'), hook.start())

    def test_client_move_applies_climb_effects_to_humans(self):
        self.assertIn('\t\t\tif (mob_is_human)\n\t\t\t\tterrain_climb_effects(H, mob_loc, n, distance_fraction)\n', MOVEMENT)
        self.assertIn('#define TERRAIN_STEEP_LEVELS 3', MODULE)
        self.assertIn('/proc/terrain_climb_effects(mob/living/human/H, turf/origin, turf/destination, distance_fraction = 1)', MODULE)
        self.assertIn('var/levels = terrain_step_levels(origin, destination)', MODULE)
        self.assertIn('You scramble up the steep slope.', MODULE)
        self.assertIn('You pick your way down the steep slope.', MODULE)

    def test_parser_matches_tool_format(self):
        self.assertIn(f'"{tool.HEADER.split()[0]}"', MODULE)
        self.assertIn('regex(@"[^0-9a-f]")', MODULE)
        self.assertEqual(tool.DIGITS, '0123456789abcdef')

    def test_shading_is_placed_once_and_kept_on_turf_changes(self):
        ticker = (ROOT / 'code/processes/ticker.dm').read_text(encoding='utf-8')
        self.assertIn('\tterrain_shading_check()\n', ticker)
        changing = (ROOT / 'code/game/turfs/turf_changing.dm').read_text(encoding='utf-8')
        self.assertIn('\tif (terrain_shading_applied)\n\t\tW.terrain_shade_refresh()\n\treturn W\n', changing)
        self.assertIn('mouse_opacity = 0', MODULE)
        self.assertIn('should_save = FALSE', MODULE)

    def test_heights_are_not_saved(self):
        self.assertIn('var/tmp/datum/terrain_heights/terrain_heights_cache', MODULE)
        self.assertIn('key == "terrain_height_file" || key == "terrain_heights_cache"', MODULE)


if __name__ == '__main__':
    unittest.main()
