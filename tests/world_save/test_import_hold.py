"""A world whose save failed to load stays closed and never saves over it."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


class ImportHoldTests(unittest.TestCase):
    def test_an_unloaded_save_holds_the_world(self):
        functions = read('code/modules/persistence/functions.dm')
        self.assertIn('/proc/persistence_import_held()\n\treturn persistence_startup_recovery_status == "unresolved"\n', functions)
        self.assertIn('return persistence_restart.startup_hold || persistence_restart.busy || persistence_import_held()', functions)
        save = functions.split('/datum/controller/gameticker/proc/savemap(', 1)[1]
        # The refusal comes before any save operation begins.
        self.assertLess(save.index('if(persistence_import_held())'), save.index('begin_persistence_operation('))
        # The failed automatic load leaves the status unresolved.
        setup = read('code/setup.dm')
        self.assertIn('else persistence_startup_recovery_status = "unresolved"', setup)

    def test_every_lobby_join_waits_for_the_load(self):
        lobby = read('code/game/mob/new_player/new_player.dm')
        self.assertEqual(lobby.count('if (!ticker.players_can_join || persistence_join_held())'), 6)
        self.assertNotIn('if (!ticker.players_can_join || persistence_restart.startup_hold || persistence_restart.busy)', lobby)
        fresh = lobby.split('/mob/new_player/proc/lobby_join_admission_current()', 1)[1].split('\n/mob/', 1)[0]
        self.assertIn('!persistence_import_held()', fresh)


if __name__ == '__main__':
    unittest.main()
