"""Exercise body-bag label overlay changes projected from the DM source."""
import importlib.util
from pathlib import Path
from types import SimpleNamespace as NS
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('bodybag_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)
SOURCE = (ROOT / 'code/game/objects/items/bodybag.dm').read_text(encoding='utf-8-sig')


class Overlays(list):
    def __iadd__(self, item):
        self.append(item)
        return self

    def __isub__(self, item):
        while item in self:
            self.remove(item)
        return self


def apply_label(overlays, label):
    body = adapter.extract(SOURCE, '/obj/structure/closet/body_bag/attackby').splitlines()
    start = next(i for i, line in enumerate(body) if 't = sanitizeSafe' in line)
    end = next(i for i in range(start, len(body)) if body[i].strip() == 'return')
    lines = ['\t' + line[2:] for line in body[start:end]]
    proc = adapter.project('/test/proc/run()\n' + '\n'.join(lines) + '\n', '/test/proc/run', 't, overlays', {
        'sanitizeSafe': lambda value, _: value, 'MAX_NAME_LEN': 128,
        'image': lambda icon, state: (icon, state), 'icon': 'bodybag',
    })
    proc(label, overlays)


class BodyBagLabelTests(unittest.TestCase):
    def test_clearing_label_removes_tag_and_preserves_other_overlays(self):
        overlays = Overlays(['unrelated'])
        apply_label(overlays, 'Jane')
        self.assertIn(('bodybag', 'bodybag_label'), overlays)
        apply_label(overlays, '')
        self.assertEqual(overlays, ['unrelated'])


class BodyBagDropTests(unittest.TestCase):
    def test_shared_open_closet_checks_still_own_admission(self):
        closets = (ROOT / 'code/game/objects/structures/crates_lockers/closets.dm').read_text()
        drop = adapter.extract(closets, '/obj/structure/closet/MouseDrop_T')
        call = drop.index('finish_open_closet_drop(O, user)')
        for check in ('O.anchored', 'Adjacent(user)', 'Adjacent(O)', 'user.Adjacent(O)',
                      'isturf(user.loc)', 'if (!opened)', 'no_mans_land'):
            self.assertLess(drop.index(check), call)
        fallback = adapter.extract(closets, '/obj/structure/closet/proc/finish_open_closet_drop')
        self.assertEqual(fallback.strip(), 'return FALSE')

    def test_casualty_is_moved_by_normal_collision_and_only_success_is_announced(self):
        floor, other = object(), object()
        effects = []
        user = NS(show_viewers=effects.append)

        def trial(*, blocked=False, redirected=False, **state):
            effects.clear()
            candidate = NS(loc=other, living=True, buckled=False, pinned=[], stat=1, lying=False, prone=False)
            for k, value in state.items():
                setattr(candidate, k, value)
            moves = []

            def move(destination, direction):
                moves.append((destination, direction))
                if blocked:
                    return False
                candidate.loc = other if redirected else destination
                return True

            candidate.Move = move
            drop = adapter.project(SOURCE, '/obj/structure/closet/body_bag/finish_open_closet_drop',
                                   'O, user', dict(loc=floor, length=len, CONSCIOUS=0,
                                   QDELETED=lambda _obj: False, istype=lambda obj: obj.living,
                                   isturf=lambda obj: obj is floor or obj is other,
                                   get_dir=lambda _a, _b: 4, SPAN_NOTICE=str))
            result = drop(candidate, user)
            return result, candidate.loc, len(moves), len(effects)

        self.assertEqual(trial(), (True, floor, 1, 1))
        self.assertEqual(trial(stat=0, lying=True), (True, floor, 1, 1))
        self.assertEqual(trial(blocked=True), (False, other, 1, 0))
        self.assertEqual(trial(redirected=True), (False, other, 1, 0))
        for refusal in ({'living': False}, {'buckled': True}, {'pinned': [object()]}, {'stat': 0}):
            with self.subTest(refusal=refusal):
                self.assertEqual(trial(**refusal), (False, other, 0, 0))


if __name__ == '__main__':
    unittest.main()
