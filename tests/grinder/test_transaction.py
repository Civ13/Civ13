"""Offline projection of grinder procedures, with deterministic external adapters.

This executes the supported scalar/branch/spawn subset directly from production
source. It is not a DM compiler, native stack test or power-network simulation.
Unknown statements fail closed; no production code or Git history is modified.
"""
import ast
import heapq
import math
from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/reagents/Chemistry-Machinery.dm').read_text(encoding='utf-8')
WOOD = '/obj/item/stack/material/wood'
MACHINE = '/obj/structure/grinder'
BATCH = '/datum/grinder_batch'
STACK = '/obj/item/stack'
STACK_SOURCE = (ROOT / 'code/game/objects/items/stacks/stack.dm').read_text(encoding='utf-8')


class Record:
    def __init__(self, **fields):
        self.__dict__.update(fields)


class Returned(Exception):
    def __init__(self, value):
        self.value = value


class Projection:
    def __init__(self, source=SOURCE):
        self.source = source + '\n' + STACK_SOURCE
        self.time = 0
        self.pending = []
        self.sequence = 0
        self.outputs = []
        self.globals = dict(persistence_admission_identity=0,
                            persistence_save_in_progress=False,
                            persistence_active_operation=None,
                            persistence_load_recovery_required=False)

    def proc(self, path):
        match = re.search(r'^' + re.escape(path) + r'\([^\n]*\)\n(.*?)(?=^/|\Z)',
                          self.source, re.M | re.S)
        if not match:
            raise AssertionError('Missing production procedure: ' + path)
        return [(len(line) - len(line.lstrip('\t')), line.strip())
                for line in match[1].splitlines()
                if line.strip() and not line.strip().startswith('//')]

    def expression(self, text, receiver, local):
        text = text.replace('&&', ' and ').replace('||', ' or ')
        text = re.sub(r'!(?!=)', ' not ', text).strip()
        tree = ast.parse(text, mode='eval')
        permitted = (ast.Expression, ast.BoolOp, ast.And, ast.Or, ast.UnaryOp,
                     ast.Not, ast.USub, ast.Compare, ast.Eq, ast.NotEq, ast.Lt,
                     ast.LtE, ast.Gt, ast.GtE, ast.BinOp, ast.Mult, ast.Div,
                     ast.Add, ast.Sub, ast.Call, ast.Name, ast.Load,
                     ast.Attribute, ast.Constant)
        if any(not isinstance(node, permitted) for node in ast.walk(tree)):
            raise AssertionError('Unsupported expression: ' + text)
        environment = dict(receiver.__dict__) | self.globals | local
        for name in ('valid', 'check_power', 'stop_grinding', 'can_grind_input', 'draw_cable_power'):
            if hasattr(receiver, name):
                environment[name] = getattr(receiver, name)
        environment |= dict(src=receiver, TRUE=True, FALSE=False, null=None,
                            istype=lambda item: bool(item and (item.type == WOOD or item.type.startswith(WOOD + '/'))),
                            isnum=lambda value: isinstance(value, (int, float)),
                            round=math.floor, min=min, prob=lambda _chance: False,
                            qdel=lambda obj: (setattr(obj, 'gcDestroyed', True), setattr(obj, 'loc', None)),
                            get_turf=lambda obj: obj.loc if getattr(obj.loc, 'turf', False) else None)
        return eval(compile(tree, '<DM scalar projection>', 'eval'), {'__builtins__': {}}, environment)

    def run(self, path, receiver, **arguments):
        try:
            self.execute(self.proc(path), receiver, dict(arguments))
        except Returned as returned:
            return returned.value

    def execute(self, lines, receiver, local):
        index = 0
        while index < len(lines):
            indent, line = lines[index]
            end = index + 1
            while end < len(lines) and lines[end][0] > indent:
                end += 1
            child = lines[index + 1:end]
            evaluate = lambda text: self.expression(text, receiver, local)
            if line.startswith('if (') or line.startswith('if('):
                if evaluate(line[line.index('(') + 1:-1]):
                    self.execute(child, receiver, local)
            elif line.startswith('spawn('):
                delay = int(re.fullmatch(r'spawn\((\d+) SECONDS\)', line)[1])
                self.sequence += 1
                heapq.heappush(self.pending, (self.time + delay, self.sequence, child, receiver, local.copy()))
            elif line.startswith(('visible_message(', 'playsound(', 'update_icon(')):
                pass  # UI/sound adapters have no transaction effects.
            elif line == 'return ..()':
                raise Returned(None)  # Native parent lifecycle is outside this projection.
            elif line.startswith('return'):
                raise Returned(evaluate(line[7:]) if line != 'return' else None)
            else:
                declaration = re.match(r'var/(\S+) = (.+)', line)
                assignment = re.fullmatch(r'([\w.]+) ([-+]?)= (.+)', line)
                if declaration or assignment:
                    if declaration:
                        target, value = declaration.groups()
                        operator = ''
                    else:
                        target, operator, value = assignment.groups()
                    if declaration:
                        kind, _, target = target.rpartition('/')
                    if value.startswith('new type('):
                        if receiver.type != WOOD:
                            raise AssertionError('Unsupported dynamic constructor')
                        kind = 'obj/item/stack/material/wood'
                        value = value.replace('new type(', 'new(', 1)
                    if value.startswith('new('):
                        args = [evaluate(arg.strip()) for arg in value[4:-1].split(',')]
                        if kind == 'datum/grinder_batch':
                            result = Batch(self, args[0])
                        elif kind == 'obj/item/stack/material/wood':
                            if args[2] is not False:
                                raise AssertionError('Output must opt out of constructor merge')
                            result = Stock(args[0], args[1])
                            self.outputs.append(result)
                        else:
                            raise AssertionError('Unsupported constructor: ' + kind)
                    else:
                        result = evaluate(value)
                    if operator:
                        result = evaluate(target) + result if operator == '+' else evaluate(target) - result
                    if '.' in target:
                        parent, _, key = target.rpartition('.')
                        setattr(evaluate(parent), key, result)
                    elif declaration or target in local:
                        local[target] = result
                    else:
                        if target not in receiver.__dict__:
                            raise AssertionError('Unknown instance field: ' + target)
                        setattr(receiver, target, result)
                else:
                    evaluate(line)
            index = end

    def advance(self, seconds):
        until = self.time + seconds
        while self.pending and self.pending[0][0] <= until:
            self.time, _, lines, receiver, local = heapq.heappop(self.pending)
            try:
                self.execute(lines, receiver, local)
            except Returned:
                pass
        self.time = until


class Stock(Record):
    def __init__(self, loc, amount=25, kind=WOOD):
        super().__init__(loc=loc, amount=amount, type=kind,
                         material=Record(name='wood'), max_amount=50,
                         gcDestroyed=False, gc_destroyed=False, onfire=False,
                         splitting_in_progress=False, woodwork_owner=None,
                         debits=[], refuse_debit=False, pulledby=None,
                         color=None, blood_DNA=None)

    def use(self, amount):
        if self.refuse_debit or self.amount < amount:
            return False
        self.debits.append(amount)
        self.amount -= amount
        if not self.amount:
            self.gcDestroyed = True
            self.loc = None
        return True

    def forceMove(self, location):
        self.loc = location

    def update_icon(self):
        pass

    def update_strings(self):
        pass


class Machine(Record):
    def __init__(self, projection):
        super().__init__(projection=projection, loc=Record(turf=True), anchored=True,
                         powersource=Record(gcDestroyed=False, gc_destroyed=False),
                         powerneeded=30, powered=False, active=True, grinding_batch=None,
                         gcDestroyed=False, gc_destroyed=False, power_available=True,
                         power_checks=0, reservation=0)
        self.powersource.update_power = lambda amount, _recheck, _consumer: setattr(self, 'reservation', amount)
        self.inserted = Stock(self)

    def draw_cable_power(self):
        self.power_checks += 1
        self.reservation = 30 if self.power_available else 0
        return self.power_available

    def check_power(self):
        # Expose this call used by the production procedure's bare name.
        return self.projection.run(MACHINE + '/proc/check_power', self)

    def stop_grinding(self, expected_batch=None):
        return self.projection.run(MACHINE + '/proc/stop_grinding', self, expected_batch=expected_batch)

    def can_grind_input(self, stock):
        return self.projection.run(MACHINE + '/proc/can_grind_input', self, stock=stock)

    def update_icon(self):
        pass

    def start(self):
        self.active = True
        return self.projection.run(MACHINE + '/proc/process_machine', self)


class Batch(Record):
    def __init__(self, projection, owner):
        super().__init__(projection=projection, machine=None, stock=None, stock_type=None,
                         stock_material=None, stock_amount=None, site=None, supply=None,
                         save_epoch=None, committed=False)
        projection.run(BATCH + '/New', self, owner=owner)

    def valid(self):
        return self.projection.run(BATCH + '/proc/valid', self)

    def commit(self):
        return self.projection.run(BATCH + '/proc/commit', self)


class GrinderTransaction(unittest.TestCase):
    def scenario(self, source=SOURCE):
        projection = Projection(source)
        machine = Machine(projection)
        return projection, machine, machine.inserted

    def test_complete_batches_and_boundaries(self):
        for count in range(0, 52):
            with self.subTest(count=count):
                p, machine, stock = self.scenario()
                stock.amount = count
                started = machine.start()
                p.advance(15)
                valid = 5 <= count <= 50
                self.assertEqual(started, valid)
                self.assertFalse(machine.active)
                self.assertEqual(sum(out.amount for out in p.outputs), count // 5 if valid else 0)
                self.assertEqual(stock.amount, count % 5 if valid else count)
                self.assertEqual(stock.debits, [count // 5 * 5] if valid else [])
                self.assertEqual(machine.reservation, 0)
                self.assertIs(machine.inserted, None if valid and not stock.amount else stock)

    def test_power_loss_in_each_wait_and_restart(self):
        for phase in (0, 10):
            for disconnected in (False, True):
                with self.subTest(phase=phase, disconnected=disconnected):
                    p, machine, stock = self.scenario()
                    machine.start()
                    p.advance(phase)
                    machine.power_available = False
                    if disconnected:
                        machine.powersource = None
                    p.advance(15 - phase)
                    self.assertEqual(stock.amount, 25)
                    self.assertFalse(p.outputs)
                    self.assertFalse(machine.active)
                    machine.power_available = True
                    if not disconnected:
                        machine.start()
                        p.advance(15)
                        self.assertEqual(sum(out.amount for out in p.outputs), 5)

    def test_observed_outage_invalidates_callback_even_after_power_returns(self):
        for elapsed in (2, 12):
            p, machine, stock = self.scenario()
            machine.start()
            p.advance(elapsed)
            machine.power_available = False
            self.assertFalse(machine.check_power())
            machine.power_available = True
            machine.start()
            replacement = machine.grinding_batch
            p.advance(15 - elapsed)
            self.assertIs(machine.grinding_batch, replacement)
            self.assertTrue(machine.active)
            self.assertEqual(stock.amount, 25)
            p.advance(elapsed)
            self.assertEqual(stock.debits, [25])
            self.assertEqual(len(p.outputs), 1)

    def test_cancellation_stale_finish_does_not_stop_replacement(self):
        p, machine, stock = self.scenario()
        machine.start()
        old = machine.grinding_batch
        p.advance(12)
        machine.stop_grinding()
        machine.start()
        replacement = machine.grinding_batch
        self.assertFalse(old.commit())
        self.assertFalse(machine.stop_grinding(old))
        p.advance(3)
        self.assertIs(machine.grinding_batch, replacement)
        p.advance(12)
        self.assertEqual(stock.debits, [25])
        self.assertEqual(len(p.outputs), 1)

    def test_duplicate_start_and_duplicate_commit(self):
        p, machine, stock = self.scenario()
        machine.start()
        batch = machine.grinding_batch
        self.assertFalse(machine.start())
        p.advance(15)
        self.assertFalse(batch.commit())
        self.assertEqual(stock.debits, [25])
        self.assertEqual(len(p.outputs), 1)

    def test_revalidation_in_each_wait(self):
        changes = {
            'replacement': lambda m, s: setattr(m, 'inserted', Stock(m)),
            'moved': lambda m, s: setattr(s, 'loc', m.loc),
            'legacy_deleted': lambda m, s: setattr(s, 'gcDestroyed', True),
            'deleted': lambda m, s: setattr(s, 'gc_destroyed', True),
            'type': lambda m, s: setattr(s, 'type', WOOD + '/twentyfive'),
            'material': lambda m, s: setattr(s, 'material', Record(name='wood')),
            'split': lambda m, s: setattr(s, 'amount', 24),
            'merge': lambda m, s: setattr(s, 'amount', 26),
            'burning': lambda m, s: setattr(s, 'onfire', True),
            'worked': lambda m, s: setattr(s, 'woodwork_owner', object()),
            'unanchored': lambda m, s: setattr(m, 'anchored', False),
            'machine_moved': lambda m, s: setattr(m, 'loc', Record(turf=True)),
            'machine_deleted': lambda m, s: setattr(m, 'gcDestroyed', True),
            'supply_replaced': lambda m, s: setattr(m, 'powersource', Record(gcDestroyed=False, gc_destroyed=False, update_power=lambda *args: None)),
            'supply_deleted': lambda m, s: setattr(m.powersource, 'gcDestroyed', True),
        }
        for elapsed in (2, 12):
            for name, change in changes.items():
                with self.subTest(elapsed=elapsed, change=name):
                    p, machine, stock = self.scenario()
                    machine.start()
                    p.advance(elapsed)
                    change(machine, stock)
                    p.advance(15 - elapsed)
                    self.assertFalse(p.outputs)
                    self.assertFalse(stock.debits)

    def test_input_rejection(self):
        for count in (-1, 0, 1, 4, 4.9, 5.5, 51, None, '25'):
            p, machine, stock = self.scenario()
            stock.amount = count
            self.assertFalse(machine.start())
            self.assertFalse(stock.debits)
        for kind in ('/obj/item/stack/material/iron', '/obj/item/stack/material/woodplank'):
            p, machine, _ = self.scenario()
            machine.inserted = Stock(machine, kind=kind)
            self.assertFalse(machine.start())
        for field, value in (('onfire', True), ('splitting_in_progress', True),
                             ('woodwork_owner', object()), ('material', Record(name='iron'))):
            p, machine, stock = self.scenario()
            setattr(stock, field, value)
            self.assertFalse(machine.start())
            self.assertFalse(stock.debits)
        p, machine, stock = self.scenario()
        stock.type = WOOD + '/twentyfive'
        self.assertTrue(machine.start())
        p.advance(15)
        self.assertEqual(stock.debits, [25])
        p, machine, _ = self.scenario()
        machine.inserted = None
        self.assertFalse(machine.start())

    def test_inventory_and_restart_wiring(self):
        p = Projection()
        insertion = '\n'.join(line for _, line in p.proc(MACHINE + '/attackby'))
        self.assertLess(insertion.index('!can_grind_input(W)'), insertion.index('user.drop_from_inventory(W, src)'))
        self.assertLess(insertion.index('W.loc != src'), insertion.index('inserted =  W'))
        self.assertIn('!user.item_is_in_hands(W)', insertion)
        self.assertIn('!inserted && !active && !grinding_batch', insertion)
        restart = '\n'.join(line for _, line in p.proc(MACHINE + '/attack_hand'))
        self.assertLess(restart.index('stop_grinding()'), restart.index('active = TRUE'))
        self.assertLess(restart.index('active = TRUE'), restart.index('process_machine()'))

    def test_failed_debit_produces_nothing(self):
        p, machine, stock = self.scenario()
        stock.refuse_debit = True
        machine.start()
        p.advance(15)
        self.assertFalse(stock.debits)
        self.assertEqual(stock.amount, 25)
        self.assertFalse(p.outputs)

    def test_destruction_ejects_input_and_cancels_callbacks(self):
        for elapsed in (2, 12):
            p, machine, stock = self.scenario()
            site = machine.loc
            machine.start()
            p.advance(elapsed)
            p.run(MACHINE + '/Destroy', machine)
            machine.gcDestroyed = True
            p.advance(15)
            self.assertIs(stock.loc, site)
            self.assertEqual(stock.amount, 25)
            self.assertFalse(stock.debits)
            self.assertFalse(p.outputs)
            self.assertEqual(machine.reservation, 0)

    def test_save_admission_fences_and_runtime_exclusions(self):
        for field, value in (('persistence_save_in_progress', True),
                             ('persistence_active_operation', object()),
                             ('persistence_load_recovery_required', True),
                             ('persistence_admission_identity', 1)):
            for elapsed in (2, 12):
                p, machine, stock = self.scenario()
                machine.start()
                p.advance(elapsed)
                p.globals[field] = value
                p.advance(15)
                self.assertFalse(p.outputs)
                self.assertFalse(stock.debits)
        declaration = SOURCE.split(MACHINE + '/persistence_runtime_var(key)', 1)[1].split('\n/', 1)[0]
        self.assertIn('key == "active"', declaration)
        self.assertIn('key == "grinding_batch"', declaration)
        self.assertIn('|| ..()', declaration)
        self.assertIn('should_save = FALSE', SOURCE.split(BATCH + '\n', 1)[1].split('\n/', 1)[0])

    def test_construction_is_sized_and_does_not_merge_with_neighbors(self):
        p, machine, stock = self.scenario()
        neighbor = Stock(machine.loc, 49)
        p.outputs.append(neighbor)
        machine.start()
        p.advance(15)
        self.assertEqual([s.amount for s in p.outputs], [49, 5])
        self.assertEqual(stock.debits, [25])
        output = p.outputs[1]
        split = p.run(STACK + '/proc/split', output, _amount=2)
        self.assertEqual((output.amount, split.amount), (3, 2))
        # Execute real base-stack merge branches, including the max-count cap.
        self.assertEqual(p.run(STACK + '/proc/merge', output, S=neighbor), 1)
        self.assertEqual((neighbor.amount, output.amount), (50, 2))
        self.assertEqual(p.run(STACK + '/proc/merge', split, S=output), 2)
        self.assertTrue(split.gcDestroyed)
        self.assertEqual(sum(s.amount for s in p.outputs if not s.gcDestroyed), 54)

    def test_mutations_are_detected_by_behavior(self):
        mutations = {
            'ownership': ('machine.grinding_batch != src', 'FALSE'),
            'identity': ('machine.inserted == stock', 'TRUE'),
            'quantity': ('stock.amount == stock_amount', 'TRUE'),
            'power': ('!valid() || !machine.check_power()', '!valid()'),
            'debit': ('if (!stock.use(input_amount))', 'if (FALSE)'),
        }
        for name, (before, after) in mutations.items():
            with self.subTest(mutation=name):
                self.assertEqual(SOURCE.count(before), 1)
                p, machine, stock = self.scenario(SOURCE.replace(before, after, 1))
                machine.start()
                old = machine.grinding_batch
                p.advance(12)
                if name == 'ownership':
                    machine.grinding_batch = Batch(p, machine)
                elif name == 'identity':
                    machine.inserted = Stock(machine)
                elif name == 'quantity':
                    stock.amount = 30
                elif name == 'power':
                    machine.power_available = False
                p.advance(3)
                self.assertTrue(p.outputs, 'Mutation should expose an unsafe output')
                if name == 'debit':
                    self.assertEqual(stock.debits, [])
                self.assertTrue(old.committed)

    def test_historical_source_is_rejected_without_git_history(self):
        old = Path(__file__).with_name('historical-grinder.dm').read_text(encoding='utf-8-sig')
        self.assertIn('tospawn.amount = inserted.amount/5', old)
        with self.assertRaisesRegex(AssertionError, 'Missing production procedure'):
            Projection(old).proc(BATCH + '/proc/valid')


if __name__ == '__main__':
    unittest.main(verbosity=2)
