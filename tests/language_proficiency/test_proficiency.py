"""Language proficiency: pacing numbers and the source boundaries that keep
learning slow, capped and shared by hearing, speaking and study. Offline only."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text()


DEFINES = dict(re.findall(r'#define (LANGUAGE_\w+) ([\d.]+)', read('code/__defines/species_languages.dm')))
D = {k: float(v) for k, v in DEFINES.items()}
PROF = read('code/game/mob/language/proficiency.dm')


def proc(source, name):
    body = source[source.index(name):]
    nxt = re.search(r'\n(?=/|#|// [A-Z])', body[len(name):])
    return body[:len(name) + nxt.start()] if nxt else body


class Pacing(unittest.TestCase):
    def test_levels_are_ordered(self):
        self.assertTrue(1 < D['LANGUAGE_BROKEN'] < D['LANGUAGE_CONVERSATIONAL'] < D['LANGUAGE_FLUENT'] <= 100)

    def test_hearing_takes_about_ten_hours_to_converse(self):
        per_hour = D['LANGUAGE_HEAR_GAIN'] * 36000 / D['LANGUAGE_LEARN_COOLDOWN']
        hours = D['LANGUAGE_CONVERSATIONAL'] / per_hour
        self.assertTrue(8 <= hours <= 12, hours)

    def test_practice_beats_listening_and_the_daily_cap_spreads_it_out(self):
        self.assertGreater(D['LANGUAGE_PRACTICE_GAIN'], D['LANGUAGE_HEAR_GAIN'])
        days = D['LANGUAGE_CONVERSATIONAL'] / D['LANGUAGE_DAILY_CAP']
        self.assertTrue(3 <= days <= 10, days)


class Rules(unittest.TestCase):
    def test_a_given_language_is_fluent_and_a_learned_one_keeps_its_score(self):
        add = proc(read('code/game/mob/language/language.dm'), '/mob/proc/add_language(')
        self.assertIn('var/fluent = TRUE', add)
        self.assertIn('H.partial_languages[new_language.name] = new_language.difficulty', add)
        self.assertIn('own_share = H.language_score(new_language) / 100', add)
        score = proc(PROF, '/mob/living/human/language_score(')
        self.assertIn('score < LANGUAGE_BROKEN - 1 && knows_language(L)', score)

    def test_gain_respects_ceiling_cap_and_unlocks_speech_at_broken(self):
        gain = proc(PROF, '/mob/living/human/proc/gain_language(')
        self.assertLess(gain.index('if (score >= ceiling)'), gain.index('partial_languages[L.name] ='))
        self.assertIn('LANGUAGE_DAILY_CAP - language_gain_today[L.name]', gain)
        self.assertIn('round(world.realtime / 864000)', gain)
        self.assertIn('amount = min(amount, ceiling - score)', gain)
        self.assertIn('if (new_score >= LANGUAGE_BROKEN && !knows_language(L))', gain)
        self.assertIn('add_language(L.name, FALSE, FALSE)', gain)
        self.assertIn('INNATE | NONVERBAL | SIGNLANG | HIVEMIND | NONGLOBAL', PROF)

    def test_hearing_only_learns_from_better_speakers_and_is_rate_limited(self):
        heard = proc(PROF, '/mob/living/human/proc/language_exposure(')
        self.assertIn('speaker == src', heard)
        self.assertIn('own >= 100 || theirs <= own || world.time < next_language_learn', heard)
        self.assertIn('next_language_learn = world.time + LANGUAGE_LEARN_COOLDOWN', heard)
        self.assertIn('learner.gain_language(L, LANGUAGE_PRACTICE_GAIN)', heard)
        self.assertIn('own > theirs', heard)
        hear = read('code/game/mob/hear_say.dm')
        self.assertIn('H.language_exposure(language, speaker)', hear)
        self.assertNotIn('partial_languages', hear)
        self.assertIn('"next_language_practice" = list(/mob/living/human)',
                      read('code/modules/persistence/world_time_stamps.dm'))

    def test_understanding_and_speaking_follow_the_score(self):
        understands = proc(read('code/game/mob/say.dm'), '/mob/proc/say_understands(')
        self.assertIn('return language_score(L) >= LANGUAGE_FLUENT', understands)
        hear = read('code/game/mob/hear_say.dm')
        self.assertIn('if (speaker != src && !say_understands(speaker,language))', hear)
        self.assertIn('([language.name][accent])', hear)
        say = read('code/game/mob/living/say.dm')
        say = say[say.index('/mob/living/say('):]
        self.assertLess(say.index('garble_own_speech'), say.index('handle_speech_problems'))
        garble = proc(PROF, '/mob/living/human/proc/garble_own_speech(')
        self.assertIn('if (score >= LANGUAGE_FLUENT)\n\t\treturn message', garble)
        self.assertIn('prob(score)', garble)
        scramble = proc(read('code/game/mob/language/language.dm'), '/datum/language/proc/scramble(')
        self.assertIn('prob(H.partial_languages[name] / difficulty * 100)', scramble)

    def test_books_and_writing_stop_at_broken(self):
        book = read('code/modules/1713/language_book.dm')
        self.assertIn('H.gain_language(langtolearn, 100, LANGUAGE_BROKEN, FALSE)', book)
        self.assertNotIn('H.add_language(', book)
        self.assertIn('user.language_score(held) >= LANGUAGE_CONVERSATIONAL', book)
        study = read('code/modules/paperwork/study.dm')
        self.assertIn('H.gain_language(L, points * 100 / L.difficulty, LANGUAGE_BROKEN, FALSE)', study)
        self.assertNotIn('add_language(', study)

    def test_reader_shows_levels_and_languages_in_progress(self):
        language = read('code/game/mob/language/language.dm')
        data = proc(language, '/mob/proc/known_languages_ui_data()')
        self.assertIn('[language_standing(L)][html_encode(L.desc)]', data)
        self.assertIn('entries += languages_being_learned()', data)
        learning = proc(language, '/mob/living/human/languages_being_learned()')
        self.assertIn('knows_language(L)', learning)
        self.assertIn('html_encode(L.name)', learning)


if __name__ == '__main__':
    unittest.main()
