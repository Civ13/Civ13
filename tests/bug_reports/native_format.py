"""In-game bug reports: run the formatting procs natively (by hand, needs the pinned BYOND).

    source byondsetup && python3 tests/bug_reports/native_format.py

The offline CI suite (test_bug_reports.py) forbids skipped tests, so this
DreamDaemon check lives here instead of skipping on runners without BYOND.
"""
from pathlib import Path
import json
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]

FIXTURE = r'''
/proc/trim(text)
	var/start = 1
	var/finish = length(text)
	while (start <= finish && text2ascii(text, start) <= 32)
		start++
	while (finish >= start && text2ascii(text, finish) <= 32)
		finish--
	return copytext(text, start, finish + 1)

/world/New()
	var/list/out = list()
	out["clean"] = bug_report_clean("  a\tb[ascii2text(13)]\nc[ascii2text(1)]  ")
	out["clean_title"] = bug_report_clean("one\ntwo", 80, FALSE)
	out["clean_cap"] = bug_report_clean("abcdef", 3)
	out["clean_utf8"] = bug_report_clean("caf[ascii2text(233)] [ascii2text(20013)][ascii2text(25991)]", 6)
	out["title"] = bug_report_issue_title("  Boat   sinks\n")
	out["title_empty"] = bug_report_issue_title("")
	out["fence"] = bug_report_fence("x```y")
	out["cell"] = bug_report_cell("a|b`c @d\nnext")
	var/list/ctx = list("Map" = "Gaia", "Round" = "abc|def")
	out["body"] = bug_report_issue_body("val", "it @broke #12", "", "work", ctx, "")
	out["body_note"] = bug_report_issue_body("val", "x", "y", "z", list(), "look at turf.dm")
	out["repo_ok"] = bug_report_repo_valid("Civ13/Civ13")
	out["repo_bad"] = list(bug_report_repo_valid("Civ13"), bug_report_repo_valid("a/b/c"), bug_report_repo_valid("x/y?z"), bug_report_repo_valid("/abc"))
	out["url"] = bug_report_prefill_url("Civ13/Civ13", "\[In-game] A & B", "line", "bug")
	out["url_bad"] = bug_report_prefill_url("evil.com/x/y", "t", "b", "")
	out["token"] = bug_report_token_from_lines(list("#BUG_REPORT_GITHUB_TOKEN github_pat_commentedoutvalue000", "WEBHOOK_KEY x", "bug_report_github_token github_pat_AAAAAAAAAAAAAAAAAAAAAA", "BUG_REPORT_GITHUB_TOKEN bad token with spaces here"))
	out["token_none"] = bug_report_token_from_lines(list("#BUG_REPORT_GITHUB_TOKEN github_pat_AAAAAAAAAAAAAAAAAAAAAA"))
	out["labels"] = bug_report_labels(" bug, In game , bug,,")
	text2file(json_encode(out), "out.json")
	del src
'''


class BugReportFormat(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        assert shutil.which('DreamMaker') and shutil.which('DreamDaemon'), 'source byondsetup first'
        with tempfile.TemporaryDirectory() as tmp:
            fmt = (ROOT / 'code/modules/bug_reports/bug_report_format.dm').read_text(encoding='utf-8')
            (Path(tmp) / 'fixture.dme').write_text(fmt + FIXTURE, encoding='utf-8')
            subprocess.run(['DreamMaker', 'fixture.dme'], cwd=tmp, check=True, capture_output=True)
            subprocess.run(['DreamDaemon', 'fixture.dmb', '-trusted', '-invisible'], cwd=tmp,
                check=True, capture_output=True, timeout=60)
            cls.out = json.loads((Path(tmp) / 'out.json').read_text(encoding='utf-8'))

    def test_clean(self):
        self.assertEqual(self.out['clean'], 'a b\nc')
        self.assertEqual(self.out['clean_title'], 'one two')
        self.assertEqual(self.out['clean_cap'], 'abc')
        self.assertEqual(self.out['clean_utf8'], 'café 中')

    def test_title(self):
        self.assertEqual(self.out['title'], '[In-game] Boat   sinks')
        self.assertEqual(self.out['title_empty'], '[In-game] Bug report')

    def test_fence_cannot_be_closed(self):
        self.assertEqual(self.out['fence'], "```text\nx'''y\n```")

    def test_cell(self):
        self.assertEqual(self.out['cell'], 'a b c  d next')

    def test_body(self):
        body = self.out['body']
        self.assertIn('```text\nit @broke #12\n```', body)
        self.assertIn('### Steps to reproduce\n```text\n(not given)\n```', body)
        self.assertIn('| Round | abc def |', body)
        self.assertNotIn('Admin note', body)
        self.assertIn('### Admin note\n```text\nlook at turf.dm\n```', self.out['body_note'])
        self.assertNotIn('Round details', self.out['body_note'])

    def test_repo(self):
        self.assertEqual(self.out['repo_ok'], 1)
        self.assertEqual(self.out['repo_bad'], [0, 0, 0, 0])

    def test_prefill_url(self):
        url = self.out['url']
        self.assertTrue(url.startswith('https://github.com/Civ13/Civ13/issues/new?title='))
        self.assertIn('&labels=bug', url)
        self.assertNotIn(' ', url)
        self.assertIsNone(self.out['url_bad'])

    def test_token(self):
        self.assertEqual(self.out['token'], 'github_pat_AAAAAAAAAAAAAAAAAAAAAA')
        self.assertIsNone(self.out['token_none'])

    def test_labels(self):
        self.assertEqual(self.out['labels'], ['bug', 'In game'])


if __name__ == '__main__':
    unittest.main()
