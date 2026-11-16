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
        self.assertIn('persistence_freeze_lifted(FALSE)', release)
        lifted = proc_body(self.restart, '/proc/persistence_freeze_lifted(save_over)')
        # Play after a level's capture is end-of-round activity; players are told it won't carry over.
        self.assertIn('anything you do from now until the move finishes will not carry over', lifted)
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

    def test_told_players_hear_when_they_can_act_again_on_every_exit(self):
        # Val (2026-11-16): the freeze notice had no matching notice when it lifted.
        notice = proc_body(self.restart, '/proc/persistence_freeze_notice(client/C)')
        self.assertIn('persistence_freeze_notified[C.ckey] || !persistence_input_frozen(C)) return', notice)
        self.assertIn('persistence_freeze_notified[C.ckey] = TRUE', notice)
        freeze = proc_body(self.restart, '/proc/persistence_freeze_level(z)')
        self.assertIn('persistence_freeze_notice(C)', freeze)
        # Players who join or arrive mid-save, or click while held, are told too.
        login = read('code/game/mob/login.dm')
        self.assertIn('if(persistence_frozen_levels.len) persistence_freeze_notice(client)', login)
        click = proc_body(self.restart, '/client/Click(atom/object, location, control, params)')
        self.assertIn('persistence_freeze_notice(src)', click)
        lifted = proc_body(self.restart, '/proc/persistence_freeze_lifted(save_over)')
        # Only told players hear it; one still held on a frozen level waits.
        self.assertIn('if(!C.ckey || !persistence_freeze_notified[C.ckey]) continue', lifted)
        self.assertIn('if(!save_over && persistence_input_frozen(C)) continue', lifted)
        self.assertIn('if(save_over) persistence_freeze_notified.Cut()', lifted)
        self.assertIn('You can act again.', lifted)
        # A finished, failed or abandoned save, or a called-off move, ends every hold.
        release_all = proc_body(self.restart, '/proc/persistence_release_all_levels()')
        self.assertLess(release_all.index('persistence_frozen_levels.Cut()'), release_all.index('persistence_freeze_lifted(TRUE)'))

    def test_player_messages_describe_the_level_freeze(self):
        admission = read(FUNCTIONS)
        self.assertIn('you are held still while your own level saves', admission)
        self.assertIn('Do not move between z-levels until the move finishes. Each level is held still for a moment while it saves', self.restart)

    def test_held_players_needs_wait_with_their_movement(self):
        life = read('code/game/mob/living/life.dm')
        helper = proc_body(life, '/proc/persistence_life_frozen(mob/living/M)')
        # Players, logged-off player bodies and agent characters; never wildlife or NPCs.
        self.assertIn('(!M.ckey && !agent_characters[M])', helper)
        self.assertIn('persistence_frozen_levels["[T.z]"]', helper)
        mob = read('code/processes/mob.dm')
        self.assertIn('!(persistence_frozen_levels.len && persistence_life_frozen(M))', mob)
        self.assertLess(mob.index('persistence_life_frozen(M)'), mob.index('\t\t\t\tM.Life()'))
        living = read('code/game/mob/living/living.dm')
        self.assertIn('!persistence_life_frozen(src))\n\t\t\t\tLife()', living)

    def test_animals_hold_still_while_their_level_is_saved(self):
        # Val (2026-11-14): simple animals are held like players while their
        # level is captured; ai_step, the mob process and dog walking all ask
        # ecology_animal_frozen.
        eco = read('code/modules/ecology/ecology_spawning.dm')
        frozen = proc_body(eco, '/proc/ecology_animal_frozen(mob/living/simple_animal/A)')
        self.assertIn('return ecology_world_unwatched || persistence_animal_save_frozen(A)', frozen)
        self.assertIn('if (!istype(A) || A.client || A.stat == DEAD)', frozen)
        level = proc_body(eco, '/proc/persistence_animal_save_frozen(mob/living/simple_animal/A)')
        self.assertIn('persistence_frozen_levels["[T.z]"]', level)
        hold = proc_body(eco, '/proc/persistence_hold_level_animals(z)')
        self.assertIn('if (A.z == z && ecology_animal_frozen(A))', hold)
        self.assertIn('A.ecology_hold_still()', hold)
        freeze = proc_body(self.restart, '/proc/persistence_freeze_level(z)')
        self.assertLess(freeze.index('persistence_frozen_levels["[z]"] = TRUE'), freeze.index('call(hold_animals)(z)'))
        self.assertIn('text2path("/proc/persistence_hold_level_animals")', freeze)
        step = read('code/game/mob/living/simple_animal/subtile_movement.dm')
        self.assertIn('ecology_animal_frozen(src)', step)

    def test_an_animal_that_moves_anyway_is_deleted(self):
        delete = proc_body(self.saving, '/map_storage/proc/delete_unheld_save_animal(mob/living/simple_animal/A, where)')
        self.assertIn('if(!istype(A) || A.gcDestroyed || A.client || A.ckey) return FALSE', delete)
        self.assertIn('qdel(A)', delete)
        fail = proc_body(self.saving, '/map_storage/proc/fail_save_on_animal(mob/living/simple_animal/A, where, remove = TRUE)')
        self.assertIn('if(!istype(A) || A.client || A.ckey) return FALSE', fail)
        self.assertIn('save_animal_failure = "[A.type] ([where])"', fail)
        self.assertIn('if(remove) delete_unheld_save_animal(A, where)', fail)
        capture = proc_body(self.saving, '/map_storage/proc/capture_moving_save_root(savefile/destination, list/record)')
        self.assertIn('if(A) fail_save_on_animal(A, "moving-save capture", changed)', capture)
        self.assertIn('fail_save_on_animal(A, "changed while the save waited for headroom")', capture)
        sweep = proc_body(self.saving, '/map_storage/proc/sweep_uncaptured_animals(savefile/F)')
        self.assertLess(sweep.index('fail_save_on_animal(A, "uncaptured animal sweep")'), sweep.index('throw EXCEPTION("Swept mob moved or disappeared during capture")'))
        export = proc_body(self.saving, '/map_storage/proc/export_saved_entry(')
        self.assertIn('if(content) fail_save_on_animal(content, "turf contents")', export)
        drain = proc_body(self.saving, '/map_storage/proc/drain_moving_save_roster(savefile/F)')
        for where in ('moving-save roster', 'moving-save replay', 'moving-save drain checkpoint'):
            self.assertIn('fail_save_on_animal(A, "%s")' % where, drain)

    def test_an_uncaptured_roster_animal_that_changed_never_fails_the_save(self):
        drain = proc_body(self.saving, '/map_storage/proc/drain_moving_save_roster(savefile/F)')
        decline = drain.index('if(!ref)\n\t\t\t\tmoving_save_roots -= identity\n\t\t\t\tcontinue')
        self.assertLess(decline, drain.index('throw EXCEPTION("Moving save roster member disappeared or changed ownership")'))

    def test_a_save_that_failed_on_an_animal_saves_again(self):
        functions = read(FUNCTIONS)
        savemap = proc_body(functions, '/datum/controller/gameticker/proc/savemap(')
        self.assertIn('#define PERSISTENCE_ANIMAL_SAVE_ATTEMPTS 4', functions)
        self.assertLess(savemap.index('map_storage.save_animal_failure = null'), savemap.index('begin_persistence_operation('))
        retry = savemap.index('if(animal && !debug_policy && map_storage.save_animal_retries < PERSISTENCE_ANIMAL_SAVE_ATTEMPTS - 1)')
        self.assertLess(savemap.index('var/released = operation.finish(FALSE)'), retry)
        self.assertLess(retry, savemap.index('return savemap(transaction, debug_policy, shutdown)'))
        abandoned = savemap[savemap.index('if(operation.abandoned)'):]
        self.assertLess(abandoned.index('map_storage.save_animal_failure = null'), abandoned.index('return 0'))
        self.assertIn('map_storage.save_animal_retries = 0\n\tvar/released_success = operation.finish(TRUE)', savemap)


if __name__ == '__main__':
    unittest.main()
