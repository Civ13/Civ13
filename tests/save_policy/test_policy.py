"""Save policy (Val, 2026-11-05): no automatic saves during active play.

Automatic saves and the daily maintenance reboot wait until only the host is
online; a catch-up save follows soon after the last player leaves. Players can
vote for a save at most once per 30 minutes.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


def proc_body(text, signature):
    start = text.index(signature)
    rest = text[start + len(signature):]
    end = re.search(r'\n/proc/|\n/[a-z_]+/proc/|\nvar/', rest)
    return rest[:end.start()] if end else rest


class SavePolicy(unittest.TestCase):
    def setUp(self):
        self.world = (ROOT / 'code/world.dm').read_text(encoding='utf-8')
        self.vote = (ROOT / 'code/datums/vote.dm').read_text(encoding='utf-8')
        self.loop = proc_body(self.world, '/proc/start_persistence_loop()')

    def test_host_is_not_an_active_player(self):
        body = proc_body(self.world, '/proc/persistence_active_players()')
        self.assertIn('config/host.txt', body)
        self.assertIn('C.ckey != host', body)
        self.assertIn('C.key != world.host', body)

    def test_autosave_only_runs_without_players(self):
        players = self.loop.index('if (persistence_active_players())')
        empty = self.loop.index('\t\t\t\telse\n', players)
        save = self.loop.index('ticker.savemap()')
        self.assertLess(empty, save, 'periodic save must sit in the empty-server branch')
        self.assertEqual(self.loop.count('ticker.savemap()'), 1)
        held = self.loop[players:empty]
        self.assertIn('persistence_played_since_save = TRUE', held)
        self.assertNotIn('savemap', held)

    def test_catch_up_save_soon_after_last_player_leaves(self):
        self.assertIn('#define PERSISTENCE_EMPTY_SAVE_DELAY 3000', self.world)
        self.assertIn('persistence_played_since_save && world.realtime - persistence_empty_since >= PERSISTENCE_EMPTY_SAVE_DELAY', self.loop)
        functions = (ROOT / 'code/modules/persistence/functions.dm').read_text(encoding='utf-8')
        self.assertIn('last_persistence_save_time = world.time\n\t// Players still online mark the session unsaved again on the next loop.', functions)
        self.assertIn('global.vars["persistence_played_since_save"] = FALSE', functions)

    def test_catch_up_save_is_not_rescheduled_by_a_running_save(self):
        # Pulling nextsave in while a save ran started another save as soon
        # as it finished (Gaia, 2026-11-07), and failures retried every loop.
        empty = self.loop.index('\t\t\t\telse\n')
        restart = self.loop.index('if (!persistence_empty_since || persistence_save_active())\n\t\t\t\t\t\tpersistence_empty_since = world.realtime', empty)
        pull = self.loop.index('nextsave = min(nextsave, world.realtime)', empty)
        self.assertLess(restart, pull)
        guard = self.loop.rindex('\n', 0, pull)
        line = self.loop[self.loop.rindex('\n', 0, guard) + 1:guard]
        self.assertIn('!persistence_save_active() && persistence_played_since_save', line)

    def test_maintenance_reboot_waits_for_empty_server(self):
        self.assertIn('persistence_reboot_due = TRUE', self.loop)
        self.assertIn('if (persistence_reboot_due && !persistence_active_players())', self.loop)

    def test_save_vote_cooldown_is_thirty_minutes(self):
        body = proc_body(self.vote, '/proc/persistence_save_vote_block_reason()')
        self.assertIn('last_persistence_save_vote_time, round_start_time) + 18000 - world.time', body)
        self.assertIn('if (initiate_vote("save",usr.key))\n\t\t\t\t\tlast_persistence_save_vote_time = world.time', self.vote)


if __name__ == '__main__':
    unittest.main()


class HostRequestedSave(unittest.TestCase):
    """The host may ask for the empty-world save through the lifecycle Topic
    (action save_idle); it runs only the save the persistence loop would run."""

    def setUp(self):
        self.lifecycle = (ROOT / 'code/modules/persistence/nomads_lifecycle.dm').read_text(encoding='utf-8')
        self.body = proc_body(self.lifecycle, '/datum/nomads_lifecycle_control/proc/save_idle()')

    def test_save_idle_keeps_the_no_autosave_rule(self):
        self.assertIn('persistence_active_players()) skip = "players_online"', self.body)
        self.assertIn('!persistence_played_since_save) skip = "nothing_played"', self.body)
        self.assertIn('persistence_save_in_progress', self.body)
        self.assertIn('persistence_restart.exists()', self.body)
        self.assertEqual(self.body.count('ticker.savemap()'), 1)
        self.assertLess(self.body.index('if(skip)'), self.body.index('ticker.savemap()'))

    def test_save_idle_needs_only_the_token(self):
        handler = proc_body(self.lifecycle, '/datum/nomads_lifecycle_control/proc/handle(list/input, addr)')
        self.assertIn('(action == "status" || action == "save_idle") ? list("nomads_lifecycle", "token", "action")', handler)
        self.assertLess(handler.index('if(action == "save_idle") return json_encode(save_idle())'),
                        handler.index('input["session"] != boot_session()'))
