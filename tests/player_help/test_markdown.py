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
