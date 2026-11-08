"""Source contracts for group-wide OOC (region_ooc.dm). Never launches BYOND.

A line reaches Discord once: from the region it was said in when that region
has a webhook, otherwise from the mainland; receiving regions show it with a region tag and skip it when
OOC is muted there or the speaker holds an OOC ban there.
"""
import os
import re
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def read(path):
    with open(os.path.join(ROOT, path), encoding='utf-8-sig') as f:
        return f.read().replace('\r\n', '\n')


def proc(source, name):
    start = source.index('\n' + name + '(') + 1
    end = re.search(r'\n(?=[^\s#])', source[start + 1:])
    return source[start:start + 1 + end.start()] if end else source[start:]


OOC = read('code/modules/persistence/region_ooc.dm')
VERBS = read('code/modules/client/client_verbs.dm')
RELAY = read('code/modules/1713/radio_relay.dm')


class RegionOoc(unittest.TestCase):
    def test_included(self):
        self.assertIn('#include "code\\modules\\persistence\\region_ooc.dm"', read('civ13.dme'))

    def test_verb_sends_the_unhighlighted_line_after_its_own_checks(self):
        verb = proc(VERBS, '/client/verb/ooc')
        checks = max(verb.index('MUTE_OOC'), verb.index('quickBan_isbanned("OOC")'), verb.index('byond://'))
        saved = verb.index('var/region_msg = msg')
        self.assertLess(checks, saved)
        self.assertLess(saved, verb.index('msg = ooc_ping_clients(msg)'))
        self.assertLess(verb.index('webhook_send_ooc'), verb.index('region_ooc_outbound(src, region_msg, ooc_style)'))

    def test_only_the_mainland_posts_lines_their_region_did_not(self):
        # Rail Yard has no webhook (the bot knows one server), so its OOC never
        # reached Discord until the mainland posted it (2026-11-08).
        receive = proc(OOC, '/proc/region_ooc_receive')
        outbound = proc(OOC, '/proc/region_ooc_outbound_line')
        self.assertIn('"posted" = webhook_enabled()', outbound)
        self.assertIn('return region_ooc_outbound_line(speaker.key, speaker.ckey, msg, style, rank, fakekey)',
                      proc(OOC, '/proc/region_ooc_outbound'))
        gate = '!envelope["posted"] && shard_group.region == shard_group.mainland'
        self.assertIn(gate, receive)
        post = receive.index('region_ooc_post_to_discord(region_name, name, msg)')
        self.assertLess(receive.index(gate), post)
        # After the sender and ban checks, before the local mute, which only hides it here.
        self.assertLess(receive.index('findtext(msg, "<")'), post)
        self.assertLess(receive.index('region_ooc_ckey_banned'), post)
        self.assertLess(post, receive.index('config.ooc_allowed'))
        code = '\n'.join(line for line in OOC.split('\n') if not line.lstrip().startswith('//'))
        for call in ('webhook_send', 'discord_log', 'ooc.log'):
            # Only the mainland's relay post and an agent's own line (it is said here) post to Discord.
            rest = code.replace(proc(OOC, '/proc/region_ooc_post_to_discord'), '').replace(proc(OOC, '/proc/agent_ooc_say'), '')
            self.assertNotIn(call, rest)
        poster = proc(OOC, '/proc/region_ooc_post_to_discord')
        self.assertIn('webhook_send_ooc(name, line)', poster)
        self.assertIn('file("ooc.log")', poster)
        self.assertIn('([region_name]) OOC:', poster)
        hooks = read('code/modules/webhooks/webhooks.dm')
        self.assertIn('if (!webhook_enabled())', proc(hooks, '/proc/webhook_send'))
        for check in ('config.ooc_allowed', 'region_ooc_ckey_banned', 'show_ooc', 'findtext(msg, "<")',
                      'source == shard_group.region', 'html_encode(name)'):
            self.assertIn(check, receive)
        self.assertIn('\\[[region_name]\\]', receive)

    def test_discord_messages_reach_the_other_regions_once(self):
        # The bot writes discord2ooc.txt for the mainland only (2026-11-08).
        loop = proc(read('code/world.dm'), '/proc/start_messaging_loop')
        self.assertLess(loop.index('discord_ooc_show(dsender, dtext)'), loop.index('region_ooc_outbound_discord(dsender, dtext)'))
        outbound = proc(OOC, '/proc/region_ooc_outbound_discord')
        self.assertIn('"discord" = TRUE, "posted" = TRUE', outbound)
        self.assertIn('region_ooc_linked()', outbound)
        receive = proc(OOC, '/proc/region_ooc_receive')
        branch = receive.index('if (envelope["discord"])')
        # Sender and markup checks first; shown before any Discord post or ckey ban check.
        self.assertLess(receive.index('source == shard_group.region'), branch)
        self.assertLess(receive.index('findtext(msg, "<")'), branch)
        self.assertLess(branch, receive.index('region_ooc_post_to_discord'))
        self.assertLess(branch, receive.index('region_ooc_ckey_banned'))
        self.assertIn('return discord_ooc_show(name, msg)', receive)
        show = proc(OOC, '/proc/discord_ooc_show')
        for check in ('config.ooc_allowed', 'show_ooc', "iconstate='discord'", 'log_discord'):
            self.assertIn(check, show)

    def test_agent_ooc_goes_everywhere_a_player_line_does(self):
        # Ada can check the whole OOC path (Val, 2026-11-08): local clients, Discord, other regions.
        say = proc(OOC, '/proc/agent_ooc_say')
        for step in ('config.ooc_allowed', 'sanitize(msg)', 'log_ooc', 'webhook_send_ooc', 'discord_log', 'show_ooc',
                     'region_ooc_outbound_line(name, speaker_ckey, msg, "everyone")'):
            self.assertIn(step, say)
        self.assertLess(say.index('sanitize(msg)'), say.index('webhook_send_ooc'))
        chars = read('code/modules/agent_control/agent_characters.dm')
        self.assertIn('if (!A.has_scope("ooc"))', chars)
        self.assertLess(chars.index('if (!A.has_scope("ooc"))'), chars.index('agent_ooc_say("[M.real_name] (AI)"'))

    def test_rides_the_radio_process_before_the_relay_gate(self):
        fire = proc(RELAY, '/process/civ_radio_relay/fire')
        self.assertLess(fire.index('region_ooc_tick()'), fire.index('if (!on_air.len)'))
        tick = proc(OOC, '/proc/region_ooc_tick')
        exchange = proc(OOC, '/proc/region_ooc_exchange')
        self.assertIn('"/ooc/send"', exchange)
        self.assertIn('"/ooc/inbox"', exchange)
        # One OOC exchange at a time, and the inbox is polled every few seconds,
        # so a stalled agent cannot pile up rust_g requests (Rail Yard, 2026-11-08).
        self.assertLess(tick.index('if (region_ooc_busy)'), tick.index('region_ooc_exchange()'))
        self.assertLess(exchange.index('region_ooc_next_poll'), exchange.index('"/ooc/inbox"'))
        bridge = proc(read('code/modules/persistence/transfer_bridge.dm'), '/datum/transfer_bridge/proc/request')
        self.assertIn('TRANSFER_BRIDGE_ABANDONED_LIMIT', bridge)
        self.assertIn('abandoned += R', bridge)
        self.assertIn('shard_group.enabled', proc(OOC, '/proc/region_ooc_linked'))
        self.assertIn('region_ooc_linked()', proc(OOC, '/proc/region_ooc_enabled'))

    def test_lines_said_before_the_round_wait_instead_of_dropping(self):
        # Val's Rail Yard line during the save load never left (2026-11-08).
        enabled = proc(OOC, '/proc/region_ooc_enabled')
        self.assertIn('GAME_STATE_PLAYING', enabled)
        self.assertNotIn('GAME_STATE_PLAYING', proc(OOC, '/proc/region_ooc_linked'))
        for name in ('/proc/region_ooc_outbound_line', '/proc/region_ooc_outbound_discord'):
            body = proc(OOC, name)
            self.assertIn('region_ooc_linked()', body)
            self.assertNotIn('region_ooc_enabled()', body)
            self.assertIn('"queued" = world.time', body)
        tick = proc(OOC, '/proc/region_ooc_tick')
        # Only an unlinked world clears the queue; a world not yet playing keeps it.
        self.assertLess(tick.index('if (!region_ooc_linked())'), tick.index('region_ooc_outbound_queue.Cut()'))
        self.assertLess(tick.index('region_ooc_outbound_queue.Cut()'), tick.index('if (!region_ooc_enabled())'))
        exchange = proc(OOC, '/proc/region_ooc_exchange')
        self.assertLess(exchange.index('REGION_OOC_MAX_AGE'), exchange.index('"/ooc/send"'))
        self.assertLess(exchange.index('envelope -= "queued"'), exchange.index('"/ooc/send"'))


if __name__ == '__main__':
    unittest.main()
