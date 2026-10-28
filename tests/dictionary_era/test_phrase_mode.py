"""Phrase source contracts and offline reference traces; no native execution."""
from pathlib import Path
import re
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import prepare
from test_slang_content import BOUNDARIES, apply_rows, phrase_replace


def schema_row(text):
    row = text.split(',')
    if len(row) not in (2, 3, 4):
        return None
    if len(row) >= 3:
        if row[2].strip() not in list('012345678'):
            return None
        row[2] = row[2].strip()
    if len(row) == 4:
        if row[3].strip() != 'phrase' or not row[0] or row[0] != row[0].strip() or not row[0].isascii():
            return None
        row[3] = 'phrase'
    return row


def check_phrase_source(source):
    boundary = prepare.proc(source, 'dictionary_phrase_boundary')
    scanner = prepare.proc(source, 'replace_dictionary_phrase')
    assert 'position < 1 || position > length(message)' in boundary
    values = re.search(r'\t\tif \(([0-9, ]+)\)', boundary)[1]
    assert {int(x) for x in values.split(',')} == BOUNDARIES
    assert 'if (!source_length)\n\t\treturn message' in scanner
    assert 'dictionary_phrase_boundary(message, match_at - 1) && dictionary_phrase_boundary(message, match_at + source_length)' in scanner
    assert 'result += copytext(message, copied_through, match_at) + replacement' in scanner
    assert '\n\t\t\tcopied_through = match_at + source_length\n' in scanner
    assert 'search_from = copied_through' in scanner
    assert 'search_from = match_at + 1' in scanner
    assert 'findtext(message, source, search_from)' in scanner
    assert 'return result + copytext(message, copied_through)' in scanner
    assert 'message =' not in scanner


class PhraseMode(unittest.TestCase):
    def test_production_scanner_contract_and_omission_controls(self):
        source = prepare.read(prepare.HELPER)
        check_phrase_source(source)
        for before, after in [('32, 33', '32, 39, 33'),
                              ('position < 1', 'position < 0'),
                              ('match_at - 1', 'match_at'),
                              ('copied_through = match_at + source_length', 'copied_through = match_at + source_length + 1'),
                              ('search_from = copied_through', 'search_from = 1'),
                              ('search_from = match_at + 1', 'search_from = match_at + source_length'),
                              ('findtext(message, source, search_from)', 'findtext(result, source, search_from)')]:
            with self.subTest(control=before):
                with self.assertRaises((AssertionError, TypeError)):
                    check_phrase_source(source.replace(before, after))

    def test_malformed_modes_and_old_field_shapes(self):
        for text in ['a,b,0,', 'a,b,0,literal', 'a,b,0,PHRASE', 'a,b,0,regex',
                     'a,b,,phrase', 'a,b,9,phrase', 'a,b,0,phrase,extra',
                     ',b,0,phrase', ' a,b,0,phrase', 'a ,b,0,phrase', 'caf\u00e9,b,0,phrase']:
            self.assertIsNone(schema_row(text), text)
        self.assertEqual(schema_row(' a , b '), [' a ', ' b '])
        self.assertEqual(schema_row(' a , b , 0 '), [' a ', ' b ', '0'])
        self.assertEqual(schema_row('a,b,0, phrase\r'), ['a', 'b', '0', 'phrase'])

    def test_starts_ends_punctuation_and_no_recasing(self):
        rules = [['excuse me', 'mind the grease', '4', 'phrase']]
        for text, expected in [('Excuse me', 'mind the grease'),
                               ('Excuse me, please', 'mind the grease, please'),
                               ('Please excuse me!', 'Please mind the grease!'),
                               ('(excuse me)', '(mind the grease)'),
                               ('excuse me now', 'mind the grease now')]:
            self.assertEqual(apply_rows(text, rules, 4), expected)
        self.assertEqual(apply_rows('Excuse me', rules, 3), 'Excuse me')
        self.assertEqual(apply_rows('Excuse me', rules, None), 'Excuse me')

    def test_all_neighbor_bytes_and_unicode_are_conservative(self):
        for value in range(128):
            neighbor = chr(value)
            self.assertEqual(phrase_replace(neighbor + 'cat', 'cat', 'X'),
                             neighbor + ('X' if value in BOUNDARIES else 'cat'))
            self.assertEqual(phrase_replace('cat' + neighbor, 'cat', 'X'),
                             ('X' if value in BOUNDARIES else 'cat') + neighbor)
        for neighbor in ['\u00e9', '\u2014', '\u2019', '\u4e2d']:
            self.assertEqual(phrase_replace(neighbor + 'cat' + neighbor, 'cat', 'X'),
                             neighbor + 'cat' + neighbor)

    def test_single_scan_repeated_adjacent_and_rejected_overlap(self):
        self.assertEqual(phrase_replace('a a', 'a', 'a a'), 'a a a a')
        self.assertEqual(phrase_replace('be brave brave now', 'brave', 'bricky'), 'be bricky bricky now')
        self.assertEqual(phrase_replace('xa a a', 'a a', 'X'), 'xa X')
        self.assertEqual(phrase_replace('a.b aXb', 'a.b', 'X'), 'X aXb')

    def test_mixed_rows_keep_literal_substrings_order_and_overlap(self):
        rules = [['lol', 'hahaha'], ['cat', 'dog', '4'], ['dog', 'wolf', '4', 'phrase']]
        self.assertEqual(apply_rows('lol catapult cat', rules, 4), 'hahaha dogapult wolf')
        self.assertEqual(apply_rows('lol catapult cat', rules, 3), 'hahaha catapult cat')
        self.assertEqual(apply_rows('cat cat cat', [[' cat ', ' dog ', '4']], 4), 'cat dog cat')
        self.assertEqual(apply_rows('a', [['a', 'b', '4', 'phrase'], ['b', 'c', '4', 'phrase']], 4), 'c')


if __name__ == '__main__':
    unittest.main()
