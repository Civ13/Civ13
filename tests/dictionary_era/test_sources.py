"""Source wiring checks for the speech dictionary. No BYOND."""
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import prepare  # noqa: E402

OLD_LOOP = '\tfor (var/i in dictionary_list)\n\t\tmessage = replacetext(message,i[1],i[2])'


def git_blob(text):
    data = text.encode('utf-8')
    return hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()


class DictionarySources(unittest.TestCase):
    def test_speech_and_whisper_call_sites_unchanged(self):
        expected = {prepare.SAY: 'add3bf6ba8e9e0cf150963a1396d75549dd9c068',
                    prepare.WHISPER: 'a3b12151099069ccec891105f9051d325bc1112f'}
        for path, sha in expected.items():
            with self.subTest(path=path):
                source = prepare.read(path)
                self.assertEqual(source.count(prepare.CALL), 1)
                self.assertEqual(git_blob(source.replace(prepare.CALL, OLD_LOOP)), sha)

    def test_loader_builds_the_tables_once(self):
        setup = prepare.read('code/setup.dm')
        section = setup.split('var/F4 = file("config/dictionary.txt")', 1)[1].split('\n\telse', 1)[0]
        self.assertIn('load_speech_dictionary(dictionary_temp)', section)
        self.assertNotIn('dictionary_list +=', section)

    def test_include_order(self):
        dme = prepare.read('civ13.dme')
        helper = '#include "code\\_helpers\\dictionary.dm"'
        self.assertEqual(dme.count(helper), 1)
        self.assertLess(dme.index('#include "code\\__defines\\_rust_g.dm"'), dme.index(helper))

    def test_helper_keeps_era_rustg_fallback_and_self_test(self):
        helper = prepare.read(prepare.HELPER)
        apply = prepare.proc(helper, 'apply_dictionary_replacements')
        self.assertIn('map ? map.ordinal_age : null', apply)
        # The vendored rustg_setup_acreplace_with_options macro calls the
        # three-argument setup_acreplace, so the helper names the right export.
        self.assertIn('RUSTG_CALL(RUST_G, "setup_acreplace_with_options")', helper)
        self.assertNotIn('rustg_setup_acreplace_with_options(', helper)
        self.assertIn('"match_kind" = "LeftmostLongest"', helper)
        self.assertIn('"ascii_case_insensitive" = 1', helper)
        setup = helper.split('/datum/speech_dictionary/proc/setup_rustg()', 1)[1].split('\n/', 1)[0]
        self.assertIn('\ttry\n', setup)
        self.assertIn('\tcatch\n', setup)
        self.assertIn('!= match_regex(table, view)', setup)
        self.assertEqual(setup.count('return FALSE'), 2)
        self.assertIn('use_rustg ? RUSTG_CALL(RUST_G, "acreplace")(table.key, view) : match_regex(table, view)', helper)

    def test_preparer_is_deterministic(self):
        with tempfile.TemporaryDirectory() as tmp:
            first = prepare.prepare(Path(tmp) / 'a')
            second = prepare.prepare(Path(tmp) / 'b')
            self.assertEqual(first, second)
            fixture = (Path(tmp) / 'a' / 'fixture.dme').read_text(encoding='utf-8')
            self.assertIn(prepare.read(prepare.HELPER), fixture)
            self.assertIn(prepare.read('tests/dictionary_era/legacy/dictionary.dm'), fixture)
            self.assertIn('/proc/legacy_say(message)', fixture)
            inputs = json.loads((Path(tmp) / 'a' / 'inputs.json').read_text(encoding='utf-8'))
            self.assertEqual(len(inputs['records']), first['records'])
            with self.assertRaises(FileExistsError):
                prepare.prepare(Path(tmp) / 'a')

    def test_frozen_legacy_data_is_the_pre_rework_dictionary(self):
        # config/dictionary.txt as of Civ13 commit 21f0473, before the rework.
        self.assertEqual(git_blob(prepare.read('tests/dictionary_era/legacy/dictionary.txt')),
                         'acfb4e80f2f1bca09a59d9bd954f0e335da08119')

if __name__ == '__main__':
    unittest.main()
