"""Source-projected friendly-fire decisions; this does not launch BYOND."""
from pathlib import Path
from types import SimpleNamespace
import importlib.util
import unittest

ROOT = Path(__file__).resolve().parents[2]

def load(name, path):
    spec = importlib.util.spec_from_file_location(name, ROOT / path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

adapter = load('friendly_source_adapter', 'tests/save_movement/source_adapter.py')
line_tests = load('friendly_line_contract', 'tests/getline2/test_getline2.py')
DECL = '/mob/living/simple_animal/hostile/human/proc/check_friendly_fire'
SOURCE = (ROOT / 'code/game/mob/living/simple_animal/hostile/tactical_ai.dm').read_text(encoding='utf-8-sig')

class Turf:
    def __init__(self, x, y, z=1):
        self.x, self.y, self.z = x, y, z
        self.contents = []
    def __iter__(self):
        return iter(self.contents)

class Mob:
    def __init__(self, kind, faction='ally', dead=False):
        self.kind, self.faction, self.faction_text = kind, faction, faction
        self.stat = 2 if dead else 0


def project(body, tiles, include_start=False):
    # Keep the full source body; supply only modeled engine boundaries.
    path = '/mob/living/simple_animal/hostile/human'
    body = body.replace('istype(L, ' + path + ')', "istype(L, 'npc')")
    line = line_tests.projected_getline()
    def getline(start, end, include):
        if include_start:
            include = True
        return [tiles.get(coords) for coords in line(start, end, include)]
    def typed_iter(values, path):
        return (v for v in values if (isinstance(v, Turf) if path == '/turf' else isinstance(v, Mob)))
    env = {'get_turf': lambda x: x, 'getline2': getline, 'typed_iter': typed_iter,
           'ishuman': lambda x: x.kind == 'human', 'istype': lambda x, path: x.kind == path,
           'DEAD': 2}
    return adapter.project('/proc/friendly_projection()\n' + body + '\n', '/proc/friendly_projection',
                           'src, target, faction', env)

class FriendlyFireLine(unittest.TestCase):
    def setUp(self):
        self.body = adapter.extract(SOURCE, DECL)
        current = 'if(T == end) continue'
        self.assertEqual(self.body.count(current), 1)
        self.old = self.body.replace(current, 'if(T == start || T == end) continue', 1)

    def test_old_and_new_decisions_over_octants_and_occupants(self):
        for dx in range(-4, 5):
            for dy in range(-4, 5):
                for kind, faction, dead in [('human', 'ally', False), ('npc', 'ally', False),
                                            ('human', 'enemy', False), ('npc', 'enemy', False),
                                            ('human', 'ally', True), ('other', 'ally', False)]:
                    start, end = Turf(10, 10), Turf(10 + dx, 10 + dy)
                    points = line_tests.projected_getline()(start, end, False)
                    tiles = {(10, 10, 1): start, (end.x, end.y, 1): end}
                    for coords in points:
                        tiles.setdefault(coords, Turf(*coords))
                    for tile in tiles.values():
                        tile.contents.append(Mob(kind, faction, dead))
                    old, new = project(self.old, tiles), project(self.body, tiles)
                    with self.subTest(dx=dx, dy=dy, kind=kind, faction=faction, dead=dead):
                        self.assertEqual(old(start, end, 'ally'), new(start, end, 'ally'))
                        self.assertNotIn((start.x, start.y, start.z), points)
                        expected = max(abs(dx), abs(dy)) > 1 and faction == 'ally' and not dead and kind in ('human', 'npc')
                        self.assertEqual(bool(new(start, end, 'ally')), expected)

    def test_negative_controls_detect_start_and_target_regressions(self):
        start, end, middle = Turf(1, 1), Turf(3, 1), Turf(2, 1)
        tiles = {(1, 1, 1): start, (2, 1, 1): middle, (3, 1, 1): end}
        start.contents.append(Mob('human'))
        self.assertFalse(project(self.body, tiles)(start, end, 'ally'))
        self.assertTrue(project(self.body, tiles, include_start=True)(start, end, 'ally'))
        start.contents.clear()
        end.contents.append(Mob('human'))
        mutant = self.body.replace('if(T == end) continue', 'if(FALSE) continue', 1)
        self.assertFalse(project(self.body, tiles)(start, end, 'ally'))
        self.assertTrue(project(mutant, tiles)(start, end, 'ally'))

    def test_null_target_returns_false(self):
        self.assertFalse(project(self.body, {})(Turf(1, 1), None, 'ally'))

if __name__ == '__main__':
    unittest.main()
