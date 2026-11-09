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


if __name__ == '__main__':
    unittest.main()
