"""Nation governments: source contract checks (docs/nation-government.md).

    python3 tests/nation_government/test_source.py
"""
import re
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from tools.transfer_storage.nations import GOVERNMENTS  # noqa: E402

SOURCE = ROOT / 'code/game/mob/groups/nation_government.dm'


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


def proc_text(text, header):
    start = text.index(header)
    following = re.search(r'\n(?=/)', text[start + len(header):])
    return text[start:start + len(header) + following.start()] if following else text[start:]


class NationGovernmentSource(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = SOURCE.read_text(encoding='utf-8')

    def test_included_after_nation(self):
        self.assertIn('#include "code\\game\\mob\\groups\\nation.dm"\n#include "code\\game\\mob\\groups\\nation_government.dm"',
                      read('civ13.dme'))

    def test_prompt_table_matches_the_coordinator(self):
        rows = {k: (n, int(a), int(b), int(h)) for k, n, a, b, h in
                re.findall(r'"(\w+)" = list\("([^"]+)", (?:"[^"]+"|null), (\d), (\d), (\d+),', self.text)}
        self.assertEqual(set(rows), set(GOVERNMENTS))
        for kind, g in GOVERNMENTS.items():
            self.assertEqual(rows[kind], (g['name'], g['age'], g['bonus'], g['notice'] // 3600), kind)
        types = re.search(r'#define GOVERNMENT_TYPES list\(([^)]*)\)', self.text).group(1)
        self.assertEqual(set(re.findall(r'"(\w+)"', types)), set(GOVERNMENTS))

    def test_heads_need_verified_citizens(self):
        pick = proc_text(self.text, '/mob/living/human/proc/nation_government_pick_head(')
        self.assertIn('account_verified(H.nation_account())', pick)
        self.assertIn('nation_of_id(nation_faction_id(H.civilization)) != nid', pick)
        self.assertIn('H.religious_leader', pick)

    def test_verified_fails_closed(self):
        helper = proc_text(read('code/_helpers/access_lists.dm'), '/proc/account_verified(')
        self.assertIn('verified_access_member("approved"', helper)

    def test_ruler_acts_only_from_a_home_member_faction(self):
        rules = proc_text(self.text, '/mob/living/human/proc/nation_rules(')
        self.assertIn('nation_home_faction(civilization)', rules)
        self.assertIn('G["head_account"] == nation_account()', rules)

    def test_nation_menu_offers_government_and_gates_the_ruler(self):
        menu = proc_text(read('code/game/mob/groups/nation.dm'), '/mob/living/human/proc/nation_menu(')
        self.assertIn('"Government"', menu)
        self.assertIn('if (G["type"] == "confederation")\n\t\t\t\t\tchoices += "Vote for a head"', menu)
        self.assertIn('!(map.is_faction_leader(src, faction) || nation_rules(nid))', menu)
        self.assertIn('nation_government_menu(faction, id, nid)', menu)
        self.assertIn('"Stay"', menu)

    def test_refresh_announces_and_reports_eras(self):
        refresh = proc_text(read('code/game/mob/groups/nation.dm'), '/proc/nations_refresh(')
        self.assertIn('var/list/old_registry = nation_registry', refresh)
        self.assertIn('nation_government_announce(old_registry)', refresh)
        self.assertIn('nation_eras_report()', refresh)
        self.assertIn('nation_census_report()', refresh)
        self.assertIn('nation_succession_report()', refresh)

    def test_agent_passes_the_new_fields(self):
        region = read('tools/transfer_storage/region.py')
        keys = re.search(r"request = \{k: body\[k\] for k in \(([^)]*)\)", region).group(1)
        for key in ('issuer', 'type', 'person', 'pname', 'pfaction', 'religion', 'age', 'role', 'motion', 'choice',
                    'citizens', 'wealth'):
            self.assertIn("'%s'" % key, keys)


    def test_citizens_are_verified_settled_and_active(self):
        eligible = proc_text(self.text, '/proc/nation_citizen_eligible(')
        self.assertIn('account_verified(account)', eligible)
        self.assertIn('row[1] <= world.realtime - CITIZEN_MEMBER_DAYS * 864000', eligible)
        self.assertIn('row[2] >= world.realtime - CITIZEN_SEEN_DAYS * 864000', eligible)
        self.assertIn('#define CITIZEN_MEMBER_DAYS 3', self.text)
        self.assertIn('#define CITIZEN_SEEN_DAYS 7', self.text)

    def test_requests_say_who_speaks(self):
        ask = proc_text(read('code/game/mob/groups/nation.dm'), '/mob/living/human/proc/nation_ask(')
        self.assertIn('body["role"] = map.is_faction_leader(src, faction) || (nid && nation_rules(nid)) ? "leader" : "citizen"', ask)

    def test_ballots_follow_the_body(self):
        menu = proc_text(self.text, '/mob/living/human/proc/nation_motions_menu(')
        self.assertIn('var/can_vote = voters == "leader" ? leader : eligible', menu)
        self.assertIn('"op" = "ballot"', menu)
        self.assertIn('"op" = "stand"', menu)
        propose = proc_text(self.text, '/mob/living/human/proc/nation_may_propose(')
        self.assertIn('G["body"] == "referendum" && nation_eligible()', propose)


    def test_throne_claim_is_held_and_contested(self):
        offer = proc_text(self.text, '/mob/living/human/proc/throne_claim_offer(')
        self.assertIn('account_verified(nation_account())', offer)
        self.assertIn('G["type"] != "monarchy" || istext(G["head_account"])', offer)
        tick = proc_text(self.text, '/proc/throne_claim_tick(')
        self.assertIn('get_dist(claimant, A) > THRONE_CLAIM_RANGE', tick)
        self.assertIn('if (!contested)\n\t\tC[3] += THRONE_CLAIM_STEP', tick)
        self.assertIn('"op" = "claim"', tick)
        self.assertIn('#define THRONE_CLAIM_TIME 18000', self.text)

    def test_head_presence_and_faith_are_reported(self):
        report = proc_text(self.text, '/proc/nation_succession_report(')
        self.assertIn('"op" = "present"', report)
        self.assertIn('H.nation_heads(nid)', report)
        self.assertIn('H.religious_leader && H.religion == G["religion"]', report)
        self.assertIn('account_verified(H.nation_account())', report)


if __name__ == '__main__':
    unittest.main()
