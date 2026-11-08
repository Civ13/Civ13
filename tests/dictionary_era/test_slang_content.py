"""Dictionary data checks: the wiki slang inventory and row hygiene. No BYOND."""
from collections import Counter
import hashlib
import json
from pathlib import Path
import sys
import unittest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import reference  # noqa: E402

ROOT = HERE.parents[1]
MARKER = '\n# Wiki slang'
PERIODS = {2: '1013 AD', 3: '1713 AD', 4: '1873 AD', 5: '1896 AD',
           6: "1940's AD", 7: '1969 AD', 8: '1984 AD'}


def say(text, rows, era):
    return reference.apply(reference.say_prefix(text), rows, era)


class DictionaryContent(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.plan = json.loads((HERE / 'wiki_slang.json').read_text(encoding='utf-8'))
        cls.text = (ROOT / 'config/dictionary.txt').read_text(encoding='utf-8')
        cls.rows = reference.current_rows()
        general, appended = cls.text.split(MARKER, 1)
        cls.general = reference.parse(general.split('\n'))[0]
        cls.additions = reference.parse(appended.split('\n'))[0]

    def test_every_line_parses(self):
        lines = [line for line in self.text.split('\n') if ',' in line and not line.startswith('#')]
        rows, accepted = reference.parse(lines)
        self.assertEqual(len(rows), len(lines))
        self.assertTrue(all(accepted))

    def test_general_rows_are_unrestricted_and_wiki_rows_are_by_era(self):
        self.assertTrue(all(era is None for _, _, era in self.general))
        self.assertGreaterEqual(len(self.general), 66)
        self.assertEqual(Counter(era for _, _, era in self.additions),
                         {2: 6, 3: 8, 4: 9, 5: 10, 6: 6, 7: 5, 8: 6})

    def test_source_attribution_mapping_and_reviewed_inventory(self):
        source = self.plan['source']
        self.assertEqual(source['commit'], '8c361bc28cb5cfae3b215800622d509d534b7370')
        self.assertEqual(source['blob'], '966a476eb352c0a445c19192688b62d64aaf1437')
        self.assertEqual(source['license'], 'MIT')
        self.assertEqual({period: (item['ordinal'], item['engine_epoch'])
                          for period, item in self.plan['period_approximations'].items()},
                         {'1896 AD': (5, '1903'), '1984 AD': (8, '2013')})
        notice = (ROOT / source['notice']).read_text(encoding='utf-8').encode()
        self.assertEqual(hashlib.sha1(b'blob ' + str(len(notice)).encode() + b'\0' + notice).hexdigest(),
                         source['license_blob'])
        expected = []
        for entry in self.plan['entries']:
            self.assertEqual(entry['period'], PERIODS[entry['era']])
            self.assertIn(entry['term'], source['selected_terms'][entry['period']])
            self.assertIn(entry['term'].replace('’', "'").lower(), entry['replacement'].lower())
            expected.append((entry['source'], entry['replacement'], entry['era']))
        self.assertEqual(self.additions, expected)

    def test_every_wiki_entry_only_in_its_era(self):
        for source, target, era in self.additions:
            for active in reference.ERAS:
                with self.subTest(source=source, era=active):
                    expected = 'Before ' + (target if active == era else reference.html_encode(source)) + ' after'
                    self.assertEqual(say('before ' + source + ' after', self.rows, active), expected)

    def test_no_row_feeds_or_hides_another(self):
        # One pass never rescans output, but a replacement that contains
        # another source would read as a missed match, so keep them apart.
        for era in reference.ERAS:
            table = reference.table(self.rows, era)
            sources = [s for s, _ in table]
            for _, replacement in table:
                with self.subTest(replacement=replacement, era=era):
                    message = 'before ' + reference.html_encode(replacement) + ' after'
                    self.assertEqual(reference.apply(message, self.rows, era), message)
            self.assertEqual(len(set(map(reference.ascii_lower, sources))), len(sources))

    def test_wiki_examples(self):
        self.assertEqual(say('they were brave and fearless today', self.rows, 4), 'They were bricky and bricky today')
        self.assertEqual(say('the rainy weather made us play cards tonight', self.rows, 3),
                         'The blashy weather made us study the history of the four kings tonight')
        self.assertEqual(say('get some sleep then count paper money later', self.rows, 6),
                         'Get some shuteye then count greenbacks later')
        self.assertEqual(say('bring a dollar and use the telephone today', self.rows, 5),
                         'Bring a simoleon and use the tube today')
        self.assertEqual(say('that was really good near my home yesterday', self.rows, 8),
                         'That was really bitchin near my crib yesterday')
        self.assertEqual(say('ask the lord\'s steward', self.rows, 2), 'Ask the bailiff')


if __name__ == '__main__':
    unittest.main()
