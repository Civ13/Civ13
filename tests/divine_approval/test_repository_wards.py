"""Source guards for repository reach (repository_wards.dm): what each tier covers, the low warning and who can move one."""
from pathlib import Path
import json
import unittest

ROOT = Path(__file__).resolve().parents[2]
WARDS = (ROOT / 'code/modules/divine/repository_wards.dm').read_text()
REPO = (ROOT / 'code/modules/divine/repository.dm').read_text()
ITEMS = (ROOT / 'code/game/objects/items.dm').read_text()
MOB = (ROOT / 'code/game/mob/mob.dm').read_text()
TOOLS = (ROOT / 'code/_helpers/tools.dm').read_text()
BALANCE = json.loads((ROOT / 'config/magic_law_balance.json').read_text())


def body(text, path):
    return text.split(path, 1)[1].split('\n/', 1)[0]


class RepositoryWards(unittest.TestCase):
    def test_built(self):
        dme = (ROOT / 'civ13.dme').read_text()
        self.assertIn('#include "code\\modules\\divine\\repository_wards.dm"', dme)

    def test_interface_for_the_law_plan(self):
        for proc in ('/proc/ward_reach(obj/repo)', '/proc/ward_covers(obj/repo, turf/T)', '/proc/wards_at(turf/T)'):
            self.assertIn(proc, WARDS)
        self.assertIn('ward_covers(O, T)', body(WARDS, '/proc/wards_at('))

    def test_each_tier_covers_its_own_area(self):
        covers = body(WARDS, '/proc/ward_covers(')
        self.assertIn('repo.magic_repo_dormant()', covers)
        self.assertIn('map.land_plot_at(T)', covers)
        self.assertIn('province_near_faction_seat(repo.magic_repo_faction, T)', covers)
        self.assertIn('magic_repo_province_at(T) == c', covers)
        # National reach: provinces its nation holds where it keeps a provincial repository.
        self.assertIn('province_holder_of(c) != repo.magic_repo_group', covers)
        self.assertIn('magic_repo_group_keeps_province(repo.magic_repo_group, c)', covers)
        self.assertEqual(BALANCE['reach']['warning_fraction'], 0.25)

    def test_low_warning_fires_once_on_the_way_down(self):
        drain = body(REPO, '/proc/ward_drain(')
        self.assertLess(drain.index('var/before = repo.magic_repo_charge'), drain.index('ward_low_warning(repo, before)'))
        warn = body(WARDS, '/proc/ward_low_warning(')
        self.assertIn('if (before < line || repo.magic_repo_charge >= line)', warn)
        self.assertIn('repo.magic_repo_is_keeper(H)', warn)

    def test_who_can_move_one(self):
        self.assertIn('magic_repo_move_refused(user)', body(ITEMS, '/obj/item/attack_hand('))
        self.assertIn('I.magic_repo_move_refused(src)', body(MOB, '/mob/proc/start_pulling('))
        self.assertIn('magic_repo_unfasten_refused(user)', body(TOOLS, '/obj/proc/toggle_anchor('))
        self.assertIn('magic_repo_unfasten_refused(user)', body(TOOLS, '/obj/proc/timed_toggle_anchor('))
        refused = body(WARDS, '/obj/proc/magic_repo_move_refused(')
        self.assertIn('magic_repo_tier < 2', refused)
        self.assertIn('magic_repo_tier < 3 && istype(H) && magic_repo_is_keeper(H)', refused)
        self.assertIn('magic_repo_tier < 3', body(WARDS, '/obj/proc/magic_repo_unfasten_refused('))

    def test_stays_ordinary_to_everyone_else(self):
        for forbidden in ('.name =', '.desc =', '.icon_state =', '.icon ='):
            self.assertNotIn(forbidden, WARDS)


if __name__ == '__main__':
    unittest.main()
