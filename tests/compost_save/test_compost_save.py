"""Compost bins keep their stock through a save of a running world (#5292).

Offline structural checks on current source. No BYOND, network or saves.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


def block(text, header):
    lines = text.splitlines()
    start = lines.index(header)
    body = []
    for line in lines[start + 1:]:
        if line and not line.startswith('\t'):
            break
        body.append(line)
    return '\n'.join(body)


class CompostSaveTests(unittest.TestCase):
    def setUp(self):
        self.source = read('code/modules/1713/production.dm')

    def test_stock_is_a_saved_field(self):
        decl = block(self.source, '/obj/structure/compost')
        self.assertRegex(decl, r'(?m)^\tvar/current = 0$')
        self.assertNotIn('var/tmp/current', decl)
        self.assertIn('var/tmp/composting', decl)

    def test_save_does_not_zero_the_live_bin(self):
        self.assertNotIn('/obj/structure/compost/before_save()', self.source)

    def test_load_restarts_the_cycle(self):
        self.assertIn('initialize()', block(self.source, '/obj/structure/compost/after_load()'))


if __name__ == '__main__':
    unittest.main()
