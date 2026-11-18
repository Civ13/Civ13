"""Offline source contracts for the join-screen relay to CivilizationBot's
lobby channel (lobby chat out, Discord lobby lines in, arrival notices)."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/webhooks/lobby_relay.dm'


class LobbyRelaySourceTests(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding='utf-8')
        self.webhooks = (ROOT / 'code/modules/webhooks/webhooks.dm').read_text(encoding='utf-8')
        self.new_player = (ROOT / 'code/game/mob/new_player/new_player.dm').read_text(encoding='utf-8')
        self.world = (ROOT / 'code/world.dm').read_text(encoding='utf-8')

    def test_included(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8').splitlines()
        self.assertIn('#include "code\\modules\\webhooks\\lobby_relay.dm"', dme)

    def test_lobby_chat_posts_after_muted_and_spam_checks(self):
        say = self.new_player[self.new_player.index('/mob/new_player/say('):]
        say = say[:say.index('\n/mob/new_player/')]
        self.assertIn('webhook_send_lobby(key, capitalize(message))', say)
        self.assertLess(say.index('MUTE_DEADCHAT'), say.index('webhook_send_lobby('))
        self.assertLess(say.index('handle_spam_prevention(message,MUTE_OOC)'), say.index('webhook_send_lobby('))
        self.assertIn('webhook_send("lobbymessage", query)', self.webhooks)

    def test_arrivals_use_the_lobby_route_with_a_kind(self):
        self.assertIn('webhook_send("lobbymessage", query)', self.source)
        self.assertIn('webhook_send_lobby_arrival(C.key, "join_screen")', self.source)
        self.assertIn('webhook_send_lobby_arrival(C.key, "entered")', self.source)

    def test_arrivals_carry_readable_text_for_older_bots(self):
        arrival = self.source[self.source.index('/proc/webhook_send_lobby_arrival('):]
        arrival = arrival[:arrival.index('\n/proc/')]
        self.assertIn('"message" = line', arrival)
        self.assertIn('entered the world.', arrival)
        self.assertIn('is on the join screen.', arrival)

    def test_hidden_staff_and_restart_rush_get_no_notice(self):
        self.assertIn('C.holder.fakekey', self.source)
        arrival = self.source[self.source.index('/proc/lobby_relay_arrival('):]
        self.assertIn('GAME_STATE_PLAYING', arrival[:arrival.index('\n/proc/')])
        self.assertIn('LOBBY_RELAY_QUIET_START', arrival[:arrival.index('\n/proc/')])

    def test_entered_needs_a_join_screen_notice_and_fires_once(self):
        entered = self.source[self.source.index('/proc/lobby_relay_entered('):]
        entered = entered[:entered.index('\n/proc/')]
        self.assertIn('lobby_relay_waiting[ckey]', entered)
        self.assertLess(entered.index('lobby_relay_waiting -= ckey'), entered.index('webhook_send_lobby_arrival('))
        self.assertIn('isliving(C.mob)', entered)

    def test_discord_lobby_lines_are_escaped_and_join_screen_only(self):
        loop = self.world[self.world.index('SQL/discord2lobby.txt'):]
        loop = loop[:loop.index('SQL/discord2admin.txt')]
        self.assertIn('sanitize(copytext_char(tempmsg[1], 1, 46), 0)', loop)
        self.assertIn('sanitize(copytext_char(tempmsg[2], 1, 1025), 0)', loop)
        self.assertIn('discord_lobby_show(lsender, ltext)', loop)
        self.assertIn('fdel(L)', loop)
        show = self.source[self.source.index('/proc/discord_lobby_show('):]
        self.assertIn('for (var/mob/new_player/P in new_player_mob_list)', show)
        self.assertIn('config.ooc_allowed', show)

    def test_no_spawn(self):
        self.assertNotIn('spawn(', self.source.replace(' ', ''))


if __name__ == '__main__':
    unittest.main()
