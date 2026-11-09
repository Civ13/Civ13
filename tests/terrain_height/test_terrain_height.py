"""Offline checks for terrain heights: the generator tool and the movement hook.

The native probe (run.py) covers the game's parser, lookup and slope cost.
"""
from pathlib import Path
import importlib.util
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


class Wiring(unittest.TestCase):
    def test_client_move_adds_slope_cost_for_walking_living_mobs(self):
        hook = re.search(r'\n\t\t// Hills:.*\n\t\tif \(mob_is_living && !mob\.buckled && isturf\(mob_loc\) && isturf\(n\)\)\n'
                         r'\t\t\tmove_delay \+= terrain_slope_delay\(mob_loc, n, move_delay - world\.time\)\n', MOVEMENT)
        self.assertIsNotNone(hook)
        # After the intent costs, so the downhill cap sees the whole step delay.
        self.assertLess(MOVEMENT.index('if ("proning")'), hook.start())

    def test_parser_matches_tool_format(self):
        self.assertIn(f'"{tool.HEADER.split()[0]}"', MODULE)
        self.assertIn('regex(@"[^0-9a-f]")', MODULE)
        self.assertEqual(tool.DIGITS, '0123456789abcdef')

    def test_heights_are_not_saved(self):
        self.assertIn('var/tmp/datum/terrain_heights/terrain_heights_cache', MODULE)
        self.assertIn('key == "terrain_height_file" || key == "terrain_heights_cache"', MODULE)


if __name__ == '__main__':
    unittest.main()
