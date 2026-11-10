"""Project the septim icon update offline; this does not run BYOND or render sprites."""
import importlib.util
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/objects/items/stacks/money.dm'
DECL = '/obj/item/stack/money/septim/update_icon'
spec = importlib.util.spec_from_file_location('source_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)


class Septim:
    def __init__(self, amount, icon_state):
        self.amount = amount
        self.icon_state = icon_state
        self.parent_calls = 0

    def update(self, source):
        body = adapter.extract(source, DECL)
        body = re.sub(r'(?<![\w.])amount\b', 'src.amount', body)
        body = body.replace('..()', 'parent()')

        def parent():
            # Septims inherit novariants=TRUE, so the money parent returns.
            self.parent_calls += 1

        proc = adapter.project(DECL + '()\n' + body + '\n', DECL, 'src',
                               {'parent': parent}, method=True)
        proc(self)


class SeptimAppearanceTests(unittest.TestCase):
    def test_split_to_one_restores_single_coin(self):
        source = SOURCE.read_text(encoding='utf-8-sig')
        for previous in ('septim_2', 'septim_100'):
            with self.subTest(previous=previous):
                coin = Septim(1, previous)
                coin.update(source)
                self.assertEqual(coin.icon_state, 'septim')
                self.assertEqual(coin.parent_calls, 1)

    def test_other_stack_sizes_keep_their_appearance(self):
        source = SOURCE.read_text(encoding='utf-8-sig')
        for amount, expected in ((2, 'septim_2'), (7, 'septim_7'),
                                 (10, 'septim_10'), (100, 'septim_100'),
                                 (500, 'septim_500')):
            with self.subTest(amount=amount):
                coin = Septim(amount, 'septim')
                coin.update(source)
                self.assertEqual(coin.icon_state, expected)

    def test_original_source_negative_control(self):
        source = SOURCE.read_text(encoding='utf-8-sig')
        fixed = '\tif(amount == 1)\n\t\ticon_state = "septim"\n'
        self.assertEqual(source.count(fixed), 1)
        coin = Septim(1, 'septim_2')
        coin.update(source.replace(fixed, '', 1))
        self.assertEqual(coin.icon_state, 'septim_2')


if __name__ == '__main__':
    unittest.main()
