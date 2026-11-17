"""Source contracts for the new-player tutorial. Never launches BYOND."""
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import run  # noqa: E402

TUTORIAL = 'code/modules/client/player_tutorial.dm'


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


class PlayerTutorialSourceTests(unittest.TestCase):
    def test_included_once_before_preferences(self):
        dme = read('civ13.dme')
        line = '#include "code\\modules\\client\\player_tutorial.dm"'
        self.assertEqual(dme.count(line), 1)
        # preferences.dm uses the TUTORIAL_ state defines.
        self.assertLess(dme.index(line), dme.index('#include "code\\modules\\client\\preferencesSQLite\\preferences.dm"'))

    def test_progress_is_saved_in_preferences(self):
        saving = read('code/modules/client/preferencesSQLite/preferences_saving&loading&del.dm')
        self.assertIn('"tutorial_state", "tutorial_done"', saving)
        prefs = read('code/modules/client/preferencesSQLite/preferences.dm')
        new_player = prefs[prefs.index('if (preferences_exist(charprefs))'):prefs.index('/datum/preferences/Del()')]
        self.assertIn('tutorial_state = TUTORIAL_ACTIVE', new_player)

    def test_step_ids_are_safe_pref_values(self):
        source = read(TUTORIAL)
        ids = source[source.index('/proc/tutorial_step_ids()'):].split('\n')[1]
        for bad in '&=|;{}':
            self.assertNotIn(bad, ids.replace('list(', '').replace(')', ''))

    def test_reset_is_offered_in_menu_and_settings(self):
        self.assertIn('owner.tutorial_menu()', read('code/modules/client/escape_menu.dm'))
        settings = read('code/modules/client/preferencesSQLite/character_setup_ui.dm')
        self.assertIn('if ("reset_tutorial")', settings)
        self.assertIn('action="reset_tutorial"', read('tgui/src/interfaces/CharacterSetup.tsx'))
        self.assertIn('user.client.reset_tutorial()', settings)
        self.assertIn('"Reset tutorial progress"', read(TUTORIAL))

    def test_event_hooks(self):
        self.assertIn('client.tutorial_event("atlas")', read('code/game/mob/crafting_atlas.dm'))
        self.assertIn('tutorial_event("help")', read('code/game/mob/player_help.dm'))
        self.assertEqual(read('code/modules/research_tree/book_research.dm').count('tutorial_event_for('), 2)

    def test_survival_steps_are_hooked_where_the_player_does_them(self):
        self.assertIn('tutorial_event_for(user, "branch")', read('code/game/objects/structures/wild.dm'))
        # animal_harvest.dm is pinned by the atlas tanning contracts, so twine is seen by what the body carries.
        self.assertIn('locate(/obj/item/stack/crude_twine) in body', read(TUTORIAL))
        self.assertIn('tutorial_event_for(user, "whittle")', read('code/game/objects/items/weapons/material/ooga_booga_weapons.dm'))
        source = read(TUTORIAL)
        self.assertIn('return map && (map.civilizations || map.nomads)', source)

    def test_practice_body_is_skipped(self):
        source = read(TUTORIAL)
        login = source[source.index('/client/proc/tutorial_login('):]
        self.assertIn('istype(H, /mob/living/human/practice)', login.split('\n')[1])

    def test_public_text_is_generic(self):
        self.assertNotIn('persistence', read(TUTORIAL).lower().replace('persistence_', ''))

    def test_fixture_prepares(self):
        generated = run.sources()
        self.assertIn('#include "tests/player_tutorial/probe.dm"', generated['.player_tutorial_ci.dme'])


if __name__ == '__main__':
    unittest.main()
