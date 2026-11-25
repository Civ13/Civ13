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
    """Project the completion arguments through the constructor's source guard."""
    args = [a.strip() for a in completion(source).split(',')]
    signature = barrier.split('/obj/structure/window/barrier/New(', 1)[1].split(')', 1)[0]
    params = [p.strip().split('/')[-1] for p in signature.split(',')]
    bound = dict(zip(params, args))
    if bound.get('creator') == 'user' and bound.get('direction') == 'dir':
        return own_dir
    body = barrier_constructor(barrier)
    return last_global if 'dir = set_dir' in body else own_dir


def barrier_constructor(barrier):
    return barrier.split('/obj/structure/window/barrier/New(', 1)[1].split('\n/obj/', 1)[0]


class SnowBarricadeSource(unittest.TestCase):
    def setUp(self):
        self.snow = SNOW.read_text(encoding="utf-8")
        self.barrier = BARRIER.read_text(encoding="utf-8")

    def test_completion_passes_creator_and_own_direction(self):
        self.assertEqual(completion(self.snow), 'loc, user, dir')

    def test_completed_wall_keeps_its_direction(self):
        self.assertEqual(project(self.snow, self.barrier, 'NORTH', 'EAST'), 'NORTH')
        old = self.snow.replace('snowwall(loc, user, dir)', 'snowwall(loc, dir)', 1)
        # A creatorless construction must not inherit the previous barrier's direction.
        self.assertEqual(project(old, self.barrier, 'NORTH', 'EAST'), 'NORTH')

    def test_only_the_creators_direction_can_replace_authored_facing(self):
        body = barrier_constructor(self.barrier)
        self.assertNotIn('var/set_dir', self.barrier)
        before_visuals = body.split('switch (dir)', 1)[0]
        self.assertRegex(
            before_visuals,
            r'if \(ismob\(creator\) && direction\)\n'
            r'\t\t[^\n]*\n'
            r'\t\tif \(direction & EAST\)\n\t\t\tdir = EAST\n'
            r'\t\telse if \(direction & WEST\)\n\t\t\tdir = WEST\n'
            r'\t\telse\n\t\t\tdir = direction',
        )
        self.assertEqual(len(re.findall(r'(?m)^\s+dir = ', before_visuals)), 3)


if __name__ == "__main__":
    unittest.main()
