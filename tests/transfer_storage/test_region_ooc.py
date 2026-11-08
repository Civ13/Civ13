"""Source contracts for group-wide OOC (region_ooc.dm). Never launches BYOND.

Only the region a line was said in posts it to Discord, so CivilizationBot sees
each line once; receiving regions show it with a region tag and skip it when
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

    def test_receiving_regions_do_not_post_to_discord(self):
        receive = proc(OOC, '/proc/region_ooc_receive')
        code = '\n'.join(line for line in OOC.split('\n') if not line.lstrip().startswith('//'))
        for call in ('webhook_send', 'discord_log', 'ooc.log'):
            self.assertNotIn(call, code)
        for check in ('config.ooc_allowed', 'region_ooc_ckey_banned', 'show_ooc', 'findtext(msg, "<")',
                      'source == shard_group.region', 'html_encode(name)'):
            self.assertIn(check, receive)
        self.assertIn('\\[[region_name]\\]', receive)

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
        self.assertIn('shard_group.enabled', proc(OOC, '/proc/region_ooc_enabled'))


if __name__ == '__main__':
    unittest.main()
