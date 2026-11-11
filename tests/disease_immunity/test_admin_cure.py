"""Source checks for the admin Cure Disease and Cure All Diseases verbs.

During a cholera outbreak the only tool was Rejuvenate, one player at a
time, which also fully heals and revives bodies. The cure verbs clear only
the illness, include bodies that died sick, and never revive anyone.
"""
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


class AdminCure(unittest.TestCase):
    def setUp(self):
        self.verbs = read("code/modules/admin/verbs/random_verbs.dm")

    def body(self, header):
        return self.verbs.split(header, 1)[1].split("\n/", 1)[0]

    def test_cure_clears_illness_without_reviving(self):
        cure = self.body("/mob/living/human/proc/admin_cure_disease()")
        self.assertIn("clear_disease()", cure)
        for forbidden in ("revive(", "rejuvenate", "stat = CONSCIOUS"):
            self.assertNotIn(forbidden, cure)

    def test_single_and_all_verbs_are_registered_and_guarded(self):
        lists = read("code/modules/admin/admin_verbs.dm")
        rejuv = lists.split("var/list/admin_verbs_rejuv = list(", 1)[1].split(")", 1)[0]
        for verb in ("cmd_admin_cure_disease", "cmd_admin_cure_all_diseases"):
            self.assertIn(f"/client/proc/{verb}", rejuv)
            body = self.body(f"/client/proc/{verb}(")
            self.assertIn("check_rights(R_REJUVINATE)", body)
            self.assertIn("admin_cure_disease()", body)
            self.assertIn("log_and_message_admins(", body)
        everyone = self.body("/client/proc/cmd_admin_cure_all_diseases()")
        self.assertIn("for (var/mob/living/human/H in human_mob_list)", everyone)
        self.assertIn('"Yes"', everyone)  # confirmation before a world-wide change


if __name__ == "__main__":
    unittest.main()
