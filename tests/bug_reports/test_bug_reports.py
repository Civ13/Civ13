"""In-game bug reports: wiring and safety contracts (offline, no BYOND).

native_format.py runs the formatting procs in DreamDaemon by hand, because the
offline CI suite forbids skipped tests.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
FORMAT = 'code/modules/bug_reports/bug_report_format.dm'
QUEUE = 'code/modules/bug_reports/bug_reports.dm'


def read(path):
    return (ROOT / path).read_text(encoding='utf-8', errors='replace')


def body(source, start, end):
    return source[source.index(start):source.index(end, source.index(start) + len(start))]


class BugReportWiring(unittest.TestCase):
    def test_files_are_compiled_format_first(self):
        dme = read('civ13.dme')
        fmt = dme.index('#include "code\\modules\\bug_reports\\bug_report_format.dm"')
        self.assertLess(fmt, dme.index('#include "code\\modules\\bug_reports\\bug_reports.dm"'))

    def test_help_menu_and_admin_verb(self):
        skin = read('interface/skin.dmf')
        menu = skin[skin.index('menu "menu"'):skin.index('window "mainwindow"')]
        self.assertIn('command = "Report-Bug"', menu)
        self.assertIn('set name = "Report Bug"', read(QUEUE))
        verbs = read('code/modules/admin/admin_verbs.dm')
        admin = verbs[verbs.index('var/list/admin_verbs_admin = list('):]
        self.assertIn('/client/proc/bug_reports_panel', admin[:admin.index('\n)')])
        self.assertNotIn("top right of your screen", read('code/modules/admin/verbs/adminhelp.dm'))

    def test_config_keys(self):
        conf = read('code/datums/configuration.dm')
        for key in ('bug_report_github_repo', 'bug_report_github_labels', 'bug_report_github_token'):
            self.assertIn(f'if ("{key}")', conf)
        self.assertIn('BUG_REPORT_GITHUB_REPO Civ13/Civ13', read('config/config.txt'))
        # The checked-in config never carries a real token.
        self.assertNotRegex(read('config/config.txt'), r'(?m)^BUG_REPORT_GITHUB_TOKEN ')


class BugReportSafety(unittest.TestCase):
    def test_token_never_stored_in_a_variable(self):
        conf = read('code/datums/configuration.dm')
        self.assertNotIn('var/bug_report_github_token', conf)
        token_case = conf[conf.index('if ("bug_report_github_token")'):]
        self.assertNotIn('=', token_case[:token_case.index('\n\n')])
        queue = read(QUEUE)
        blocks = re.findall(r'(?m)^/datum/[^\n(]*\n((?:\tvar/[^\n]*\n)+)', queue)
        self.assertGreaterEqual(len(blocks), 2, 'datum var blocks found')
        for block in blocks:
            self.assertNotRegex(block, r'(?i)token', 'no datum var holds the token')
        self.assertIn('bug_report_token_from_lines(file2list("config/config.txt"))', queue)

    def test_token_is_not_logged(self):
        queue = read(QUEUE)
        for line in queue.splitlines():
            if re.search(r'log_admin|message_admins|to_chat|world\.log', line):
                self.assertNotIn('[token]', line)

    def test_every_admin_action_checks_rights_at_use(self):
        queue = read(QUEUE)
        topic = body(queue, '/datum/bug_report_queue/Topic(', '/client/verb/report_bug()')
        self.assertIn('check_rights(R_ADMIN, TRUE, usr)', topic.split('\n', 3)[2])
        # The prompts sleep: rights and ownership are checked again before acting.
        self.assertGreaterEqual(topic.count('check_rights(R_ADMIN, TRUE, usr)'), 3)
        self.assertIn('reports["[R.id]"] != R', topic)
        self.assertIn('check_rights(R_ADMIN, TRUE, user)', body(queue, 'proc/show_panel(', 'Topic('))

    def test_double_filing_is_refused(self):
        queue = read(QUEUE)
        approve = body(queue, '/datum/bug_report_queue/proc/approve(', '/datum/bug_report_queue/proc/post_issue(')
        self.assertIn('if (!R || R.state == "filing")', approve[:approve.index('github_repo()')])
        self.assertLess(approve.index('R.state = "filing"'), approve.index('post_issue('))

    def test_player_text_is_escaped_in_the_panel(self):
        panel = body(read(QUEUE), 'proc/panel_html()', 'proc/show_panel(')
        for field in ('R.title', 'R.what', 'R.steps', 'R.expected', 'R.ckey'):
            self.assertIn(f'html_encode({field})', panel)
        self.assertNotRegex(panel, r'\[R\.(what|steps|expected|title)\]')

    def test_player_text_is_fenced_on_github(self):
        fmt = read(FORMAT)
        issue = body(fmt, '/proc/bug_report_issue_body(', '/proc/bug_report_repo_valid(')
        for field in ('what', 'steps', 'expected'):
            self.assertIn(f'bug_report_fence({field})', issue)
        self.assertIn('replacetext(text, "```", "\'\'\'")', fmt)

    def test_player_limits(self):
        queue = read(QUEUE)
        refusal = body(queue, 'proc/refusal(', 'proc/context_for(')
        for guard in ('MUTE_ADMINHELP', 'BUG_REPORT_PENDING_MAX', 'BUG_REPORT_PER_PLAYER', 'BUG_REPORT_COOLDOWN'):
            self.assertIn(guard, refusal)
        verb = body(queue, '/client/verb/report_bug()', '/client/proc/bug_reports_panel()')
        self.assertEqual(verb.count('bug_reports.refusal(src)'), 2, 'checked before and after the prompts')

    def test_no_private_details_attached(self):
        context = body(read(QUEUE), 'proc/context_for(', 'proc/add(')
        for private in ('address', 'computer_id', 'C.key', 'lastKnownIP'):
            self.assertNotIn(private, context)

    def test_github_request(self):
        post = body(read(QUEUE), 'proc/post_issue(', 'proc/finish(')
        self.assertIn('RUSTG_HTTP_METHOD_POST', post)
        self.assertIn('"https://api.github.com/repos/[repo]/issues"', post)
        self.assertIn('status == 201', post)
        self.assertIn('R.status_code = L["status_code"]', read('code/datums/http.dm'))


if __name__ == '__main__':
    unittest.main()
