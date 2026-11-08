"""Per-level save freeze: players freeze only while their own level is captured.

A map save blocks crossing between levels for the whole save but holds a level's
players only while that level is captured. A handover keeps captured levels held
until the move, because play there after the capture would be lost at the switch.
"""
import re
import unittest

from source_adapter import read

SAVING = 'code/modules/persistence/saving.dm'
RESTART = 'code/modules/persistence/restart_transaction.dm'
FUNCTIONS = 'code/modules/persistence/functions.dm'
MOVEMENT = 'code/game/mob/mob_movement.dm'


def proc_body(text, header):
    start = text.index(header)
    following = re.compile(r'^/', re.M).search(text, start + len(header))
    return text[start:following.start() if following else len(text)]


class LevelFreeze(unittest.TestCase):
    def setUp(self):
        self.saving = read(SAVING)
        self.restart = read(RESTART)

    def test_each_level_is_held_only_during_its_own_capture(self):
        loop = self.saving[self.saving.index('for(var/A = 1, A <= world.maxz, A++)'):]
        loop = loop[:loop.index('finish_level_links()')]
        freeze = loop.index('persistence_freeze_level(A)')
        release = loop.index('persistence_release_level(A)')
        self.assertLess(loop.index('saving_z = A'), freeze)
        for capture in ('BuildVarDirectory(savefile, T, 1)', 'drain_moving_save_roster(savefile)',
                        'sweep_uncaptured_animals(savefile)', 'savefile.Flush()'):
            self.assertLess(freeze, loop.index(capture))
            self.assertLess(loop.index(capture), release)
        self.assertEqual(loop.count('persistence_freeze_level('), 1)
        self.assertEqual(loop.count('persistence_release_level('), 1)

    def test_handover_keeps_captured_levels_held_until_the_move(self):
        release = proc_body(self.restart, '/proc/persistence_release_level(z)')
        self.assertIn('if(world_moving || !persistence_frozen_levels["[z]"]) return', release)
        release_all = proc_body(self.restart, '/proc/persistence_release_all_levels()')
        self.assertIn('if(world_moving) return', release_all)
        moving = proc_body(self.restart, '/proc/set_world_moving(moving)')
        self.assertIn('if(!world_moving) persistence_release_all_levels()', moving)

    def test_frozen_input_rules(self):
        frozen = proc_body(self.restart, '/proc/persistence_input_frozen(client/C)')
        # After a handover save completes every client waits for the switch.
        self.assertIn('world_moving && persistence_restart.handover_state != "saving"', frozen)
        # During the save only players on a held level wait; observers never do.
        self.assertIn('isobserver(C.mob)', frozen)
        self.assertIn('persistence_frozen_levels["[T.z]"]', frozen)
        self.assertLess(frozen.index('handover_state != "saving"'), frozen.index('isobserver(C.mob)'))
        click = proc_body(self.restart, '/client/Click(atom/object, location, control, params)')
        self.assertIn('persistence_input_frozen(src)', click)
        self.assertLess(click.index('persistence_input_frozen(src)'), click.index('return ..()'))
        move = proc_body(read(MOVEMENT), '/client/Move(n, direct, ordinal = FALSE, fine_step = FALSE)')
        self.assertIn('(world_moving || persistence_frozen_levels.len) && persistence_input_frozen(src)', move)
        self.assertLess(move.index('persistence_input_frozen(src)'), move.index('if (!canmove)'))

    def test_finished_or_failed_save_releases_every_ordinary_hold(self):
        functions = read(FUNCTIONS)
        finish = functions[functions.index('	proc/finish(success)'):]
        finish = finish[:finish.index('return TRUE')]
        self.assertLess(finish.index('persistence_release_all_levels()'), finish.index('persistence_active_operation = null'))
        cancel = self.restart[self.restart.index('diagnostic_phase = "failure_cleanup"'):]
        self.assertLess(cancel.index('handover_state = null'), cancel.index('set_world_moving(FALSE)'))

    def test_player_messages_describe_the_level_freeze(self):
        admission = read(FUNCTIONS)
        self.assertIn('Players are held still only while their own level is being saved.', admission)
        self.assertIn('Do not move between z-levels. Each level is held still from when it saves until the move finishes', self.restart)


if __name__ == '__main__':
    unittest.main()
