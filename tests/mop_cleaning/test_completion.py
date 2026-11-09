"""Execute the production mop completion body with inert actor and turf stubs."""
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('mop_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)
adapter.FIELDS += ('reagents',)
SOURCE = ROOT / 'code/game/objects/items/weapons/mop.dm'


def complete(contents):
    body = adapter.extract(SOURCE.read_text(), '/obj/item/weapon/mop/afterattack')
    tail = body[body.index('\tif (do_after(user, 40, T))'):]
    source = '/test/proc/complete()\n' + tail + '\n'
    messages = []
    reagents = SimpleNamespace(has_reagent=lambda name, amount: contents.get(name, 0) >= amount)
    actor = object()
    def clean(mop, user):
        if not (mop.reagents.has_reagent('water', True) or mop.reagents.has_reagent('cleaner', True)):
            messages.append('refused')
        else:
            messages.append('cleaned')
        contents.clear()  # Shared turf.clean consumes fluid after checking it.
    target = SimpleNamespace(clean=clean)
    env = {'do_after': lambda *args: True, 'to_chat': lambda user, text: messages.append('finished')}
    proc = adapter.project(source, '/test/proc/complete', 'src, user, T', env, method=True)
    proc(SimpleNamespace(reagents=reagents), actor, target)
    return messages


class MopCleaningTest(unittest.TestCase):
    def test_non_cleaning_liquid_does_not_report_success(self):
        self.assertEqual(complete({'oil': 5}), ['refused'])

    def test_cleaning_liquid_reports_success_even_if_consumed(self):
        for name in ('water', 'cleaner'):
            with self.subTest(reagent=name):
                self.assertEqual(complete({name: 1}), ['cleaned', 'finished'])


if __name__ == '__main__':
    unittest.main()
