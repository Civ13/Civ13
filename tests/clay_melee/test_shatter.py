"""Project the clay-vessel melee effect with an injected destruction boundary."""
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('clay_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)
SOURCE = (ROOT / 'code/game/objects/items/clay_items.dm').read_text(encoding='utf-8-sig')


def strike(volume):
    body = adapter.extract(SOURCE, '/obj/item/weapon/reagent_containers/food/drinks/clay/apply_hit_effect').splitlines()
    start = next(i for i, line in enumerate(body) if line.strip() == 'if (reagents && reagents.total_volume > 0)')
    tail = '\n'.join(body[start:]).replace('spawn (', 'spawn(')
    events = []
    holder = SimpleNamespace(total_volume=volume)
    holder.splash = lambda target, amount: events.append(('splash', amount))
    user = SimpleNamespace(visible_message=lambda *args: None,
                           put_in_active_hand=lambda item: events.append(('held', item)))
    target = SimpleNamespace(loc='target tile')

    def shatter(*args):
        events.append(('shatter', args[0]))
        return 'shard'

    env = {'reagents': holder, 'src': object(), 'loc': 'source tile', 'shatter': shatter,
           'deferred': lambda delay: False}
    proc = adapter.project('/test/proc/run()\n' + tail + '\n', '/test/proc/run', 'user, target', env)
    proc(user, target)
    return events


class ClayMeleeTests(unittest.TestCase):
    def test_filled_vessel_splashes_before_one_shatter(self):
        self.assertEqual(strike(10), [('splash', 10), ('shatter', 'target tile'), ('held', 'shard')])

    def test_empty_vessel_shatters_once(self):
        self.assertEqual(strike(0), [('shatter', 'target tile'), ('held', 'shard')])


if __name__ == '__main__':
    unittest.main()
