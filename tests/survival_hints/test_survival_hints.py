#!/usr/bin/env python3
"""Offline source contracts for the one-time survival hints."""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8', errors='replace').replace('\r\n', '\n')


HINTS = read('code/modules/client/survival_hints.dm')


class SurvivalHints(unittest.TestCase):
    def test_compiled_once_and_called_from_life(self):
        self.assertEqual(read('civ13.dme').count('client\\survival_hints.dm"'), 1)
        life = read('code/game/mob/living/carbon/human/human_life.dm')
        self.assertEqual(life.count('\thandle_survival_hints()\n'), 1)

    def test_seen_hints_are_saved_with_the_account(self):
        saving = read('code/modules/client/preferencesSQLite/preferences_saving&loading&del.dm')
        self.assertIn('"survival_hints_seen"', saving)
        self.assertIn('P.survival_hints_seen += id\n\tP.save_preferences()', HINTS)

    def test_ids_are_safe_pref_values(self):
        ids = re.findall(r'^\t"(\w+)" = "', HINTS, re.M)
        self.assertEqual(ids, ['cold', 'soaked', 'starving', 'parched', 'pit', 'knocked_down', 'stack'])

    def test_hints_follow_show_tips_and_skip_practice(self):
        handler = HINTS[HINTS.index('/mob/living/human/proc/handle_survival_hints()'):]
        self.assertIn('is_preference_enabled(/datum/client_preference/show_tips)', handler)
        self.assertIn('istype(src, /mob/living/human/practice)', handler)
        # The check must stay cheap: nothing runs once every hint was seen.
        self.assertLess(handler.index('survival_hints_seen.len >= survival_hint_texts.len'), handler.index('survival_hint_due('))

    def test_public_text_is_generic(self):
        lowered = HINTS.lower()
        self.assertNotIn('magic', lowered)
        self.assertNotIn('persistence', lowered)


if __name__ == '__main__':
    unittest.main()
