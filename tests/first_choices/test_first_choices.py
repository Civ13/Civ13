#!/usr/bin/env python3
"""Offline source contracts for the first-join choices and bottom hover text."""
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8', errors='replace').replace('\r\n', '\n')


CHOICES = read('code/modules/client/first_choices.dm')
HOVER = read('code/_onclick/hud/hover_name_bottom.dm')
LAYOUT = read('code/_onclick/hud/hud_layout.dm')
SAVING = read('code/modules/client/preferencesSQLite/preferences_saving&loading&del.dm')


class FirstChoices(unittest.TestCase):
    def test_the_file_is_compiled_into_the_game(self):
        self.assertEqual(read('civ13.dme').count('client\\first_choices.dm"'), 1)

    def test_the_choices_come_before_the_tutorial(self):
        tutorial = read('code/modules/client/player_tutorial.dm')
        login = tutorial[tutorial.index('/mob/living/human/Login()'):tutorial.index('/client/proc/tutorial_login')]
        self.assertIn('client.first_choices_login(src)', login)
        self.assertNotIn('client.tutorial_login(src)', login)
        body = CHOICES[CHOICES.index('/client/proc/first_choices_login'):CHOICES.index('/client/proc/ask_first_choices')]
        self.assertLess(body.index('ask_first_choices()'), body.index('tutorial_login(mob)'))
        self.assertIn('set waitfor = FALSE', body)

    def test_asked_once_per_account_and_never_in_practice(self):
        self.assertIn('"first_choices_done"', SAVING)
        self.assertIn('"hover_text_bottom"', SAVING)
        self.assertIn('!prefs.first_choices_done', CHOICES)
        self.assertIn('/mob/living/human/practice', CHOICES)
        self.assertIn('prefs.first_choices_done = TRUE', CHOICES)

    def test_every_question_can_be_cancelled(self):
        ask = CHOICES[CHOICES.index('/client/proc/ask_first_choices'):]
        self.assertEqual(ask.count('player_input('), 3)
        self.assertEqual(ask.count(', TRUE)\n'), 3)

    def test_bottom_hover_text_is_a_saved_option(self):
        self.assertEqual(read('civ13.dme').count('hud\\hover_name_bottom.dm"'), 1)
        follow = HOVER[HOVER.index('/obj/screen/hover_name/follow_pointer()'):]
        self.assertIn('!C.prefs.hover_text_bottom', follow)
        self.assertIn('return ..()', follow)
        self.assertIn('hover_name_bottom_loc(size[1] * 32, hover_text_width)', follow)
        self.assertIn('set name = "Hover Text Position"', LAYOUT)
        setup = read('code/modules/client/preferencesSQLite/character_setup_ui.dm')
        self.assertIn('settings["hover_text"] = hover_text_enabled ? (hover_text_bottom ? 2 : 1) : 0', setup)
        self.assertIn("[2, 'Bottom of screen']", read('tgui/src/interfaces/CharacterSetup.tsx'))


if __name__ == '__main__':
    unittest.main()
