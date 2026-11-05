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


def section(text, start, end):
    return text.split(start, 1)[1].split(end, 1)[0]


class LanguageLearning(unittest.TestCase):
    def test_exposure_check_compares_by_type(self):
        learn = section(HEAR, 'if (language && ishuman(src))', '/mob/proc/on_hear_say(')
        self.assertIn('H.knows_language(language)', learn)
        self.assertNotIn('languages.Find(language)', learn)

    def test_message_only_when_language_was_added(self):
        learn = section(HEAR, 'if (language && ishuman(src))', '/mob/proc/on_hear_say(')
        add = learn.index('H.add_language(')
        self.assertLess(add, learn.index('from hearing it so much'))
        self.assertIn('&& H.add_language(', learn)

    def test_knows_language_matches_copies(self):
        body = section(LANG, '/mob/proc/knows_language(', '/mob/proc/canonicalize_languages()')
        self.assertIn('canonical_language(L)', body)
        self.assertIn('known.type == L.type', body)

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
