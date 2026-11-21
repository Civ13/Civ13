"""Source guards for the magic whitelist (magic_whitelist.dm): only listed players may take part in magic."""
from pathlib import Path
import re
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
LIST = (ROOT / 'code/modules/divine/magic_whitelist.dm').read_text()
VERB = (ROOT / 'code/modules/admin/verbs/magic_whitelist.dm').read_text()
PATRON = (ROOT / 'code/modules/admin/verbs/divine_patron.dm').read_text()
COVENANT = (ROOT / 'code/modules/divine/covenant.dm').read_text()
JOURNAL = (ROOT / 'code/modules/divine/journal.dm').read_text()
STATS = (ROOT / 'code/game/mob/living/carbon/human/human_stats.dm').read_text()
ADMIN_VERBS = (ROOT / 'code/modules/admin/admin_verbs.dm').read_text()
sys.path.insert(0, str(ROOT / 'scripts/shard-group'))


def body(text, path):
    return text.split(path, 1)[1].split('\n/', 1)[0]


class MagicWhitelist(unittest.TestCase):
    def test_built_and_offered_to_staff(self):
        dme = (ROOT / 'civ13.dme').read_text()
        self.assertIn('#include "code\\modules\\divine\\magic_whitelist.dm"', dme)
        self.assertIn('#include "code\\modules\\admin\\verbs\\magic_whitelist.dm"', dme)
        self.assertIn('/client/proc/cmd_admin_magic_whitelist,', ADMIN_VERBS)
        self.assertIn('check_rights(R_ADMIN)', body(VERB, '/client/proc/cmd_admin_magic_whitelist()'))

    def test_one_file_shared_like_admins(self):
        path = body(LIST, '/proc/magic_whitelist_file()')
        self.assertIn('settings["gate"]', path)
        self.assertIn('settings["mainland"]', path)
        self.assertIn('"../[source]/SQL/[MAGIC_WHITELIST_NAME]"', path)
        self.assertIn('#define MAGIC_WHITELIST_NAME "magic_whitelist.txt"', LIST)
        # The group script writes the same header the world does.
        import shard_group
        header = re.search(r'#define MAGIC_WHITELIST_HEADER "(.*)"', LIST).group(1).replace('\\n', '\n')
        self.assertEqual(shard_group.MAGIC_WHITELIST_HEADER, header)

    def test_only_persistent_worlds_are_gated(self):
        self.assertIn('map && map.persistence', body(LIST, '/proc/magic_whitelist_applies()'))
        allowed = body(LIST, '/mob/living/human/proc/magic_allowed()')
        self.assertIn('magic_whitelist_applies()', allowed)
        self.assertIn('magic_whitelisted(magic_key())', allowed)

    def test_every_way_in_checks_the_list(self):
        self.assertIn('magic_allowed()', body(COVENANT, '/mob/living/human/proc/divine_refresh_verbs()'))
        problem = body(COVENANT, '/mob/living/human/proc/divine_problem(')
        self.assertLess(problem.index('magic_allowed()'), problem.index('divine_spells_allowed()'))
        self.assertIn('magic_allowed()', body(JOURNAL, '/mob/living/human/proc/can_read_divine_journal()'))
        self.assertIn('statname == "magic" && !magic_allowed()', body(STATS, '/mob/living/human/proc/setStat('))
        self.assertIn('statname == "magic" && multiplier > 0 && !magic_allowed()', body(STATS, '/mob/living/human/proc/adaptStat('))
        initiate = PATRON.split('if ("Initiate a follower")', 1)[1].split('if ("Teach an invocation"', 1)[0]
        self.assertIn('magic_whitelist_admit(H)', initiate)
        teach = PATRON.split('if ("Teach an invocation", "Take back an invocation")', 1)[1].split('if ("Release a follower")', 1)[0]
        self.assertIn('magic_whitelist_admit(H)', teach)

    def test_players_never_see_the_list(self):
        # Hidden mechanic: the refusal a follower sees stays in the fiction.
        problem = body(COVENANT, '/mob/living/human/proc/divine_problem(')
        self.assertIn('return "No answer comes."', problem)
        self.assertNotIn('whitelist', problem.split('magic_allowed()', 1)[1].split('\n', 2)[1])

    def test_removal_suspends_without_deleting(self):
        revoked = body(LIST, '/mob/living/human/proc/magic_whitelist_revoked()')
        self.assertIn('divine_break_covenant()', revoked)
        self.assertIn('divine_refresh_verbs()', revoked)
        self.assertNotIn('divine_patron = null', revoked)
        self.assertNotIn('divine_known = null', revoked)
        self.assertIn('magic_whitelist_revoked()', body(VERB, '/client/proc/magic_whitelist_change('))


if __name__ == '__main__':
    unittest.main()
