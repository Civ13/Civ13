"""Source-executed Move -> observation Entered -> LOS publication identity trace.

The native Move/parent Entered, ownership token, geometry capture/decision,
client reconciliation glue, root scene admission and bake are explicit boundaries. No engine, client, pixels,
timing, dense workload or actual parent dispatch is executed here.
"""
import importlib.util
from pathlib import Path
from types import SimpleNamespace as N
from unittest.mock import patch
import re
import unittest
import hashlib
import json
import sys

ROOT = Path(__file__).resolve().parents[2]

def load(name, relative):
    spec = importlib.util.spec_from_file_location(name, ROOT / relative)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

P = load('entered_presenter_fixture', 'tests/los_context/test_production.py')
R = load('entered_root_fixture', 'tests/root_tree_presentation/test_contract.py')
A = P.adapter
LIFE = (ROOT / 'code/modules/visibility/los_lifecycle.dm').read_text()
MOVE = (ROOT / 'code/game/mob/mob_movement.dm').read_text()
ENTERED = (ROOT / 'code/datums/observation/moved.dm').read_text()


class EngineMover(P.Identity):
    def __setattr__(self, name, value):
        super().__setattr__(name, value)
        if name == 'loc' and value is not None:
            for field in ('x', 'y', 'z'):
                super().__setattr__(field, getattr(value, field))


class IdentityTrace:
    """Reuse existing storage/presenter adapters; execute the callback seam."""
    def __init__(self, mode='fallback', outcome='allowed', native='tile',
                 entered_source=ENTERED, move_source=MOVE, smooth=True):
        self.mode, self.outcome, self.native = mode, outcome, native
        self.trace, self.captures = [], [0, 0]
        self.models = [P.model(), P.model()]
        self.tree = P.atom(13, 10, tree=True, opaque=True)
        self.old = P.atom(10, 10, turf=True)
        self.destination = P.atom(11, 10, turf=True)
        self.mover = EngineMover(**vars(self.models[0].V.body))
        self.mover.type = '/mob/living/human'
        self.mover.loc = self.old
        self.mover.client = self.models[0].C
        self.mover.dir = 4
        self.mover.riding = False
        self.mover.riding_mob = self.mover.pulling = None
        self.mover.human_subtile_offset_owned = bool(smooth)
        self.mover.human_subtile_pulse = N() if smooth else None
        self.mover.human_subtile_transaction = N(total_distance=0)
        self.mover.set_dir = lambda direction: setattr(self.mover, 'dir', direction)
        self.mover.human_subtile_take_pulse = lambda *_: N(
            sx=2 if native == 'offset' else 0, sy=0, restoring=False,
            before=dict(x=self.mover.x, y=self.mover.y,
                        sx=self.mover.step_x, sy=self.mover.step_y))
        self.old.contents.append(self.mover)
        self.roots = []
        for index, m in enumerate(self.models):
            if index == 0:
                m.V.body = self.mover
            m.V.owner, m.V.retired = m.C, False
            m.V.movement_turf = m.V.body.loc
            m.V.viewport_radii = lambda: P.geometry.DMList([4, 4])
            m.C.los_dirty = False
            m.include(self.tree)
            if mode == 'root':
                self.roots.append(self.root_presenter(m))
            m.C.reconcile_geometric_los = lambda i=index: self.reconcile(i)
            self.reconcile(index)
        self.captures = [0, 0]
        self.env = dict(
            CIV13_GEOMETRIC_LOS_CORE=True, list=lambda *xs: P.List(xs),
            abs=abs, typed_iter=lambda xs, _: getattr(xs, 'contents', xs),
            get_turf=lambda a: a if a.type.startswith('/turf/') else a.loc,
            ishuman=lambda a: a.type.startswith('/mob/living/human'),
            ismob=lambda a: a.type.startswith('/mob/'),
            istype=lambda a, kind: a.type.startswith(kind),
            los_active_contexts=P.List([m.V for m in self.models]))
        invalidate = A.project(LIFE, '/proc/los_invalidate',
                               'changed, possible_opacity=False, viewer_refresh=False', self.env)
        before = A.project(LIFE, '/proc/los_invalidate_movement', 'A', self.env)
        self.env['los_invalidate'] = invalidate
        near = A.project(LIFE, '/proc/los_movement_affects_context',
                         'V, old_turf, new_turf', self.env)
        self.env['los_movement_affects_context'] = near
        after = A.project(LIFE, '/proc/los_refresh_moved_viewer',
                          'A, force_refresh=False, previous_contexts=None', self.env)
        self.env['los_invalidate_movement'] = before
        def postmove(*args):
            self.record('before_postmove')
            after(*args)
            self.record('after_postmove')
        self.env['los_refresh_moved_viewer'] = postmove
        entered_env = dict(self.env, parent_entered=lambda: None,
            GLOB=N(moved_event=N(raise_event=lambda *_: self.record('moved_event'))))
        # The native/inherited parent is an explicit boundary, not a removed
        # executable line or an assertion about BYOND's multiple definitions.
        entered_source = entered_source.replace('..()', 'parent_entered()')
        self.entered = A.project(entered_source, '/atom/Entered',
                                 'am, old_loc', entered_env)
        def native_move(*_):
            self.record('before_native')
            if native == 'blocked':
                return False
            if native == 'offset':
                self.mover.step_x = 2
                return True
            old = self.mover.loc
            self.mover.loc = self.destination
            self.mover.step_x = 0
            self.record('before_entered')
            self.entered(self.mover, old)
            self.record('after_entered')
            return True
        self.env.update(parent_move=native_move, persistence_movement_allowed=lambda *_: True,
            subtile_pull_ownership=N(owners=P.List()), world=N(time=1),
            isDeleted=lambda _: False, get_dir=lambda *_: 4,
            isnull=lambda x: x is None, NORTH=1, SOUTH=2, EAST=4, WEST=8,
            step=lambda *_: (_ for _ in ()).throw(AssertionError('Unselected diagonal seam')))
        move_source = move_source.replace('..(', 'parent_move(')
        move_source = re.sub(r'(?m)(=\s*)\.([ \t]*)$', r'\1result\2', move_source)
        # DM uninitialized proc locals start null. Preserve, rather than skip,
        # every selected line of the complete production movement body.
        move_source = re.sub(r'(?m)^(\t*)var/(?:\w+/)*(\w+)\s*$',
                             r'\1var/\2 = null', move_source)
        for kind in ('/mob/living/simple_animal', '/mob/living/human'):
            move_source = move_source.replace('istype(src, '+kind+')',
                                              'istype(src, '+repr(kind)+')')
        with patch.object(A, 'FIELDS', A.FIELDS + (
                'dir', 'x', 'y', 'step_x', 'step_y', 'l_move_time', 'last_move', 'set_dir')):
            self.move = A.project(move_source, '/atom/movable/Move',
                'src, newloc, direct', self.env, method=True,
                defines={'CIV13_ROOT_TREE_PRESENTATION': True})
        self.record('initial')

    def root_presenter(self, m):
        env = R.environment()
        env.update(TILE_BOUND=16, RESET_COLOR=1, RESET_ALPHA=2, RESET_TRANSFORM=4)
        image = P.Identity(loc=self.tree, appearance_flags=16, icon=None,
                           overlays=[], underlays=[], maptext='', mouse_opacity=0)
        root = N(owner=m.C, context=m.V, retired=False, scene_active=True,
                 images=P.List(), owned_images=P.List([image]),
                 published_frames=P.List(), source_appearances=P.List(),
                 frame=object(), image=image, frame_writes=0)
        root.images[self.tree] = image
        root.owns_tree = lambda tree: tree is self.tree
        withdraw = R.compile_proc(R.TREE, '/datum/root_tree_presenter/proc/withdraw_tree(',
                                  'self, T, I', env, True)
        env['withdraw_tree'] = lambda tree, im: withdraw(root, tree, im)
        invalidate = R.compile_proc(R.TREE, '/datum/root_tree_presenter/proc/invalidate(',
            'self, changed=None, possible_opacity=False, viewer_refresh=False', env, True)
        root.invalidate = lambda *args: invalidate(root, *args)
        publish = R.compile_proc(R.TREE, '/datum/root_tree_presenter/proc/frame_needs_publication(',
            'self, T, frame, source_appearance=None', env, True)
        set_frame = R.compile_proc(R.TREE, '/proc/root_tree_set_frame(', 'I, T, frame', env)
        sample = R.compile_proc(R.SNAP, '/proc/root_light_mask_snapshot(',
                                'root, allow_pending=False', env)
        turf = self.tree.loc
        turf.lighting_overlay = N(loc=turf, needs_update=False,
                                  color=R.Values([.25]*20), last_color=R.Values([.25]*20))
        def refresh(snapshot):
            # Geometry/capture and baking are existing fixture boundaries;
            # invalidation, strict committed-mask checks, publication guard and
            # frame assignment below execute the production procedures.
            if not snapshot or m.V.decision_snapshot(self.tree, snapshot, 'visual_tree') == 0:
                withdraw(root, self.tree, image)
                return snapshot is not None
            if sample(turf, True) is None:
                withdraw(root, self.tree, image)
                return False
            if publish(root, self.tree, root.frame, self.tree.appearance):
                set_frame(image, self.tree, root.frame)
                root.published_frames[self.tree] = root.frame
                root.source_appearances[self.tree] = self.tree.appearance
                root.frame_writes += 1
            return True
        root.refresh = refresh
        m.C.root_tree_presenter = root
        m.C.images |= image
        return root

    def reconcile(self, index):
        m = self.models[index]
        self.captures[index] += 1
        snapshot = m.S if self.outcome != 'capture_failed' or not self.trace else None
        if self.outcome == 'denied' and self.trace:
            m.outcomes[self.tree] = 0
        if snapshot is None:
            if m.C.root_tree_presenter:
                m.C.root_tree_presenter.invalidate()
            m.P.invalidate()
            m.C.los_dirty = True
            return False
        root_ok = not m.C.root_tree_presenter or m.C.root_tree_presenter.refresh(snapshot)
        ok = m.P.refresh(snapshot) and root_ok
        m.C.los_dirty = not ok
        return ok

    def record(self, event):
        def state(index):
            m = self.models[index]
            image = (self.roots[index].image if self.mode == 'root'
                     else m.P.tree_images[self.tree])
            return dict(image=image, allowed=bool(image and image in m.C.images and
                       (self.mode != 'root' or image.icon is not None)),
                        frame=image.icon if self.mode == 'root' else None)
        self.trace.append(dict(event=event, own=state(0), other=state(1)))

    def run(self):
        self.move(self.mover, self.destination, 4)
        self.record('returned')
        return {row['event']: row for row in self.trace}

    def queue_light(self):
        self.tree.loc.lighting_overlay.needs_update = True
        env = R.environment()
        env['root_tree_presenters'] = R.Items(self.roots)
        changed = R.compile_proc(R.TREE, '/proc/root_tree_light_changed(', 'root', env)
        changed(self.tree.loc)
        self.record('queued_light')


class EnteredIdentityRegression(unittest.TestCase):
    def test_smooth_tile_move_executes_entered_and_replaces_fallback_identity(self):
        scene = IdentityTrace()
        rows = scene.run()
        first, final = rows['initial']['own'], rows['returned']['own']
        self.assertTrue(first['allowed'])
        self.assertFalse(rows['after_entered']['own']['allowed'])
        self.assertFalse(rows['moved_event']['own']['allowed'])
        self.assertTrue(final['allowed'])
        self.assertIsNot(first['image'], final['image'])
        self.assertIs(rows['initial']['other']['image'], rows['returned']['other']['image'])
        self.assertEqual(scene.captures, [1, 1])
        self.assertEqual(scene.mover.human_subtile_transaction.total_distance, 32)

    def test_root_image_identity_survives_but_frame_is_withdrawn_then_republished(self):
        scene = IdentityTrace(mode='root')
        rows = scene.run()
        self.assertIs(rows['initial']['own']['image'], rows['returned']['own']['image'])
        self.assertFalse(rows['after_entered']['own']['allowed'])
        self.assertIsNone(rows['after_entered']['own']['frame'])
        self.assertTrue(rows['returned']['own']['allowed'])
        self.assertEqual([r.frame_writes for r in scene.roots], [2, 1])

    def test_denial_or_capture_failure_keeps_entered_withdrawal_conservative(self):
        for mode in ('fallback', 'root'):
            for outcome in ('denied', 'capture_failed'):
                scene = IdentityTrace(mode=mode, outcome=outcome)
                rows = scene.run()
                self.assertTrue(rows['initial']['own']['allowed'])
                self.assertFalse(rows['after_entered']['own']['allowed'])
                self.assertFalse(rows['returned']['own']['allowed'], (mode, outcome))

    def test_blocked_and_offset_only_native_outcomes_do_not_deliver_entered(self):
        for mode in ('fallback', 'root'):
            for native in ('blocked', 'offset'):
                scene = IdentityTrace(mode=mode, native=native)
                rows = scene.run()
                self.assertNotIn('after_entered', rows)
                self.assertIs(rows['initial']['own']['image'], rows['returned']['own']['image'])
                self.assertTrue(rows['returned']['own']['allowed'])
                self.assertEqual(scene.captures, [0, 0])

    def test_queued_committed_light_keeps_frame_but_cannot_override_entered_denial(self):
        for outcome in ('allowed', 'denied'):
            scene = IdentityTrace(mode='root', outcome=outcome)
            scene.queue_light()
            self.assertTrue(scene.trace[-1]['own']['allowed'])
            self.assertEqual([r.frame_writes for r in scene.roots], [1, 1])
            rows = scene.run()
            self.assertFalse(rows['after_entered']['own']['allowed'])
            self.assertEqual(rows['returned']['own']['allowed'], outcome == 'allowed')

    def test_omission_controls_distinguish_entered_revocation_from_postmove_rebuild(self):
        # Use the injected parent boundary to omit only this notification.
        scene = IdentityTrace(entered_source=ENTERED.replace('los_invalidate(am)', 'parent_entered()'))
        rows = scene.run()
        self.assertTrue(rows['after_entered']['own']['allowed'])
        self.assertIs(rows['initial']['own']['image'], rows['returned']['own']['image'])
        scene = IdentityTrace(move_source=MOVE.replace(
            'los_refresh_moved_viewer(src, FALSE, los_move_contexts)', 'omitted_postmove(src)'))
        scene.env['omitted_postmove'] = lambda *_: None
        rows = scene.run()
        self.assertFalse(rows['returned']['own']['allowed'])


def write_trace(destination):
    scenarios = []
    for mode, outcome, native, queued in [
            ('fallback', 'allowed', 'tile', False),
            ('root', 'allowed', 'tile', False),
            ('root', 'allowed', 'tile', True),
            ('root', 'denied', 'tile', True),
            ('fallback', 'capture_failed', 'tile', False),
            ('fallback', 'allowed', 'blocked', False),
            ('root', 'allowed', 'offset', False)]:
        scene = IdentityTrace(mode=mode, outcome=outcome, native=native)
        if queued:
            scene.queue_light()
        scene.run()
        labels = {}
        def label(obj):
            if obj is None:
                return None
            return labels.setdefault(id(obj), 'identity-' + str(len(labels)))
        phases = []
        for row in scene.trace:
            phases.append(dict(event=row['event'], **{
                who: dict(allowed=row[who]['allowed'],
                          image=label(row[who]['image']), frame=label(row[who]['frame']))
                for who in ('own', 'other')}))
        scenarios.append(dict(mode=mode, outcome=outcome, native_adapter_outcome=native,
                              queued_light=queued, captures=scene.captures, phases=phases))
    inputs = ['tests/los_context/test_entered_trace.py',
              'tests/los_context/test_production.py',
              'tests/root_tree_presentation/test_contract.py',
              'tests/save_movement/source_adapter.py',
              'code/game/mob/mob_movement.dm', 'code/datums/observation/moved.dm',
              'code/modules/visibility/los_lifecycle.dm',
              'code/modules/visibility/los_presenter.dm',
              'code/modules/visibility/root_tree_presenter.dm',
              'code/modules/visibility/root_light_snapshot.dm']
    report = dict(kind='offline-source-identity-trace', native_executed=False,
                  pixels_verified=False, performance_measured=False,
                  source_sha256={p: hashlib.sha256((ROOT/p).read_bytes()).hexdigest()
                                 for p in inputs}, scenarios=scenarios)
    Path(destination).write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    if '--write-trace' in sys.argv:
        import argparse
        parser = argparse.ArgumentParser(description=__doc__)
        parser.add_argument('--write-trace', type=Path, required=True)
        write_trace(parser.parse_args().write_trace)
    else:
        unittest.main()

