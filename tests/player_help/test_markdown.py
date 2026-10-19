"""Negative controls for the independent native-render output oracle."""
import json
from pathlib import Path
import unittest

from render_contract import validate


class MarkdownOracleTests(unittest.TestCase):
    def test_case_inventory(self):
        cases = json.loads(Path(__file__).with_name('render-cases.json').read_text())
        self.assertEqual(len(cases), len({case['name'] for case in cases}))
        self.assertGreaterEqual(len(cases), 16)
        for case in cases:
            self.assertLessEqual(len(case['markdown']), 4000)
            self.assertEqual(case['expected_links'][-2:], [
                'https://civ13.github.io/civ13-wiki/',
                'https://civ13.github.io/Civ13/crafting/'])

    def test_footer_does_not_allow_answer_link(self):
        case = dict(name='footer', contains=[], absent=[],
                    expected_links=['https://example.org/wiki'])
        footer = "<a href='https://example.org/wiki'>Wiki</a>"
        validate(case, '<p>plain answer</p>' + footer)
        with self.assertRaises(ValueError):
            validate(case, '<a href="https://example.org/extra">answer</a>' + footer)
        with self.assertRaises(ValueError):
            validate(case, "<a href='https://example.org/extra'>answer</a>" + footer)

    def test_decoded_text_accepts_quote_entity_variants(self):
        case = dict(name='text', contains=[], absent=[], expected_links=[],
                    contains_text=['"onmouseover=evil'])
        for quote in ('&quot;', '&#34;'):
            validate(case, '<p>' + quote + 'onmouseover=evil</p>')
        with self.assertRaises(ValueError):
            validate(case, '<p>onmouseover=evil</p>')

    def test_rejects_injection_and_bad_structure(self):
        case = dict(name='oracle', contains=[], absent=[])
        for html in ('<script>x</script>', '<img src="https://example.org">',
                     '<a href="javascript:evil()">x</a>',
                     '<a href="byond://?src=x">x</a>',
                     '<a href="https://example.org" onclick="x">x</a>',
                     '<p style="color:red">x</p>', '<p><b>x</p></b>',
                     '<pre>unclosed', '<!--model comment-->'):
            with self.subTest(html=html), self.assertRaises(ValueError):
                validate(case, html)

    def test_accepts_supported_tags(self):
        validate(dict(name='oracle', contains=['<b>bold</b>'], absent=[]),
                 '<html><body><h2>Help</h2><p><b>bold</b> <i>italic</i><br>'
                 '&bull; item <code>&lt;script&gt;</code></p><pre>code\n</pre>'
                 '<a href="https://example.org/?a=1&amp;b=2">Wiki</a></body></html>')
