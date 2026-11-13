"""Server Revision verb: run the reader natively (by hand, needs the pinned BYOND).

    source byondsetup && python3 tests/server_build/native_server_build.py

The offline CI suite (test_server_build.py) forbids skipped tests, so this
check lives here. It compiles the module into a small fixture with the pinned
DreamMaker and runs it in DreamDaemon: it reads
the host's config/server-build.json, falls back to lifecycle-revision.txt and
then to the checkout's .git HEAD (branch ref, packed-refs, worktree gitdir).
The host side (gaia_host.py write_server_build) is covered in tests/gaia_host.
"""
from pathlib import Path
import json
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
MODULE = ROOT / 'code/modules/server_build/server_build.dm'
SOURCE = MODULE.read_text(encoding='utf-8')
PANEL = (ROOT / 'code/modules/statpanel/statpanel.dm').read_text(encoding='utf-8')
DME = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
GITIGNORE = (ROOT / '.gitignore').read_text(encoding='utf-8')

STUBS = r'''
/proc/trim(text)
	var/start = 1
	var/end = length(text)
	while(start <= end && (text2ascii(text, start) in list(9, 10, 13, 32))) start++
	while(end >= start && (text2ascii(text, end) in list(9, 10, 13, 32))) end--
	return copytext(text, start, end + 1)
/proc/persistence_last_save_ago(elapsed)
	return "[round(max(0, elapsed) / 600)] min ago"
/proc/to_chat(target, text)
	return
'''

PROBE = r'''
/world/New()
	..()
	var/list/out = list()
	var/A = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
	var/B = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
	var/C = "cccccccccccccccccccccccccccccccccccccccc"
	var/D = "dddddddddddddddddddddddddddddddddddddddd"
	// 1. The host's record.
	// The host writes whole minutes since 2000-01-01 UTC; compiled_minute is malformed here.
	text2file("{\"schema\": 1, \"revision\": \"[A]\", \"subject\": \"Fix <b> & stuff\", \"committed\": 1794790800, \"committed_utc\": \"2026-11-16 01:00\", \"committed_minute\": 14135100, \"deployed\": 1794798000, \"deployed_utc\": \"2026-11-16 03:00\", \"deployed_minute\": 14135220, \"compiled_utc\": \"x\", \"compiled_minute\": 1.5}", "config/server-build.json")
	text2file("[B]\n", "config/lifecycle-revision.txt")
	var/list/info = server_build_read()
	// 2026-11-16 05:00 UTC
	var/now = 14135340 * 600
	out["host"] = list("source" = info["source"], "revision" = info["revision"], "has_compiled" = ("compiled" in info), "summary" = server_build_summary(info, now), "html" = server_build_html(info, now))
	// 2. A broken record falls back to the lifecycle revision.
	fdel("config/server-build.json")
	text2file("{not json", "config/server-build.json")
	info = server_build_read()
	out["lifecycle"] = list("source" = info["source"], "revision" = info["revision"], "summary" = server_build_summary(info, now))
	fdel("config/server-build.json")
	fdel("config/lifecycle-revision.txt")
	// 3. A plain checkout on a branch, then the branch only in packed-refs.
	text2file("ref: refs/heads/master\n", ".git/HEAD")
	text2file("[C]\n", ".git/refs/heads/master")
	info = server_build_read()
	out["checkout"] = list("source" = info["source"], "revision" = info["revision"], "html" = server_build_html(info, now))
	fdel(".git/refs/heads/master")
	text2file("# pack-refs with: peeled fully-peeled sorted\n[D] refs/heads/master\n", ".git/packed-refs")
	out["packed"] = server_build_git_head()
	// 4. A worktree: .git is a file naming its gitdir; a detached HEAD there.
	text2file("gitdir: wt-main/.git/worktrees/region\n", "wt/.git")
	text2file("[A]\n", "wt-main/.git/worktrees/region/HEAD")
	out["worktree_detached"] = server_build_git_head("wt/")
	fdel("wt-main/.git/worktrees/region/HEAD")
	text2file("ref: refs/heads/region\n", "wt-main/.git/worktrees/region/HEAD")
	text2file("../..\n", "wt-main/.git/worktrees/region/commondir")
	text2file("[B]\n", "wt-main/.git/refs/heads/region")
	out["worktree_branch"] = server_build_git_head("wt/")
	out["nothing"] = server_build_git_head("missing/")
	text2file(json_encode(out), "probe-result.json")
	shutdown()
'''


class Native(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.dir = Path(tempfile.mkdtemp(prefix='server_build_'))
        (cls.dir / 'server_build.dm').write_text(SOURCE, encoding='utf-8')
        (cls.dir / 'stubs.dm').write_text(STUBS, encoding='utf-8')
        (cls.dir / 'probe.dm').write_text(PROBE, encoding='utf-8')
        (cls.dir / 'fixture.dme').write_text('#include "stubs.dm"\n#include "server_build.dm"\n#include "probe.dm"\n', encoding='utf-8')
        built = subprocess.run(['DreamMaker', 'fixture.dme'], cwd=cls.dir, capture_output=True, text=True, timeout=300)
        assert '0 errors, 0 warnings' in built.stdout, built.stdout + built.stderr
        subprocess.run(['DreamDaemon', 'fixture.dmb', '-trusted', '-invisible'], cwd=cls.dir, capture_output=True,
                       text=True, timeout=120)
        cls.result = json.loads((cls.dir / 'probe-result.json').read_text(encoding='utf-8'))

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.dir, ignore_errors=True)

    def test_host_record(self):
        host = self.result['host']
        self.assertEqual((host['source'], host['revision']), ('host', 'a' * 40))
        self.assertEqual(host['has_compiled'], 0, 'a malformed time is left out')
        # A BYOND number holds realtime to about 100 s, so allow a couple of minutes.
        self.assertRegex(host['summary'], r'^aaaaaaa, updated 2026-11-16 03:00 UTC \((11[89]|12[0-2]) min ago\)$')
        html = host['html']
        self.assertIn("<a href='https://github.com/Civ13/Civ13/commit/" + 'a' * 40 + "'>aaaaaaa</a>", html)
        self.assertIn('Change: Fix &lt;b&gt; &amp; stuff', html)
        self.assertRegex(html, r'Committed: 2026-11-16 01:00 UTC \((23[89]|24[0-2]) min ago\)')
        self.assertRegex(html, r'Updated on this server: 2026-11-16 03:00 UTC \((11[89]|12[0-2]) min ago\)')
        self.assertNotIn('Compiled:', html)
        self.assertIn('Running since:', html)

    def test_lifecycle_fallback(self):
        self.assertEqual(self.result['lifecycle'], {'source': 'lifecycle', 'revision': 'b' * 40, 'summary': 'bbbbbbb'})

    def test_checkout_fallback(self):
        checkout = self.result['checkout']
        self.assertEqual((checkout['source'], checkout['revision']), ('checkout', 'c' * 40))
        self.assertIn('the running build may be older', checkout['html'])
        self.assertEqual(self.result['packed'], 'd' * 40)
        self.assertEqual(self.result['worktree_detached'], 'a' * 40)
        self.assertEqual(self.result['worktree_branch'], 'b' * 40)
        self.assertIsNone(self.result['nothing'])


if __name__ == '__main__':
    unittest.main()
