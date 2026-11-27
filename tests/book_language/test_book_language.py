"""Research chapters carry the language they were written in. Source
boundaries for recording, reading, copying (translation), printing and
torn-out chapters. Offline only."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TREE = ROOT / 'code/modules/research_tree'


def read(name):
    return (TREE / name).read_text()


LANG = read('book_language.dm')
RESEARCH = read('book_research.dm')
PAGES = read('book_pages.dm')


def proc(source, name):
    body = source[source.index(name):]
    nxt = re.search(r'\n/(?:obj|proc|mob|datum)', body[len(name):])
    return body[:len(name) + nxt.start()] if nxt else body


class Recording(unittest.TestCase):
    def test_every_new_chapter_records_a_language(self):
        add = proc(RESEARCH, '/obj/item/weapon/book/proc/add_research_chapter(')
        self.assertIn('mob/living/human/writer = null, language = null', add)
        self.assertLess(add.index("research_chapters = jointext(chapters, \";\")"),
                        add.index('record_chapter_language(node_id, writer, language)'))
        record = proc(LANG, '/obj/item/weapon/book/proc/record_chapter_language(')
        self.assertIn('map.book_research_enabled()', record)
        self.assertLess(record.index('if (!istext(language))'), record.index('infer_chapter_writer()'))
        self.assertIn('writer.writing_language()', record)

    def test_researchers_and_writers_are_named_where_known(self):
        work = proc(RESEARCH, '/obj/item/weapon/book/proc/add_research_work(')
        self.assertIn('add_research_chapter(node_id, TRUE, writer)', work)
        self.assertIn(', FALSE, researcher))', RESEARCH)
        self.assertIn('add_research_chapter(node_id, FALSE, H)', PAGES)
        self.assertIn('fuller.add_research_work(node_id, points, FALSE, H)', read('compare_notes.dm'))
        for call in ('B.add_research_work(node_id, points, FALSE, H)', 'finished = B.add_research_work(node_id, points, FALSE, H)'):
            self.assertIn(call, read('subject_prototypes.dm'))
        # Starting books are plain to everyone.
        self.assertIn('B.add_research_chapter(node_id, FALSE, null, "")', read('book_launch.dm'))

    def test_writing_language_needs_a_real_command(self):
        writing = proc(LANG, '/mob/living/human/proc/writing_language()')
        self.assertIn('language_score(chosen) >= LANGUAGE_CONVERSATIONAL', writing)
        self.assertIn('mother_tongue()', writing)

    def test_only_real_languages_are_stored(self):
        setter = proc(LANG, '/obj/item/weapon/book/proc/set_chapter_language(')
        self.assertIn('languages -= node_id', setter)
        self.assertIn('istext(language_name) && all_languages[language_name]', setter)


class Reading(unittest.TestCase):
    def test_study_is_blocked_below_broken_and_slower_below_fluent(self):
        study = proc(RESEARCH, '/proc/study_research_source(')
        self.assertIn('language_reading_problem(H, written_in, LANGUAGE_BROKEN)', study)
        self.assertLess(study.index('language_reading_problem('), study.index('H.knows_recipe_node(node_id)'))
        self.assertIn('research_chapter_study_time(H, N, written_in, tutor)', study)
        timing = proc(RESEARCH, '/proc/research_chapter_study_time(')
        self.assertIn('round(H.scholar_study_time(N.era_tier, N.id) * language_study_factor(H, written_in))', timing)
        self.assertIn('tutor ? round(time / tutor.tutor_rate()) : time', timing)
        self.assertIn('H.timed_study(node_id, time, anchor)', study)
        self.assertIn('loose.chapter_language', study)
        factor = proc(LANG, '/proc/language_study_factor(')
        self.assertIn('if (score >= LANGUAGE_FLUENT)\n\t\treturn 1', factor)
        self.assertIn('(LANGUAGE_FLUENT - max(score, LANGUAGE_BROKEN)) / (LANGUAGE_FLUENT - LANGUAGE_BROKEN)', factor)
        problem = proc(LANG, '/proc/language_reading_problem(')
        self.assertIn('!L || !map || !map.book_research_enabled()', problem)

    def test_hand_copying_translates_and_needs_conversational(self):
        job = proc(RESEARCH, '/obj/structure/research_bench/proc/book_copy_job(')
        self.assertIn('source.chapter_refuses(H, node_id, LANGUAGE_CONVERSATIONAL)', job)
        self.assertLess(job.index('source.chapter_refuses('), job.index('do_reading('))
        commit = proc(RESEARCH, '/obj/structure/research_bench/proc/copy_chapter_commit(')
        self.assertIn('dest.add_research_chapter(node_id, FALSE, H)', commit)

    def test_printed_and_torn_chapters_keep_their_language(self):
        printing = read('book_printing.dm')
        self.assertLess(printing.index('printed.add_research_chapter(node_id)'),
                        printing.index('printed.copy_chapter_languages_from(original)'))
        tear = proc(PAGES, '/obj/item/weapon/book/proc/tear_out_page(')
        self.assertIn('R.chapter_language = written_in ? written_in.name : ""', tear)
        self.assertIn('set_chapter_language(which, null)', tear)
        bind = proc(PAGES, '/obj/item/weapon/book/proc/bind_loose_page(')
        self.assertIn('add_research_chapter(R.node_id, FALSE, null, istext(R.chapter_language) ? R.chapter_language : "")', bind)

    def test_book_window_names_the_languages(self):
        ui = read('book_interface.dm')
        self.assertIn('var/language_note = chapter_language_note(H)', ui)
        self.assertIn('data["cipher_note"] = jointext(reading_notes, " ")', ui)


if __name__ == '__main__':
    unittest.main()
