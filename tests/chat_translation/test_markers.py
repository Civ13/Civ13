"""Chat translation markers and the server translator (docs/chat-translation.md).

The chat window translates only the text inside chat-tr and never a line that
holds chat-notr. Speech this listener did not understand (scrambled, starred,
nonverbal unseen, animal noises) must be marked chat-notr; understood speech,
device speech, typed emotes and OOC/LOOC bodies are chat-tr. Unmarked lines are
game messages and are never translated (2026-11-22: "Thibault Sommer makes a
trench." came back as "trench coat"). Translation is off until turned on.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
HEAR = (ROOT / 'code/game/mob/hear_say.dm').read_text(encoding='utf-8')
VERBS = (ROOT / 'code/modules/client/client_verbs.dm').read_text(encoding='utf-8')
REGION = (ROOT / 'code/modules/persistence/region_ooc.dm').read_text(encoding='utf-8')
EMOTE = (ROOT / 'code/game/mob/emote.dm').read_text(encoding='utf-8')
SAY = (ROOT / 'code/game/mob/say.dm').read_text(encoding='utf-8')
LIVING_SAY = (ROOT / 'code/game/mob/living/say.dm').read_text(encoding='utf-8')
HUMAN_EMOTE = (ROOT / 'code/game/mob/living/carbon/human/emotes/emote.dm').read_text(encoding='utf-8')
CHAT = (ROOT / 'interface/chat/chat.html').read_text(encoding='utf-8')
SERVER = (ROOT / 'code/modules/chat/chat_translate.dm').read_text(encoding='utf-8')


def section(text, start, end):
    a = text.index(start)
    return text[a:text.index(end, a + len(start))]


class SpeechMarkers(unittest.TestCase):
    def setUp(self):
        self.hear = section(HEAR, '/mob/proc/hear_say(', '/mob/proc/on_hear_say(')

    def test_every_garbling_path_clears_understood(self):
        nonverbal = self.hear.index('message = stars(message)')
        self.assertIn('understood = FALSE', self.hear[nonverbal:nonverbal + 80])
        misunderstand = self.hear.index("if (speaker != src && !say_understands(speaker,language))")
        self.assertIn('understood = FALSE', self.hear[misunderstand:misunderstand + 100])

    def test_marker_wraps_before_display(self):
        mark = self.hear.index("message = understood ? \"<span class='chat-tr'>[message]</span>\" : \"<span class='chat-notr'>[message]</span>\"")
        self.assertLess(self.hear.index('understood = FALSE'), mark)
        self.assertLess(mark, self.hear.index('on_hear_say('))
        # Language formatting capitalizes; do it before the tag hides the first letter.
        self.assertLess(self.hear.index('message = capitalize(message)'), mark)

    def test_device_speech_marks_only_the_words(self):
        # comprehend_device_speech is frozen by tests/device_hearing; each
        # device marks its words after it, understood only when unchanged.
        helper = section(HEAR, '/mob/proc/comprehend_device_speech(', 'return list(message)')
        self.assertNotIn('chat-tr', helper)
        for name in ('hear_radio(', 'hear_phone(', 'hear_voicepipe('):
            with self.subTest(name=name):
                body = section(HEAR, '/mob/proc/' + name, '\n/mob/proc/')
                spoken = body.index('var/as_spoken = message')
                self.assertLess(spoken, body.index('comprehend_device_speech('))
                mark = body.index('message = chat_translate_mark(message, comprehended[1] == as_spoken)')
                self.assertLess(mark, body.index('full_message ='))
        self.assertIn('/proc/chat_translate_mark(message, understood)', SERVER)

    def test_only_typed_emotes_are_marked(self):
        body = section(EMOTE, '/mob/proc/custom_emote(', '/mob/proc/emote_dead(')
        self.assertIn('var/typed = FALSE)', body.splitlines()[0])
        self.assertIn('var/shown = typed ? "<b>[src]</b> <span class=\'chat-tr\'>[input]</span>" : message', body)
        self.assertIn('var/chat_message = CHAT_TYPED(CHAT_IC, shown)', body)
        # The input box, the Me verb and the ^ prefix are typed; canned emotes are not.
        self.assertIn('typed = TRUE', body[body.index('Choose an emote to display.'):body.index('if (input)')])
        self.assertIn('usr.emote("me",usr.emote_type,message,TRUE)', SAY)
        self.assertIn('return custom_emote(type, message, null, typed)', SAY)
        self.assertIn('if ("^") return custom_emote(1, copytext(message,2), null, TRUE)', LIVING_SAY)
        self.assertIn('return custom_emote(m_type, message, null, typed)', HUMAN_EMOTE)
        self.assertIn('custom_emote(m_type,message)\n\t\t\tbody_motion_emote(act)', HUMAN_EMOTE)

    def test_ooc_bodies_are_marked(self):
        self.assertEqual(VERBS.count("<span class='message chat-tr'>[msg]</span>"), 3)  # OOC, LOOC, LOOC admin copy
        self.assertEqual(REGION.count("<span class='message chat-tr'>[msg]</span>"), 1)


class ClientContract(unittest.TestCase):
    def test_defaults_off_and_english(self):
        # Val, 2026-11-22: players turn translation on themselves. v1 saved
        # "on" with every language change, so only its language is kept.
        self.assertIn("const prefs = { enabled: false, lang: 'en' };", CHAT)
        self.assertIn("const TRANSLATE_KEY = 'civ13-chat-translate-v2';", CHAT)
        self.assertIn("if (raw && saved && typeof saved.enabled === 'boolean') prefs.enabled = saved.enabled;", CHAT)

    def test_client_honours_markers(self):
        body = section(CHAT, 'function translationSource(div, type) {', '\n        }\n')
        self.assertLess(body.index("querySelector('.chat-notr')) return ''"), body.index("querySelectorAll('.chat-tr')"))
        # No whole-line fallback: unmarked game messages are never sent.
        self.assertNotIn('div.textContent', body)

    def test_too_short_lines_skipped(self):
        self.assertIn('const TRANSLATE_MIN_LETTERS = 3;', CHAT)
        self.assertIn('if (letters < TRANSLATE_MIN_LETTERS) return;', section(CHAT, 'function queueTranslation(', '\n        }\n'))

    def test_only_live_lines_and_only_to_the_game_server(self):
        self.assertEqual(CHAT.count('queueTranslation(messageDiv, chatType);'), 1)
        self.assertNotIn('queueTranslation', section(CHAT, 'function restoreHistory()', 'function setChatIdentity('))
        js = section(CHAT, 'const TRANSLATE_KEY', 'setupTranslationSettings();')
        for forbidden in ('fetch(', 'XMLHttpRequest', 'WebSocket', 'sendBeacon'):
            self.assertNotIn(forbidden, js)
        # The one way out is the game server that sent the line, and only once it offers translation.
        self.assertEqual(js.count('byond://'), 1)
        self.assertIn("window.location.href = 'byond://?chat_translate=' + id", js)
        self.assertIn('if (serverTranslate) return serverTranslateJob(job);', js)


CLIENT_PROCS = (ROOT / 'code/modules/client/client_procs.dm').read_text(encoding='utf-8')
CHAT_DM = (ROOT / 'code/modules/chat/chat.dm').read_text(encoding='utf-8')
CONFIG = (ROOT / 'code/datums/configuration.dm').read_text(encoding='utf-8')


class ServerTranslation(unittest.TestCase):
    """Behaviour is covered by the native probe:
    python3 tests/ecology_spawning/run_linux.py . tests/chat_translation/probe.dm 300
    """

    def test_included_and_wired(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8').splitlines()
        self.assertIn('#include "code\\modules\\chat\\chat_translate.dm"', dme)
        self.assertIn('chat_translator.handle_topic(src, href_list)', CLIENT_PROCS)
        self.assertIn('chat_translator.announce(client)', CHAT_DM)
        self.assertIn('"chat_translate_url"', CONFIG)
        self.assertNotIn('chat_translate_model', CONFIG)

    def test_off_unless_configured(self):
        enabled = section(SERVER, '/datum/chat_translator/proc/enabled()', '\n\n')
        self.assertIn('config.chat_translate_url', enabled)

    def test_edge_service_not_ollama(self):
        # Val, 2026-11-21: translate through Edge's on-device translator, not Ollama.
        self.assertNotIn('/api/chat', SERVER)
        self.assertIn('"[url]/translate"', SERVER)
        service = (ROOT / 'tools/edge-translator/edge_translator.js').read_text(encoding='utf-8')
        self.assertIn("ignoreDefaultArgs: ['--disable-component-update']", service)
        self.assertIn("listen(opts.port, '127.0.0.1'", service)

    def test_text_is_never_logged_or_saved(self):
        for line in SERVER.splitlines():
            if any(word in line for word in ('log_', 'world.log', 'message_admins', 'text2file', 'fdel', '<< file')):
                self.assertNotIn('text', line.replace('log_game("Chat translation:', ''), line.strip())

    def test_bounded(self):
        for define in ('CHAT_TRANSLATE_MAX_CHARS 500', 'CHAT_TRANSLATE_QUEUE_LIMIT 40', 'CHAT_TRANSLATE_CACHE_LIMIT 1000', 'CHAT_TRANSLATE_CLIENT_PER_MINUTE 40'):
            self.assertIn('#define ' + define, SERVER)
        self.assertNotIn('spawn(', SERVER)

    def test_languages_match_the_window(self):
        import re
        window = re.findall(r"\['([a-z]{2})', '([A-Za-z]+)'\]", section(CHAT, 'const TRANSLATE_LANGS', '];'))
        server = re.findall(r'"([a-z]{2})" = "([A-Za-z]+)"', section(SERVER, 'chat_translate_languages = list(', ')'))
        self.assertEqual(window, server)

    def test_translations_not_saved(self):
        self.assertIn('const html = untranslatedHtml(child);', CHAT)


if __name__ == '__main__':
    unittest.main()
