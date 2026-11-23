"""The Barracks votes on the empty battle world's next map (Val, 2026-11-23). Source checks, no BYOND runtime."""
from pathlib import Path
import re
import unittest

from test_tdm_epochs import map_lists, proc_body as mapswap_proc

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


VOTE_FILE = read('code/modules/tdm_barracks/barracks_map_vote.dm')
BATTLE = read('code/modules/tdm_barracks/battle.dm')
BARRACKS = read('code/modules/tdm_barracks/barracks.dm')
LINK = read('code/modules/tdm_barracks/tdm_link.dm')
VOTE = read('code/datums/vote.dm')


def proc(source, signature):
    start = source.index(signature)
    following = re.search(r'^/[^/]', source[start + len(signature):], re.M)
    return source[start:start + len(signature) + (following.start() if following else len(source))]


class BarracksMapVoteTests(unittest.TestCase):
    def test_choices_are_every_tdm_epoch_filtered_by_players(self):
        body = proc(VOTE_FILE, '/proc/tdm_battle_map_choices(')
        self.assertIn('for(var/epoch in tdm_epochs())', body)
        self.assertIn('mapswap_epoch_maps(epoch)', body)
        self.assertIn('if(isnum(players) && players < needed)', body)

    def test_player_needs_leave_small_groups_some_maps(self):
        # The filter above, applied to the real lists: two players still get a vote,
        # and a big group gets every map.
        lists = dict(map_lists())
        epochs = re.findall(r'^\t\t"([^"]+)" = \d+', mapswap_proc('/proc/tdm_epochs()'), re.M)
        needs = {}
        body = mapswap_proc('/proc/mapswap_epoch_maps(epoch)')
        for epoch in epochs:
            case = re.search(r'^\t\tif \("' + re.escape(epoch) + r'"\)\n(.*?)^\t\t\t\)', body, re.M | re.S)
            for map_id, need in re.findall(r'^\t+(MAP_\w+) = (\d+)', case.group(1), re.M):
                needs.setdefault(map_id, int(need))
        self.assertTrue(all(lists.get(e) for e in epochs))
        self.assertGreater(len([m for m, n in needs.items() if n <= 2]), 10)
        self.assertLess(len([m for m, n in needs.items() if n <= 2]), len(needs))

    def test_vote_starts_only_while_the_battle_is_empty_and_waiting(self):
        idle = proc(VOTE_FILE, '/datum/tdm_barracks/proc/battle_idle(')
        self.assertIn('status["phase"] != "pregame"', idle)
        self.assertIn('return !status["players"]', idle)
        block = proc(VOTE_FILE, '/datum/tdm_barracks/proc/map_vote_block(')
        self.assertIn('if(!battle_idle())', block)
        self.assertIn('if(vote.mode)', block)
        self.assertIn('vote.initiate_vote("battle map"', proc(VOTE_FILE, '/datum/tdm_barracks/proc/start_map_vote('))

    def test_winner_is_checked_again_and_sent_over_the_link(self):
        won = proc(VOTE_FILE, '/datum/tdm_barracks/proc/map_vote_won(')
        self.assertLess(won.index('if(!battle_idle())'), won.index('tdm_link.command("map"'))
        self.assertIn('"tdm_command"', proc(LINK, '/datum/tdm_link/proc/command('))
        self.assertIn('shard_group.kind != "BARRACKS"', proc(LINK, '/datum/tdm_link/proc/command('))
        topic = proc(LINK, '/datum/world_topic/tdm_command/Run(')
        self.assertIn('if(!tdm_battle_active() || input["token"] != tdm_link.token)', topic)
        self.assertIn('tdm_battle.barracks_map(data["map"])', topic)

    def test_battle_takes_a_map_only_when_empty_in_pregame(self):
        body = proc(BATTLE, '/datum/tdm_battle/proc/barracks_map(')
        self.assertIn('if(!(map_id in tdm_battle_map_choices()))', body)
        self.assertIn('ticker.current_state != GAME_STATE_PREGAME || length(clients)', body)
        self.assertIn('returning || barracks_rotation || rotation_map || updating', body)
        self.assertLess(body.index('length(clients)'), body.index('rotate(map_id)'))
        self.assertIn('world.Reboot(', proc(BATTLE, '/datum/tdm_battle/proc/reboot_for_barracks_map('))

    def test_a_reboot_before_any_round_sends_no_results(self):
        body = proc(BATTLE, '/datum/tdm_battle/proc/before_reboot(')
        self.assertIn('if(ticker && ticker.current_state >= GAME_STATE_PLAYING)\n\t\tsend_results()', body)

    def test_barracks_blocks_joins_while_the_new_map_builds(self):
        self.assertIn('if(returning || barracks_rotation)\n\t\treturn rotation_map ? "rotating" : "returning"',
                      proc(BATTLE, '/datum/tdm_battle/proc/phase('))
        joinable = proc(BARRACKS, '/datum/tdm_barracks/proc/joinable(')
        self.assertNotIn('"rotating"', joinable)

    def test_vote_type_and_verb_are_wired(self):
        self.assertIn('if ("battle map")', VOTE)
        self.assertIn('tdm_battle_map_choices(clients.len)', VOTE)
        self.assertIn('/client/proc/tdm_vote_battle_map', BARRACKS)
        self.assertIn('set name = "Vote Battle Map"', VOTE_FILE)
        self.assertIn('href_list["tdm_map_vote"]', BARRACKS)
        self.assertIn('barracks_map_vote.dm', read('civ13.dme'))


if __name__ == '__main__':
    unittest.main()
