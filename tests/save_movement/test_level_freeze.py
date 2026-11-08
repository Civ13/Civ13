"""Per-level save freeze: players freeze only while their own level is captured.

A map save blocks crossing between levels for the whole save but holds a level's
players only while that level is captured. A handover does the same; play after a
level's capture is end-of-round activity that does not carry over, and players are
told so.
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

    def test_handover_releases_each_level_when_its_save_completes(self):
        release = proc_body(self.restart, '/proc/persistence_release_level(z)')
        self.assertIn('if(!persistence_frozen_levels["[z]"]) return', release)
        self.assertNotIn('if(world_moving ||', release)
        # Play after a level's capture is end-of-round activity; players are told it won't carry over.
        self.assertIn('anything you do from now until the move finishes will not carry over', release)
        release_all = proc_body(self.restart, '/proc/persistence_release_all_levels()')
        self.assertNotIn('world_moving', release_all)
        moving = proc_body(self.restart, '/proc/set_world_moving(moving)')
        self.assertIn('if(!world_moving) persistence_release_all_levels()', moving)
        wait = proc_body(self.restart, '/datum/persistence_restart_transaction/proc/wait_for_handover()')
        self.assertIn('anything you do until the move finishes will not carry over', wait)

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
        self.assertIn('Do not move between z-levels until the move finishes. Each level is held still for a moment while it saves', self.restart)


if __name__ == '__main__':
    unittest.main()
