"""What's New (code/modules/player_changelog): host collector and offline wiring.

scripts/gaia-host/player_changelog.py turns merged PRs' Changelog: lines into
config/player-changelog.json; the world shows it from the lobby, the Game Menu
and the OOC Changelog verb. Parsing mirrors tools/changelog/publish.mjs.
"""
import json
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts' / 'gaia-host'))
import player_changelog as pc  # noqa: E402

SOURCE = (ROOT / 'code/modules/player_changelog/player_changelog.dm').read_text(encoding='utf-8')
LOBBY = (ROOT / 'code/game/mob/new_player/new_player.dm').read_text(encoding='utf-8')
MENU = (ROOT / 'code/modules/client/escape_menu.dm').read_text(encoding='utf-8')
HOST = (ROOT / 'scripts/gaia-host/gaia_host.py').read_text(encoding='utf-8')
GROUP = (ROOT / 'scripts/shard-group/shard_group.py').read_text(encoding='utf-8')
DME = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
GITIGNORE = (ROOT / '.gitignore').read_text(encoding='utf-8')

A, B, C = 'a' * 40, 'b' * 40, 'c' * 40


def pull(number, sha, body, merged='2026-11-13T10:00:00Z'):
    return {'number': number, 'merge_commit_sha': sha, 'body': body, 'merged_at': merged}


class Parser(unittest.TestCase):
    def test_reads_the_one_visible_line(self):
        self.assertEqual(pc.changelog_line('## Change\n\nChangelog: Added boats.\r\n'), 'Added boats.')
        self.assertEqual(pc.changelog_line('changelog:   Fixed rafts.  '), 'Fixed rafts.')

    def test_blank_missing_and_hidden_lines_post_nothing(self):
        for body in (None, '', 'Changelog:', 'Changelog:   \nLater prose', 'No field here',
                     '<!-- Changelog: hidden -->', '```\nChangelog: example\n```', '~~~~\nChangelog: x\n~~~~'):
            self.assertIsNone(pc.changelog_line(body), body)

    def test_placeholders_and_unsafe_text_are_skipped(self):
        for text in ('TODO', 'n/a', '**Required**', 'Write your changelog here', 'None.',
                     'Ping @everyone', 'Use <b>bold</b>', 'x' * 1501):
            self.assertIsNone(pc.changelog_line('Changelog: ' + text), text)

    def test_two_fields_are_ambiguous(self):
        self.assertIsNone(pc.changelog_line('Changelog: one\nChangelog: two'))


class Collector(unittest.TestCase):
    def test_only_merged_prs_in_the_running_revision_newest_first(self):
        pulls = [pull(1, A, 'Changelog: Older.', '2026-11-12T09:00:00Z'),
                 pull(2, B, 'Changelog: Newer.', '2026-11-13T09:00:00Z'),
                 pull(3, C, 'Changelog: Not deployed yet.'),
                 dict(pull(4, A, 'Changelog: Closed unmerged.'), merged_at=None),
                 pull(5, B, 'No changelog.')]
        rows = pc.entries_from_pulls(pulls, lambda sha: sha in {A, B})
        self.assertEqual([(r['pr'], r['text'], r['date']) for r in rows],
                         [(2, 'Newer.', '2026-11-13'), (1, 'Older.', '2026-11-12')])
        self.assertEqual(rows[0]['merged_minute'], (1794560400 - pc.BYOND_EPOCH) // 60)

    def test_write_skips_a_known_revision_and_keeps_the_file_when_offline(self):
        with tempfile.TemporaryDirectory() as tmp:
            calls = []

            def fetch(url):
                calls.append(url)
                return [pull(7, A, 'Changelog: Added sails.')]
            self.assertEqual(pc.write(tmp, A, {A}, fetch, now=pc.BYOND_EPOCH + 600), 1)
            record = json.loads((Path(tmp) / pc.FILE).read_text(encoding='utf-8'))
            self.assertEqual(record['revision'], A)
            self.assertEqual(record['generated_minute'], 10)
            self.assertEqual(record['entries'][0]['text'], 'Added sails.')
            self.assertIn('state=closed', calls[0])
            self.assertIsNone(pc.write(tmp, A, {A}, fetch))
            self.assertEqual(len(calls), 1, 'the same revision does not ask GitHub again')

            def offline(url):
                raise OSError('no network')
            self.assertIsNone(pc.write(tmp, B, {A, B}, offline))
            self.assertEqual(json.loads((Path(tmp) / pc.FILE).read_text(encoding='utf-8'))['revision'], A)

    def test_history_from_rev_list(self):
        self.assertEqual(pc.history_from_output(0, A + '\n' + B + '\n'), {A, B})
        self.assertIsNone(pc.history_from_output(128, 'fatal'))


class Wiring(unittest.TestCase):
    def test_world_side(self):
        self.assertIn('#include "code\\modules\\player_changelog\\player_changelog.dm"', DME)
        self.assertIn('config/player-changelog.json', GITIGNORE.splitlines())
        self.assertIn('html_encode(entry["text"])', SOURCE)
        self.assertIn('set name = "Changelog"', SOURCE)
        self.assertIn("changelog=1'>What's New", LOBBY)
        self.assertIn('client.show_player_changelog()', LOBBY)
        self.assertIn('L["changelog"]', MENU)
        self.assertIn('owner.show_player_changelog()', MENU)

    def test_host_side_runs_after_the_world_is_up(self):
        start = HOST[HOST.index('    def do_start('):]
        start = start[:start.index('\n    def ', 10)]
        self.assertLess(start.index('self.platform.listening'), start.index('self.write_player_changelog(revision)'))
        self.assertIn('self.write_player_changelog(revision)', GROUP)


if __name__ == '__main__':
    unittest.main()
