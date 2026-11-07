"""Old-vs-new regression corpus for the speech dictionary.

corpus.json holds the DM fixture's output for every corpus line, from the
frozen legacy helper (`old`) and the production helper (`new`). These checks
need no BYOND: they confirm both Python models reproduce the recorded output,
that the corpus is current, and that old and new differ only where the rework
meant them to. Regenerate with `prepare.py --output <dir> --write`.
"""
import json
from pathlib import Path
import sys
import unittest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import prepare  # noqa: E402
import reference  # noqa: E402

# Shapes where whole-word matching, casing or entity handling change output.
CHANGED_SHAPES = {'inside_right', 'inside_left', 'plural', 'possessive', 'quoted', 'hyphen',
                  'start', 'alone', 'caps', 'sentence'}
# Rows an earlier row used to swallow, and rows the rework added.
SHADOWED = {'pm the admins', 'gamergirl', 'gamers rise up', 'poggers'}


def visible(text):
    return ''.join('\\x%02x' % ord(c) if ord(c) < 32 else c for c in text)


def prefix(text, kind):
    return reference.say_prefix(text) if kind == 'say' else reference.sanitize(text)


class Corpus(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.corpus = json.loads((HERE / 'corpus.json').read_text(encoding='utf-8'))
        cls.old_rows = reference.frozen_legacy_rows()
        cls.new_rows = reference.current_rows()
        cls.old_sources = {row[0] for row in cls.old_rows}

    def test_corpus_matches_current_inputs(self):
        expected = [(kind, source, era, text, pre) for kind, source, era, text, pre in prepare.corpus_lines()]
        recorded = [(r['kind'], r['source'], r['era'], r['text'], r['prefix']) for r in self.corpus['records']]
        self.assertEqual(recorded, expected, 'corpus.json is stale; rerun prepare.py --write')
        self.assertEqual([r['line'] for r in self.corpus['parser']], prepare.PARSER_LINES)

    def test_legacy_model_reproduces_recorded_old_output(self):
        for record in self.corpus['records']:
            with self.subTest(text=record['text'], era=record['era']):
                message = prefix(record['text'], record['prefix'])
                self.assertEqual(visible(reference.legacy_apply(message, self.old_rows, record['era'])), record['old'])

    def test_new_model_reproduces_recorded_new_output(self):
        for record in self.corpus['records']:
            with self.subTest(text=record['text'], era=record['era']):
                message = prefix(record['text'], record['prefix'])
                self.assertEqual(visible(reference.apply(message, self.new_rows, record['era'])), record['new'])

    def test_old_and_new_differ_only_where_intended(self):
        for record in self.corpus['records']:
            if record['old'] == record['new'] or record['kind'] in CHANGED_SHAPES:
                continue
            source = record['source']
            # Apostrophes reach the dictionary as &#39;, which old rows never matched.
            intended = (source in SHADOWED or source not in self.old_sources or "'" in source
                        or any(source != other and source.lower() in other.lower() for other in self.old_sources))
            # Literal rows used to match next to punctuation like :b in :bread.
            intended = intended or (record['kind'] == 'punctuation' and not source[-1].isalnum())
            with self.subTest(kind=record['kind'], text=record['text'], era=record['era']):
                self.assertTrue(intended, (record['old'], record['new']))

    def test_parser_model_matches_recorded_diagnostics(self):
        for record in self.corpus['parser']:
            with self.subTest(line=record['line']):
                _, accepted = reference.parse([record['line']])
                self.assertEqual(bool(accepted and accepted[0]), bool(record['accepted']))

    def test_notable_changes(self):
        def say(text, era=None):
            return reference.apply(reference.say_prefix(text), self.new_rows, era)
        self.assertEqual(say('the cuckoo ate my lollipop in the bungalow'),
                         'The cuckoo ate my lollipop in the bungalow')
        self.assertEqual(say('my gamergirl friend'), 'My woman friend')
        self.assertEqual(say('poggers'), 'Awesome')
        self.assertEqual(say('pm the admins please'), 'Pray to the gods please')
        self.assertEqual(say('GAMERS RISE UP'), "BROTHERS LET'S FIGHT")
        self.assertEqual(say(':b :bread'), 'haha :bread')
        self.assertEqual(say('Excuse me!', 4), 'Mind the grease!')
        self.assertEqual(say('"brave"', 4), '&#34;bricky&#34;')
        self.assertEqual(say("that's gross", 8), 'Gag me with a spoon')
        self.assertEqual(say('be brave brave now', 4), 'Be bricky bricky now')
        self.assertEqual(say('brave-looking bravest', 4), 'Brave-looking bravest')
        self.assertEqual(say('excuse me', 3), 'Excuse me')

    def test_corpus_covers_every_row_and_era(self):
        sources = {(r['source'], r['era']) for r in self.corpus['records']}
        for source, _, era in self.new_rows:
            self.assertIn((source, era), sources)
        self.assertEqual({r['era'] for r in self.corpus['records'] if r['kind'] == 'sentence'},
                         set(reference.ERAS))


if __name__ == '__main__':
    unittest.main()
