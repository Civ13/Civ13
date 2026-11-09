"""Project sledgehammer hand admission and attack dispatch with inert effects."""
import importlib.util
import re
from pathlib import Path
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('sledge_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)
SOURCE = ROOT / 'code/game/objects/items/weapons/sledgehammer.dm'


def simulate(free_hand, uranium=False):
    source = re.sub(r'/\*.*?\*/', '', SOURCE.read_text(encoding='utf-8-sig'), flags=re.S)
    events = []
    user = SimpleNamespace(has_empty_hand=lambda both=False: free_hand)
    hammer = SimpleNamespace(loc='floor')
    check = adapter.project(source, '/obj/item/weapon/sledgehammer/proc/special_check', 'src, user',
                            {'to_chat': lambda *args: events.append('warning')})
    env = {'special_check': lambda actor: check(hammer, actor),
           'parent_attack': lambda: events.append('hit') or True,
           'explosion': lambda *args: events.append('explosion'),
           'radiation_pulse': lambda *args: events.append('radiation'),
           'qdel': lambda *args: events.append('deleted'), 'src': hammer}
    declaration = '/obj/item/weapon/sledgehammer/uranium/attack' if uranium else '/obj/item/weapon/sledgehammer/attack'
    if not uranium and declaration + '(' not in source:
        body = '\treturn parent_attack()'  # Inherited /obj/item attack on baseline.
    else:
        body = adapter.extract(source, declaration).replace('..()', 'parent_attack()')
    probe = '/test/proc/attack(mob/living/M, mob/living/user, var/target_zone)\n' + body + '\n'
    attack = adapter.project(probe, '/test/proc/attack', 'M, user, target_zone', env)
    attack(object(), user, 'chest')
    return events


class SledgehammerHandTest(unittest.TestCase):
    def test_occupied_other_hand_blocks_normal_and_uranium_attacks(self):
        for uranium in (False, True):
            with self.subTest(uranium=uranium):
                self.assertEqual(simulate(False, uranium), ['warning'])

    def test_free_other_hand_allows_original_attack(self):
        self.assertEqual(simulate(True), ['hit'])
        self.assertEqual(simulate(True, True), ['explosion', 'radiation', 'deleted'])


if __name__ == '__main__':
    unittest.main()
