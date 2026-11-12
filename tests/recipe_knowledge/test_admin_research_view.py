"""Source checks for the read-only admin research knowledge view.

Admins had no way to see which research a character knows under book research
without View Variables. Special > Check Research Knowledge lists everyone
(including sleeping offline bodies) with the reverse who-knows-what view,
right-click Show Research Knowledge shows one character, and the agent
`players` read reports the same summary. None of them may change knowledge.
"""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCE = 'code/modules/admin/verbs/research_knowledge.dm'


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


def body(text, header):
    return text.split(header, 1)[1].split('\n/', 1)[0]


class AdminResearchView(unittest.TestCase):
    def setUp(self):
        self.source = read(SOURCE)

    def test_included(self):
        self.assertIn('#include "code\\modules\\admin\\verbs\\research_knowledge.dm"', read('civ13.dme'))

    def test_never_writes_knowledge(self):
        for name in ('known_recipe_nodes', 'study_progress', 'recipe_knowledge_initialized'):
            self.assertIsNone(re.search(r'\b' + name + r'\s*([-+|&]?=|\+\+|--)(?!=)', self.source), name)
        for call in ('learn_recipe_node(', 'forget_recipe_knowledge(', 'note_study_progress(', 'clear_study_progress('):
            self.assertNotIn(call, self.source)

    def test_verbs_are_admin_guarded_and_registered(self):
        lists = read('code/modules/admin/admin_verbs.dm')
        admin = lists.split('var/list/admin_verbs_admin = list(', 1)[1].split('\n\t)', 1)[0]
        for proc, name in (('cmd_admin_check_research', 'Check Research Knowledge'),
                           ('cmd_admin_show_research', 'Show Research Knowledge')):
            verb = body(self.source, '/client/proc/' + proc + '(')
            self.assertIn('set name = "%s"' % name, verb)
            self.assertIn('check_rights(R_ADMIN)', verb)
            self.assertIn('research_knowledge_summary()', verb)
            self.assertIn('html_encode(H.real_name)', verb)
            self.assertIn('/client/proc/' + proc, admin)

    def test_offline_bodies_and_reverse_view(self):
        verb = body(self.source, '/client/proc/cmd_admin_check_research(')
        self.assertIn('for (var/mob/living/human/H in human_mob_list)', verb)
        self.assertIn('By research', verb)
        account = body(self.source, '/mob/living/human/proc/research_knowledge_account(')
        self.assertIn('persistence_owner_ckey', account)

    def test_agent_players_reports_research(self):
        actions = read('code/modules/agent_control/agent_actions.dm')
        players = body(actions, '/datum/agent_control/proc/act_players(')
        self.assertIn('H.research_knowledge_summary()', players)
        self.assertIn('row["research"]', players)


if __name__ == '__main__':
    unittest.main()
