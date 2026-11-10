"""Offline source contract for snow barricade completion (#4290); does not execute DM."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SNOW = ROOT / "code/modules/1713/barriers/snow_walls.dm"
BARRIER = ROOT / "code/modules/1713/barriers/sandbag.dm"


def completion(source):
    body = source.split('/obj/structure/window/barrier/snowwall/incomplete/attackby(', 1)[1].split('\n/obj/', 1)[0]
    return re.search(r'new/obj/structure/window/barrier/snowwall\(([^)]*)\)', body).group(1)


def project(source, barrier, own_dir, last_global):
    """Direction the completed wall gets; the constructor only takes the passed direction with a creator."""
    args = [a.strip() for a in completion(source).split(',')]
    signature = barrier.split('/obj/structure/window/barrier/New(', 1)[1].split(')', 1)[0]
    params = [p.strip().split('/')[-1] for p in signature.split(',')]
    bound = dict(zip(params, args))
    if bound.get('creator') == 'user' and bound.get('direction') == 'dir':
        return own_dir
    return last_global


class SnowBarricadeSource(unittest.TestCase):
    def setUp(self):
        self.snow = SNOW.read_text(encoding="utf-8")
        self.barrier = BARRIER.read_text(encoding="utf-8")

    def test_completion_passes_creator_and_own_direction(self):
        self.assertEqual(completion(self.snow), 'loc, user, dir')

    def test_completed_wall_keeps_its_direction(self):
        self.assertEqual(project(self.snow, self.barrier, 'NORTH', 'EAST'), 'NORTH')
        old = self.snow.replace('snowwall(loc, user, dir)', 'snowwall(loc, dir)', 1)
        self.assertEqual(project(old, self.barrier, 'NORTH', 'EAST'), 'EAST')


if __name__ == "__main__":
    unittest.main()
