"""Offline projections of frame completion and hive forage; no BYOND world."""
import importlib.util
import re
from types import SimpleNamespace
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'code/modules/1713/beekeeping.dm'
spec = importlib.util.spec_from_file_location('bee_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)
DECL = '/obj/item/honey_frame/filled/attackby'


def project(source):
    body = adapter.extract(source, DECL)
    lines = body.splitlines()
    assert lines.pop(0).strip().startswith('if (istype(I, /obj/item/weapon/material/kitchen/utensil/knife/))')
    lines = [line[1:] for line in lines if 'visible_message(' not in line and 'to_chat(' not in line]
    body = '\n'.join(lines)
    body = body.replace('!Adjacent(user)', '!src.Adjacent(user)')
    for path, kind in (
        ('/obj/item/weapon/reagent_containers/food/snacks/honeycomb', 'honeycomb'),
        ('/obj/item/honey_frame', 'frame'),
    ):
        pattern = rf'new {re.escape(path)}\((\w+)\)'
        body, replacements = re.subn(pattern, lambda match: f'emit("{kind}", ' +
                                     ('src.loc' if match[1] == 'loc' else match[1]) + ')', body)
        assert replacements == 1
    return adapter.project('/test/proc/run()\n' + body + '\n', '/test/proc/run',
                           'src, user, do_after, QDELETED, get_turf, emit, qdel', {})


class Frame:
    def __init__(self):
        self.loc = 'original'
        self.deleted = False
        self.adjacent = True

    def Adjacent(self, user):
        return self.adjacent


def run_case(source, event):
    frame, user, output = Frame(), Frame(), []
    if event == 'held':
        frame.loc, user.loc = user, 'actor turf'
    if event == 'no_turf':
        frame.loc, user.loc = user, None

    def get_turf(obj):
        loc = obj.loc
        while isinstance(loc, Frame):
            loc = loc.loc
        return loc

    def wait(actor, delay, target=None):
        before = frame.loc
        if event == 'moved':
            frame.loc = 'elsewhere'
        if event == 'deleted':
            frame.deleted = True
        if event == 'user_deleted':
            user.deleted = True
        if event == 'container_moved':
            frame.adjacent = False
        return target is None or frame.loc == before

    def delete(obj):
        obj.deleted = True

    project(source)(frame, user, wait, lambda obj: obj.deleted, get_turf,
                    lambda kind, loc: output.append((kind, loc)), delete)
    return output, frame.deleted


class BeekeepingWaitTests(unittest.TestCase):
    def test_completion_checks_frame_and_actor_after_wait(self):
        source = SOURCE.read_text(encoding='utf-8')
        self.assertEqual(run_case(source, 'stationary'), ([('honeycomb', 'original'), ('frame', 'original')], True))
        for event in ('moved', 'deleted', 'user_deleted', 'container_moved'):
            with self.subTest(event=event):
                self.assertEqual(run_case(source, event)[0], [])

        # Prove both the wait target and the post-wait guard affect these cases.
        untargeted = source.replace('do_after(user, 90, src)', 'do_after(user, 90)', 1)
        self.assertNotEqual(run_case(untargeted, 'moved')[0], [])
        unguarded = source.replace('if (QDELETED(src) || QDELETED(user) || !Adjacent(user))\n',
                                   'if (FALSE)\n', 1)
        self.assertNotEqual(run_case(unguarded, 'deleted')[0], [])


    def test_cutting_a_held_frame_places_both_results_on_the_turf(self):
        source = SOURCE.read_text(encoding='utf-8')
        output, consumed = run_case(source, 'held')
        self.assertEqual(output, [('honeycomb', 'actor turf'), ('frame', 'actor turf')])
        self.assertTrue(consumed)

    def test_no_turf_preserves_the_full_frame(self):
        source = SOURCE.read_text(encoding='utf-8')
        self.assertEqual(run_case(source, 'no_turf'), ([], False))



HIVES = ROOT / 'code/modules/1713/kept_hives.dm'


def forage_points(objects):
    source = HIVES.read_text(encoding='utf-8')
    body = adapter.extract(source, '/proc/bee_forage_points')
    body = re.sub(r'(istype\(O, )(/obj/structure/[\w/]+)(\))', r'\1"\2"\3', body)
    run = adapter.project('/test/proc/forage(A)\n' + body + '\n', '/test/proc/forage', 'A', {
        'range': lambda radius, center: objects,
        'typed_iter': lambda values, kind: values,
        'istype': lambda obj, kind: obj.kind == kind,
        'KEPT_HIVE_FORAGE_RANGE': 5, 'KEPT_HIVE_FORAGE_FULL': 16,
    })
    return run(None)


class HiveForageTests(unittest.TestCase):
    @staticmethod
    def crop(stage, limit=10):
        return SimpleNamespace(kind='/obj/structure/farming/plant', stage=stage, readyStageMax=limit)

    def test_dead_field_crops_cannot_supply_full_forage(self):
        self.assertEqual(forage_points([self.crop(11) for _ in range(16)]), 0)

    def test_living_crops_and_wild_trees_keep_existing_weights(self):
        tree = SimpleNamespace(kind='/obj/structure/wild/tree')
        self.assertEqual(forage_points([self.crop(11), self.crop(10), tree]), 1.5)
        self.assertEqual(forage_points([self.crop(9, 8), self.crop(8, 8)]), 1)
        self.assertEqual(forage_points([self.crop(10) for _ in range(17)]), 16)


    def test_swarming_debits_only_if_a_recoverable_cluster_is_placed(self):
        root = Path(__file__).resolve().parents[1]
        kept = (root / 'code/modules/1713/kept_hives.dm').read_text(encoding='utf-8')
        framed = (root / 'code/modules/1713/beekeeping.dm').read_text(encoding='utf-8')
        self.assertIn('&& cast_swarm(src, 40))\n\t\t\tstrength -= 40', kept)
        self.assertIn('&& cast_swarm(src, 40))\n\t\t\tbee_count -= 40', framed)
        cast = kept.split('/proc/cast_swarm(', 1)[1].split('/proc/', 1)[0]
        self.assertIn('if (!sites.len)\n\t\treturn null', cast)
        self.assertIn('return new /obj/structure/bee_swarm_cluster', cast)


if __name__ == '__main__':
    unittest.main()
