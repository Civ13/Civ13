"""Project factory transfer control flow with fake movement and stack boundaries."""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('factory_projection', ROOT / 'tests/save_movement/source_adapter.py')
vm = importlib.util.module_from_spec(spec)
spec.loader.exec_module(vm)
PORTS = ROOT / 'code/modules/1713/factory_ports.dm'
ARMS = ROOT / 'code/modules/1713/factory_arms.dm'
STACK = '/obj/item/stack'


class Bin:
    def __init__(self):
        self.contents = []


class Stack:
    type = stacktype = '/obj/item/stack/money/fiat'
    color = None
    max_amount = 1_000_000

    def __init__(self, kind, amount, loc, deny_move=False):
        self.kind, self.amount, self.loc = kind, amount, loc
        self.deleted, self.deny_move, self.deny_split_move = False, deny_move, False
        loc.contents.append(self)

    def stack_compatible(self, other):
        return self.kind == other.kind

    def forceMove(self, dest):
        if self.deny_move:
            return False
        self.loc.contents.remove(self)
        self.loc = dest
        dest.contents.append(self)
        return True

    def transfer_to(self, dest, amount):
        if not self.stack_compatible(dest):
            return False
        count = min(self.amount, amount, dest.max_amount - dest.amount)
        self.amount -= count
        dest.amount += count
        if self.amount == 0:
            delete(self)
        return bool(count)

    def split(self, count):
        if not 0 < count < self.amount:
            raise AssertionError('Only a true partial delivery should call split()')
        self.amount -= count
        return Stack(self.kind, count, self.loc, deny_move=self.deny_split_move)

    def update_icon(self):
        pass

    def update_slot_count(self):
        pass


def delete(item):
    item.deleted = True
    item.loc.contents.remove(item)
    item.loc = None


def move_proc(source, movement_allowed=True):
    # Quote the one DM type path; the source adapter handles the complete control flow.
    source = source.replace('istype(I, /obj/item/stack)', 'istype(I, "/obj/item/stack")')
    env = {
        'istype': lambda s, type_=STACK: isinstance(s, Stack) and type_ == STACK,
        'factory_movable_item': lambda item: not item.deleted,
        'persistence_movement_allowed': lambda item, dest: movement_allowed,
        'typed_iter': lambda container, _: iter(list(container.contents)),
        'QDELETED': lambda item: not item or item.deleted,
        'qdel': delete,
    }
    env['factory_stack_matches'] = vm.project(source, '/proc/factory_stack_matches', 'A,B', env)
    return vm.project(source, '/proc/factory_move_units', 'I,container,amount', env)


class FactoryArmCustodyTest(unittest.TestCase):
    def setUp(self):
        self.move = move_proc(PORTS.read_text(encoding='utf-8'))
        self.origin, self.dest = Bin(), Bin()

    def test_different_ids_remain_separate(self):
        stored = Stack('first', 5, self.dest)
        incoming = Stack('second', 4, self.origin)
        self.assertEqual(self.move(incoming, self.dest, 4), 4)
        self.assertEqual((stored.amount, incoming.amount), (5, 4))
        self.assertEqual([item.kind for item in self.dest.contents], ['first', 'second'])

    def test_shared_admission_predicate_rejects_distinct_ids_before_capacity_credit(self):
        source = PORTS.read_text(encoding='utf-8')
        env = {'istype': lambda item: isinstance(item, Stack)}
        name = '/proc/factory_stack_matches'
        current = vm.project(source, name, 'A,B', env)
        older = source.replace(' && A.stack_compatible(B) && B.stack_compatible(A)', '', 1)
        self.assertNotEqual(older, source)
        without_identity = vm.project(older, name, 'A,B', env)
        left, right = Stack('first', 4, self.dest), Stack('second', 3, self.origin)
        self.assertFalse(current(left, right))
        self.assertTrue(without_identity(left, right))

    def test_partial_merge_moves_the_same_original_stack_for_remaining_units(self):
        stored = Stack('issued-id', 999_990, self.dest)
        incoming = Stack('issued-id', 20, self.origin)
        self.assertEqual(self.move(incoming, self.dest, 20), 20)
        self.assertEqual((stored.amount, incoming.amount), (1_000_000, 10))
        self.assertIs(self.dest.contents[1], incoming)
        self.assertEqual(incoming.kind, 'issued-id')

    def test_true_partial_delivery_delegates_identity_preserving_split(self):
        incoming = Stack('issued-id', 20, self.origin)
        self.assertEqual(self.move(incoming, self.dest, 7), 7)
        self.assertEqual(incoming.amount, 13)
        self.assertEqual([(s.kind, s.amount) for s in self.dest.contents], [('issued-id', 7)])
        fiat = (ROOT / 'code/modules/1713/fiatcurrency.dm').read_text(encoding='utf-8')
        override = vm.extract(fiat, '/obj/item/stack/money/fiat/split')
        self.assertIn('new(null, _amount, src.fiat_id)', override)

    def test_whole_remainder_move_refusal_only_reports_units_already_merged(self):
        stored = Stack('issued-id', 999_990, self.dest)
        incoming = Stack('issued-id', 20, self.origin, deny_move=True)
        self.assertEqual(self.move(incoming, self.dest, 20), 10)
        self.assertEqual((stored.amount, incoming.amount), (1_000_000, 10))
        self.assertEqual(self.origin.contents, [incoming])
        self.assertEqual(self.dest.contents, [stored])

    def test_rejected_split_is_recombined_without_reporting_a_delivery(self):
        incoming = Stack('issued-id', 20, self.origin)
        incoming.deny_split_move = True
        self.assertEqual(self.move(incoming, self.dest, 7), 0)
        self.assertEqual(incoming.amount, 20)
        self.assertEqual(self.origin.contents, [incoming])
        self.assertEqual(self.dest.contents, [])

    def test_persistence_refusal_happens_before_stack_units_move(self):
        denied = move_proc(PORTS.read_text(encoding='utf-8'), movement_allowed=False)
        stored = Stack('issued-id', 5, self.dest)
        incoming = Stack('issued-id', 4, self.origin)
        self.assertEqual(denied(incoming, self.dest, 4), 0)
        self.assertEqual((stored.amount, incoming.amount), (5, 4))
        self.assertIs(incoming.loc, self.origin)

    def test_wrench_delegates_before_filter_choice_for_all_arms(self):
        body = vm.extract(ARMS.read_text(encoding='utf-8'), '/obj/structure/factory_arm/attackby')
        wrench = body.split('if (is_tool(W, TOOL_WRENCH))', 1)
        self.assertEqual(len(wrench), 2)
        options = wrench[1].split('if (can_filter', 1)[0]
        self.assertIn('\n\t\tif (on)\n', options)
        self.assertIn('\n\t\t\treturn\n\t\treturn ..()\n', options)
        self.assertNotIn('filter_type', options)


if __name__ == '__main__':
    unittest.main()
