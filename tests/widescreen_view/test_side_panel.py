"""Side panel (interface/info/info.html): grouped command sections, search and
tab order, with the server hooks the panel talks through left intact.

Offline checks on the page source. The grouping tables name verbs by their
in-game names; a verb missing from them still shows up under "Other".
"""
from pathlib import Path
import glob
import json
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
PAGE = (ROOT / 'interface/info/info.html').read_text(encoding='utf-8')


def js_object(name):
    """Returns the JSON-compatible literal assigned to `const name = ...;`."""
    start = PAGE.index(f'const {name} = ') + len(f'const {name} = ')
    end = PAGE.index(';\n', start)
    text = re.sub(r'//[^\n]*', '', PAGE[start:end])
    return json.loads(text)


def verb_names():
    names = set()
    for path in glob.glob(str(ROOT / 'code/**/*.dm'), recursive=True):
        source = Path(path).read_text(encoding='utf-8', errors='replace')
        for m in re.finditer(r'(?:/verb/|\n/?[\w/]*?proc/)(\w+)\([^\n]*\)\n((?:\t[^\n]*\n){0,8})', source):
            named = re.search(r'set name = "([^"]+)"', m[2])
            names.add(named[1] if named else m[1].replace('_', ' '))
    return names


class SidePanelHooks(unittest.TestCase):
    def test_server_hooks_are_kept(self):
        for hook in ('action=statpanel_ready', 'action=statpanel_tab', 'action=execute_verb',
                     'action=refocus_map', 'window.receiveStats = receiveStats'):
            self.assertIn(hook, PAGE)

    def test_unlisted_verbs_fall_back_to_other_or_their_category(self):
        self.assertIn('sections.push(["Other", rest])', PAGE)
        self.assertIn('grouped[v.category]', PAGE)

    def test_search_and_tab_order(self):
        self.assertIn('id="search"', PAGE)
        self.assertEqual(js_object('TAB_ORDER')[0], 'Status')


class SidePanelTables(unittest.TestCase):
    def test_groups_list_each_verb_once_and_name_real_verbs(self):
        groups = js_object('GROUPS')
        known = verb_names()
        for tab, sections in groups.items():
            seen = []
            for title, names in sections:
                self.assertTrue(title)
                seen += names
            self.assertEqual(len(seen), len(set(seen)), tab)
            missing = [n for n in seen if n not in known]
            self.assertEqual(missing, [], tab)

    def test_labels_only_rename_listed_verbs(self):
        labels = js_object('LABELS')
        listed = {n for sections in js_object('GROUPS').values() for _, names in sections for n in names}
        self.assertEqual(sorted(set(labels) - listed), [])


if __name__ == '__main__':
    unittest.main()
