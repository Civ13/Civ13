"""Offline contract checks; native fixture exercises the actual renderer separately."""
import json
from pathlib import Path
import unittest

SOURCE = Path(__file__).resolve().parents[2] / 'code/game/mob/player_help.dm'


class QuestionDisplaySourceTests(unittest.TestCase):
    def test_actual_poll_remembers_the_correlated_question_then_redraws(self):
        text = SOURCE.read_text(encoding='utf-8')
        poll = text.split('/datum/player_help_service/proc/poll()', 1)[1].split('/datum/player_help_service/proc/response_format', 1)[0]
        remember = 'remember(C, asked, response["answer"], answer_format == "plain-v1")'
        self.assertIn('var/asked = entry["question"]', poll)
        self.assertLess(poll.index('C.player_help_generation != entry["generation"]'), poll.index(remember))
        self.assertLess(poll.index(remember), poll.index('show_window(C)'))
        # Every outcome a connected player has reaches the window, never only the chat.
        self.assertNotIn('C << ', poll)
        self.assertEqual(poll.count('refuse(C, '), 5)

    def test_window_escapes_player_text_and_keeps_the_conversation_in_order(self):
        text = SOURCE.read_text(encoding='utf-8')
        renderer = text.split('/datum/player_help_service/proc/render_window(', 1)[1].split('// Bounded display subset', 1)[0]
        for escaped in ('html_encode(pair["question"])', 'html_encode(C.player_help_pending)', 'html_encode(C.player_help_notice)',
                        'html_encode(copytext(C.player_help_draft, 1, 2001))'):
            self.assertIn(escaped, renderer)
        # Model text reaches the page only through the bounded renderer.
        self.assertIn('answer_markup(pair["answer"], ', renderer)
        self.assertEqual(renderer.count('pair["answer"]'), 3)
        for field in ("name='action' value='ask'", "name='token' value='[token]'", "name='question' maxlength='500'"):
            self.assertIn(field, renderer)
        # Oldest exchange first, then the question box, then the reference links.
        self.assertLess(renderer.index("<div id='thread'>"), renderer.index("<form class='ask'"))
        self.assertLess(renderer.index("name='question'"), renderer.index('Crafting Atlas</a>'))
        self.assertIn('Do not enter personal information', renderer)
        markup = text.split('/datum/player_help_service/proc/answer_markup(', 1)[1].split('/datum/player_help_service/proc/render_window(', 1)[0]
        self.assertIn('"<pre>[html_encode(answer)]</pre>"', markup)
        self.assertIn('return markdown_answer(answer)', markup)

    def test_window_questions_revalidate_and_a_chosen_exchange_is_the_only_context(self):
        text = SOURCE.read_text(encoding='utf-8')
        topic = text.split('/datum/player_help_service/proc/handle_action(', 1)[1].split('/datum/player_help_service/proc/valid_action', 1)[0]
        self.assertIn('"[turn]" != raw_turn', topic)
        # Every refusal is reported in the window; a stale window never fails silently.
        self.assertIn('That window was out of date', topic.split('if (href_list["action"] == "reset")', 1)[0])
        self.assertLess(topic.index('valid_action(C, href_list["token"])'), topic.index('submit(C, question, pair)'))
        self.assertIn('pair = C.player_help_turns[turn]', topic)
        self.assertNotIn('C << "', topic)
        # Only links to the game's own pages are opened for the player.
        self.assertIn('findtext(url, "https://civ13.github.io/") == 1', topic)
        verb = text.split('/client/verb/ask_player_help()', 1)[1].split('/datum/player_help_service\n', 1)[0]
        self.assertIn('player_help_service.open_window(src)', verb)
        self.assertNotIn('input(', verb)
        enqueue = text.split('/datum/player_help_service/proc/enqueue(', 1)[1].split('/datum/player_help_service/proc/write_request', 1)[0]
        self.assertLess(enqueue.index('!C.player_help_turns.Find(target_pair)'), enqueue.index('reserve(account)'))
        self.assertIn('target_pair ? list(target_pair) : C.player_help_turns.Copy()', enqueue)

    def test_mood_projection_matches_visible_categories_without_raw_value(self):
        text = SOURCE.read_text(encoding='utf-8')
        needs = (SOURCE.parents[0] / 'living/carbon/human/human_needs.dm').read_text(encoding='utf-8')
        visible = needs.split('/mob/living/human/proc/print_mood()', 1)[1].split('/mob/living/human/proc/flash_sadness', 1)[0]
        category = text.split('/datum/player_help_service/proc/mood_category(value)', 1)[1].split('// Read public map metadata', 1)[0]
        # Both read the one shared scale, so they cannot disagree at a boundary.
        self.assertIn('capitalize(mood_tier_name(value))', category)
        self.assertIn('switch(mood_tier(mood))', visible)
        names = needs.split('/proc/mood_tier_name(value)', 1)[1].split('/proc/mood_stat_modifier', 1)[0]
        for name in ('Horrible', 'Bad', 'Neutral', 'Good', 'Excellent'):
            self.assertIn('if(MOOD_TIER_' + name.upper() + ')', visible)
            self.assertIn('Your mood is ' + name.lower(), visible)
            if name != 'Excellent':
                self.assertIn('if (tier == MOOD_TIER_' + name.upper() + ')\n\t\treturn "' + name.lower() + '"', names)
        self.assertIn('\treturn "excellent"', names)
        context = text.split('/datum/player_help_service/proc/game_context(', 1)[1].split('/datum/player_help_service/proc/submit', 1)[0]
        self.assertIn('condition["mood_category"] = mood_category(H.mood)', context)
        self.assertNotIn('condition["mood"]', context)

    def test_targeted_overflow_refuses_before_trimming_or_writing(self):
        text = SOURCE.read_text(encoding='utf-8')
        enqueue = text.split('/datum/player_help_service/proc/enqueue(', 1)[1].split('/datum/player_help_service/proc/write_request', 1)[0]
        guard = 'if (target_pair && request_size(request) > 16384)'
        self.assertIn(guard, enqueue)
        section = enqueue.split(guard, 1)[1].split('// Retain complete newest pairs', 1)[0]
        self.assertIn('clear_slot(slot)', section)
        self.assertIn("selected exchange and your character's details are too large", section)
        self.assertNotIn('player_help_turns.Cut', section)
        self.assertNotIn('write_request', section)
        self.assertLess(enqueue.index(guard), enqueue.index('turns.Cut(1, 2)'))
        self.assertLess(enqueue.index(guard), enqueue.index('write_request(slot, request)'))

    def test_multibyte_budget_example_keeps_target_and_history_separate(self):
        name = '😀' * 20  # The game projects at most 80 UTF-8 bytes per item name.
        inventory = [{'name': name, 'quantity': 1, 'place': 'back'}] + [
            {'name': name, 'quantity': 1, 'place': name} for _ in range(23)]
        large = {'question': 'q' * 500, 'answer': '😀' * 750}
        small = {'question': 'short earlier', 'answer': '😀' * 100}
        history = [large, small]
        request = {'id': 'fixture-id', 'account': 'a' * 32, 'question': 'q' * 500,
                   'game_context': {'player': {'inventory': {'items': inventory, 'truncated': False}}},
                   'render_contract': {'version': 1, 'capabilities': ['markdown-basic-v1']},
                   'conversation': {'version': 1, 'turns': [large]}}
        size = lambda value: len(json.dumps(value, ensure_ascii=True, separators=(',', ':')))
        self.assertGreater(size(request), 16384)
        request['conversation']['turns'] = [small]
        self.assertGreater(size(request), 10000)
        self.assertLess(size(request), 16000)
        self.assertEqual(history, [large, small])


if __name__ == '__main__':
    unittest.main()
