"""Offline contract checks; native fixture exercises the actual renderer separately."""
from pathlib import Path
import unittest

SOURCE = Path(__file__).resolve().parents[2] / 'code/game/mob/player_help.dm'


class QuestionDisplaySourceTests(unittest.TestCase):
    def test_actual_poll_passes_correlated_question_and_snapshots_history(self):
        text = SOURCE.read_text(encoding='utf-8')
        poll = text.split('/datum/player_help_service/proc/poll()', 1)[1].split('/datum/player_help_service/proc/response_format', 1)[0]
        self.assertIn('previous_pairs = C.player_help_turns.Copy()', poll)
        self.assertLess(poll.index('C.player_help_generation != entry["generation"]'), poll.index('previous_pairs'))
        self.assertLess(poll.index('previous_pairs'), poll.index('remember(C, entry["question"]'))
        self.assertIn('render_answer(response["answer"], answer_format, C, entry["question"], previous_pairs)', poll)

    def test_actual_renderer_escapes_questions_and_puts_history_after_links(self):
        text = SOURCE.read_text(encoding='utf-8')
        renderer = text.split('/datum/player_help_service/proc/render_answer(', 1)[1].split('// Bounded display subset', 1)[0]
        self.assertIn('html_encode(question)', renderer)
        self.assertIn('html_encode(pair["question"])', renderer)
        self.assertIn('html_encode(pair["answer"])', renderer)
        self.assertIn('C.player_help_turns.Find(pair)', renderer)
        self.assertIn('action=followup;token=[C.player_help_action_token];turn=[turn]', renderer)
        self.assertLess(renderer.index('Crafting Atlas</a>'), renderer.index('[history]'))

    def test_targeted_followup_revalidates_after_input_and_uses_only_selected_pair(self):
        text = SOURCE.read_text(encoding='utf-8')
        topic = text.split('/datum/player_help_service/Topic(', 1)[1].split('/datum/player_help_service/proc/valid_action', 1)[0]
        self.assertIn('"[turn]" != raw_turn', topic)
        self.assertLess(topic.index('var/question = C.player_help_prompt()'), topic.index('valid_action(C, href_list["token"]) && C.mob == body'))
        self.assertIn('C.player_help_generation == generation', topic)
        self.assertIn('C.player_help_turns[turn] == pair', topic)
        enqueue = text.split('/datum/player_help_service/proc/enqueue(', 1)[1].split('/datum/player_help_service/proc/write_request', 1)[0]
        self.assertLess(enqueue.index('!C.player_help_turns.Find(target_pair)'), enqueue.index('reserve(account)'))
        self.assertIn('target_pair ? list(target_pair) : C.player_help_turns.Copy()', enqueue)

    def test_mood_projection_matches_visible_categories_without_raw_value(self):
        text = SOURCE.read_text(encoding='utf-8')
        needs = (SOURCE.parents[0] / 'living/carbon/human/human_needs.dm').read_text(encoding='utf-8')
        visible = needs.split('/mob/living/human/proc/print_mood()', 1)[1].split('/mob/living/human/proc/flash_sadness', 1)[0]
        category = text.split('/datum/player_help_service/proc/mood_category(value)', 1)[1].split('// Read public map metadata', 1)[0]
        for bound, name in (('-5000000 to 20', 'Horrible'), ('20 to 40', 'Bad'),
                            ('40 to 60', 'Neutral'), ('60 to 80', 'Good'), ('80 to 10000', 'Excellent')):
            self.assertIn('if(' + bound + ')\n\t\t\treturn "' + name + '"', category)
            self.assertIn('if(' + bound + ')', visible)
            self.assertIn('Your mood is ' + name.lower(), visible)
        context = text.split('/datum/player_help_service/proc/game_context(', 1)[1].split('/datum/player_help_service/proc/submit', 1)[0]
        self.assertIn('condition["mood_category"] = mood_category(H.mood)', context)
        self.assertNotIn('condition["mood"]', context)


if __name__ == '__main__':
    unittest.main()
