"""Offline contracts for the disabled large-body exit bridge.

These checks do not replace native collision, callback, save, or facing tests.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]

def source(path):
    return (ROOT/path).read_text(encoding='utf-8')

def check_exit_direction(explicit, legacy):
    return legacy if explicit is None else explicit

class LargeExitContracts(unittest.TestCase):
    def test_legacy_direction_and_remote_direction_are_distinct(self):
        # A westward partial pulse can retain the actor's anchor (legacy 0).
        self.assertEqual(check_exit_direction(None, 0), 0)
        self.assertEqual(check_exit_direction(8, 0), 8)
        # A remote flipped table may see a target west of itself while the
        # actual actor pulse is east; the authenticated direction wins.
        self.assertEqual(check_exit_direction(None, 8), 8)
        self.assertEqual(check_exit_direction(4, 8), 4)

    def test_all_repo_exit_overrides_retain_legacy_fallback(self):
        paths={
            'code/game/objects/structures/window.dm':'get_dir(O.loc, target)',
            'code/game/objects/structures/railing.dm':'get_dir(O.loc, target)',
            'code/game/objects/structures/table.dm':'get_dir(loc, target)',
            'code/modules/1713/machinery/modular_vehicles/frame.dm':'get_dir(O.loc, target)',
        }
        for path,legacy in paths.items():
            text=source(path)
            self.assertIn('exit_direction = null)',text,path)
            self.assertIn('isnull(exit_direction) ? '+legacy+' : exit_direction',text,path)

    def test_scope_lifecycle_and_rejection_guards(self):
        animal=source('code/game/mob/living/simple_animal/subtile_movement.dm')
        movement=source('code/game/mob/mob_movement.dm')
        atoms=source('code/game/atoms.dm')
        self.assertIn('var/tmp/npc_subtile_large_exit_enabled = FALSE',animal)
        self.assertIn('bound_width == 32 && bound_height == 32',animal)
        self.assertIn('!pulse.armed && !pulse.restoring',animal)
        self.assertIn('actor.npc_subtile_large_frame == src',animal)
        self.assertIn('actor.npc_subtile_transaction == transaction',animal)
        self.assertIn('if (faulted || !valid() || checking)',animal)
        self.assertNotIn('checked[obstacle]',animal)
        self.assertIn('obstacle.CheckExit(actor, destination, direction)',animal)
        self.assertIn('if (!. || !istype(mover, /mob/living/simple_animal))',atoms)
        self.assertIn('if (!F)\n\t\treturn .',atoms)
        self.assertIn('if (npc.npc_subtile_large_exit_enabled)',movement)
        self.assertIn('catch (var/exception/large_move_error)\n\t\t\t\t\tlarge_frame.close()',movement)
        self.assertNotIn('Bump(',animal[animal.index('/datum/npc_subtile_large_frame'):animal.index('/datum/npc_subtile_transaction\n')])

    def test_callback_fault_survives_native_boundary_and_frame_closes_first(self):
        animal=source('code/game/mob/living/simple_animal/subtile_movement.dm')
        frame=animal.split('/datum/npc_subtile_large_frame/proc/check_exit',1)[1].split('/mob/living/simple_animal/proc/npc_subtile_begin_large_frame',1)[0]
        catch=frame.split('catch (var/exception/large_exit_error)',1)[1]
        self.assertLess(catch.index('if (!faulted)'),catch.index('fault = large_exit_error'))
        self.assertLess(catch.index('fault = large_exit_error'),catch.index('checking = FALSE'))
        self.assertLess(catch.index('checking = FALSE'),catch.index('throw large_exit_error'))
        movement=source('code/game/mob/mob_movement.dm')
        segment=movement.split('var/large_frame_faulted = large_frame.faulted',1)[1].split('\n\t\t\telse',1)[0]
        self.assertLess(segment.index('var/exception/large_frame_fault = large_frame.fault'),segment.index('large_frame.close()'))
        self.assertLess(segment.index('large_frame.close()'),segment.index('throw large_frame_fault'))

    def test_destroy_retires_only_owned_frame_without_deleting_callback_datum(self):
        animal=source('code/game/mob/living/simple_animal/simple_animal.dm')
        destroy=animal.split('/mob/living/simple_animal/Destroy()',1)[1].split('/mob/living/simple_animal/death(',1)[0]
        self.assertIn('if (F && F.actor == src)',destroy)
        self.assertLess(destroy.index('npc_subtile_large_frame = null'),destroy.index('F.retire()'))
        self.assertNotIn('qdel(F)',destroy)
        self.assertNotIn('living_movement_completed',destroy)
        frame=source('code/game/mob/living/simple_animal/subtile_movement.dm')
        retire=frame.split('/datum/npc_subtile_large_frame/proc/retire()',1)[1].split('/datum/npc_subtile_large_frame/proc/close()',1)[0]
        self.assertLess(retire.index('active = FALSE'),retire.index('actor.npc_subtile_large_frame == src'))
        for name in ('actor','pulse','transaction','intent_owner','fault','start','destination','path_target','combat_target','following'):
            self.assertIn(name+' = null',retire)
        self.assertNotIn('qdel(',retire)
        close=frame.split('/datum/npc_subtile_large_frame/proc/close()',1)[1].split('/datum/npc_subtile_transaction',1)[0]
        self.assertLess(close.index('retire()'),close.index('qdel(src)'))

    def test_native_fixture_draft_uses_engine_move_and_strict_matrix(self):
        fixture=source('tests/human_subtile/large_bridge_fixture.dm')
        self.assertIn('list(EAST, WEST, NORTH, SOUTH)', fixture)
        self.assertIn('for (var/allow in list(FALSE, TRUE))', fixture)
        self.assertIn('large_bridge_rows.len == 64', fixture)
        self.assertIn('B.fixture_checks == native_exits && B.fixture_direction == direction', fixture)
        self.assertIn('large_native_pulse(A, direction', fixture)
        self.assertIn('bridge_no_late_displacement', fixture)
        self.assertNotIn('.CheckExit(', fixture)

    def test_native_helper_snapshots_before_callback_can_delete_transaction(self):
        source_text=source('tests/human_subtile/large_native_observe.dm')
        pulse=source_text.split('/proc/large_native_pulse(',1)[1].split('/proc/large_native_turfs(',1)[0]
        before,after=pulse.split('var/native_result = A.Move',1)
        self.assertIn('var/list/admitted_before = T.expected.Copy()',before)
        self.assertNotIn('T.expected',after)
        self.assertNotIn('T.fixture_',after)
        self.assertLess(after.index('actor_pulse_present = !!A.npc_subtile_pulse'),after.index('A.npc_subtile_pulse = null'))
        self.assertLess(after.index('actor_transaction_present = !!A.npc_subtile_transaction'),after.index('A.npc_subtile_transaction = null'))
        self.assertIn('actor_frame_present = !!A.npc_subtile_large_frame',after)

    def test_failed_callback_observation_is_recorded_before_assertion(self):
        fixture=source('tests/human_subtile/large_bridge_fixture.dm')
        segment=fixture.split('var/control_dx =',1)[1].split('C.control_object = null',1)[0]
        self.assertLess(segment.index('large_bridge_controls += '),segment.index('large_bridge_assert('))
        self.assertIn('"caught_name" = caught_name',segment)
        self.assertIn('"helper_returned" = helper_returned',segment)
        self.assertIn('"throw_attempted" = B.fixture_throw_attempted',segment)
        self.assertIn('"boundary_caught" = B.fixture_boundary_caught',segment)
        self.assertIn('"frame_cleared" = !C.npc_subtile_large_frame',segment)

    def test_throw_boundary_rethrows_and_direct_sentinel_is_identical(self):
        fixture=source('tests/human_subtile/large_bridge_fixture.dm')
        self.assertEqual(fixture.count('throw EXCEPTION("fixture_bridge_exception")'),2)
        boundary=fixture.split('/obj/large_native_border/bridge/throw_boundary/Uncross(',1)[1].split('// Fixture-only parent seam',1)[0]
        self.assertIn('fixture_boundary_caught = TRUE',boundary)
        self.assertIn('throw fixture_boundary_error',boundary)
        self.assertIn('bridge_direct_exception_sentinel',fixture)

if __name__ == '__main__': unittest.main()
