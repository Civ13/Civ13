"""Map-driven sizing hypothesis; runtime admission remains exact."""
from pathlib import Path
import unittest

ROOT = Path(__file__).parent
SCENE = (ROOT / 'changed-source/filming/scene.dm').read_text()

class MapOrigin(unittest.TestCase):
    def test_no_compile_time_dimensions_or_runtime_resize(self):
        world = SCENE.split('/world\n', 1)[1].split('/world/OpenPort', 1)[0]
        self.assertNotRegex(world, r'(?m)^\s*max[xyz]\s*=')
        self.assertNotRegex(SCENE, r'world\.max[xyz]\s*=(?!=)')

    def test_exact_runtime_and_z1_witness_admission_remain(self):
        self.assertIn('world.maxx == 15 && world.maxy == 13 && world.maxz == 1', SCENE)
        self.assertIn('var/turf/T = locate(row[1], row[2], 1)', SCENE)
        self.assertIn('filming_check(ok, "authored map witnesses [phase]")', SCENE)
        self.assertIn('eye = locate(7, 7, 1)', SCENE)
        self.assertIn('loc = locate(7, 7, 1)', SCENE)
        self.assertIn('"z2_diagnostic" = z2_observed', SCENE)

    def test_only_authored_map_include(self):
        dme = (ROOT / 'changed-source/civ13.dme').read_text()
        maps = [line.strip() for line in dme.splitlines() if line.strip().startswith('#include ') and '.dmm"' in line]
        self.assertEqual(maps, ['#include "filming\\tree.dmm"'])

if __name__ == '__main__':
    unittest.main()
