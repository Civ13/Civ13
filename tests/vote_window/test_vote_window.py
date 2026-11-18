"""The vote window must not be re-sent every second (source checks, no BYOND runtime).

Players saw the Voting Panel reload constantly and pop back open after they
closed it, because the vote process re-sent the whole page to every client
that had ever opened it, once a second.
"""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VOTE = (ROOT / 'code/datums/vote.dm').read_text(encoding='utf-8')


def proc_body(name):
    match = re.search(r'^\tproc/' + name + r'\(.*?\n(.*?)(?=^\tproc/|^\t[A-Z]\w*\(|^/)', VOTE, re.S | re.M)
    assert match, name
    return match.group(1)


class VoteWindowTests(unittest.TestCase):
    def test_process_does_not_resend_the_page(self):
        body = proc_body('process')
        self.assertNotIn('show_browse', body)
        self.assertNotIn('interface(', body)
        self.assertNotIn('show_window', body)
        self.assertIn('push_tally()', body)

    def test_tally_update_goes_to_the_open_page(self):
        body = proc_body('push_tally')
        self.assertIn('vote.browser:voteUpdate', body)
        self.assertNotIn('show_browse', body)
        self.assertIn('function voteUpdate(json)', VOTE)
        self.assertIn("id='vote-count-[i]'", VOTE)

    def test_closing_with_x_stops_updates(self):
        self.assertIn('onclose(C.mob, "vote", src)', proc_body('show_window'))
        topic = VOTE[VOTE.index('\tTopic(href'):]
        close = topic.index('href_list["close"]')
        self.assertLess(close, topic.index('usr.vote()'))
        self.assertIn('voting -= usr.client', topic[close:close + 200])

    def test_new_votes_mark_the_tally(self):
        self.assertIn('tally_changed = TRUE', proc_body('submit_vote'))


if __name__ == '__main__':
    unittest.main()
