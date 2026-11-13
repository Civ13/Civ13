"""Source checks for the admin research restore verb.

A revive used to leave a character without the research and scholarship they
had before dying. Admin > Restore Research Knowledge gives it back from a
record (for example the last save); it must be admin-only, registered, logged
and only ever add. Behaviour is covered by tests/resuscitation/probe.dm.
"""
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCE = 'code/modules/admin/verbs/research_restore.dm'


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


class AdminResearchRestore(unittest.TestCase):
    def test_included_and_registered(self):
        self.assertIn('#include "code\\modules\\admin\\verbs\\research_restore.dm"', read('civ13.dme'))
        lists = read('code/modules/admin/admin_verbs.dm')
        admin = lists.split('var/list/admin_verbs_admin = list(', 1)[1].split('\n\t)', 1)[0]
        self.assertIn('/client/proc/cmd_admin_restore_research', admin)

    def test_admin_only_and_logged(self):
        verb = read(SOURCE).split('/client/proc/cmd_admin_restore_research(', 1)[1]
        self.assertIn('set name = "Restore Research Knowledge"', verb)
        self.assertIn('check_rights(R_ADMIN)', verb)
        self.assertIn('log_admin(', verb)
        self.assertIn('message_admins(', verb)

    def test_only_adds(self):
        helper = read(SOURCE).split('/mob/living/human/proc/admin_restore_research(', 1)[1].split('\n/', 1)[0]
        self.assertIn('clean_recipe_node_ids(record["known"])', helper)
        self.assertIn('clean_scholarship(record["scholarship"])', helper)
        self.assertIn('> scholar_level(discipline)', helper)
        self.assertNotIn('forget_recipe_knowledge(', helper)


if __name__ == '__main__':
    unittest.main()
