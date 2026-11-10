"""Project statue initialization with the deferred callback run immediately."""
import sys
import unittest
from pathlib import Path
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests' / 'save_movement'))
import source_adapter


class StatueAppearanceTests(unittest.TestCase):
    def test_named_and_default_statues_initialize_appearance(self):
        source = (ROOT / 'code/game/objects/structures/religious.dm').read_text()
        declaration = '/obj/structure/religious/statue\n'
        body = source.split(declaration, 1)[1].split('\n/obj/structure/religious/statue/update_icon()', 1)[0]
        body = body.split('\n\tNew()\n', 1)[1]
        body = '\n'.join(line[1:] for line in body.splitlines())
        body = body.replace('..()', 'parent_new()')
        env = {'parent_new': lambda: None, 'deferred': lambda delay: True}
        old_fields = source_adapter.FIELDS
        try:
            source_adapter.FIELDS += ('name', 'statue_material', 'update_icon')
            start = source_adapter.project('proc/start()\n' + body + '\n',
                                           'proc/start', 'src', env, method=True)
        finally:
            source_adapter.FIELDS = old_fields
        for name in ('The King', 'statue'):
            calls = []
            statue = SimpleNamespace(name=name, statue_material='sandstone',
                                     update_icon=lambda: calls.append(True))
            start(statue)
            self.assertEqual(calls, [True], name)
            if name == 'The King':
                self.assertEqual(statue.name, name)


if __name__ == '__main__':
    unittest.main()
