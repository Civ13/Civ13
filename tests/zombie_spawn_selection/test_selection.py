"""Project both zombie spawn selectors with fake range/view/type boundaries.

These checks execute the complete selection bodies and compare their ordered
candidate sets. They do not execute BYOND or model its visibility algorithm.
"""
import importlib.util
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/objects/effects/spawner.dm'
DECL = '/obj/effect/spawner/mobspawner/zombies/special/getEmptyTurf'
spec = importlib.util.spec_from_file_location('spawn_selection_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)

# Frozen pre-optimization body. This is independent of the checkout under test.
BASELINE = '''/obj/effect/spawner/mobspawner/zombies/special/getEmptyTurf()
\tvar/list/turf/emptyTurfs = new
\tfor(var/turf/T in range(max_range,src))
\t\tvar/invalid = FALSE
\t\tif (istype(T, /turf/wall) || istype(T, /turf/floor/dirt/underground) || istype (T, /turf/floor/beach/water))
\t\t\tinvalid = TRUE
\t\tfor(var/obj/structure/OB in T)
\t\t\tinvalid = TRUE
\t\tfor(var/obj/covers/OB in T)
\t\t\tinvalid = TRUE
\t\tfor(var/mob/living/human/OB in view(4,T))
\t\t\tif (OB.stat != DEAD)
\t\t\t\tinvalid = TRUE
\t\tif (!invalid)
\t\t\temptyTurfs += T
\tif (emptyTurfs.len)
\t\treturn pick(emptyTurfs)
'''


class DMList(list):
    @property
    def len(self):
        return len(self)

    def __iadd__(self, item):
        self.append(item)
        return self


class Turf:
    def __init__(self, name, kind='floor', structures=0, covers=0, humans=(), distance=0):
        self.name, self.kind = name, kind
        self.structures, self.covers = structures, covers
        self.humans, self.distance = humans, distance


class Human:
    def __init__(self, stat):
        self.stat = stat


def execute(source, turfs):
    body = adapter.extract(source, DECL)
    body, replacements = re.subn(r'istype\s*\(T,\s*(/turf/[\w/]+)\)', r'istype(T, "\1")', body)
    if replacements != 3:
        raise AssertionError('Unexpected terrain type checks')
    observations = {'views': [], 'visited': [], 'picks': []}

    def typed_iter(items, kind):
        if kind == '/turf':
            return iter(items)
        if kind in ('/obj/structure', '/obj/covers'):
            count = items.structures if kind == '/obj/structure' else items.covers
            def objects():
                for _ in range(count):
                    observations['visited'].append((items.name, kind))
                    yield object()
            return objects()
        if kind == '/mob/living/human':
            return iter(items)
        raise AssertionError('Unexpected typed iteration: ' + kind)

    def get_range(max_range, src):
        return [t for t in turfs if t.distance <= max_range]

    def view(radius, turf):
        assert radius == 4
        observations['views'].append(turf.name)
        return [Human(stat) for stat, visible in turf.humans if visible]

    def pick(items):
        observations['picks'].append([item.name for item in items])
        return items[0]

    def istype(turf, path):
        return turf.kind == path or turf.kind.startswith(path + '/')

    env = dict(typed_iter=typed_iter, range=get_range, view=view, pick=pick,
               istype=istype, new_operation=DMList, DEAD=2, max_range=9)
    proc = adapter.project(DECL + '()\n' + body + '\n', DECL, 'src', env)
    result = proc(object())
    return (None if result is None else result.name), observations


class ZombieSpawnSelectionTests(unittest.TestCase):
    def setUp(self):
        self.candidate = SOURCE.read_text(encoding='utf-8-sig')

    def check_selection(self, turfs, expected):
        for source in (BASELINE, self.candidate):
            result, data = execute(source, turfs)
            self.assertEqual(data['picks'], [expected] if expected else [])
            self.assertEqual(result, expected[0] if expected else None)

    def test_order_and_candidate_set_cover_terrain_objects_and_visibility(self):
        turfs = [Turf('open'), Turf('wall', '/turf/wall/stone'),
                 Turf('underground', '/turf/floor/dirt/underground'),
                 Turf('water', '/turf/floor/beach/water'),
                 Turf('structure', structures=3), Turf('cover', covers=2),
                 Turf('alive', humans=[(0, True), (2, True)]),
                 Turf('dead', humans=[(2, True)]),
                 Turf('hidden', humans=[(0, False)]), Turf('outside', distance=10),
                 Turf('mixed', structures=1, covers=1, humans=[(0, True)]),
                 Turf('edge', distance=9)]
        self.check_selection(turfs, ['open', 'dead', 'hidden', 'edge'])

    def test_empty_and_all_blocked_never_call_pick(self):
        self.check_selection([], [])
        self.check_selection([Turf('wall', '/turf/wall'), Turf('cover', covers=1)], [])

    def test_dense_workload_skips_redundant_queries(self):
        turfs = [Turf(f'wall-{i}', '/turf/wall', structures=2, covers=2) for i in range(120)]
        turfs += [Turf(f'structure-{i}', structures=3, covers=2) for i in range(120)]
        turfs += [Turf(f'cover-{i}', covers=3) for i in range(120)]
        turfs += [Turf('open')]
        self.check_selection(turfs, ['open'])
        _, old = execute(BASELINE, turfs)
        _, new = execute(self.candidate, turfs)
        self.assertEqual((len(old['views']), len(new['views'])), (361, 1))
        self.assertEqual((len(old['visited']), len(new['visited'])), (1440, 240))

    def test_controls_reject_ignoring_living_humans_and_rejecting_dead_ones(self):
        alive = [Turf('alive', humans=[(0, True)])]
        dead = [Turf('dead', humans=[(2, True)])]
        ignored = self.candidate.replace('if (OB.stat != DEAD)', 'if (FALSE)', 1)
        reversed_check = self.candidate.replace('if (OB.stat != DEAD)', 'if (OB.stat == DEAD)', 1)
        self.assertEqual(execute(self.candidate, alive)[1]['picks'], [])
        self.assertEqual(execute(ignored, alive)[1]['picks'], [['alive']])
        self.assertEqual(execute(self.candidate, dead)[1]['picks'], [['dead']])
        self.assertEqual(execute(reversed_check, dead)[1]['picks'], [])


if __name__ == '__main__':
    unittest.main()
