"""Source checks for the read-only Check Illnesses admin verb.

Admins had no way to see who was ill without opening View Variables on each
player, and the agent `players` read returned no illness at all. Both now use
one summary proc that only reads the illness variables.
"""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


class CheckIllnesses(unittest.TestCase):
    def setUp(self):
        self.verbs = read("code/modules/admin/verbs/random_verbs.dm")

    def body(self, text, header):
        return text.split(header, 1)[1].split("\n/", 1)[0]

    def test_summary_only_reads(self):
        summary = self.body(self.verbs, "/mob/living/human/proc/illness_summary()")
        for field in ('"type"', '"severe"', '"stage"', '"progression"', '"course"', '"treated"', '"resistance"'):
            self.assertIn(field, summary)
        self.assertIn("is_severe_disease()", summary)
        self.assertIn("disease_resistance_to(disease_type)", summary)
        # No assignment to any illness variable: the summary must not change state.
        self.assertIsNone(re.search(r"^\s*disease\w*\s*[-+*/]?=", summary, re.M))
        self.assertNotIn("clear_disease(", summary)

    def test_verb_is_admin_guarded_registered_and_read_only(self):
        verb = self.body(self.verbs, "/client/proc/cmd_admin_check_illnesses()")
        self.assertIn('set name = "Check Illnesses"', verb)
        self.assertIn("check_rights(R_ADMIN)", verb)
        self.assertIn("for (var/mob/living/human/H in human_mob_list)", verb)
        self.assertIn("H.illness_summary()", verb)
        self.assertIn("html_encode(H.real_name)", verb)
        for forbidden in ("admin_cure_disease(", "clear_disease(", "disease_type =", "disease ="):
            self.assertNotIn(forbidden, verb)
        lists = read("code/modules/admin/admin_verbs.dm")
        admin = lists.split("var/list/admin_verbs_admin = list(", 1)[1].split("\n\t)", 1)[0]
        self.assertIn("/client/proc/cmd_admin_check_illnesses", admin)

    def test_agent_players_reports_illness(self):
        actions = read("code/modules/agent_control/agent_actions.dm")
        players = self.body(actions, "/datum/agent_control/proc/act_players(")
        self.assertIn("H.illness_summary()", players)
        self.assertIn('row["illness"]', players)


if __name__ == "__main__":
    unittest.main()
