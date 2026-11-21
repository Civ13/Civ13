"""Source guards for repository_upkeep.dm: too few keepers after a grace period, and shrines bound to their home."""
from pathlib import Path
import json
import unittest

ROOT = Path(__file__).resolve().parents[2]
UPKEEP = (ROOT / 'code/modules/divine/repository_upkeep.dm').read_text()
REPO = (ROOT / 'code/modules/divine/repository.dm').read_text()
TIERS = (ROOT / 'code/modules/divine/repository_tiers.dm').read_text()
BALANCE = json.loads((ROOT / 'config/magic_law_balance.json').read_text())


def body(text, path):
    return text.split(path, 1)[1].split('\n/', 1)[0]


class RepositoryUpkeep(unittest.TestCase):
    def test_built(self):
        dme = (ROOT / 'civ13.dme').read_text()
        self.assertIn('#include "code\\modules\\divine\\repository_upkeep.dm"', dme)

    def test_keeper_counts_and_grace(self):
        self.assertEqual([t['keepers'] for t in BALANCE['tiers']], [1, 2, 3, 5, 8])
        self.assertEqual(BALANCE['keeper_grace_days'], 7)
        count = body(UPKEEP, '/obj/proc/magic_repo_keeper_count()')
        self.assertIn('magic_whitelisted(key)', count)
        short = body(UPKEEP, '/obj/proc/magic_repo_short_dormant()')
        self.assertIn('world.realtime - magic_repo_short_since >= magic_balance_num("keeper_grace_days", 7)', short)
        check = body(UPKEEP, '/obj/proc/magic_repo_check_keepers()')
        self.assertIn('magic_repo_tier < 2', check)

    def test_still_but_never_lost(self):
        dormant = body(REPO, '/obj/proc/magic_repo_dormant()')
        self.assertIn('magic_repo_astray', dormant)
        self.assertIn('magic_repo_short_dormant()', dormant)
        self.assertNotIn('magic_repo_unmake', UPKEEP)
        tick = body(TIERS, '/obj/proc/magic_repo_tick()')
        self.assertLess(tick.index('magic_repo_check_keepers()'), tick.index('if (magic_repo_dormant())'))
        self.assertLess(tick.index('magic_repo_check_home()'), tick.index('if (magic_repo_dormant())'))

    def test_shrines_belong_to_their_home(self):
        home = body(UPKEEP, '/obj/proc/magic_repo_check_home()')
        self.assertIn('magic_repo_tier != 2', home)
        self.assertIn('!magic_repo_at_home(T)', home)
        at = body(UPKEEP, '/obj/proc/magic_repo_at_home(')
        self.assertIn('map.land_plot_at(T)', at)
        self.assertIn('magic_reach_value("shrine_radius", 7)', at)
        # The move rite gives the greater object a new home.
        self.assertIn('D.magic_repo_home = null', TIERS)

    def test_saved_fields_are_plain(self):
        self.assertIn('var/magic_repo_short_since = 0', UPKEEP)
        self.assertIn('var/magic_repo_home = null', UPKEEP)
        for forbidden in ('.name =', '.desc =', '.icon_state =', '.icon ='):
            self.assertNotIn(forbidden, UPKEEP)


if __name__ == '__main__':
    unittest.main()
