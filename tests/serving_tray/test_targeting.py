"""Exercise the tray attack's production targeting condition offline."""
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('tray_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)


def uses_body_branch(organ):
    source = (ROOT / 'code/game/objects/items/weapons/trays.dm').read_text(encoding='utf-8-sig')
    body = adapter.extract(source, '/obj/item/weapon/tray/attack')
    condition = next(line for line in body.splitlines() if line.lstrip().startswith('if ') and 'targeted_organ' in line)
    probe = '/test/proc/branch()\n' + condition.split('//', 1)[0].rstrip() + '\n\t\treturn TRUE\n\treturn FALSE\n'
    branch = adapter.project(probe, '/test/proc/branch', 'user', {})
    return branch(SimpleNamespace(targeted_organ=organ))


class ServingTrayTargetTest(unittest.TestCase):
    def test_head_and_eyes_use_face_hit_branch(self):
        for organ in ('head', 'eyes'):
            with self.subTest(organ=organ):
                self.assertFalse(uses_body_branch(organ))

    def test_other_body_parts_use_body_hit_branch(self):
        for organ in ('chest', 'l_arm'):
            with self.subTest(organ=organ):
                self.assertTrue(uses_body_branch(organ))


class ServingTrayLoadTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        source = (ROOT / 'code/game/objects/items/weapons/trays.dm').read_text(encoding='utf-8-sig')
        cls.weight = staticmethod(adapter.project(source, '/obj/item/weapon/tray/proc/carry_weight', 'I', {}))
        cls.total = staticmethod(adapter.project(
            source, '/obj/item/weapon/tray/proc/calc_carry', 'carrying',
            {'typed_iter': lambda items, kind: items, 'carry_weight': cls.weight}))
        pickup = adapter.extract(source, '/obj/item/weapon/tray/pickup')
        assert pickup.index('var/add = carry_weight(I)') < pickup.index('if (calc_carry() + add >= max_carry)')
        assert pickup.index('if (calc_carry() + add >= max_carry)') < pickup.index('I.loc = src')
        condition = next(line for line in pickup.splitlines() if 'if (calc_carry() + add' in line)
        probe = '/test/proc/stop()\n\t' + condition.strip() + '\n\t\treturn TRUE\n\treturn FALSE\n'
        cls.stop = staticmethod(adapter.project(probe, '/test/proc/stop', 'calc_carry, add, max_carry', {}))

    def test_item_sizes_and_total_load(self):
        for size, expected in ((0, 5), (1, 1), (1.5, 5), (2, 3), (3, 5)):
            with self.subTest(size=size):
                self.assertEqual(self.weight(SimpleNamespace(w_class=size)), expected)
        self.assertEqual(self.total([]), 0)
        self.assertEqual(self.total([SimpleNamespace(w_class=size) for size in (1, 2, 3)]), 9)

    def test_pickup_stops_at_capacity_before_moving_item(self):
        for current, added, expected in ((6, 3, False), (7, 3, True), (9, 5, True)):
            with self.subTest(current=current, added=added):
                self.assertEqual(self.stop(lambda: current, added, 10), expected)


if __name__ == '__main__':
    unittest.main()
