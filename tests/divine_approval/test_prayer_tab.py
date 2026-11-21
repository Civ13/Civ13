"""Source guards for the Prayer chat tab: prayers, god answers and divine alerts."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
PRAY = (ROOT / 'code/game/mob/pray.dm').read_text()
CHAT = (ROOT / 'code/__defines/chat.dm').read_text()
HTML = (ROOT / 'interface/chat/chat.html').read_text()
TOPIC = (ROOT / 'code/modules/admin/topic.dm').read_text()
COVENANT = (ROOT / 'code/modules/divine/covenant.dm').read_text()
VERB = (ROOT / 'code/modules/admin/verbs/divine_patron.dm').read_text()


def body(text, path):
    return text.split(path, 1)[1].split('\n/', 1)[0]


class PrayerTab(unittest.TestCase):
    def test_prayer_type_matches_the_page(self):
        self.assertIn('#define CHAT_PRAYER	"prayer"', CHAT)
        self.assertIn("['prayer', 'Prayers and answers from the gods']", HTML)
        self.assertIn("{ name: 'Prayer', types: ['prayer'], auto: 'prayer' }", HTML)
        self.assertIn("const ADDED_TYPES = ['prayer'];", HTML)

    def test_every_prayer_line_is_typed(self):
        pray = body(PRAY, '/mob/verb/pray()')
        self.assertEqual(pray.count('to_chat(C, '), pray.count('to_chat(C, CHAT_TYPED(CHAT_PRAYER, text))'))
        self.assertIn('to_chat(usr, CHAT_TYPED(CHAT_PRAYER, "<span class=\'notice\'><i>You pray to', pray)
        self.assertIn('prayer_hearers()', pray)
        self.assertIn('divine_staff_for(deity)', pray)

    def test_gods_hear_every_prayer(self):
        hearers = body(PRAY, '/proc/prayer_hearers()')
        self.assertIn('R_ADMIN', hearers)
        self.assertIn('show_chat_prayers', hearers)
        self.assertIn('divine_identity_of(C.ckey)', hearers)

    def test_answers_only_reach_followers(self):
        self.assertIn("divine_reply=\\ref[src]'>Answer</A>", PRAY)
        answer = body(VERB, '/client/proc/divine_answer_prayer(')
        self.assertIn('check_rights(R_ADMIN)', answer)
        self.assertEqual(answer.count('divine_book_key(H.divine_patron) != divine_book_key(entry["name"])'), 2)
        self.assertIn('to_chat(H, CHAT_TYPED(CHAT_PRAYER,', answer)
        self.assertIn('log_admin(', answer)
        reply = TOPIC.split('href_list["divine_reply"]', 1)[1].split('else if', 1)[0]
        self.assertIn('check_rights(R_ADMIN)', reply)
        self.assertIn('divine_answer_prayer(M)', reply)

    def test_divine_messages_use_the_tab(self):
        self.assertIn('to_chat(C, CHAT_TYPED(CHAT_PRAYER, "<span class=\'notice\'>[text]</span>"))',
                      body(COVENANT, '/proc/divine_alert_operators('))
        self.assertIn('CHAT_TYPED(CHAT_PRAYER, SPAN_NOTICE("Your prayer goes unanswered."))', COVENANT)
        self.assertIn('to_chat(H, CHAT_TYPED(CHAT_PRAYER, "<span class=\'notice\'><i>[words]</i></span>"))', VERB)

    def test_unfollowing_prayers_offer_an_invitation(self):
        pray = body(PRAY, '/mob/verb/pray()')
        self.assertIn("divine_invite=\\ref[src]'>Invite</A>", pray)
        self.assertLess(pray.index('follower.divine_patron'), pray.index('divine_invite='))
        topic = TOPIC.split('href_list["divine_invite"]', 1)[1].split('else if', 1)[0]
        self.assertIn('check_rights(R_ADMIN)', topic)
        self.assertIn('divine_invite_follower(M)', topic)
        invite = body(VERB, '/client/proc/divine_invite_follower(')
        for guard in ('check_rights(R_ADMIN)', 'if (H.divine_patron)', 'H.divine_invite_from',
                      'arcane_apostate_may_join(claim)', 'magic_whitelist_admit(H)', 'log_admin('):
            self.assertIn(guard, invite)
        self.assertNotIn('H.divine_patron =', invite)  # only the player's acceptance changes devotion
        answer = body(VERB, '/mob/living/human/proc/divine_answer_invitation(')
        self.assertIn('player_alert(src,', answer)
        self.assertIn('list("Follow", "Decline")', answer)
        self.assertIn('divine_invite_from = null', answer)
        follow = answer.split('else\n\t\toutcome = "accepted"', 1)[1]
        self.assertIn('divine_patron = deity', follow)
        self.assertIn('arcane_apostate_return(claim)', follow)
        self.assertIn('divine_refresh_verbs()', follow)
        for recheck in ('divine_patron ||', '!magic_allowed()', '!arcane_apostate_may_join(claim)'):
            self.assertIn(recheck, answer.split('outcome = "accepted"', 1)[0])
        self.assertIn('var/tmp/divine_invite_from = null', COVENANT)
        self.assertIn('key == "divine_invite_from"', COVENANT)


if __name__ == '__main__':
    unittest.main()
