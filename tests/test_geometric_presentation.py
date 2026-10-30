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

    def test_retirement_releases_masks(self):
        self.assertIn('owner.images -= owned_images', SOURCE)
        self.assertIn('owner.los_presenter = null', SOURCE)
        self.assertIn('images.Cut()', SOURCE)
        self.assertIn('owned_images.Cut()', SOURCE)
        self.assertIn('should_save = FALSE', SOURCE)


if __name__ == '__main__':
    unittest.main()
