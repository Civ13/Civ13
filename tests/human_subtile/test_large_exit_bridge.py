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
        self.assertIn('if (!valid() || checking)',animal)
        self.assertNotIn('checked[obstacle]',animal)
        self.assertIn('obstacle.CheckExit(actor, destination, direction)',animal)
        self.assertIn('if (!. || !istype(mover, /mob/living/simple_animal))',atoms)
        self.assertIn('if (!F)\n\t\treturn .',atoms)
        self.assertIn('if (npc.npc_subtile_large_exit_enabled)',movement)
        self.assertIn('catch (var/exception/large_move_error)\n\t\t\t\t\tlarge_frame.close()',movement)
        self.assertNotIn('Bump(',animal[animal.index('/datum/npc_subtile_large_frame'):animal.index('/datum/npc_subtile_transaction\n')])

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

if __name__ == '__main__': unittest.main()
