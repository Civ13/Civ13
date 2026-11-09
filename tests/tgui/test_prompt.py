"""Source contracts for the modern WWinput prompt. Not DM or native execution."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
PROMPT = (ROOT / 'code/modules/nano/modules/prompt.dm').read_text()
WWINPUT = (ROOT / 'code/_helpers/WWinput.dm').read_text()
TGUI = (ROOT / 'code/modules/nano/tgui.dm').read_text()


def section(source, start, end=None):
    body = source.split(start, 1)[1]
    return body.split(end, 1)[0] if end else body


class PromptContract(unittest.TestCase):
    def test_included_after_the_nano_module_base(self):
        dme = (ROOT / 'civ13.dme').read_text()
        self.assertLess(dme.index('#include "code\\modules\\nano\\modules\\nano_module.dm"'),
                        dme.index('#include "code\\modules\\nano\\modules\\prompt.dm"'))

    def test_only_plain_notices_are_routed_and_before_movement_stops(self):
        route = 'if (!toc1 && !toc2 && wwinput_prompt_notice(C, message, title))'
        self.assertIn(route, WWINPUT)
        # Agent-controlled characters keep their own answer path first.
        self.assertLess(WWINPUT.index('agent_character_for(asked)'), WWINPUT.index(route))
        # The modern notice does not freeze the player; the classic alert still does.
        self.assertLess(WWINPUT.index(route), WWINPUT.index('C.stopmovingup()'))
        self.assertLess(WWINPUT.index(route), WWINPUT.index('alert(C, message, title, "Continue")'))
        # Typed and list prompts are untouched in this step.
        self.assertEqual(WWINPUT.count('wwinput_prompt_notice('), 1)

    def test_routing_requires_an_acknowledged_modern_browser(self):
        notice = section(PROMPT, '/proc/wwinput_prompt_notice(')
        self.assertIn('!C.modern_ui_acknowledged || C.modern_ui_failed', notice)
        self.assertLess(notice.index('return FALSE'), notice.index('new(C.mob'))
        self.assertIn('var/shown = !prompt.fell_back', notice)
        self.assertIn('qdel(prompt)', notice)
        ack = section(TGUI, 'message_type == "ack"', 'if (status != STATUS_INTERACTIVE')
        self.assertLess(ack.index('if (frontend_ready)'), ack.index('user.client.modern_ui_acknowledged = TRUE'))

    def test_fallback_ends_the_prompt_and_is_sticky_for_the_client(self):
        fallback = section(PROMPT, '/datum/nanoui/tgui/prompt/use_legacy_renderer()', '/datum/nanoui/tgui/prompt/')
        self.assertIn('user.client.modern_ui_failed = TRUE', fallback)
        self.assertIn('old_prompt.fell_back = TRUE', fallback)
        self.assertLess(fallback.index('old_prompt.fell_back = TRUE'), fallback.index('old_prompt.finish(null)'))
        # No classic template exists, so the parent renderer is never reopened.
        self.assertNotIn('..()', fallback)
        self.assertNotIn('open()', fallback)

    def test_answer_is_one_allowed_action_checked_by_index_and_owner(self):
        self.assertIn('/datum/nanoui/tgui/prompt/allowed_actions()\n\treturn list("answer")', PROMPT)
        consume = section(PROMPT, '/datum/nanoui/tgui/prompt/consume_topic', '/proc/')
        for guard in ('!prompt || prompt.finished', 'legacy_renderer', '!frontend_acknowledged', 'status != STATUS_INTERACTIVE', 'usr != user'):
            self.assertLess(consume.index(guard), consume.index('prompt.choose('))
        choose = section(PROMPT, '/datum/nano_module/prompt/proc/choose(index)', '/datum/nanoui/tgui/prompt')
        for guard in ('finished', '!isnum(index)', 'index != round(index)', 'index < 1', 'index > length(choices)'):
            self.assertLess(choose.index(guard), choose.index('finish(choices[index])'))
        state = section(PROMPT, '/datum/topic_state/prompt/can_use_topic', '/datum/nano_module/prompt\n')
        self.assertIn('user != prompt.owner', state)
        self.assertIn('prompt.finished', state)

    def test_every_ending_releases_the_caller(self):
        wait = section(PROMPT, '/datum/nano_module/prompt/proc/wait(', '/datum/nano_module/prompt/proc/finish(')
        for ending in ('world.time >= deadline', '!owner || !owner.client', '!ui || !ui.state'):
            self.assertIn(ending, wait)
        self.assertIn('sleep(1)', wait)
        self.assertIn('#define PROMPT_WAIT_LIMIT', PROMPT)
        close = section(PROMPT, '/datum/nanoui/tgui/prompt/close()', '/datum/nanoui/tgui/prompt/consume_topic')
        self.assertIn('old_prompt.finish(null)', close)
        transfer = section(PROMPT, '/datum/nanoui/tgui/prompt/prepare_user_transfer', '/datum/nanoui/tgui/prompt/close()')
        self.assertIn('close()', transfer)
        self.assertNotIn('open()', transfer)
        destroy = section(PROMPT, '/datum/nano_module/prompt/Destroy()', '/datum/nano_module/prompt/proc/')
        self.assertIn('finish(null)', destroy)
        finish = section(PROMPT, '/datum/nano_module/prompt/proc/finish(value)', '/datum/nano_module/prompt/proc/choose')
        self.assertLess(finish.index('if (finished)\n\t\treturn'), finish.index('finished = TRUE'))
        self.assertLess(finish.index('old_ui.prompt = null'), finish.index('old_ui.close()'))

    def test_prompt_is_transient_non_modal_and_escaped(self):
        for owner in ('/datum/topic_state/prompt\n\tshould_save = FALSE', '/datum/nano_module/prompt\n\tname = "Prompt"\n\tshould_save = FALSE',
                      '/datum/nanoui/tgui/prompt\n\tshould_save = FALSE'):
            self.assertIn(owner, PROMPT)
        self.assertIn('focus=0;', section(PROMPT, '/datum/nanoui/tgui/prompt\n', '/datum/nanoui/tgui/prompt/allowed_actions'))
        data = section(PROMPT, '/datum/nano_module/prompt/proc/prompt_data()', '/datum/nano_module/prompt/proc/open()')
        self.assertIn('html_encode("[choice]")', data)
        self.assertIn('html_encode(message)', data)
        opening = section(PROMPT, '/datum/nano_module/prompt/proc/open()', '/datum/nano_module/prompt/proc/wait(')
        self.assertIn('"prompt.tmpl"', opening)
        self.assertIn('_state = prompt_state', opening)
        self.assertLess(opening.index('ui.use_on_close_logic(FALSE)'), opening.index('ui.open()'))

    def test_frontend_screen_registered(self):
        index = (ROOT / 'tgui/src/interfaces/index.tsx').read_text()
        self.assertIn("'prompt.tmpl': Prompt,", index)
        screen = (ROOT / 'tgui/src/interfaces/Prompt.tsx').read_text()
        self.assertIn("act('answer', { answer: index + 1 })", screen)

    def test_stock_sale_confirmation_asks_the_seller(self):
        # The message used to be passed as the client, so WWinput returned
        # FALSE without asking and the sale went through unconfirmed.
        programs = (ROOT / 'code/modules/1713/computers/programs.dm').read_text()
        sale = section(programs, 'var/choice1 = WWinput(', 'map.globalmarketplace[tcode][7] = 1')
        self.assertTrue(sale.startswith('user, "Are you sure you want to sell'))
        # Recheck both consent and current ownership after the sleeping prompt.
        self.assertIn('if (choice1 != "Yes" || !map.globalmarketplace[tcode] || map.globalmarketplace[tcode][7] != 0 || map.globalmarketplace[tcode][2] != user)', sale)


if __name__ == '__main__':
    unittest.main()
