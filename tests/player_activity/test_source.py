"""Source checks for the player activity recorder wiring.

The recorder is off by default, writes only ckey-level account keys, and is
fed from the existing choke points: client join and leave, region travel
depart/arrive/refusal, the death hook, world save notices and reboot.
"""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCE = 'code/modules/player_activity/player_activity.dm'


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


class PlayerActivityWiring(unittest.TestCase):
    def setUp(self):
        self.source = read(SOURCE)

    def test_included(self):
        self.assertIn('#include "code\\modules\\player_activity\\player_activity.dm"', read('civ13.dme'))

    def test_off_by_default(self):
        config = read('code/datums/configuration.dm')
        self.assertIn('var/player_activity = FALSE', config)
        self.assertIn('config.player_activity = text2num(value) == 1', config)
        self.assertIn('#PLAYER_ACTIVITY 1', read('config/config.txt'))

    def test_client_join_and_leave(self):
        client = read('code/modules/client/client_procs.dm')
        self.assertIn('player_activity.session_start(src)', client)
        self.assertIn('player_activity.session_end(src)', client)

    def test_travel_choke_points(self):
        travel = read('code/modules/persistence/region_travel.dm')
        self.assertIn('player_activity.depart(H, destination, payload)', travel)
        self.assertIn('player_activity.arrive(P, incoming)', travel)
        self.assertIn('player_activity.travel_refused(H, destination, result)', travel)

    def test_save_and_reboot(self):
        # Persistence fixtures build without this module, so the save notice
        # reaches it only through text2path.
        functions = read('code/modules/persistence/functions.dm')
        self.assertIn('text2path("/proc/player_activity_world_save")', functions)
        self.assertNotIn('player_activity.', functions)
        self.assertEqual(read('code/world.dm').count('player_activity.world_stopping("restart")'), 2)

    def test_hooks_return_true(self):
        for hook in ('/hook/death/proc/player_activity_death',):
            body = self.source.split(hook, 1)[1].split('\n/', 1)[0]
            self.assertIn('return TRUE', body)

    def test_no_private_identifiers(self):
        code = '\n'.join(line for line in self.source.splitlines() if not line.lstrip().startswith('//'))
        for forbidden in ('public_address', 'computer_id', 'address', 'real_name', '.x,', 'message', 'msg'):
            self.assertNotIn(forbidden, code, forbidden)

    def test_no_new_mob_vars(self):
        # Mob vars would be written by the world save and carried by every NPC.
        self.assertIsNone(re.search(r'^/mob[^\n]*/var/', self.source, re.M))

    def test_not_under_logs(self):
        # The getlogs verb hands out data/logs to every admin.
        self.assertIn('#define PLAYER_ACTIVITY_DIR "data/player_activity/"', self.source)

    def test_runs_as_a_process(self):
        process = read('code/processes/player_activity.dm')
        self.assertIn('/process/player_activity/fire()', process)
        self.assertIn('#include "code\\processes\\player_activity.dm"', read('civ13.dme'))
        self.assertNotIn('spawn', self.source)

    def test_bounded_buffer(self):
        self.assertIn('#define PLAYER_ACTIVITY_MAX_LINES 2000', self.source)


if __name__ == '__main__':
    unittest.main()
