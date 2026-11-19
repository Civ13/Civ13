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
        gate = '!envelope["posted"] && shard_group.region == shard_group.discord_region()'
        self.assertLess(receive.index('findtext(msg, "<")'), discord)
        # A Discord line is shown and returns before any Discord post.
        self.assertLess(discord, receive.index(gate))
        self.assertLess(receive.index(gate), receive.index('discord_asay_log(name, msg, region_name)'))
        self.assertIn('"posted" = webhook_enabled()', proc(ASAY, '/proc/region_asay_outbound'))
        self.assertIn('"discord" = TRUE, "posted" = TRUE', proc(ASAY, '/proc/region_asay_outbound_discord'))
        code = '\n'.join(line for line in ASAY.split('\n') if not line.lstrip().startswith('//'))
        for call in ('webhook_send', 'admin.log', 'to_chat'):
            self.assertNotIn(call, code)


ANNOUNCE = read('code/modules/persistence/region_announce.dm')
ADMIN = read('code/modules/admin/admin.dm')


class RegionAnnounce(unittest.TestCase):
    """Announce (All Regions): the Announce styling for every region's players."""

    def test_included_and_given_wherever_announce_is(self):
        self.assertIn('#include "code\\modules\\persistence\\region_announce.dm"', read('civ13.dme'))
        verbs = read('code/modules/admin/admin_verbs.dm')
        self.assertEqual(verbs.count('/datum/admins/proc/announce,'),
                         verbs.count('/datum/admins/proc/announce_all_regions,'))
        fire = proc(read('code/modules/1713/radio_relay.dm'), '/process/civ_radio_relay/fire')
        self.assertLess(fire.index('region_announce_tick()'), fire.index('if (!on_air.len)'))

    def test_both_verbs_share_the_announce_style(self):
        show = proc(ANNOUNCE, '/proc/admin_announce_show')
        self.assertIn('to_chat(world,', show)
        self.assertIn('Announces:</b></big>', show)
        self.assertIn('admin_announce_show(', proc(ADMIN, '/datum/admins/proc/announce'))
        verb = proc(ADMIN, '/datum/admins/proc/announce_all_regions')
        self.assertIn('set name = "Announce (All Regions)"', verb)
        # Always plain text, sanitized before it is shown or sent.
        checks = max(verb.index('check_rights(0)'), verb.index('region_ooc_linked()'), verb.index('message = sanitize(message'))
        for step in ('admin_announce_show(shown_name, message)', 'log_admin("Announce (All Regions):',
                     'region_announce_outbound(shown_name, usr.ckey, message)'):
            self.assertLess(checks, verb.index(step), step)

    def test_own_ring_and_receive_refuses_markup(self):
        exchange = proc(ANNOUNCE, '/proc/region_announce_exchange')
        self.assertIn('"/announce/send"', exchange)
        self.assertIn('"/announce/inbox"', exchange)
        for other in ('/ooc/', '/asay/', 'region_ooc_outbound', 'region_asay_outbound'):
            self.assertNotIn(other, ANNOUNCE)
        # A silent agent keeps the announcement queued until it is too old.
        self.assertLess(exchange.index('REGION_ANNOUNCE_MAX_AGE'), exchange.index('"/announce/send"'))
        self.assertLess(exchange.index('"/announce/send"'), exchange.index('region_announce_outbound_queue.Cut(1, 2)\n\tif'))
        tick = proc(ANNOUNCE, '/proc/region_announce_tick')
        self.assertLess(tick.index('if (region_announce_busy)'), tick.index('region_announce_exchange()'))
        receive = proc(ANNOUNCE, '/proc/region_announce_receive')
        for check in ('source == shard_group.region', 'findtext(msg, "<")', 'html_encode(name)'):
            self.assertIn(check, receive)
        self.assertLess(receive.index('findtext(msg, "<")'), receive.index('admin_announce_show('))


if __name__ == '__main__':
    unittest.main()


class StaffHelpRequests(unittest.TestCase):
    """Mentorhelps and adminhelps reach staff through the browser chat and
    land on the Admin tab. A raw `client << text` skips the browser chat
    entirely: staff heard the ping sound but saw no message."""

    MHELP = read('code/modules/admin/verbs/mentorhelp.dm')
    AHELP = read('code/modules/admin/verbs/adminhelp.dm')

    def staff_loop(self, source):
        start = source.index('for (var/client/X in admins)')
        return source[start:]

    def test_no_raw_text_output_to_staff(self):
        for source in (self.MHELP, self.AHELP):
            loop = self.staff_loop(source)
            for line in loop.splitlines():
                if 'X <<' in line:
                    self.assertIn("'sound/", line, line)

    def test_staff_copies_are_admin_typed(self):
        mhelp = self.staff_loop(self.MHELP)
        self.assertIn('to_chat(X, CHAT_TYPED(CHAT_ADMIN, mentormsg))', mhelp)
        self.assertIn('to_chat(X, CHAT_TYPED(CHAT_ADMIN, adminmsg))', mhelp)
        ahelp = self.staff_loop(self.AHELP)
        # Admins get the karma-annotated copy, moderators the plain one (#6182).
        self.assertIn('to_chat(X, CHAT_TYPED(CHAT_ADMIN, (R_ADMIN & X.holder.rights) ? karma_msg : msg))', ahelp)
        self.assertIn('to_chat(X, CHAT_TYPED(CHAT_ADMIN, mentormsg))', ahelp)
