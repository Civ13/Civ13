"""Restored (persistent-save) humans regain the map-wide faction role verbs."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/game/mob/groups/factions.dm').read_text()
PERSIST = (ROOT / 'code/modules/persistence/functions.dm').read_text()


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


if __name__ == '__main__':
    unittest.main()
