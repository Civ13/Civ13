"""Compost bins keep their stock through a save of a running world (#5292).

Offline structural checks on current source. No BYOND, network or saves.
"""
import importlib.util
from pathlib import Path
import re
from types import SimpleNamespace
import unittest
from unittest.mock import Mock

ROOT = Path(__file__).resolve().parents[2]
ADAPTER_SPEC = importlib.util.spec_from_file_location('source_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(ADAPTER_SPEC)
ADAPTER_SPEC.loader.exec_module(adapter)


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


def block(text, header):
    lines = text.splitlines()
    start = lines.index(header)
    body = []
    for line in lines[start + 1:]:
        if line and not line.startswith('\t'):
            break
        body.append(line)
    return '\n'.join(body)


class CompostSaveTests(unittest.TestCase):
    def setUp(self):
        self.source = read('code/modules/1713/production.dm')

    def test_stock_is_a_saved_field(self):
        decl = block(self.source, '/obj/structure/compost')
        self.assertRegex(decl, r'(?m)^\tvar/current = 0$')
        self.assertNotIn('var/tmp/current', decl)
        self.assertIn('var/tmp/composting', decl)

    def test_save_does_not_zero_the_live_bin(self):
        self.assertNotIn('/obj/structure/compost/before_save()', self.source)

    def test_load_restarts_the_cycle(self):
        self.assertIn('initialize()', block(self.source, '/obj/structure/compost/after_load()'))

    def test_materials_fit_capacity_without_consuming_the_remaining_stack(self):
        stack = block(self.source, '/obj/structure/compost/proc/add_compost_stack(obj/item/stack/S, mob/living/human/H, units_per_compost)')
        self.assertIn('min(S.amount, round(max(0, 10 - current) * units_per_compost', stack)
        self.assertLess(stack.index('if (S.use(units))'), stack.index('credit_compost(H,'))
        self.assertNotIn('S.use(units, H)', stack)
        self.assertNotIn('qdel(S)', stack)
        inputs = block(self.source, '/obj/structure/compost/proc/auto_load(var/mob/living/human/H)')
        add = block(self.source, '/obj/structure/compost/proc/add(obj/item/W, mob/living/human/H, amount_to_add, legacy_marker = FALSE)')
        self.assertLess(add.index('!legacy_marker && amount_to_add > 10 - current'), add.index('qdel(W)'))
        self.assertIn('add(W, H, W.amount * 10, legacy_marker = TRUE)', inputs)

    def test_plant_stacks_are_admitted_and_loaded_at_the_same_rates(self):
        # Project DM type literals as strings for the mocked subtype lookup.
        source = re.sub(r'(?<=[ ,])(/obj(?:/\w+)+)(?=\))', r'"\1"', self.source)
        env = {
            'current': 0,
            'nitrary_mode': False,
            'istype': lambda item, kind: item.type == kind or item.type.startswith(kind + '/'),
            'is_tool': lambda item, tool: False,
            'TOOL_WRENCH': 'wrench',
            'TOOL_HAMMER': 'hammer',
            'typed_iter': lambda contents, kind: (item for item in contents if env['istype'](item, kind)),
            'to_chat': Mock(),
            'auto_load': Mock(),
            'add_compost_stack': Mock(),
            'add': Mock(),
        }
        prefix = '/obj/structure/compost/'
        env['compost_stack_units_per_credit'] = adapter.project(
            source, prefix + 'proc/compost_stack_units_per_credit', 'W', env)
        attack = adapter.project(source, prefix + 'attackby', 'src, W, H', env)
        load_ground = adapter.project(source, prefix + 'proc/auto_load', 'src, H', env)
        food = '/obj/item/weapon/reagent_containers/food'
        cases = (
            ('/obj/item/stack/material/leaf/mulberry', True, 18, None),
            ('/obj/item/stack/farming/seeds/wheat', True, 10, None),
            *((f'/obj/item/stack/material/{material}', True, 4, None) for material in (
                'poppy', 'tobacco_green', 'tobacco', 'coca', 'cannabis_fresh',
                'cannabis', 'flax', 'hemp', 'rettedfabric')),
            ('/obj/item/stack/material/wood', False, None, None),
            ('/obj/item/stack/dung', True, None, None),
            (food, True, None, 0.5),
            (food + '/snacks/poo', True, None, 0.75),
            (food + '/snacks/poo/animal', True, None, None),
            (food + '/snacks/poo/fertilizer', True, None, None),
            ('/obj/item/stack/ore', False, None, 20),
            ('/obj/item/stack/ore/iron', False, None, None),
        )
        for kind, accepted, rate, credit in cases:
            with self.subTest(kind=kind):
                item = SimpleNamespace(type=kind, amount=2)
                bin_state = SimpleNamespace(loc=[item])
                user = SimpleNamespace(drop_item=Mock())
                for effect in ('auto_load', 'add_compost_stack', 'add'):
                    env[effect].reset_mock()
                self.assertEqual(bool(attack(bin_state, item, user)), accepted)
                if accepted:
                    user.drop_item.assert_called_once_with(bin_state.loc)
                    env['auto_load'].assert_called_once_with(user)
                else:
                    user.drop_item.assert_not_called()
                    env['auto_load'].assert_not_called()
                load_ground(bin_state, user)
                if rate is None:
                    env['add_compost_stack'].assert_not_called()
                else:
                    env['add_compost_stack'].assert_called_once_with(item, user, rate)
                if credit is None:
                    env['add'].assert_not_called()
                elif kind == '/obj/item/stack/ore':
                    env['add'].assert_called_once_with(item, user, credit, legacy_marker=True)
                else:
                    env['add'].assert_called_once_with(item, user, credit)


if __name__ == '__main__':
    unittest.main()
