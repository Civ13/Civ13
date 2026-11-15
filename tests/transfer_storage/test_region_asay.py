"""Source contracts for admin chat (adminsay.dm) and group-wide admin chat
(region_asay.dm). Never launches BYOND.

Every online admin sees an ASAY line; it reaches CivilizationBot's admin
channel once and the admins of the other regions through its own agent ring,
never the OOC ring, so it can never be shown to players as OOC.
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


SAY = read('code/modules/admin/verbs/adminsay.dm')
ASAY = read('code/modules/persistence/region_asay.dm')


class AdminSay(unittest.TestCase):
    def test_included_and_given_to_all_staff(self):
        dme = read('civ13.dme')
        self.assertIn('#include "code\\modules\\admin\\verbs\\adminsay.dm"', dme)
        self.assertIn('#include "code\\modules\\persistence\\region_asay.dm"', dme)
        verbs = read('code/modules/admin/admin_verbs.dm')
        default = verbs[verbs.index('var/list/admin_verbs_default'):verbs.index('var/list/admin_verbs_admin')]
        self.assertIn('/client/proc/cmd_admin_say,', default)

    def test_verb_checks_then_shows_posts_and_relays(self):
        verb = proc(SAY, '/client/proc/cmd_admin_say')
        self.assertIn('set name = "Asay"', verb)
        checks = max(verb.index('if (!holder)'), verb.index('MUTE_ADMINHELP'), verb.index('handle_spam_prevention'),
                     verb.index('msg = sanitize(msg)'))
        for step in ('log_admin("ASAY:', 'admin_say_show(key, msg, html_encode(rank))', 'discord_asay_log(key, msg)',
                     'region_asay_outbound(key, ckey, msg, rank)'):
            self.assertLess(checks, verb.index(step), step)

    def test_lines_reach_only_admins_in_the_admin_tab(self):
        show = proc(SAY, '/proc/admin_say_show')
        self.assertIn('for (var/client/C in admins)', show)
        self.assertIn('if (!C.holder)', show)
        self.assertIn('CHAT_TYPED(CHAT_ADMIN,', show)
        self.assertIn("<span class='admin_channel'>", show)
        self.assertNotIn('world', show)

    def test_discord_post_uses_the_bot_admin_channel(self):
        log = proc(SAY, '/proc/discord_asay_log')
        self.assertIn('file("admin.log")', log)
        # Staff-written: the bot must never ping @Admin for an admin's own asay.
        self.assertIn('webhook_send_asay(name, line, "asay", TRUE)', log)
        self.assertIn('ASAY:**__', log)

    def test_staff_lines_tell_the_bot_who_wrote_them(self):
        hooks = proc(read('code/modules/webhooks/webhooks.dm'), '/proc/webhook_send_asay')
        for field in ('"kind" = kind', '"from_staff" =', '"staff_online" = webhook_staff_online()'):
            self.assertIn(field, hooks)

    def test_discord_admin_messages_are_escaped_and_handed_on(self):
        loop = proc(read('code/world.dm'), '/proc/start_messaging_loop')
        block = loop[loop.index('SQL/discord2admin.txt'):loop.index('SQL/discord2dm.txt')]
        self.assertLess(block.index('sanitize(copytext_char(tempmsg[1]'), block.index('admin_say_show(asender, atext, "", "", TRUE)'))
        self.assertLess(block.index('admin_say_show(asender, atext'), block.index('region_asay_outbound_discord(asender, atext)'))

    def test_agent_asay_reaches_the_admins(self):
        # act_asay only wrote an audit line before; nobody saw the message.
        act = proc(read('code/modules/agent_control/agent_actions.dm'), '/datum/agent_control/proc/act_asay')
        for step in ('sanitize(agent_text_arg(req, "text"))', 'admin_say_show(', 'discord_asay_log(name, message)',
                     'region_asay_outbound(name, "agent", message)', 'return list("sent_to" = shown)'):
            self.assertIn(step, act)


class RegionAsay(unittest.TestCase):
    def test_own_agent_routes_never_the_ooc_ring(self):
        exchange = proc(ASAY, '/proc/region_asay_exchange')
        self.assertIn('"/asay/send"', exchange)
        self.assertIn('"/asay/inbox"', exchange)
        self.assertNotIn('/ooc/', ASAY)
        self.assertNotIn('region_ooc_outbound', ASAY)
        self.assertLess(exchange.index('REGION_ASAY_MAX_AGE'), exchange.index('"/asay/send"'))
        self.assertLess(exchange.index('region_asay_next_poll'), exchange.index('"/asay/inbox"'))
        tick = proc(ASAY, '/proc/region_asay_tick')
        self.assertLess(tick.index('if (region_asay_busy)'), tick.index('region_asay_exchange()'))
        self.assertLess(tick.index('region_asay_outbound_queue.Cut()'), tick.index('if (!region_ooc_enabled())'))
        fire = proc(read('code/modules/1713/radio_relay.dm'), '/process/civ_radio_relay/fire')
        self.assertLess(fire.index('region_asay_tick()'), fire.index('if (!on_air.len)'))

    def test_receive_checks_then_posts_once_and_shows_to_admins(self):
        receive = proc(ASAY, '/proc/region_asay_receive')
        for check in ('source == shard_group.region', 'findtext(msg, "<")', 'html_encode(name)', 'html_encode(envelope["rank"])'):
            self.assertIn(check, receive)
        discord = receive.index('if (envelope["discord"])')
        gate = '!envelope["posted"] && shard_group.region == shard_group.mainland'
        self.assertLess(receive.index('findtext(msg, "<")'), discord)
        # A Discord line is shown and returns before any Discord post.
        self.assertLess(discord, receive.index(gate))
        self.assertLess(receive.index(gate), receive.index('discord_asay_log(name, msg, region_name)'))
        self.assertIn('"posted" = webhook_enabled()', proc(ASAY, '/proc/region_asay_outbound'))
        self.assertIn('"discord" = TRUE, "posted" = TRUE', proc(ASAY, '/proc/region_asay_outbound_discord'))
        code = '\n'.join(line for line in ASAY.split('\n') if not line.lstrip().startswith('//'))
        for call in ('webhook_send', 'admin.log', 'to_chat'):
            self.assertNotIn(call, code)


if __name__ == '__main__':
    unittest.main()
