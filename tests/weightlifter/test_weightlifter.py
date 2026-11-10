"""Exercise the weight adjustment handler with fake engine effects."""
import sys
import unittest
from pathlib import Path
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests' / 'save_movement'))
import source_adapter


class WeightlifterTests(unittest.TestCase):
    def test_weights_cannot_change_during_lift(self):
        source = (ROOT / 'code/game/objects/structures/fitness.dm').read_text()
        source = source.replace('/obj/item/weapon/wrench', 'WRENCH')
        messages = []
        env = {'WRENCH': object(), 'istype': lambda item, kind: item is kind,
               'playsound': lambda *args: None,
               'to_chat': lambda *args: messages.append(args)}
        old_fields = source_adapter.FIELDS
        try:
            source_adapter.FIELDS += ('being_used', 'weight', 'qualifiers')
            adjust = source_adapter.project(
                source, '/obj/structure/fitness/weightlifter/attackby',
                'src, W, H', env, method=True)
        finally:
            source_adapter.FIELDS = old_fields
        machine = SimpleNamespace(being_used=1, weight=1, loc=None,
                                  qualifiers=SimpleNamespace(len=3))
        adjust(machine, env['WRENCH'], object())
        self.assertEqual(machine.weight, 1)
        self.assertEqual(len(messages), 1)
        machine.being_used = 0
        adjust(machine, env['WRENCH'], object())
        self.assertEqual(machine.weight, 2)
        machine.weight = 3
        adjust(machine, env['WRENCH'], object())
        self.assertEqual(machine.weight, 1)


if __name__ == '__main__':
    unittest.main()
