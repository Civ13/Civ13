"""Offline contracts only: these checks do not establish BYOND pixel behavior."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
LIFECYCLE = (ROOT / 'code/modules/visibility/los_lifecycle.dm').read_text()
CONTEXT = (ROOT / 'code/modules/visibility/los_context.dm').read_text()
PROCESS = (ROOT / 'code/processes/visibility.dm').read_text()
SOURCE = (Path(__file__).resolve().parents[1] / 'code/modules/visibility/los_presenter.dm').read_text()


class PresenterSourceContracts(unittest.TestCase):
    def test_no_worldwide_or_private_timer(self):
        self.assertNotIn(' in world', SOURCE)
        self.assertNotIn('spawn(', SOURCE)
        self.assertNotIn('sleep(', SOURCE)
        self.assertIn('locate(cx, cy, S.eye_z)', SOURCE)
        self.assertIn('context.body.x-S.radius_x-2', SOURCE)

    def test_masks_do_not_clip_whole_canopy(self):
        self.assertIn('I.plane = A.plane', SOURCE)
        self.assertIn('I.layer = A.layer', SOURCE)
        self.assertNotIn('screen_loc =', SOURCE)
        self.assertIn('owner.root_tree_presenter.owns_tree(A)', SOURCE)
        self.assertIn('!owner.root_tree_presenter.retired', SOURCE)

    def test_completed_revision_before_publication(self):
        start = SOURCE.index('/datum/los_presenter/proc/refresh(')
        publication = SOURCE.index('owner.images -= owned_images - next_owned', start)
        guard = SOURCE.index('S.revision != context.revision', start)
        self.assertLess(guard, publication)
        self.assertIn('owner.images |= next_owned - owned_images', SOURCE)

    def test_one_scheduler_and_body_rebind(self):
        self.assertIn('C.reconcile_geometric_los()', PROCESS)
        self.assertIn('PROCESS_LIST_CHECK', PROCESS)
        self.assertIn('PROCESS_TICK_CHECK', PROCESS)
        self.assertIn('los_context.body != mob', LIFECYCLE)
        self.assertIn('los_context.retire()', LIFECYCLE)
        self.assertIn('owner.los_presenter.retire()', CONTEXT)
        self.assertIn('owner.root_tree_presenter.retire()', CONTEXT)

    def test_runtime_optout_and_periodic_raw_writer_audit(self):
        self.assertIn('/client/proc/set_geometric_los(enabled)', LIFECYCLE)
        self.assertIn('los_enabled = !!enabled', LIFECYCLE)
        self.assertIn('!los_enabled', LIFECYCLE)
        self.assertIn('world.time < los_next_audit', LIFECYCLE)
        self.assertIn('los_next_audit = world.time + 5', LIFECYCLE)

    def test_carried_items_and_lighting_are_not_visual_masks(self):
        self.assertIn('isturf(A) || isturf(A.loc)', SOURCE)
        self.assertIn('istype(A, /obj/screen)', SOURCE)
        self.assertIn('istype(A, /atom/movable/lighting_overlay)', SOURCE)
        self.assertIn('A == context.body', SOURCE)

    def test_capture_suspension_precedes_retirement_and_preserves_world_masks(self):
        start = LIFECYCLE.index('if(V.eligible() && ((persistence_active_operation && persistence_active_operation.kind != "save") || V.mutations.len))')
        end = LIFECYCLE.index('var/key = V.policy_key()', start)
        suspended = LIFECYCLE[start:end]
        self.assertIn('root_tree_presenter.invalidate()', suspended)
        self.assertIn('los_dirty = TRUE', suspended)
        self.assertIn('return', suspended)
        self.assertNotIn('.retire()', suspended)
        self.assertNotIn('clear_images()', suspended)
        self.assertLess(end, LIFECYCLE.index('if(!key || !mob.hud_used)', end))

    def test_blocker_invalidation_masks_affected_content_synchronously(self):
        import importlib.util
        import re
        spec = importlib.util.spec_from_file_location('los_invalidation_geometry', ROOT / 'tests/los_context/test_offline.py')
        geometry = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(geometry)
        projected = geometry.projected_geometry()
        block = SOURCE.split('/datum/los_presenter/proc/invalidate(', 1)[1].split('/datum/los_presenter/proc/owns_atom(', 1)[0]
        call = re.search(r'if\((los_footprint_hits_cell\([^\n]+\))\)', block)
        self.assertIsNotNone(call)
        def hidden(tx, ty, cx=3, cy=0):
            return eval(call[1], {'__builtins__': {}, **projected}, dict(tx=tx, ty=ty, cx=cx, cy=cy))
        self.assertTrue(hidden(4, 0))  # Behind closing door.
        self.assertFalse(hidden(1, 0))  # In front remains visible.
        self.assertFalse(hidden(0, 4))  # Unrelated region remains visible.
        self.assertTrue(hidden(4, .125, 2.125, 0))  # Smooth-offset blocker.
        self.assertIn('owner.images |= I', block)
        self.assertIn('owned_images |= I', block)
        self.assertNotIn('screen_loc', block)
        self.assertIn('blocker.step_x / 32', block)
        self.assertIn('target.step_x / 32', block)
        door = (ROOT / 'code/game/objects/structures/door.dm').read_text()
        close = door.split('/obj/structure/simple_door/proc/Close()', 1)[1].split('/obj/structure/simple_door/Destroy()', 1)[0]
        self.assertLess(close.index('los_invalidate(src, TRUE)'), close.index('opacity = TRUE'))
        movement = (ROOT / 'code/game/mob/mob_movement.dm').read_text()
        self.assertIn('los_refresh_moved_viewer(src)', movement)
        self.assertIn('M.client.reconcile_geometric_los()', LIFECYCLE)
        postmove = LIFECYCLE.split('/proc/los_refresh_moved_viewer(', 1)[1]
        self.assertLess(postmove.index('los_invalidate(A)'), postmove.index('if(!ismob(A))'))
        self.assertEqual(movement.split('/atom/movable/Move(newloc, direct)', 1)[1].split('/client/proc/Move_object', 1)[0].count('los_refresh_moved_viewer(src)'), 3)

    def test_transparent_clutter_does_not_create_hypothetical_blocker(self):
        from types import SimpleNamespace
        import re
        block = SOURCE.split('/datum/los_presenter/proc/invalidate(', 1)[1].split('/datum/los_presenter/proc/owns_atom(', 1)[0]
        self.assertIn('if(!changed || (!possible_opacity && !changed.opacity))', block)
        self.assertLess(block.index('!possible_opacity && !changed.opacity'), block.index('los_footprint_hits_cell'))
        guard = re.search(r'if\((!changed \|\| \(!possible_opacity && !changed.opacity\))\)', block)[1]
        expression = guard.replace('||', 'or').replace('&&', 'and').replace('!', 'not ')
        def skipped(opacity, possible=False):
            return eval(expression, {'__builtins__': {}}, {'changed': SimpleNamespace(opacity=opacity), 'possible_opacity': possible})
        self.assertTrue(skipped(False))  # Dropped item on eye tile: no masks.
        self.assertFalse(skipped(True))  # Moving opaque blocker.
        self.assertFalse(skipped(False, True))  # Open door about to close.
        entered = (ROOT / 'code/datums/observation/moved.dm').read_text()
        self.assertIn('los_invalidate(old_loc, am.opacity)', entered)

    def test_shared_tile_invalidation_preserves_ground_and_objects(self):
        block = SOURCE.split('/datum/los_presenter/proc/invalidate(', 1)[1].split('/datum/los_presenter/proc/owns_atom(', 1)[0]
        guard = 'if(get_turf(A) == cell)'
        self.assertIn(guard, block)
        self.assertLess(block.index(guard), block.index('los_footprint_hits_cell'))
        self.assertNotIn('isturf(A) && !A.opacity', block)
        # Native tile identity, not smooth geometric centers, controls exemption.
        self.assertNotIn('tx == cx && ty == cy', block)
        from types import SimpleNamespace
        cell, behind = object(), object()
        for target in [SimpleNamespace(tile=cell, step_x=0), SimpleNamespace(tile=cell, step_x=8), SimpleNamespace(tile=behind, step_x=-8)]:
            exempt = eval(guard[3:-1], {'__builtins__': {}, 'get_turf': lambda a: a.tile}, {'A': target, 'cell': cell})
            self.assertEqual(exempt, target.tile is cell)


    def test_retirement_releases_masks(self):
        self.assertIn('owner.images -= owned_images', SOURCE)
        self.assertIn('owner.los_presenter = null', SOURCE)
        self.assertIn('images.Cut()', SOURCE)
        self.assertIn('owned_images.Cut()', SOURCE)
        self.assertIn('should_save = FALSE', SOURCE)


if __name__ == '__main__':
    unittest.main()
