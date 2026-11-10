"""Execute paper-bin insertion and icon source offline, with fake engine effects.

This projection is not BYOND execution or visual/gameplay verification.
"""
import importlib.util
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/objects/items/bin.dm'
spec = importlib.util.spec_from_file_location('source_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)


class PaperList(list):
    def Add(self, paper):
        self.append(paper)


class Paper:
    def __init__(self):
        self.loc = None


class User:
    def drop_item(self):
        return True


class PaperBin:
    def __init__(self, amount):
        self.amount = amount
        self.icon_state = 'paper_bin0' if amount == 0 else 'paper_bin1'
        self.papers = PaperList()

    def run(self, source, declaration, paper, user=None):
        body = adapter.extract(source, declaration)
        # Qualify the two instance fields missing from the shared adapter's
        # field list. The complete proc remains subject to its syntax checks.
        body = re.sub(r'(?<![\w.])amount\b', 'src.amount', body)
        body = re.sub(r'(?<![\w.])papers\b', 'src.papers', body)
        code = declaration + '(i, user)\n' + body + '\n'
        env = {
            'istype': lambda value: isinstance(value, Paper),
            'visible_message': lambda message: None,
            'to_chat': lambda user, message: None,
            'SPAN_NOTICE': lambda message: message,
            'update_icon': lambda: self.update_icon(source),
        }
        proc = adapter.project(code, declaration, 'src,i,user', env, method=True)
        proc(self, paper, user)

    def update_icon(self, source):
        declaration = '/obj/item/weapon/paper_bin/update_icon'
        body = adapter.extract(source, declaration)
        body = re.sub(r'(?<![\w.])amount\b', 'src.amount', body)
        code = declaration + '()\n' + body + '\n'
        adapter.project(code, declaration, 'src', {}, method=True)(self)


class PaperBinAppearanceTests(unittest.TestCase):
    def test_old_order_negative_control(self):
        source = SOURCE.read_text(encoding='utf-8-sig')
        fixed = '\tpapers.Add(i)\n\tamount++\n\tupdate_icon()'
        old = '\tpapers.Add(i)\n\tupdate_icon()\n\tamount++'
        self.assertEqual(source.count(fixed), 2)
        source = source.replace(fixed, old)
        for path in ('proc/add', 'attackby'):
            with self.subTest(path=path):
                bin_ = PaperBin(0)
                bin_.run(source, '/obj/item/weapon/paper_bin/' + path, Paper(), User())
                self.assertEqual(bin_.amount, 1)
                self.assertEqual(bin_.icon_state, 'paper_bin0')

    def test_inserted_paper_updates_count_and_appearance(self):
        source = SOURCE.read_text(encoding='utf-8-sig')
        for path in ('proc/add', 'attackby'):
            for initial_amount in (0, 1):
                with self.subTest(path=path, initial_amount=initial_amount):
                    bin_ = PaperBin(initial_amount)
                    paper = Paper()
                    bin_.run(source, '/obj/item/weapon/paper_bin/' + path, paper, User())
                    self.assertIs(paper.loc, bin_)
                    self.assertEqual(bin_.papers, [paper])
                    self.assertEqual(bin_.amount, initial_amount + 1)
                    self.assertEqual(bin_.icon_state, 'paper_bin1')


if __name__ == '__main__':
    unittest.main()
