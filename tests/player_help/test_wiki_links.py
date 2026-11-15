"""Wiki links must point at the GitHub Pages wiki, not the retired MediaWiki."""
from pathlib import Path
import re
import unittest
import urllib.parse


ROOT = Path(__file__).resolve().parents[2]
WIKI_ROOT = 'https://civ13.github.io/civ13-wiki/'
LEGACY = re.compile(r'civ13\.com/wiki|index\.php\?title=', re.IGNORECASE)


def config_value(key):
    for line in (ROOT / 'config/config.txt').read_text(encoding='utf-8').splitlines():
        if line.startswith(key + ' '):
            return line.split(' ', 1)[1].strip()
    return None


def wiki_page_url(url):
    """Python mirror of /proc/wiki_page_url in code/datums/configuration.dm."""
    lowered = url.lower()
    if 'civ13.com/wiki' not in lowered:
        return url
    at = lowered.find('title=')
    if at == -1:
        return WIKI_ROOT
    title = re.split('[&#]', url[at + 6:])[0]
    title = urllib.parse.unquote(title).replace(' ', '_')
    known = {
        'rules': 'rules/Rules.html',
        'server_rules': 'rules/Rules.html',
        'main_page': '',
        'new_player_guide': 'New_Player_Guide.html',
        'starter_guide': 'Starter_Guide.html',
        'hotkeys': 'Hotkeys.html',
        'mission_and_community_standards': 'Mission_and_Community_Standards.html',
    }
    if title.lower() in known:
        return WIKI_ROOT + known[title.lower()]
    if not title:
        return WIKI_ROOT
    return WIKI_ROOT + '?search=' + urllib.parse.quote_plus(title.replace('_', ' '))


class WikiLinkTests(unittest.TestCase):
    def test_config_links_use_github_pages_wiki(self):
        self.assertEqual(config_value('WIKIURL'), WIKI_ROOT)
        self.assertEqual(config_value('RULESURL'), WIKI_ROOT + 'rules/Rules.html')

    def test_no_legacy_wiki_links_in_shipped_sources(self):
        offenders = []
        for folder in ('code', 'config', 'interface', 'tools/opendream-client/native'):
            for path in (ROOT / folder).rglob('*'):
                if path.suffix not in {'.dm', '.txt', '.html', '.cs', '.json', '.dmf'}:
                    continue
                for number, line in enumerate(path.read_text(encoding='utf-8', errors='ignore').splitlines(), 1):
                    # The rewriter itself names the old host.
                    if path.name == 'configuration.dm' and 'civ13.com/wiki' in line and ('findtext' in line or line.lstrip().startswith('//')):
                        continue
                    if LEGACY.search(line):
                        offenders.append(f'{path.relative_to(ROOT)}:{number}')
        self.assertEqual(offenders, [])

    def test_rewriter_maps_known_and_unknown_pages(self):
        source = (ROOT / 'code/datums/configuration.dm').read_text(encoding='utf-8')
        self.assertIn('config.rulesurl = wiki_page_url(value)', source)
        self.assertIn('config.wikiurl = wiki_page_url(value)', source)
        for page in ('"rules" = "rules/Rules.html"', '"new_player_guide" = "New_Player_Guide.html"'):
            self.assertIn(page, source)
        self.assertEqual(wiki_page_url('http://civ13.com/wiki/index.php?title=Rules'),
                         WIKI_ROOT + 'rules/Rules.html')
        self.assertEqual(wiki_page_url('https://civ13.com/wiki/'), WIKI_ROOT)
        self.assertEqual(wiki_page_url('https://civ13.com/wiki/index.php?title=Iron_Smelting&action=view'),
                         WIKI_ROOT + '?search=Iron+Smelting')
        self.assertEqual(wiki_page_url(WIKI_ROOT), WIKI_ROOT)

    def test_mapped_pages_exist_in_wiki_sources(self):
        wiki = ROOT.parent / 'civ13-wiki' / 'src'
        if not wiki.is_dir():
            self.skipTest('civ13-wiki checkout not beside Civ13')
        for page in ('rules/Rules.md', 'New_Player_Guide.md', 'Starter_Guide.md',
                     'Hotkeys.md', 'Mission_and_Community_Standards.md'):
            self.assertTrue((wiki / page).is_file(), page)


if __name__ == '__main__':
    unittest.main()
