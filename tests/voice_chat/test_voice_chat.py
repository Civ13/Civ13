"""Offline source contracts for launcher voice chat, game side. Gameplay is
covered by the native probe:
python3 tests/ecology_spawning/run_linux.py . tests/voice_chat/probe.dm 300
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/voice/voice_chat.dm'


class VoiceChatSourceTests(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding='utf-8')
        self.world = (ROOT / 'code/world.dm').read_text(encoding='utf-8')
        self.client = (ROOT / 'code/modules/client/client_procs.dm').read_text(encoding='utf-8')

    def test_included(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8').splitlines()
        self.assertIn('#include "code\\modules\\voice\\voice_chat.dm"', dme)

    def test_voice_topic_bypasses_the_ban_cooldown_but_not_the_ban_list(self):
        topic = self.world[self.world.index('/world/Topic('):]
        ban = topic.index('if (bannedsourceaddrs[addr])')
        voice = topic.index('voice_chat.handle_topic(')
        cooldown = topic.index('lasttimeaddr[addr] = world.time')
        self.assertLess(ban, voice)
        self.assertLess(voice, cooldown)

    def test_join_link_key_is_read_before_the_topic_is_dropped(self):
        new = self.client[self.client.index('/client/New(TopicData)'):]
        self.assertLess(new.index('voice_key_from_topic(TopicData)'), new.index('TopicData = null'))
        self.assertIn('voice_chat.attach(src, voice_topic_key)', new)
        self.assertIn('voice_chat.detach(src)', self.client[self.client.index('/client/Del()'):])

    def test_voice_key_never_logged_or_saved(self):
        self.assertIn('/client/var/tmp/voice_key', self.source)
        for line in self.source.splitlines():
            if 'log_' in line or 'world.log' in line or 'message_admins' in line:
                self.fail('voice code must not log: ' + line.strip())

    def test_roster_posts_only_over_https_or_loopback(self):
        self.assertIn('discord_verify_endpoint(address)', self.source)
        self.assertIn('"X-Webhook-Key" = config.webhook_key', self.source)
        self.assertNotIn('webhook_send(', self.source)

    def test_guests_are_left_out(self):
        self.assertIn('!IsGuestKey(C.key)', self.source)


if __name__ == '__main__':
    unittest.main()
