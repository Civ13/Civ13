"""Project the cabinet's real AltClick with inert spatial and actor boundaries."""
from pathlib import Path
import importlib.util
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/closets.dm'
spec = importlib.util.spec_from_file_location('cabinet_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)
adapter.FIELDS += ('opened', 'update_icon')
DECL = '/obj/structure/closet/cabinet/extinguisher_cabinet/AltClick'


def toggle(source, near, incapacitated, human=True, opened=False):
    cabinet = SimpleNamespace(opened=opened, updates=0)
    def update_icon():
        cabinet.updates += 1
    cabinet.update_icon = update_icon
    actor = SimpleNamespace(Adjacent=lambda target: near, incapacitated=lambda: incapacitated)
    proc = adapter.project(source, DECL, 'src, user', {'ishuman': lambda user: human}, method=True)
    proc(cabinet, actor)
    return cabinet.opened, cabinet.updates


class CabinetAltClickTest(unittest.TestCase):
    def test_distant_actor_cannot_toggle(self):
        self.assertEqual(toggle(SOURCE.read_text(encoding='utf-8-sig'), False, False), (False, 0))

    def test_incapacitated_actor_cannot_toggle(self):
        self.assertEqual(toggle(SOURCE.read_text(encoding='utf-8-sig'), True, True), (False, 0))

    def test_adjacent_capable_human_can_open_and_close(self):
        source = SOURCE.read_text(encoding='utf-8-sig')
        self.assertEqual(toggle(source, True, False), (True, 1))
        self.assertEqual(toggle(source, True, False, opened=True), (False, 1))
        self.assertEqual(toggle(source, True, False, human=False), (False, 0))


if __name__ == '__main__':
    unittest.main()
