"""Offline lexicon data checks and literal/phrase replacement traces; no DM execution."""
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
MARKER = '\n# Wiki slang'
PERIODS = {2: '1013 AD', 3: '1713 AD', 4: '1873 AD', 5: '1896 AD',
           6: "1940's AD", 7: '1969 AD', 8: '1984 AD'}


def rows(text):
    return [line.split(',') for line in text.splitlines() if ',' in line]


BOUNDARIES = {9, 10, 11, 12, 13, 32, 33, 34, 40, 41, 44, 46, 58, 59, 63, 91, 93, 123, 125}


def phrase_replace(message, source, replacement):
    pattern = re.compile(re.escape(source), re.IGNORECASE | re.ASCII)
    parts, copied, search = [], 0, 0
    def boundary(position):
        return position < 0 or position >= len(message) or ord(message[position]) in BOUNDARIES
    while match := pattern.search(message, search):
        if boundary(match.start() - 1) and boundary(match.end()):
            parts.extend((message[copied:match.start()], replacement))
            copied = search = match.end()
        else:
            search = match.start() + 1
    return ''.join(parts) + message[copied:]


def apply_rows(message, entries, era):
    for row in entries:
        if len(row) >= 3 and (era is None or int(row[2]) != era):
            continue
        if len(row) == 4:
            if row[3] == 'phrase':
                message = phrase_replace(message, row[0], row[1])
        else:
            message = re.sub(re.escape(row[0]), lambda _: row[1], message,
                             flags=re.IGNORECASE | re.ASCII)
    return message


def validate_content(additions, legacy):
    seen = set()
    for source, replacement, era, mode in additions:
        assert era in {'2', '3', '4', '5', '6', '7', '8'}
        assert mode == 'phrase' and source and source == source.strip()
        assert replacement and replacement == replacement.strip()
        assert source.isascii() and replacement.isascii()
        identity = (source.lower(), era)
        assert identity not in seen
        seen.add(identity)
        # Check even across eras to avoid later surprises when content is moved.
        for target in [row[1] for row in legacy + additions]:
            assert source.strip().lower() not in target.lower()
        for old_source, _ in legacy:
            assert old_source.lower() not in source.lower()
            assert old_source.lower() not in replacement.lower()
        for _, old_target in legacy:
            # A surrounding sentence can supply the rest of a new trigger.
            assert old_target.strip().lower() not in source.lower(), (source, old_target)
    for i, (source, _, era, _) in enumerate(additions):
        for other, _, other_era, _ in additions[i + 1:]:
            if era == other_era:
                assert source.strip().lower() not in other.strip().lower()
                assert other.strip().lower() not in source.strip().lower()


class WikiSlangContent(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.plan = json.loads((ROOT / 'tests/dictionary_era/wiki_slang.json').read_text(encoding='utf-8'))
        text = (ROOT / 'config/dictionary.txt').read_text(encoding='utf-8')
        cls.original, appended = text.split(MARKER, 1)
        cls.legacy = rows(cls.original)
        cls.additions = rows(appended)
        cls.all_rows = cls.legacy + cls.additions

    def test_original_rows_are_unchanged_and_new_rows_are_explicitly_restricted(self):
        original = self.original.split('\n', 1)[1].encode()
        blob = hashlib.sha1(b'blob ' + str(len(original)).encode() + b'\0' + original).hexdigest()
        self.assertEqual(blob, '7a99ed15e2a1da238b2eedf39d892223a272c11c')
        self.assertEqual(len(self.legacy), 66)
        self.assertTrue(all(len(row) == 2 for row in self.legacy))
        self.assertEqual(Counter(row[2] for row in self.additions),
                         {'2': 6, '3': 8, '4': 9, '5': 10, '6': 6, '7': 5, '8': 6})

    def test_source_attribution_mapping_and_reviewed_inventory(self):
        source = self.plan['source']
        self.assertEqual(source['commit'], '8c361bc28cb5cfae3b215800622d509d534b7370')
        self.assertEqual(source['blob'], '966a476eb352c0a445c19192688b62d64aaf1437')
        self.assertEqual(source['license'], 'MIT')
        self.assertEqual({period: (item['ordinal'], item['engine_epoch'])
                          for period, item in self.plan['period_approximations'].items()},
                         {'1896 AD': (5, '1903'), '1984 AD': (8, '2013')})
        self.assertTrue(all('not an exact historical match' in item['basis']
                            for item in self.plan['period_approximations'].values()))
        notice = (ROOT / source['notice']).read_text(encoding='utf-8').encode()
        self.assertEqual(hashlib.sha1(b'blob ' + str(len(notice)).encode() + b'\0' + notice).hexdigest(),
                         source['license_blob'])
        expected = []
        for entry in self.plan['entries']:
            self.assertEqual(entry['period'], PERIODS[entry['era']])
            self.assertIn(entry['term'], source['selected_terms'][entry['period']])
            term = entry['term'].replace('’', "'").lower()
            self.assertIn(term, entry['replacement'].lower())
            expected.append([entry['source'], entry['replacement'], str(entry['era']), entry['mode']])
        self.assertEqual(self.additions, expected)

    def test_every_entry_in_all_nine_eras_and_without_map(self):
        for source, target, era, _ in self.additions:
            for active in [None, *range(9)]:
                with self.subTest(source=source, era=active):
                    message = 'before ' + source + ' after'
                    expected = 'before ' + target + ' after' if active == int(era) else message
                    self.assertEqual(apply_rows(message, self.all_rows, active), expected)
                    self.assertEqual(apply_rows(message.upper(), self.all_rows, active),
                                     'BEFORE ' + target + ' AFTER' if active == int(era) else message.upper())

    def test_legacy_outputs_are_preserved_with_new_content(self):
        for source, _ in self.legacy:
            for era in [None, *range(9)]:
                for message in ('before ' + source + ' after',
                                'before a talkative ' + source + ' after',
                                'before a really ' + source + ' thing after'):
                    self.assertEqual(apply_rows(message, self.all_rows, era),
                                     apply_rows(message, self.legacy, era))

    def test_phrase_boundaries_cover_edges_and_protect_fragments(self):
        for source, target, era, _ in self.additions:
            for left, right in [('', ''), ('', ' after'), ('before ', ''),
                                ('(', ')'), ('', ', please'), ('before ', '!'), ('"', '"')]:
                self.assertEqual(apply_rows(left + source + right, self.all_rows, int(era)),
                                 left + target + right)
            for neighbor in ['x', '0', '_', '-', "'", chr(233), chr(0x2014)]:
                for message in (neighbor + source, source + neighbor):
                    self.assertEqual(apply_rows(message, self.all_rows, int(era)),
                                     apply_rows(message, self.legacy, int(era)))
        self.assertEqual(apply_rows('the bravest are fearless-looking', self.all_rows, 4),
                         'the bravest are fearless-looking')

    def test_multiple_replacements_and_existing_overlap_semantics(self):
        self.assertEqual(apply_rows('they were brave and fearless today', self.all_rows, 4),
                         'they were bricky and bricky today')
        self.assertEqual(apply_rows('be brave brave now', self.all_rows, 4),
                         'be bricky bricky now')
        self.assertEqual(apply_rows('the rainy weather made us play cards tonight', self.all_rows, 3),
                         'the blashy weather made us study the history of the four kings tonight')
        self.assertEqual(apply_rows('get some sleep then count paper money later', self.all_rows, 6),
                         'get some shuteye then count greenbacks later')
        self.assertEqual(apply_rows('bring a dollar and use the telephone today', self.all_rows, 5),
                         'bring a simoleon and use the tube today')
        self.assertEqual(apply_rows('that was really good near my home yesterday', self.all_rows, 8),
                         'that was really bitchin near my crib yesterday')

    def test_no_conflicts_cycles_or_new_cascades(self):
        validate_content(self.additions, self.legacy)
        for _, replacement, era, _ in self.additions:
            self.assertEqual(apply_rows('before ' + replacement + ' after', self.all_rows, int(era)),
                             'before ' + replacement + ' after')

    def test_unsafe_content_controls_are_rejected(self):
        controls = [
            [['man', 'dame', '6']],
            [[' brave ', ' bricky ', '4'], [' brave ', ' bold ', '4']],
            [[' foo ', ' bar ', '3'], [' bar ', ' foo ', '3']],
            [[' awesome ', " twitchin' ", '7']],
            [[' a talkative woman ', ' a church-bell ', '4']],
            [[' a policeman ', ' a mutton shunter ', '4']],
            [[' play cards ', ' game ', '3'], [' cards ', ' hands ', '3']],
        ]
        for additions in controls:
            with self.subTest(additions=additions):
                with self.assertRaises(AssertionError):
                    validate_content([[row[0].strip(), row[1].strip(), row[2], 'phrase'] for row in additions], self.legacy)


if __name__ == '__main__':
    unittest.main()
