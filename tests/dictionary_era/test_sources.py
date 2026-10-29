"""Offline source/projection checks, not execution of DM semantics."""
import hashlib
import json
import re
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import prepare


def git_blob(text):
    data = text.encode('utf-8')
    return hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()


def check_helper(source):
    parser = prepare.proc(source, 'parse_dictionary_lines')
    apply = prepare.proc(source, 'apply_dictionary_replacements')
    assert 'if (entry.len != 2 && entry.len != 3 && entry.len != 4)' in parser
    assert 'if (entry.len >= 3)' in parser
    assert 'var/selector = trim(entry[3])' in parser
    assert 'list("0", "1", "2", "3", "4", "5", "6", "7", "8")' in parser
    assert parser.index('if (!(selector in ') < parser.index('entry[3] = text2num(selector)')
    assert "skipped.\"\n\t\t\t\tcontinue" in parser
    assert re.search(r'invalid era selector[^\n]+\n\t\t\t\tcontinue\n', parser)
    assert re.search(r'invalid mode[^\n]+\n\t\t\t\tcontinue\n', parser)
    assert 'entries += list(entry)' in parser
    assert not re.search(r'entry\[[12]\] =(?![=])', parser)
    assert 'if (entry.len >= 3 && (!map || entry[3] != map.ordinal_age))\n\t\t\tcontinue' in apply
    assert 'if (mode != "phrase")' in parser
    assert 'length(entry[1]) && entry[1] == trim(entry[1])' in parser
    assert 'if (text2ascii(entry[1], position) > 127)' in parser
    assert 'if (entry[4] != "phrase")\n\t\t\t\tcontinue' in apply
    assert '\t\telse\n\t\t\tmessage = replacetext(message, entry[1], entry[2])' in apply
    assert apply.index('for (var/list/entry in dictionary_list)') < apply.index('message = replacetext(message, entry[1], entry[2])')
    assert 'return message' in apply
    assert 'sanitize(' not in apply and 'capitalize(' not in apply


class DictionarySources(unittest.TestCase):
    def test_production_guards(self):
        check_helper(prepare.read(prepare.HELPER))

    def test_speech_whisper_complete_legacy_projection(self):
        expected = {prepare.SAY: 'add3bf6ba8e9e0cf150963a1396d75549dd9c068',
                    prepare.WHISPER: 'a3b12151099069ccec891105f9051d325bc1112f'}
        for path, sha in expected.items():
            with self.subTest(path=path):
                source = prepare.read(path)
                self.assertEqual(source.count(prepare.NEW_CALL), 1)
                self.assertEqual(git_blob(source.replace(prepare.NEW_CALL, prepare.OLD_LOOP)), sha)

    def test_loader_calls_validating_parser(self):
        setup = prepare.read('code/setup.dm')
        section = setup.split('var/F4 = file("config/dictionary.txt")', 1)[1].split('\n\telse', 1)[0]
        self.assertIn('dictionary_list += parse_dictionary_lines(dictionary_temp)', section)
        self.assertNotIn('dictionary_list += list(current)', section)

    def test_legacy_dictionary_bytes_preserved(self):
        data = prepare.read('config/dictionary.txt')
        header, remainder = data.split('\n', 1)
        original, additions = remainder.split('\n# Wiki slang', 1)
        self.assertNotIn(',', header)
        self.assertEqual(git_blob(original), '7a99ed15e2a1da238b2eedf39d892223a272c11c')
        self.assertTrue(additions.strip())

    def test_game_includes_helper_once(self):
        self.assertEqual(prepare.read('civ13.dme').count('#include "code\\_helpers\\dictionary.dm"'), 1)

    def test_guard_omission_controls(self):
        original = prepare.read(prepare.HELPER)
        controls = [('!map || ', ''), ('entry.len >= 3 &&', 'entry[3] &&'),
                    ('map.ordinal_age', 'map.age'), ('entry.len != 2 && entry.len != 3 && entry.len != 4', 'entry.len != 2'),
                    ('"7", "8"', '"7", "8", "9"'),
                    ('var/selector = trim(entry[3])', 'var/selector = entry[3]'),
                    ('\t\t\t\tcontinue', '\t\t\t\t// ignored invalid selector'),
                    ('entries += list(entry)', 'entries.Insert(1, list(entry))'),
                    ('entry[3] = text2num(selector)', 'entry[1] = trim(entry[1])')]
        for before, after in controls:
            with self.subTest(control=before):
                self.assertIn(before, original)
                with self.assertRaises((AssertionError, ValueError)):
                    check_helper(original.replace(before, after, 1))

    def test_preparer_binds_sources_without_native_execution(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / 'prepared'
            manifest = prepare.prepare(output)
            fixture = (output / 'fixture.dme').read_bytes()
            self.assertEqual(hashlib.sha256(fixture).hexdigest(), manifest['fixture_sha256'])
            self.assertEqual(json.loads((output / 'manifest.json').read_text()), manifest)
            self.assertIn(prepare.read(prepare.HELPER), fixture.decode())
            for status in ('native_compilation', 'native_execution', 'full_game'):
                self.assertEqual(manifest[status], 'not_run')
            for path, sha in manifest['source_sha256'].items():
                self.assertEqual(hashlib.sha256(prepare.read(path).encode()).hexdigest(), sha)
            self.assertIn('legacy say parity', fixture.decode())
            self.assertIn('era matrix', fixture.decode())
            self.assertNotIn('subprocess', prepare.read('tests/dictionary_era/prepare.py'))
            with self.assertRaises(FileExistsError):
                prepare.prepare(output)


if __name__ == '__main__':
    unittest.main()
