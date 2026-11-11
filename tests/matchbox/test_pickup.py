"""Project matchbox hand interaction with a fake pickup boundary, not BYOND."""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/objects/items/weapons/storage/boxes.dm'
DECL = '/obj/item/weapon/matchbox/attack_hand'
spec = importlib.util.spec_from_file_location('dm_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)


class Human:
    def __init__(self, held):
        self.l_hand = held
        self.r_hand = None
        self.matches = []

    def put_in_hands(self, match):
        self.matches.append(match)


class Matchbox:
    def __init__(self, count):
        self.currcap = count
        self.messages = []
        self.parent_calls = 0

    def click(self, held=False):
        human = Human(self if held else None)
        body = adapter.extract(SOURCE.read_text(encoding='utf-8'), DECL)
        body = body.replace('currcap', 'src.currcap')
        body = body.replace('new/obj/item/weapon/flame/match(H)', 'make_match(H)')
        body = body.replace('..()', 'parent()')
        code = DECL + '(mob/living/human/H)\n' + body + '\n'

        def parent():
            self.parent_calls += 1

        proc = adapter.project(code, DECL, 'src,H', {
            'to_chat': lambda _user, text: self.messages.append(text),
            'make_match': lambda _user: object(), 'parent': parent,
        }, method=True)
        proc(self, human)
        return human


class MatchboxPickupTests(unittest.TestCase):
    def test_unheld_boxes_use_normal_pickup_even_when_empty(self):
        for count in (0, 1, 10):
            with self.subTest(count=count):
                box = Matchbox(count)
                human = box.click()
                self.assertEqual(box.parent_calls, 1)
                self.assertEqual(box.currcap, count)
                self.assertEqual(human.matches, [])

    def test_held_empty_box_reports_empty_without_drawing(self):
        box = Matchbox(0)
        human = box.click(held=True)
        self.assertEqual(box.parent_calls, 0)
        self.assertEqual(len(box.messages), 1)
        self.assertEqual(box.currcap, 0)
        self.assertEqual(human.matches, [])

    def test_held_nonempty_box_dispenses_one_match(self):
        box = Matchbox(1)
        human = box.click(held=True)
        self.assertEqual(box.parent_calls, 0)
        self.assertEqual(box.currcap, 0)
        self.assertEqual(len(human.matches), 1)


if __name__ == '__main__':
    unittest.main()
