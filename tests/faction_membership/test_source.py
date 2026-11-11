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

    def test_shared_record_keeps_identity_and_legacy_fallback(self):
        source = run.read(run.MEMBERSHIP)
        record = run.proc_text(source, '/obj/map_metadata/proc/faction_leader_record(')
        self.assertIn('islist(civ_data) && civ_data.len >= 4', record)
        leader = run.proc_text(run.read(run.RESEARCH), '/obj/map_metadata/proc/is_faction_leader(')
        self.assertIn('faction_leader_record(faction)', leader)
        self.assertIn('return civ_data[4] == H', leader)
        self.assertIn('return H.leader', leader)

    def test_death_and_leaving_share_exact_identity_cleanup(self):
        source = run.read(run.MEMBERSHIP)
        clear = run.proc_text(source, '/obj/map_metadata/proc/clear_faction_leader(')
        self.assertIn('civ_data[4] != H', clear)
        self.assertNotIn('real_name', clear)
        death = run.proc_text((ROOT / 'code/modules/1713/battlereport_variables.dm').read_text(), '/mob/living/human/death()')
        leaving = run.proc_text(run.read(run.FACTIONS), '/mob/living/human/proc/faction_leaving_proc()')
        for body in (death, leaving):
            self.assertIn('map.clear_faction_leader(src, civilization)', body)
            self.assertNotIn('real_name', body)
        self.assertIn('original_job_title == "Nomad"', death)

    def test_transition_rechecks_before_any_write_without_yielding(self):
        change = run.proc_text(run.read(run.MEMBERSHIP), '/obj/map_metadata/proc/change_faction_leader(')
        before = change.split('civ_data[4] = next')[0]
        for rule in ('civ_data[4] != previous', 'next.civilization != faction', 'next.stat == DEAD',
                     'next == previous', 'previous.stat == DEAD', 'is_faction_leader(previous, faction)'):
            self.assertIn(rule, before)
        for action in ('next.leader = TRUE', 'previous.leader = FALSE', 'next.grant_faction_symbol_editor()', 'previous.remove_faction_symbol_editor()'):
            self.assertIn(action, change)
        self.assertNotIn('WWinput', change)
        self.assertNotIn('sleep(', change)
        self.assertNotIn('clear_faction_privileges()', change)

    def test_modal_flows_revalidate_and_claim_uses_same_transition(self):
        factions = run.read(run.FACTIONS)
        transfer = run.proc_text(factions, '/mob/living/human/proc/transfer_faction()')
        after = transfer.split('WWinput(', 1)[1]
        for rule in ('!istype(choice)', 'choice in closemobs', 'map != faction_map', 'choice in range(4, loc)',
                     'change_faction_leader(faction, src, choice)'):
            self.assertIn(rule, after)
        self.assertNotIn('real_name', transfer)
        abandon = run.proc_text(factions, '/mob/living/human/proc/abandon_faction()')
        self.assertIn('confirmation != "Leave" || U.civilization != faction', abandon)
        claim = run.proc_text(factions, '/mob/living/human/proc/become_leader()')
        self.assertIn('map.change_faction_leader(U.civilization, null, U)', claim)

    def test_native_probe_covers_identity_and_stale_dialog_cases(self):
        probe = (ROOT / 'tests/faction_membership/probe.dm').read_text()
        for label in ('duplicate name is not the leader', 'same-name departure preserves leader',
                      'self-transfer cannot demote the leader', 'cancel is not a successor',
                      'leader changing during prompt invalidates transfer',
                      'restored reference wins over stale false flag', 'legacy no-record leader fallback preserved'):
            self.assertIn(label, probe)


if __name__ == '__main__':
    unittest.main()
