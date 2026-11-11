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
SHOT = 'code/modules/bug_reports/bug_report_screenshot.dm'


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
        for field in ('R.title', 'R.what', 'R.steps', 'R.expected', 'R.reporter'):
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


class BugReportScreenshots(unittest.TestCase):
    def test_compiled_after_the_queue(self):
        dme = read('civ13.dme')
        self.assertLess(dme.index('#include "code\\modules\\bug_reports\\bug_reports.dm"'),
                        dme.index('#include "code\\modules\\bug_reports\\bug_report_screenshot.dm"'))

    def test_picture_is_taken_before_the_prompts_and_the_player_chooses(self):
        verb = body(read(QUEUE), '/client/verb/report_bug()', '/client/proc/bug_reports_panel()')
        self.assertLess(verb.index('shot.start(mob, src)'), verb.index('player_input('))
        self.assertIn('"Attach picture", "No picture") == "Attach picture"', verb)
        self.assertLess(verb.index('picture = shot.result()'), verb.rindex('bug_reports.refusal(src)'))
        self.assertIn('bug_reports.add(src, title, what, steps, expected, picture)', verb)

    def test_admin_chooses_whether_the_public_issue_gets_it(self):
        queue = read(QUEUE)
        topic = body(queue, '/datum/bug_report_queue/Topic(', '/client/verb/report_bug()')
        self.assertLess(topic.index('"Attach screenshot", "Leave it out") == "Attach screenshot"'), topic.index('approve(R, admin_ckey, R.title, note, attach)'))
        approve = body(queue, '/datum/bug_report_queue/proc/approve(', '/datum/bug_report_queue/proc/post_issue(')
        self.assertIn('attach = FALSE', approve.split('\n', 1)[0])
        self.assertLess(approve.index('R.state = "filing"'), approve.index('upload_screenshot('))
        self.assertIn('else if (attach && bug_report_screenshot_exists(R.screenshot))', approve)

    def test_picture_files_are_cleaned_up(self):
        queue = read(QUEUE)
        self.assertIn('bug_report_forget_screenshot(R.screenshot)', body(queue, 'proc/reject(', 'proc/panel_html('))
        self.assertIn('if (shot != "server")', body(queue, 'proc/finish(', 'proc/reject('))
        self.assertIn('screenshot = bug_report_screenshot_exists(L["screenshot"])', queue)

    def test_draws_only_what_the_player_sees(self):
        render = body(read(SHOT), '/proc/bug_report_render_view(', '/proc/bug_report_draw(')
        self.assertIn('view("[w + 4]x[h + 4]", eye)', render)
        self.assertIn('A.invisibility > see', render)
        self.assertIn('CHECK_TICK', render)

    def test_upload_uses_its_own_token_and_repository(self):
        shot = read(SHOT)
        upload = body(shot, 'proc/upload_screenshot(', '#undef')
        self.assertIn('bug_report_token_from_lines(file2list("config/config.txt"), "bug_report_screenshot_token")', upload)
        self.assertIn('config.bug_report_screenshot_repo', upload)
        self.assertIn('RUSTG_HTTP_METHOD_PUT, "https://api.github.com/repos/[repo]/contents/[name]"', upload)
        self.assertIn('bug_report_screenshot_url_valid(url)', upload)
        for block in re.findall(r'(?m)^/datum/[^\n(]*\n((?:\tvar/[^\n]*\n)+)', shot):
            self.assertNotRegex(block, r'(?i)token', 'no datum var holds the token')
        for line in shot.splitlines():
            if re.search(r'log_admin|message_admins|to_chat|world\.log|bug_report_notify', line):
                self.assertNotIn('[token]', line)
        conf = read('code/datums/configuration.dm')
        self.assertIn('if ("bug_report_screenshot_token")\n\t\t\t\t\tcontinue', conf)
        self.assertNotRegex(read('config/config.txt'), r'(?m)^BUG_REPORT_SCREENSHOT_TOKEN ')

    def test_issue_shows_only_a_checked_address(self):
        issue = body(read(FORMAT), '/proc/bug_report_issue_body(', '/proc/bug_report_repo_valid(')
        self.assertIn('if (bug_report_screenshot_url_valid(screenshot))', issue)
        self.assertIn('https://raw.githubusercontent.com/', read(FORMAT))

    def test_panel_shows_the_picture(self):
        queue = read(QUEUE)
        self.assertIn("<img src='bugreport_[R.id].png'", body(queue, 'proc/panel_html()', 'proc/show_panel('))
        self.assertIn('browse_rsc(file(bug_report_screenshot_path(R.screenshot)), "bugreport_[R.id].png")', body(queue, 'proc/show_panel(', 'Topic('))


class AgentBugReports(unittest.TestCase):
    def action(self):
        chars = read('code/modules/agent_control/agent_characters.dm')
        return chars, body(chars, 'if ("bug_report")', 'if ("click")')

    def test_action_and_scope_are_listed(self):
        chars, _ = self.action()
        listed = body(chars, '/proc/agent_character_actions()', '\n\n')
        self.assertIn('"bug_report"', listed)
        self.assertIn('"ooc", "bug_report")', read('code/modules/agent_control/agent_control.dm'))

    def test_scope_and_limits_come_before_the_queue(self):
        _, action = self.action()
        add = action.index('bug_reports.add_from(')
        self.assertLess(action.index('if (!A.has_scope("bug_report"))'), add)
        self.assertLess(action.index('bug_reports.refusal_for(key)'), add)
        self.assertIn('"[M.real_name] (AI)"', action)
        # It only queues the report: approval stays with an admin.
        for forbidden in ('approve(', 'post_issue(', 'finish('):
            self.assertNotIn(forbidden, action)

    def test_queued_steps_check_their_text(self):
        chars, _ = self.action()
        self.assertIn('if (action == "bug_report")\n\t\tagent_text_arg(step, "title", 80)', chars)

    def test_reporter_name_reaches_issue_and_panel(self):
        queue = read(QUEUE)
        self.assertIn('bug_report_issue_body(R.reporter,', queue)
        self.assertIn('reporter = istext(L["reporter"])', queue)
        players = body(queue, '/datum/bug_report_queue/proc/refusal(', '/datum/bug_report_queue/proc/refusal_for(')
        self.assertIn('MUTE_ADMINHELP', players)
        self.assertIn('return refusal_for(C.ckey)', players)


if __name__ == '__main__':
    unittest.main()
