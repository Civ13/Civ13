"""Model restore versus first spawn around the production lipstick color choice."""
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('lipstick_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)
adapter.FIELDS += ('colour', 'name')


def make_lipstick(restoring, choice):
    source = (ROOT / 'code/game/objects/items/weapons/cosmetics.dm').read_text()
    # The inherited /atom/New invokes on_runtime_spawn only outside restore.
    assert '/obj/item/weapon/lipstick/random/New()' not in source
    parent = (ROOT / 'code/modules/persistence/restore_contract.dm').read_text()
    assert 'if (!restoring)\n\t\ton_runtime_spawn()' in parent
    body = adapter.extract(source, '/obj/item/weapon/lipstick/random/on_runtime_spawn')
    body = body.replace('\t..()\n', '\tpass\n', 1)
    proc = adapter.project('/test/proc/spawn()\n' + body + '\n', '/test/proc/spawn',
                           'src', {'pick': lambda *args: choice}, method=True)
    obj = SimpleNamespace(colour='red', name='lipstick')
    if not restoring:
        proc(obj)
    return obj


class LipstickRestoreTest(unittest.TestCase):
    def test_default_red_survives_omitted_saved_color(self):
        lipstick = make_lipstick(True, 'purple')
        lipstick.name = 'red lipstick'  # The nondefault name is present in the save.
        self.assertEqual((lipstick.name, lipstick.colour), ('red lipstick', 'red'))

    def test_new_lipstick_still_chooses_a_color(self):
        self.assertEqual(make_lipstick(False, 'purple').colour, 'purple')


if __name__ == '__main__':
    unittest.main()
