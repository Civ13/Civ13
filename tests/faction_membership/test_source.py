"""Offline checks for faction membership and recruitment authority (#4237)."""
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import run  # noqa: E402

ROOT = run.ROOT
GIVE = (ROOT / 'code/game/mob/living/carbon/give.dm').read_text(encoding='utf-8').replace('\r\n', '\n')
MARKET = (ROOT / 'code/modules/1713/marketplace.dm').read_text(encoding='utf-8')
DME = (ROOT / 'civ13.dme').read_text(encoding='utf-8')


def block(source, start, end):
    return source.split(start, 1)[1].split(end, 1)[0]


RECRUIT = block(GIVE, '/mob/living/human/verb/recruit()', '/mob/living/human/verb/faction_perms()')
PERMS = GIVE.split('/mob/living/human/verb/faction_perms()', 1)[1]


class FactionMembershipSource(unittest.TestCase):
    def test_controls_and_extracted_procs_are_unique(self):
        for control in (None, *run.CONTROLS):
            for path in (run.MEMBERSHIP, run.FACTIONS, run.RESEARCH):
                run.read(path, control)
        self.assertIn('clear_faction_privileges()', run.proc_text(run.read(run.FACTIONS), '/mob/living/human/proc/faction_leaving_proc()'))
        self.assertIn('#include "code\\game\\mob\\groups\\faction_membership.dm"', DME)

    def test_recruitment_permission_never_grants_leadership(self):
        self.assertNotIn('leader = 1', GIVE)
        self.assertNotIn('leader = TRUE', GIVE)
        self.assertNotIn('user.leader', GIVE)

    def test_recruit_uses_shared_helpers_and_rechecks_after_prompt(self):
        self.assertIn('map.can_recruit_for_faction(user, faction)', RECRUIT)
        prompt = RECRUIT.index('WWinput(')
        after = RECRUIT[prompt:]
        self.assertIn('map.can_recruit_for_faction(user, faction)', after)
        self.assertIn('get_dist(user, src) > 1', after)
        self.assertIn('enroll_in_faction(faction, TRUE)', after)
        self.assertNotIn('civilization = ', RECRUIT)
        self.assertNotIn('spawn(', RECRUIT)

    def test_permissions_are_leader_only_and_rechecked(self):
        self.assertIn('map.can_manage_faction_permissions(user, faction)', PERMS)
        self.assertIn('if (civilization != faction)', PERMS)
        self.assertIn('if (map.is_faction_leader(src, faction) && !map.is_faction_leader(user, faction))', PERMS)
        after = PERMS[PERMS.rindex('WWinput('):]
        self.assertIn('map.can_manage_faction_permissions(user, faction, index)', after)
        self.assertIn('map.can_manage_faction_permissions(user, faction, i)', PERMS)
        self.assertIn('if (civilization != faction)', after)

    def test_treasury_uses_the_stored_leader(self):
        self.assertNotIn('H.leader', MARKET)
        self.assertNotIn('user.leader', MARKET)
        self.assertEqual(MARKET.count('map.is_faction_leader(H, H.civilization)'), 2)


if __name__ == '__main__':
    unittest.main()
