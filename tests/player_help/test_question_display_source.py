"""Offline contract checks; native fixture exercises the actual renderer separately."""
from pathlib import Path
import unittest

SOURCE = Path(__file__).resolve().parents[2] / 'code/game/mob/player_help.dm'


class QuestionDisplaySourceTests(unittest.TestCase):
    def test_actual_poll_passes_correlated_question_and_snapshots_history(self):
        text = SOURCE.read_text(encoding='utf-8')
        poll = text.split('/datum/player_help_service/proc/poll()', 1)[1].split('/datum/player_help_service/proc/response_format', 1)[0]
        self.assertIn('previous_questions', poll)
        self.assertLess(poll.index('C.player_help_generation != entry["generation"]'), poll.index('previous_questions'))
        self.assertLess(poll.index('previous_questions'), poll.index('remember(C, entry["question"]'))
        self.assertIn('render_answer(response["answer"], answer_format, C, entry["question"], previous_questions)', poll)

    def test_actual_renderer_escapes_questions_and_puts_history_after_links(self):
        text = SOURCE.read_text(encoding='utf-8')
        renderer = text.split('/datum/player_help_service/proc/render_answer(', 1)[1].split('// Bounded display subset', 1)[0]
        self.assertIn('html_encode(question)', renderer)
        self.assertIn('html_encode(previous_question)', renderer)
        self.assertLess(renderer.index('Crafting Atlas</a>'), renderer.index('[history]'))


if __name__ == '__main__':
    unittest.main()
