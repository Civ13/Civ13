"""Offline projection with fake engine geometry; this does not run BYOND."""
import importlib.util
from itertools import product
from pathlib import Path
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).parent
SPEC = importlib.util.spec_from_file_location('cone_source_adapter', ROOT / 'tests/save_movement/source_adapter.py')
ADAPTER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ADAPTER)
CARDINALS = {'NORTH': 1, 'SOUTH': 2, 'EAST': 4, 'WEST': 8}


def production():
    text = (ROOT / 'code/game/mob/vision_cone.dm').read_text(encoding='utf-8')
    return text[text.index('atom/proc/InCone('):text.index('mob/dead/InCone(')]


def project_narrow(text):
    section = text[text.index('\telse if (global_hud.fov.icon_state == "narrow")'):]
    lines = ['/narrow()']
    for line in section.splitlines()[1:]:
        if not line.strip() or line.lstrip().startswith('//'):
            continue
        if line.strip() == 'switch(center.dir)':
            continue
        if line.startswith('\t\t\t'):
            line = line[1:]
        for name in CARDINALS:
            if line.strip() == f'if ({name})':
                line = '\t\tif (center.dir == ' + name + ')'
                break
        lines.append(line[1:])
    text = '\n'.join(lines) + '\n'
    args = 'center, src, d, x, y, get_dist, get_dir, supplied_dir, distance'
    return ADAPTER.project(text, '/narrow', args, dict(CARDINALS))


def run(proc, facing, supplied, x, y, direction, distance):
    center = SimpleNamespace(x=0, y=0, dir=facing)
    src = SimpleNamespace(x=x, y=y)
    calls = []
    def get_dir(a, b):
        calls.append('dir')
        return direction
    def get_dist(a, b):
        calls.append('dist')
        return distance
    return proc(center, src, direction, x, y, get_dist, get_dir, supplied, distance), calls


class DirectionTests(unittest.TestCase):
    def test_only_redundant_direction_and_distance_calls_change(self):
        original = (HERE / 'before.dm.txt').read_text(encoding='utf-8')
        self.assertEqual(original.count('get_dir(center, src) == center.dir'), 4)
        expected = original.replace('get_dir(center, src) == center.dir', 'd == center.dir')
        expected = expected.replace(
            'if (get_dist(center, src) == FALSE || src == center) return FALSE',
            'var/distance = get_dist(center, src)\n\tif (distance == FALSE || src == center) return FALSE')
        expected = expected.replace('get_dist(center, src) >= dx', 'distance >= dx')
        expected = expected.replace('get_dist(center, src) >= dy', 'distance >= dy')
        expected = expected.replace('get_dist(center,src) >= dy', 'distance >= dy')
        self.assertEqual(production(), expected)

    def test_narrow_projection_matches_original_and_rejects_wrong_facing(self):
        original = (HERE / 'before.dm.txt').read_text(encoding='utf-8')
        candidate = production()
        old, new = project_narrow(original), project_narrow(candidate)
        mutant = project_narrow(candidate.replace('d == center.dir', 'd == supplied_dir'))
        distance_mutant = project_narrow(candidate.replace('distance >=', '0 >='))
        mutant_differences = 0
        distance_mutant_differences = 0
        avoided_distances = 0
        avoided_calls = 0
        for facing, supplied, x, y, direction, distance in product(
                CARDINALS.values(), CARDINALS.values(), range(-2, 3), range(-2, 3), range(16), (0, 1, 2, 3)):
            expected, old_calls = run(old, facing, supplied, x, y, direction, distance)
            actual, new_calls = run(new, facing, supplied, x, y, direction, distance)
            self.assertEqual(actual, expected)
            self.assertEqual(new_calls, [])
            avoided_distances += old_calls.count('dist')
            avoided_calls += old_calls.count('dir')
            mutant_differences += run(mutant, facing, supplied, x, y, direction, distance)[0] != expected
            distance_mutant_differences += run(distance_mutant, facing, supplied, x, y, direction, distance)[0] != expected
        self.assertGreater(avoided_calls, 0)
        self.assertGreater(avoided_distances, 0)
        self.assertGreater(distance_mutant_differences, 0, 'the wrong-distance control must be detected')
        self.assertGreater(mutant_differences, 0, 'the wrong-facing control must be detected')


if __name__ == '__main__':
    unittest.main()
