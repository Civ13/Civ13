"""Hearing a language you already know never re-teaches it.

A restored speaker's language datum is a saved copy, so reference checks
against the listener's shared language entries fail and the listener was told
"You've learned how to speak X" after every line.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
HEAR = (ROOT / 'code/game/mob/hear_say.dm').read_text()
LANG = (ROOT / 'code/game/mob/language/language.dm').read_text()
PROF = (ROOT / 'code/game/mob/language/proficiency.dm').read_text()


def section(text, start, end):
    return text.split(start, 1)[1].split(end, 1)[0]


class LanguageLearning(unittest.TestCase):
    # Learning by ear moved to proficiency.dm; the restored-copy rules still
    # hold: scores and unlocks go through the shared language, never a copy.
    def test_exposure_check_compares_by_type(self):
        learn = section(HEAR, '// Hearing a language slowly teaches it', '/mob/proc/on_hear_say(')
        self.assertIn('H.language_exposure(language, speaker)', learn)
        self.assertNotIn('languages.Find(language)', learn)
        score = section(PROF, '/mob/living/human/language_score(', '/proc/language_level_name(')
        self.assertLess(score.index('L = canonical_language(L)'), score.index('partial_languages[L.name]'))
        self.assertIn('knows_language(L)', score)

    def test_message_only_when_language_was_added(self):
        gain = section(PROF, '/mob/living/human/proc/gain_language(', '// Heard speech')
        self.assertLess(gain.index('L = canonical_language(L)'), gain.index('partial_languages[L.name] ='))
        self.assertIn('!knows_language(L)', gain)
        self.assertLess(gain.index('if (add_language(L.name, FALSE, FALSE))'), gain.index('add_note("Known Languages", L.name)'))

    def test_knows_language_matches_copies(self):
        body = section(LANG, '/mob/proc/knows_language(', '/mob/proc/canonicalize_languages()')
        self.assertIn('canonical_language(L)', body)
        self.assertIn('language_same(known, L)', body)
        same = section((ROOT / 'code/game/mob/language/daughter.dm').read_text(), '/proc/language_same(', '/proc/language_kinship(')
        self.assertIn('return A.type == B.type', same)

    def test_add_language_rejects_known_copies(self):
        body = section(LANG, '/mob/proc/add_language(', '/mob/proc/remove_language(')
        self.assertIn('new_language = canonical_language(new_language)', body)
        self.assertIn('knows_language(new_language)', body)

    def test_restore_canonicalizes_languages(self):
        hook = section(LANG, '/mob/after_load()', '// Can we speak this language')
        self.assertIn('. = ..()', hook)
        self.assertIn('canonicalize_languages()', hook)
        body = section(LANG, '/mob/proc/canonicalize_languages()', '/mob/after_load()')
        self.assertIn('!(shared in fixed)', body)
        self.assertIn('default_language = canonical_language(', body)

    def test_can_speak_uses_type_match(self):
        body = section(LANG, '/mob/proc/can_speak(', '/mob/proc/get_language_prefix()')
        self.assertIn('knows_language(speaking)', body)


if __name__ == '__main__':
    unittest.main()
