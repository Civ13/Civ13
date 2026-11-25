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
        self.assertTrue(text.startswith('civ13-terrain-heights 2\nsize 10 6\nz 1\n'))
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
        for text in ('civ13-terrain-heights 3\nsize 1 1\nz 1\n0\n',
                     'civ13-terrain-heights 2\nsize 1 1\nz 1\n~\n',
                     'civ13-terrain-heights 1\nsize 1 1\nz 1\ng\n',
                     'civ13-terrain-heights 1\nsize 2 1\nz 1\n0\n',
                     'civ13-terrain-heights 1\nsize 1 1\nz 1\nA\n',
                     'civ13-terrain-heights 1\nsize 1 1\nz 1\n0\nz 1\n0\n'):
            bad.write_text(text, encoding='ascii')
            with self.assertRaises(ValueError):
                tool.read_heights(bad)

    def test_half_levels_round_trip(self):
        out = self.tmp / 'halves.txt'
        rows = [[0, 0.5, 1, 1.5, 9.5, 10], [15, 15.5, 25.5, 26.5, 31, 31.5]]
        tool.write_heights(out, 6, 2, {1: rows})
        self.assertEqual(out.read_text(encoding='ascii').split('\n')[3:5], ['0A1BJa', 'fPZ!v+'])
        self.assertEqual(tool.read_heights(out), (6, 2, {1: rows}))
        self.assertEqual(len(tool.DIGITS), 64)
        self.assertEqual(len(set(tool.DIGITS)), 64)

    def test_version_1_files_still_read(self):
        old = self.tmp / 'old.txt'
        old.write_text('civ13-terrain-heights 1\nsize 3 1\nz 1\n09f\n', encoding='ascii')
        self.assertEqual(tool.read_heights(old), (3, 1, {1: [[0, 9, 15]]}))

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

    def test_baked_terrace_sprites_match_the_tool(self):
        import numpy
        from PIL import Image
        dmi = Image.open(ROOT / 'icons/turf/terrain_terrace.dmi')
        states = re.findall(r'state = "(\w+)"', dmi.info['Description'])
        self.assertEqual(states, tool.terrace_states())
        sheet = numpy.asarray(dmi.convert('RGBA'))
        for i, key in enumerate(states):
            y, x = divmod(i, tool.TERRACE_COLS)
            pixels = tool.terrace_pixels(numpy, key)
            self.assertTrue(pixels[..., 3].any(), f'{key} draws nothing')
            numpy.testing.assert_array_equal(sheet[y * 32:(y + 1) * 32, x * 32:(x + 1) * 32], pixels, key)

    def test_baked_north_terrace_sprites_match_the_tool(self):
        import numpy
        from PIL import Image
        dmi = Image.open(ROOT / 'icons/turf/terrain_terrace_n.dmi')
        states = re.findall(r'state = "(\w+)"', dmi.info['Description'])
        self.assertEqual(states, tool.terrace_states())
        sheet = numpy.asarray(dmi.convert('RGBA'))
        for i, key in enumerate(states):
            y, x = divmod(i, tool.TERRACE_COLS)
            numpy.testing.assert_array_equal(sheet[y * 32:(y + 1) * 32, x * 32:(x + 1) * 32],
                                             tool.terrace_pixels(numpy, key, light=tool.TERRACE_NORTH_LIGHT), key)

    def test_turned_terrace_sprites_are_lit_from_the_suns_side(self):
        import numpy
        # The game shows the two baked sets turned by quarter turns (terrain_terrace_image):
        # each turned sprite is exactly the tile's own lines lit from that side.
        sides = ((tool.LIGHT[:2], ((1, -1), (1, 1), (-1, 1))), (tool.TERRACE_NORTH_LIGHT, ((1, 0), (0, 1), (-1, 0))))
        for base, lights in sides:
            for turns, light in enumerate(lights, 1):
                for key in tool.terrace_states()[::61]:
                    turned = numpy.rot90(tool.terrace_pixels(numpy, tool.terrace_turned_key(key, turns), light=base), -turns)
                    numpy.testing.assert_array_equal(turned, tool.terrace_pixels(numpy, key, light=light), (key, light))
        # Rising to the east: lit warm from the west, dark from the east.
        self.assertTrue((tool.terrace_pixels(numpy, '00202', light=(1, 0))[..., :3].max(axis=2) <= max(tool.DARK_COLOUR)).all())
        module = (ROOT / 'code/modules/1713/terrain_height.dm').read_text(encoding='utf-8')
        self.assertIn('state = copytext(state, 1, 2) + copytext(state, 3, 4) + copytext(state, 5, 6) + copytext(state, 2, 3) + copytext(state, 4, 5)', module)

    def test_terrace_keys(self):
        import numpy
        # Flat ground and a rise that stays inside one level have no line.
        self.assertIsNone(tool.terrace_key(3, 3, 3, 3))
        self.assertIsNone(tool.terrace_key(3, 3.5, 3, 3.5))
        # Crossing a whole level draws one; the key is relative to the lowest corner.
        self.assertEqual(tool.terrace_key(3, 4, 3, 4), '00202')
        self.assertEqual(tool.terrace_key(7.5, 8, 7.5, 8), '10101')
        self.assertEqual(tool.terrace_key(0, 9, 0, 9), '00606')
        for key in ('00202', '10101', '00606'):
            self.assertIn(key, tool.terrace_states())
        corners = tool.corner_heights(numpy, [[x for x in range(6)] for _ in range(6)])
        self.assertTrue((corners * 2 == numpy.floor(corners * 2)).all())

    def test_terrace_lines_face_the_light_and_join(self):
        import numpy
        # Rising to the east: the drop faces west, towards the light, so the line is warm.
        east = tool.terrace_pixels(numpy, '00202')
        self.assertTrue((east[east[..., 3] > 30][:, :3] == tool.LIGHT_COLOUR).all())
        west = tool.terrace_pixels(numpy, '02020')
        self.assertTrue((west[west[..., 3] > 30][:, :3] == tool.DARK_COLOUR).all())
        self.assertGreater(west[..., 3].max(), 50)
        # Soft and quiet: nothing stronger than about a third.
        self.assertLessEqual(max(tool.terrace_pixels(numpy, k)[..., 3].max() for k in tool.terrace_states()[::37]), 80)
        # Two tiles on one diagonal slope: the line crossing their shared edge agrees along it.
        left = tool.terrace_pixels(numpy, '00112')
        right = tool.terrace_pixels(numpy, '10112')
        self.assertGreater(left[:, -1, 3].max(), 30)
        # The line is diagonal, so it steps one pixel between the two edge columns.
        self.assertLessEqual(numpy.abs(left[1:, -1, 3].astype(int) - right[:-1, 0, 3].astype(int)).max(), 16)

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

    def test_every_height_file_matches_its_map(self):
        """Each map metadata naming a height file has that file and the sizes match; designed maps keep
        their design spec (generated lands, docs/americas-regions.md, get heights from their generator)."""
        generated = {'nomads_americas_north', 'nomads_americas_south'}
        named = {}
        for path in (ROOT / 'code/game/objects/map_metadata').rglob('*.dm'):
            for match in re.finditer(r'terrain_height_file = "(maps/heights/(\w+)\.txt)"', path.read_text(encoding='utf-8')):
                named[match.group(2)] = match.group(1)
        self.assertGreaterEqual(len(named), 5)
        for name, heights in named.items():
            with self.subTest(map=name):
                if name not in generated:
                    self.assertTrue((ROOT / f'maps/heights/{name}.design.json').exists(), f'{name} needs a design spec')
                tool.main(['check', '--heights', str(ROOT / heights), '--map', str(ROOT / f'maps/nomads/{name}.dmm')])
                maxx, maxy, levels = tool.read_heights(ROOT / heights)
                _, _, turfs = tool.read_dmm(ROOT / f'maps/nomads/{name}.dmm')
                for z, rows in levels.items():
                    turf_rows = turfs[z]
                    for y in range(maxy):
                        for x in range(maxx):
                            if 'water' in turf_rows[y][x]:
                                self.assertEqual(rows[y][x], 0, f'{name} water at {x + 1},{maxy - y} must be 0')
                            elif rows[y][x] and (x + 1 < maxx) and 'water' not in turf_rows[y][x + 1]:
                                self.assertLessEqual(abs(rows[y][x] - rows[y][x + 1]), tool.DESIGN_MAX_STEP)

    def test_gaia_heights_are_designed(self):
        """Gaia's file comes from the design command: steep grades, but never more than the game counts."""
        maxx, maxy, levels = tool.read_heights(ROOT / 'maps/heights/nomads_gaia.txt')
        _, _, turfs = tool.read_dmm(ROOT / 'maps/nomads/nomads_gaia.dmm')
        rows, turf_rows = levels[2], turfs[2]
        self.assertTrue(json.loads((ROOT / 'maps/heights/nomads_gaia.design.json').read_text(encoding='utf-8'))['ridges'])
        walkable = [[not (t.startswith('/turf/wall') or 'water' in t) for t in row] for row in turf_rows]
        steps = [0] * int(tool.MAX_LEVEL * 2 + 1)  # by half levels
        for y in range(maxy):
            for x in range(maxx):
                if 'water' in turf_rows[y][x]:
                    self.assertEqual(rows[y][x], 0, f'water at {x + 1},{maxy - y} must be 0')
                if not walkable[y][x]:
                    continue
                for nx, ny in ((x + 1, y), (x, y + 1)):
                    if nx < maxx and ny < maxy and walkable[ny][nx]:
                        steps[int(abs(rows[y][x] - rows[ny][nx]) * 2)] += 1
        self.assertEqual(sum(steps[tool.DESIGN_MAX_STEP * 2 + 1:]), 0, 'no walkable step is steeper than the game counts')
        self.assertGreater(sum(steps[6:tool.DESIGN_MAX_STEP * 2 + 1]), 2000, 'Gaia has real steep grades')
        self.assertGreater(sum(steps[1::2]), 2000, 'Gaia uses half levels')
        self.assertGreaterEqual(max(v for row in rows for v in row), 13, 'highlands reach the upper levels')


class Wiring(unittest.TestCase):
    def test_client_move_adds_slope_cost_for_walking_living_mobs(self):
        hook = re.search(r'\n\t\t// Hills:.*\n(?:\t\t//.*\n)*\t\tif \(mob_is_living && !mob\.buckled && isturf\(mob_loc\) && isturf\(n\)\)\n'
                         r'\t\t\tif \(mob_is_human && fine_step\)\n'
                         r'\t\t\t\tmove_delay \+= terrain_free_slope_delay\(H, n, direct, move_delay - world\.time, fine_step == FINE_STEP_HELD\)\n'
                         r'\t\t\telse\n'
                         r'\t\t\t\tmove_delay \+= terrain_slope_delay\(mob_loc, n, move_delay - world\.time\)\n', MOVEMENT)
        self.assertIsNotNone(hook)
        # After the intent costs, so the downhill cap sees the whole step delay.
        self.assertLess(MOVEMENT.index('if ("proning")'), hook.start())

    def test_client_move_applies_climb_effects_to_humans(self):
        after_move = MOVEMENT.index("terrain_completed_step(H, slope_origin, n")
        self.assertGreater(after_move, MOVEMENT.index(". = mob.SelfMove(n, direct)"))
        self.assertNotIn("terrain_climb_effects(H, mob_loc", MOVEMENT)
        self.assertIn("H.client == src", MOVEMENT[MOVEMENT.index("skipgrab:"):after_move])
        completed = MODULE.split("/proc/terrain_completed_step", 1)[1].split("/proc/terrain_trip_check", 1)[0]
        self.assertLess(completed.index("if (distance_fraction <= 0)"), completed.index("terrain_climb_effects"))
        self.assertIn("if (arrival == destination)", completed)
        self.assertIn('You lose your footing and tumble down the slope!', MODULE)
        self.assertIn('#define TERRAIN_STEEP_LEVELS 3', MODULE)
        self.assertIn('/proc/terrain_climb_effects(mob/living/human/H, turf/origin, turf/destination, distance_fraction = 1)', MODULE)
        self.assertIn('var/levels = terrain_step_levels(origin, destination)', MODULE)
        self.assertIn('You scramble up the steep slope.', MODULE)
        self.assertIn('You pick your way down the steep slope.', MODULE)

    def test_parser_matches_tool_format(self):
        self.assertIn(f'"{tool.HEADER.split()[0]}"', MODULE)
        self.assertIn('regex(@"[^0-9a-f]")', MODULE)
        self.assertIn('regex(@"[^0-9a-vA-Z!#$%&+]")', MODULE)
        self.assertIn(f'#define TERRAIN_HEIGHT_WHOLE "{tool.WHOLE}"', MODULE)
        self.assertIn(f'#define TERRAIN_HEIGHT_HALF "{tool.HALF}"', MODULE)
        defines = (ROOT / 'code/__defines/turfs.dm').read_text(encoding='utf-8')
        self.assertIn(f'#define TERRAIN_MAX_LEVEL {tool.MAX_LEVEL}', defines)

    def test_shading_is_placed_once_and_kept_on_turf_changes(self):
        ticker = (ROOT / 'code/processes/ticker.dm').read_text(encoding='utf-8')
        self.assertIn('\tterrain_shading_check()\n', ticker)
        changing = (ROOT / 'code/game/turfs/turf_changing.dm').read_text(encoding='utf-8')
        self.assertIn('\tif (terrain_shading_applied)\n\t\tW.terrain_shade_refresh()\n', changing)
        self.assertIn('I.mouse_opacity = 0', MODULE)
        # Floor icon rebuilds clear overlays; the shading must go back on.
        floor_icon = (ROOT / 'code/game/turfs/floor_icon.dm').read_text(encoding='utf-8')
        self.assertIn('\tsnowfall_ground_icon()\n\tterrain_shade_icon()\n', floor_icon)

    def test_shading_is_an_overlay_not_vis_contents(self):
        # Turf vis_contents shading was held by the server but never drawn by
        # the real client, so live hills looked flat.
        self.assertNotIn('vis_contents', MODULE.split('// Slope shading', 1)[1].split('/proc/terrain_shading_apply', 1)[0].replace('turf vis_contents never reached', ''))
        self.assertIn('I.plane = FLOOR_PLANE', MODULE)
        self.assertIn('overlays += shade', MODULE)

    def test_shading_draws_over_fallen_snow(self):
        # Fallen snow is an opaque overlay on dirt and grass; shading under it
        # left snowy hills flat all winter.
        snow = (ROOT / 'code/modules/1713/snowfall_ground.dm').read_text(encoding='utf-8')
        snow_layer = float(re.search(r'icon_state = "snow", layer = ([0-9.]+)\)', snow).group(1))
        shade_layer = float(re.search(r'#define TERRAIN_SHADE_LAYER ([0-9.]+)', MODULE).group(1))
        self.assertGreater(shade_layer, snow_layer)
        self.assertLess(shade_layer, 2.04)  # winter's decal copies stay on top
        self.assertIn('layer = TERRAIN_SHADE_LAYER)', MODULE)

    def test_heights_are_not_saved(self):
        self.assertIn('var/tmp/datum/terrain_heights/terrain_heights_cache', MODULE)
        self.assertIn('key == "terrain_height_file" || key == "terrain_heights_cache"', MODULE)


if __name__ == '__main__':
    unittest.main()
