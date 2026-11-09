"""Offline projection of the transparent-mover fast path; no native pixels.

Another player's tile step used to mark every nearby viewer dirty, so each
viewer rebuilt every mask in its view. A transparent mover blocks nothing, so
only its own mask can change: viewers queue it and re-decide it alone. These
tests project the production procs and check the queue cap, the mask updates
and every fallback to the full refresh.
"""
import importlib.util
import re
import unittest
from pathlib import Path
from types import SimpleNamespace as N

ROOT = Path(__file__).resolve().parents[2]
VIS = ROOT / 'code/modules/visibility'
LIFE = (VIS / 'los_lifecycle.dm').read_text()
PRESENTER = (VIS / 'los_presenter.dm').read_text()
MOVED = (ROOT / 'code/datums/observation/moved.dm').read_text()

spec = importlib.util.spec_from_file_location('los_mover_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)


def fragment(source, signature):
    lines = source.splitlines()
    start = next(i for i, line in enumerate(lines) if line.startswith(signature))
    end = next((i for i in range(start+1, len(lines)) if lines[i].startswith('/')), len(lines))
    return '\n'.join(lines[start:end]).rstrip()


def method(source, declaration, args, fields, env):
    text = declaration + '\n' + adapter.extract(source, declaration.split('(')[0]) + '\n'
    pieces = re.split(r'("(?:[^"\\]|\\.)*")', text)
    for i in range(0, len(pieces), 2):
        pieces[i] = re.sub(r'\bsrc\b', 'self', pieces[i])
        for field in fields:
            pieces[i] = re.sub(r'(?<![\w./])' + field + r'\b', 'self.' + field, pieces[i])
    return adapter.project(''.join(pieces), declaration.split('(')[0], 'self, ' + args, env)


class Keyed(dict):
    def __getitem__(self, key):
        return self.get(key)

    @property
    def len(self):
        return len(self)

    def __isub__(self, key):
        self.pop(key, None)
        return self

    def __ior__(self, key):
        self[key] = True
        return self


class Images(set):
    def __isub__(self, item):
        self.discard(item)
        return self

    def __ior__(self, item):
        self.add(item)
        return self


class Atom(N):
    __eq__ = object.__eq__
    __hash__ = object.__hash__


def env():
    return {'__builtins__': {}, 'len': len, 'max': max, 'min': min, 'abs': abs,
            'list': Keyed, 'length': lambda x: 0 if x is None else len(x),
            'typed_iter': lambda xs, kind: [] if xs is None else list(xs),
            'isturf': lambda x: getattr(x, 'is_turf', False), 'LOS_DENY': 0}


class NoteMover(unittest.TestCase):
    def client(self):
        note = method(LIFE, '/client/proc/los_note_mover(atom/movable/A)', 'A',
                      ['los_dirty', 'los_pending_movers'], env())
        C = N(los_dirty=False, los_pending_movers=None)
        return C, lambda A: note(C, A)

    def test_clean_viewer_queues_each_mover_once(self):
        C, note = self.client()
        a, b = Atom(), Atom()
        note(a); note(b); note(a)
        self.assertEqual(set(C.los_pending_movers), {a, b})
        self.assertFalse(C.los_dirty)

    def test_dirty_viewer_queues_nothing(self):
        C, note = self.client()
        C.los_dirty = True
        note(Atom())
        self.assertIsNone(C.los_pending_movers)

    def test_long_queue_falls_back_to_one_full_refresh(self):
        C, note = self.client()
        for _ in range(64):
            note(Atom())
        self.assertEqual(len(C.los_pending_movers), 64)
        self.assertFalse(C.los_dirty)
        note(Atom())
        self.assertIsNone(C.los_pending_movers)
        self.assertTrue(C.los_dirty)


class RefreshTargets(unittest.TestCase):
    FIELDS = ['retired', 'dirty', 'last_policy', 'owner', 'context', 'images', 'owned_images',
              'visible_targets', 'owns_atom', 'hidden_image', 'invalidate']

    def model(self, deny):
        e = env()
        refresh = method(PRESENTER, '/datum/los_presenter/proc/refresh_targets(datum/los_snapshot/S, list/targets)',
                         'S, targets', self.FIELDS, e)
        body = N(x=50, y=50)
        context = N(body=body, revision=3, eligible=lambda: True, policy_key=lambda: 'p',
                    begin_snapshot_pass=lambda S: None, end_snapshot_pass=lambda: None)
        context.decision_snapshot = lambda A, S, op: 0 if A in deny else 1
        owner = N(images=Images(), los_context=context)
        P = N(retired=False, dirty=False, last_policy='p', owner=owner, context=context,
              images=Keyed(), owned_images=Keyed(), visible_targets=Keyed(), invalidated=0)
        owner.los_presenter = P

        def hidden_image(A):
            return P.images[A] or Atom(loc=A)
        P.hidden_image = hidden_image
        P.owns_atom = lambda A: True
        P.invalidate = lambda: setattr(P, 'invalidated', P.invalidated + 1)
        S = N(policy='p', revision=3, radius_x=15, radius_y=15, eye_z=1)
        return P, S, lambda targets: refresh(P, S, targets)

    def turf(self, x, y, z=1):
        return N(is_turf=True, x=x, y=y, z=z)

    def test_hidden_mover_gets_mask_and_revealed_mover_loses_it(self):
        mover = Atom(opacity=0, loc=self.turf(55, 55))
        P, S, refresh = self.model(deny={mover})
        self.assertTrue(refresh([mover]))
        mask = P.images[mover]
        self.assertIn(mask, P.owner.images)
        self.assertTrue(P.owned_images[mask])
        self.assertNotIn(mover, P.visible_targets)
        P.context.decision_snapshot = lambda A, S, op: 1
        self.assertTrue(refresh([mover]))
        self.assertIsNone(P.images[mover])
        self.assertNotIn(mask, P.owner.images)
        self.assertNotIn(mask, P.owned_images)
        self.assertTrue(P.visible_targets[mover])

    def test_mover_leaving_the_ring_or_level_is_neither_masked_nor_visible(self):
        far = Atom(opacity=0, loc=self.turf(90, 50))
        other_z = Atom(opacity=0, loc=self.turf(50, 50, 2))
        P, S, refresh = self.model(deny={far, other_z})
        P.visible_targets[far] = True
        self.assertTrue(refresh([far, other_z]))
        self.assertIsNone(P.images[far])
        self.assertIsNone(P.images[other_z])
        self.assertNotIn(far, P.visible_targets)

    def test_opaque_target_stale_policy_or_dirty_presenter_ask_for_full_refresh(self):
        wall = Atom(opacity=1, loc=self.turf(51, 51))
        P, S, refresh = self.model(deny=set())
        self.assertFalse(refresh([wall]))
        P.dirty = True
        self.assertFalse(refresh([Atom(opacity=0, loc=self.turf(51, 51))]))
        P.dirty = False
        S.policy = 'old'
        self.assertFalse(refresh([Atom(opacity=0, loc=self.turf(51, 51))]))

    def test_revision_change_during_the_pass_invalidates(self):
        mover = Atom(opacity=0, loc=self.turf(52, 52))
        P, S, refresh = self.model(deny=set())

        def decide(A, S, op):
            P.context.revision = 4
            return 1
        P.context.decision_snapshot = decide
        self.assertFalse(refresh([mover]))
        self.assertEqual(P.invalidated, 1)
        self.assertTrue(P.dirty)


class Wiring(unittest.TestCase):
    def test_transparent_movers_are_queued_and_opaque_ones_still_dirty(self):
        invalidate = fragment(LIFE, '/proc/los_invalidate(')
        self.assertIn('if(ismovable(changed) && !possible_opacity && !changed.opacity && changed != V.body && C.los_presenter)\n\t\t\tC.los_note_mover(changed)\n\t\t\tcontinue', invalidate)
        moved = fragment(LIFE, '/proc/los_refresh_moved_viewer(')
        self.assertIn('if(M.opacity)\n\t\t\t\tC.los_dirty = TRUE\n\t\t\telse\n\t\t\t\tC.los_note_mover(M)', moved)
        self.assertIn('if(tile_changed && previous_turf && A.opacity)', moved)
        self.assertIn('if(old_loc && isturf(old_loc) && am.opacity)', MOVED)

    def test_reconcile_tries_the_mover_pass_before_the_full_refresh(self):
        reconcile = fragment(LIFE, '/client/proc/reconcile_geometric_los(')
        fast = reconcile.index('if(los_refresh_pending_movers(V))')
        self.assertLess(fast, reconcile.index('world.time < los_next_audit'))
        self.assertIn('if(los_refresh_pending_movers(V))\n\t\t\treturn TRUE\n\t\tlos_dirty = TRUE', reconcile)
        self.assertIn('los_pending_movers = null', reconcile)


if __name__ == '__main__':
    unittest.main()
