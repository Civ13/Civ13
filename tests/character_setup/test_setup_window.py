"""Offline source contracts for the character setup window. Not DM execution."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SETUP = (ROOT / 'code/modules/client/preferencesSQLite/character_setup_ui.dm').read_text()
CATALOG = (ROOT / 'code/game/mob/living/carbon/human/trait_catalog.dm').read_text()
TRAITS = (ROOT / 'code/game/mob/living/carbon/human/traits.dm').read_text()
SCREEN = (ROOT / 'tgui/src/interfaces/CharacterSetup.tsx').read_text()


def body(signature):
    return SETUP.split(signature + '\n', 1)[1].split('\n/', 1)[0]


class SetupWindow(unittest.TestCase):
    def test_only_the_owner_reaches_the_window(self):
        state = body('/datum/topic_state/character_setup/can_use_topic(var/src_object, var/mob/user)')
        self.assertIn('user.client.prefs != P', state)
        self.assertIn('return STATUS_CLOSE', state)
        act = body('/datum/preferences/ui_act(action, list/params, mob/user, datum/nanoui/ui)')
        owner = act.index('if (!user || !user.client || user.client.prefs != src)\n\t\treturn')
        self.assertLess(owner, act.index('setup_settings_act('))
        # A living character changes settings only.
        self.assertLess(act.index('setup_settings_act('), act.index('if (setup_locked(user))\n\t\treturn'))
        self.assertLess(act.index('if (setup_locked(user))\n\t\treturn'), act.index('switch (action)'))
        self.assertIn('/datum/topic_state/character_setup)', body('/datum/preferences/ui_interact(mob/user, ui_key = "main", datum/nanoui/ui = null, force_open = TRUE)'))

    def test_every_button_is_declared_and_handled(self):
        declared = set(re.findall(r'"(\w+)"', body('/datum/preferences/ui_actions(ui_key)')))
        handled = set()
        for names in re.findall(r'(?m)^\t\tif \(("[^)]+")\)$', SETUP):
            handled.update(re.findall(r'"(\w+)"', names))
        self.assertEqual(declared, handled)
        sent = set(re.findall(r'action="(\w+)"', SCREEN)) | set(re.findall(r"act\('(\w+)'", SCREEN)) | set(re.findall(r"yesNo\('(\w+)'", SCREEN))
        self.assertEqual(sent, declared)

    def test_values_are_checked_against_what_is_offered(self):
        act = body('/datum/preferences/ui_act(action, list/params, mob/user, datum/nanoui/ui)')
        for guard in ('value in valid_bloodtypes', 'value in setup_hair_styles()', 'value in setup_facial_styles()',
                      'value == MALE || value == FEMALE', 'max(min(round(value), S.max_age), S.min_age)',
                      '35 - max(min(round(value), 220), 1)', 'sanitize_name(copytext(value, 1, MAX_NAME_LEN + 1), species)'):
            self.assertIn(guard, act)
        self.assertIn('var/hex = istext(picked) ? named[picked] : null\n\tif (!hex)\n\t\treturn FALSE', SETUP)
        settings = body('/datum/preferences/proc/setup_settings_act(action, value, mob/user)')
        for guard in ('value in all_ui_styles', 'value in cursors', 'value in client_fps_choices()', 'client_pref.may_toggle(user)'):
            self.assertIn(guard, settings)

    def test_catalog_places_every_trait(self):
        names = set(re.findall(r'(?m)^\t"([^"]+)"\s*=\s*list\(-?\d+,', TRAITS))
        ids = re.findall(r'list\("id" = "(\w+)"', CATALOG)
        placed = {}
        for category, members in re.findall(r'(?m)^\t"(\w+)" = list\(([^\n]+)\)', CATALOG.split('trait_category_members', 1)[1]):
            self.assertIn(category, ids)
            for member in re.findall(r'"([^"]+)"', members):
                self.assertNotIn(member, placed, member + ' is listed twice')
                placed[member] = category
        self.assertEqual(ids[-1], 'other')
        self.assertEqual(names - set(placed), set(), 'traits shown under Other')
        self.assertIn('return found ? found : "other"', CATALOG)

    def test_old_page_is_gone(self):
        prefs = (ROOT / 'code/modules/client/preferencesSQLite/preferences.dm').read_text()
        self.assertNotIn('window=preferences', prefs)
        self.assertIn('\tui_interact(user)\n', prefs.split('/datum/preferences/proc/ShowChoices(mob/user)', 1)[1].split('\n/', 1)[0])


if __name__ == '__main__':
    unittest.main()
