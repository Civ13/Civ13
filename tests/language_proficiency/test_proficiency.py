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
        self.assertIn('amount = min(amount, language_day_left(L, daily_cap), ceiling - score)', gain)
        self.assertIn('if (daily_cap == TRUE && score >= LANGUAGE_CONVERSATIONAL)', gain)
        left = proc(PROF, '/mob/living/human/proc/language_day_left(')
        self.assertIn('round(world.realtime / 864000)', left)
        for bucket in ('"lesson:[L.name]"', '"study:[L.name]"'):
            self.assertIn(bucket, left)
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
        self.assertIn('learner.knows_language(speaking) && learner.language_score(speaking) < LANGUAGE_FLUENT', say)
        garble = proc(PROF, '/mob/living/human/proc/garble_own_speech(')
        self.assertIn('if (score >= LANGUAGE_FLUENT)\n\t\treturn message', garble)
        self.assertIn('prob(score)', garble)
        scramble = proc(read('code/game/mob/language/language.dm'), '/datum/language/proc/scramble(')
        self.assertIn('prob(H.partial_languages[name] / difficulty * 100)', scramble)

    def test_books_and_writing_stop_at_broken(self):
        book = read('code/modules/1713/language_book.dm')
        self.assertIn('H.gain_language(langtolearn, LANGUAGE_STUDY_GAIN, LANGUAGE_BROKEN, "study")', book)
        self.assertLess(book.index('H.language_day_left(langtolearn, "study")'), book.index('do_reading(user, 800, src)'))
        self.assertNotIn('H.add_language(', book)
        self.assertIn('user.language_score(held) >= LANGUAGE_CONVERSATIONAL', book)
        study = read('code/modules/paperwork/study.dm')
        self.assertIn('H.gain_language(L, points * 100 / L.difficulty, LANGUAGE_BROKEN, "study")', study)
        self.assertNotIn('add_language(', study)

    def test_reader_shows_levels_and_languages_in_progress(self):
        language = read('code/game/mob/language/language.dm')
        data = proc(language, '/mob/proc/known_languages_ui_data()')
        self.assertIn('[language_standing(L)][html_encode(L.desc)]', data)
        self.assertIn('entries += languages_being_learned()', data)
        learning = proc(language, '/mob/living/human/languages_being_learned()')
        self.assertIn('knows_language(L)', learning)
        self.assertIn('html_encode(L.name)', learning)


class Teaching(unittest.TestCase):
    TEACH = read('code/game/mob/language/teaching.dm')

    def test_lessons_are_the_fast_route_but_still_take_days(self):
        self.assertGreater(D['LANGUAGE_LESSON_GAIN'], 10 * D['LANGUAGE_PRACTICE_GAIN'] - 1e-9)
        best_day = D['LANGUAGE_DAILY_CAP'] + D['LANGUAGE_LESSON_DAILY_CAP']
        self.assertTrue(2 <= D['LANGUAGE_CONVERSATIONAL'] / best_day <= 5)
        # A primer needs several sittings and more than one day to reach Broken.
        self.assertGreaterEqual(D['LANGUAGE_BROKEN'] / D['LANGUAGE_STUDY_GAIN'], 3)
        self.assertGreater(D['LANGUAGE_BROKEN'], D['LANGUAGE_STUDY_DAILY_CAP'])

    def test_only_a_fluent_better_speaker_teaches_a_willing_neighbour(self):
        teachable = proc(self.TEACH, '/mob/living/human/proc/teachable_languages(')
        self.assertIn('language_score(L) < LANGUAGE_FLUENT', teachable)
        self.assertIn('learner.language_score(L) >= language_score(L)', teachable)
        lesson = proc(self.TEACH, '/mob/living/human/proc/give_language_lesson(')
        self.assertLess(lesson.index('learner.language_day_left(L, "lesson")'), lesson.index('WWinput(learner'))
        self.assertLess(lesson.index('if (answer != "Accept")'), lesson.index('do_after(src, LANGUAGE_LESSON_TIME, learner)'))
        self.assertLess(lesson.index('do_after(src, LANGUAGE_LESSON_TIME, learner)'),
                        lesson.index('learner.gain_language(L, LANGUAGE_LESSON_GAIN, 100, "lesson")'))
        self.assertIn('get_turf(learner) != learner_spot', lesson)
        possible = proc(self.TEACH, '/mob/living/human/proc/lesson_still_possible(')
        self.assertIn('get_dist(src, learner) > 1', possible)

    def test_paper_needs_a_real_command_of_the_language(self):
        written = read('code/modules/paperwork/written_languages.dm')
        self.assertIn('actor.can_speak(known) && actor.language_score(known) >= LANGUAGE_CONVERSATIONAL', written)

    def test_related_languages_agree_both_ways(self):
        self.assertIn('symmetrize_language_kinship()', read('code/_helpers/global_lists.dm'))
        kin = proc(PROF, '/proc/symmetrize_language_kinship()')
        self.assertIn('max(L.mutual_intelligibility[other_type], other.mutual_intelligibility[L.type])', kin)
        earth = read('code/game/mob/language/earth.dm')
        for line in earth.splitlines():
            if 'mutual_intelligibility = list(' in line:
                keys = re.findall(r'/datum/language/(\w+)', line)
                self.assertEqual(len(keys), len(set(keys)), line.strip())


if __name__ == '__main__':
    unittest.main()
