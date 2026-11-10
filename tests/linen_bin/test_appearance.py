"""Project linen bin count and icon changes from its ordinary action paths."""
from pathlib import Path
import re
import unittest


SOURCE = Path(__file__).resolve().parents[2] / 'code/game/objects/structures/bedsheet_bin.dm'
TEXT = SOURCE.read_text(encoding='utf-8')


def body(proc):
    return TEXT.split('/obj/structure/bedsheetbin/' + proc + '(', 1)[1].split('\n/obj/', 1)[0]


def icon_for(amount):
    switch = body('update_icon')
    pattern = r'if \(0\)\s+icon_state = "([^"]+)"\s+if \(1 to 10\)\s+icon_state = "([^"]+)"\s+else\s+icon_state = "([^"]+)"'
    match = re.search(pattern, switch)
    if not match:
        raise AssertionError('Linen-bin icon mapping changed; update this projection')
    return match.group(1 if amount == 0 else 2 if amount <= 10 else 3)


def action(amount, icon, proc):
    # Project count and icon effects on the successful sheet path only.
    for line in body(proc).splitlines():
        token = line.strip()
        if token == 'amount++':
            amount += 1
        elif token == 'amount--':
            amount -= 1
        elif token == 'update_icon()':
            icon = icon_for(amount)
    return amount, icon


class LinenBinAppearanceTests(unittest.TestCase):
    def test_taking_sheets_updates_half_and_empty_appearances(self):
        amount, icon = 20, 'linenbin-full'
        for _ in range(10):
            amount, icon = action(amount, icon, 'attack_hand')
        self.assertEqual((amount, icon), (10, 'linenbin-half'))
        for _ in range(10):
            amount, icon = action(amount, icon, 'attack_hand')
        self.assertEqual((amount, icon), (0, 'linenbin-empty'))

    def test_returning_sheets_updates_half_and_full_appearances(self):
        amount, icon = action(0, 'linenbin-empty', 'attackby')
        self.assertEqual((amount, icon), (1, 'linenbin-half'))
        for _ in range(10):
            amount, icon = action(amount, icon, 'attackby')
        self.assertEqual((amount, icon), (11, 'linenbin-full'))


if __name__ == '__main__':
    unittest.main()
