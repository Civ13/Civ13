"""Event regions: offline seam checks.

The native probe (probe.dm, run.py) checks the stash in a real build: a home
character kept out of play on its tile and put back where it stood, beside its
bed or on the nearest safe floor. These checks keep the hooks the probe cannot
reach in place: the frozen clock in the mob and food loops, the return on
rejoin, and the EVENT kind in the region code and host tool.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


EVENT = read('code/modules/persistence/region_event.dm')
SHARD = read('code/modules/persistence/shard_group.dm')
HOME = read('code/modules/persistence/region_home.dm')
TRAVEL = read('code/modules/persistence/region_travel.dm')
MOB = read('code/processes/mob.dm')
FOOD = read('code/modules/reagents/reagent_containers/food.dm')
VERBS = read('code/modules/admin/admin_verbs.dm')
PANEL = read('code/modules/admin/event_transfer.dm')
DME = read('civ13.dme')
HOST = read('scripts/shard-group/shard_group.py')


class EventRegionSeams(unittest.TestCase):
    def test_included_and_offered_to_admins(self):
        self.assertIn('#include "code\\modules\\persistence\\region_event.dm"', DME)
        self.assertIn('#include "code\\modules\\admin\\event_transfer.dm"', DME)
        self.assertIn('/datum/admins/proc/event_transfer,', VERBS)
        verb = PANEL.split('/datum/admins/proc/event_transfer()', 1)[1].split('\n/', 1)[0]
        self.assertIn('if(!check_rights(R_ADMIN)) return', verb)

    def test_stashed_characters_do_not_live(self):
        # Needs, wounds and carried food stay as they were while away.
        self.assertIn('!(ishuman(M) && event_stash_holds(M))', MOB)
        self.assertRegex(FOOD, r'if \(ismob\(loc\) && event_stash_holds\(src\)\)\s*\n\s*food_decay\(\)\s*\n\s*return')

    def test_rejoining_takes_the_character_out_first(self):
        # prepare_character_return refuses a restored body that is not on a tile,
        # so the stash must open before the ordinary reclaim runs.
        body = EVENT.split('/map_storage/reclaim_saved_player(mob/new_player/lobby)', 1)[1].split('\n/', 1)[0]
        self.assertLess(body.index('S.release()'), body.index('return ..()'))
        self.assertIn('!character_recovery_unready()', body)

    def test_the_stash_is_saved_and_never_lost(self):
        stash = EVENT.split('/obj/structure/event_stash\n', 1)[1].split('\n\n', 1)[0]
        self.assertNotIn('should_save = 0', stash)
        self.assertNotIn('var/tmp/', stash)
        for field in ('owner_ckey', 'event_region', 'return_mode'):
            self.assertRegex(stash, r'\tvar/%s\b' % field)
        destroy = EVENT.split('/obj/structure/event_stash/Destroy()', 1)[1].split('\n/', 1)[0]
        self.assertIn('AM.forceMove(T)', destroy)

    def test_messages_need_the_group_token(self):
        for keyword in ('event_arrive', 'event_return'):
            run = EVENT.split('/datum/world_topic/%s/Run(list/input)' % keyword, 1)[1].split('\n/', 1)[0]
            self.assertIn('input["token"] != region_event.token', run)

    def test_event_kind_across_region_code(self):
        self.assertIn('"BATTLE", "EVENT")))', SHARD)
        self.assertIn('if("EVENT") return "event"', SHARD)
        self.assertIn('peer["kind"] != "EVENT"', SHARD)
        self.assertIn('.["event_away"] = length(event_stashes())', SHARD)
        self.assertIn('list("BARRACKS", "BATTLE", "EVENT")', HOME)
        self.assertRegex(TRAVEL, r'if\(peer && peer\["kind"\] == "EVENT"\)\s*\n\s*return "The trail is overgrown')
        self.assertIn("'BARRACKS', 'BATTLE', 'EVENT')", HOST)
        self.assertIn("'config/event-token.txt'", HOST)


if __name__ == '__main__':
    unittest.main()
