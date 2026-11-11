"""Exercise the wood ash handler's source control flow with fake engine effects."""
from pathlib import Path
from types import SimpleNamespace
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'save_movement'))
from source_adapter import project, read


class Container:
    def __init__(self, opened=True, volume=0, capacity=10):
        self.opened = opened
        self.reagents = SimpleNamespace(total_volume=volume, maximum_volume=capacity)
        self.additions = []
        self.reagents.add_reagent = lambda kind, amount: self.additions.append((kind, amount))

    def is_open_container(self):
        return self.opened


class WoodAshCollection(unittest.TestCase):
    def run_handler(self, container):
        ash = SimpleNamespace(loc=object(), deleted=False)
        effects = {'istype': lambda item: isinstance(item, Container),
                   'to_chat': lambda *args: None,
                   'qdel': lambda item: setattr(item, 'deleted', True)}
        handler = project(read('code/game/objects/items/misc.dm'),
                          '/obj/item/wood_ash/attackby', 'src, C, user', effects, method=True)
        handler(ash, container, object())
        return ash

    def test_closed_container_does_not_collect_or_delete_ash(self):
        container = Container(opened=False)
        ash = self.run_handler(container)
        self.assertEqual(container.additions, [])
        self.assertFalse(ash.deleted)

    def test_open_container_collects_ash(self):
        container = Container()
        ash = self.run_handler(container)
        self.assertEqual(container.additions, [('ash', 1)])
        self.assertTrue(ash.deleted)

    def test_full_container_does_not_collect_or_delete_ash(self):
        container = Container(volume=10)
        ash = self.run_handler(container)
        self.assertEqual(container.additions, [])
        self.assertFalse(ash.deleted)

    def test_non_container_does_not_delete_ash(self):
        ash = self.run_handler(object())
        self.assertFalse(ash.deleted)
