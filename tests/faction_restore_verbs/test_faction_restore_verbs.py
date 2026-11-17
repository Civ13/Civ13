"""Restored (persistent-save) humans regain the map-wide faction role verbs."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/game/mob/groups/factions.dm').read_text()
PERSIST = (ROOT / 'code/modules/persistence/functions.dm').read_text()
MEMBERSHIP = (ROOT / 'code/game/mob/groups/faction_membership.dm').read_text()


class FactionRestoreVerbs(unittest.TestCase):
    def test_verbs_are_not_saved(self):
        # The premise of the restore hook: the serializer skips verbs.
        self.assertIn('key != "verbs"', PERSIST)

    def test_after_load_regrants_role_verbs(self):
        hook = SOURCE.split('/mob/living/human/after_load()', 1)[1].split('/mob/living/human/proc/restore_role_verbs()', 1)[0]
        self.assertIn('. = ..()', hook)
        self.assertIn('restore_role_verbs()', hook)
        body = SOURCE.split('/mob/living/human/proc/restore_role_verbs()', 1)[1].split('/mob/New()', 1)[0]
        self.assertIn('if (!map)', body)
        self.assertLess(body.index('map.nomads'), body.index('make_nomad()'))
        self.assertLess(body.index('map.civilizations'), body.index('make_nation()'))

    def test_make_nomad_grants_create_faction(self):
        nomad = SOURCE.split('/mob/living/human/proc/make_nomad()', 1)[1].split('/mob/living/human/proc/make_nation()', 1)[0]
        self.assertIn('verbs += /mob/living/human/proc/create_faction', nomad)

    def test_restore_regrants_officer_verbs(self):
        # Leaders and permission holders lost the Officer tab after a save
        # and load or an arrival from another region, because only the
        # map-wide verbs were re-granted.
        body = SOURCE.split('/mob/living/human/proc/restore_role_verbs()', 1)[1].split('/mob/New()', 1)[0]
        self.assertIn('restore_faction_privilege_verbs()', body)
        proc = MEMBERSHIP.split('/mob/living/human/proc/restore_faction_privilege_verbs()', 1)[1].split('\n// ', 1)[0]
        self.assertIn('civilization == "none"', proc)
        self.assertIn('map.is_faction_leader(src, civilization)', proc)
        self.assertIn('grant_faction_symbol_editor()', proc)
        self.assertIn('faction_perms[2] == 1', proc)
        self.assertIn('make_commander()', proc)
        self.assertIn('faction_perms[3] == 1', proc)
        self.assertIn('make_title_changer()', proc)
        self.assertLess(proc.index('faction_perms[2]'), proc.index('make_commander()'))
        self.assertLess(proc.index('faction_perms[3]'), proc.index('make_title_changer()'))


if __name__ == '__main__':
    unittest.main()
