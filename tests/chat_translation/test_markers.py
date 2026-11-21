"""Chat translation markers and the server translator (docs/chat-translation.md).

The chat window translates only the text inside chat-tr and never a line that
holds chat-notr. Speech this listener did not understand (scrambled, starred,
nonverbal unseen, animal noises) must be marked chat-notr; understood speech
and OOC/LOOC bodies are chat-tr.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
HEAR = (ROOT / 'code/game/mob/hear_say.dm').read_text(encoding='utf-8')
VERBS = (ROOT / 'code/modules/client/client_verbs.dm').read_text(encoding='utf-8')
REGION = (ROOT / 'code/modules/persistence/region_ooc.dm').read_text(encoding='utf-8')
CHAT = (ROOT / 'interface/chat/chat.html').read_text(encoding='utf-8')


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

    def test_device_speech_is_unmarked(self):
        # comprehend_device_speech is frozen by tests/device_hearing; radio,
        # phone and voicepipe lines are translated whole by the client.
        helper = section(HEAR, '/mob/proc/comprehend_device_speech(', 'return list(message)')
        self.assertNotIn('chat-tr', helper)
        self.assertNotIn('chat-notr', helper)

    def test_ooc_bodies_are_marked(self):
        self.assertEqual(VERBS.count("<span class='message chat-tr'>[msg]</span>"), 3)  # OOC, LOOC, LOOC admin copy
        self.assertEqual(REGION.count("<span class='message chat-tr'>[msg]</span>"), 1)


class ClientContract(unittest.TestCase):
    def test_defaults_on_and_english(self):
        self.assertIn("const prefs = { enabled: true, lang: 'en' };", CHAT)

    def test_client_honours_markers(self):
        body = section(CHAT, 'function translationSource(div, type) {', '\n        }\n')
        self.assertLess(body.index("querySelector('.chat-notr')) return ''"), body.index("querySelectorAll('.chat-tr')"))

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


SERVER = (ROOT / 'code/modules/chat/chat_translate.dm').read_text(encoding='utf-8')
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
        for key in ('"chat_translate_url"', '"chat_translate_model"'):
            self.assertIn(key, CONFIG)

    def test_off_unless_configured(self):
        enabled = section(SERVER, '/datum/chat_translator/proc/enabled()', '\n\n')
        self.assertIn('config.chat_translate_url', enabled)
        self.assertIn('config.chat_translate_model', enabled)

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
