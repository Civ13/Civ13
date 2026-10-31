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
CHIPS = '/obj/item/stack/wood_chips'
OVEN = '/obj/structure/oven'
SHEETS_SOURCE = (ROOT / 'code/modules/materials/material_sheets.dm').read_text(encoding='utf-8')
OVEN_SOURCE = (ROOT / 'code/game/objects/structures/kitchen/oven.dm').read_text(encoding='utf-8')
ASH_SOURCE = (ROOT / 'code/modules/1713/wood_ash_compost.dm').read_text(encoding='utf-8')


def chip_fields(source=SHEETS_SOURCE):
    block = source.split(CHIPS + '\n', 1)[1].split('\n/', 1)[0]
    return {key: value.split(' //', 1)[0] for key, value in re.findall(r'^\t(\w+) = (.+)$', block, re.M)}


class Record:
    def __init__(self, **fields):
        self.__dict__.update(fields)


class Returned(Exception):
    def __init__(self, value):
        self.value = value


class Projection:
    def __init__(self, source=SOURCE, oven=OVEN_SOURCE):
        self.source = source + '\n' + STACK_SOURCE + '\n' + SHEETS_SOURCE + '\n' + oven + '\n' + ASH_SOURCE
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
        return [(len(line) - len(line.lstrip('\t')), re.split(r'\s+//', line.strip(), maxsplit=1)[0])
                for line in match[1].splitlines()
                if line.strip() and not line.strip().startswith('//')]

    def expression(self, text, receiver, local):
        text = re.sub(r'(/(?:obj|mob)(?:/\w+)+)', lambda match: repr(match[1]), text)
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
        for name in ('valid', 'check_power', 'stop_grinding', 'can_grind_input', 'draw_cable_power',
                     'wood_residue_account', 'record_wood_fuel', 'refuel_wood_chips'):
            if hasattr(receiver, name):
                environment[name] = getattr(receiver, name)
        environment |= dict(src=receiver, TRUE=True, FALSE=False, null=None,
                            istype=lambda item, kind=None: bool(item and (
                                item.type == (kind or ('/mob/living/human' if item is local.get('H') else WOOD))
                                or item.type.startswith((kind or ('/mob/living/human' if item is local.get('H') else WOOD)) + '/'))),
                            isnum=lambda value: isinstance(value, (int, float)),
                            isturf=lambda item: bool(item and getattr(item, 'turf', False)),
                            CONSCIOUS=0,
                            wood_chip_logs_per_batch=lambda: self.run('/proc/wood_chip_logs_per_batch', Record()),
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
        branch_taken = None
        while index < len(lines):
            indent, line = lines[index]
            end = index + 1
            while end < len(lines) and lines[end][0] > indent:
                end += 1
            child = lines[index + 1:end]
            evaluate = lambda text: self.expression(text, receiver, local)
            if line.startswith('if (') or line.startswith('if('):
                branch_taken = bool(evaluate(line[line.index('(') + 1:-1]))
                if branch_taken:
                    self.execute(child, receiver, local)
            elif line.startswith('else if ('):
                if branch_taken is None:
                    raise AssertionError('Unpaired else-if')
                if not branch_taken and evaluate(line[line.index('(') + 1:-1]):
                    self.execute(child, receiver, local)
                    branch_taken = True
            elif line == 'else':
                if branch_taken is None:
                    raise AssertionError('Unpaired else')
                if not branch_taken:
                    self.execute(child, receiver, local)
                branch_taken = None
            elif line.startswith('spawn('):
                delay = int(re.fullmatch(r'spawn\((\d+) SECONDS\)', line)[1])
                self.sequence += 1
                heapq.heappush(self.pending, (self.time + delay, self.sequence, child, receiver, local.copy()))
            elif line.startswith(('visible_message(', 'playsound(', 'update_icon(', 'to_chat(')):
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
                        if receiver.type not in (WOOD, CHIPS):
                            raise AssertionError('Unsupported dynamic constructor')
                        kind = receiver.type.lstrip('/')
                        value = value.replace('new type(', 'new(', 1)
                    if value.startswith('new('):
                        args = [evaluate(arg.strip()) for arg in value[4:-1].split(',')]
                        if kind == 'datum/grinder_batch':
                            result = Batch(self, args[0])
                        elif kind in ('obj/item/stack/material/wood', 'obj/item/stack/wood_chips'):
                            if args[2] is not False:
                                raise AssertionError('Output must opt out of constructor merge')
                            result = Chips(args[0], args[1]) if kind.endswith('/wood_chips') else Stock(args[0], args[1])
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
        super().__init__(loc=loc, amount=amount, type=kind, stacktype=kind,
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


class Chips(Stock):
    def __init__(self, loc, amount=1):
        super().__init__(loc, amount, CHIPS)
        fields = chip_fields()
        self.max_amount = int(fields['max_amount'])
        self.material = None
        self.matter = None
        self.recipes = None
        self.build_type = None


class Oven(Record):
    def __init__(self, projection, site, fuel=0, paid_wood=0):
        super().__init__(projection=projection, loc=site, z=1, fuel=fuel,
                         gcDestroyed=False, gc_destroyed=False,
                         account=Record(wood_remaining=paid_wood))

    def wood_residue_account(self):
        return self.account

    def refuel(self, chips, actor):
        return self.projection.run(OVEN + '/proc/refuel_wood_chips', self, chips=chips, H=actor)

    def refuel_wood_chips(self, chips, actor):
        return self.refuel(chips, actor)

    def record_wood_fuel(self, item, amount):
        return self.projection.run('/obj/structure/proc/record_wood_fuel', self, I=item, amount=amount)

    def load(self, item, actor):
        return self.projection.run(OVEN + '/attackby', self, I=item, H=actor)


class Actor(Record):
    def __init__(self, site):
        super().__init__(type='/mob/living/human', loc=site, z=1, stat=0,
                         enabled=True, adjacent=True, held=None)

    def can_use_hands(self):
        return self.enabled

    def Adjacent(self, _target):
        return self.adjacent

    def item_is_in_hands(self, item):
        return self.held is item


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
                self.assertTrue(all(out.type == CHIPS and out.amount <= out.max_amount for out in p.outputs))
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
        neighbor = Chips(machine.loc, 9)
        p.outputs.append(neighbor)
        machine.start()
        p.advance(15)
        self.assertEqual([s.amount for s in p.outputs], [9, 5])
        self.assertEqual(stock.debits, [25])
        output = p.outputs[1]
        split = p.run(STACK + '/proc/split', output, _amount=2)
        self.assertEqual((output.amount, split.amount), (3, 2))
        # Execute real base-stack merge branches, including the max-count cap.
        self.assertEqual(p.run(STACK + '/proc/merge', output, S=neighbor), 1)
        self.assertEqual((neighbor.amount, output.amount), (10, 2))
        self.assertEqual(p.run(STACK + '/proc/merge', split, S=output), 2)
        self.assertTrue(split.gcDestroyed)
        self.assertEqual(sum(s.amount for s in p.outputs if not s.gcDestroyed), 14)

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


class ChipFuelTransaction(unittest.TestCase):
    def fixture(self, count=1, projection=None):
        p = projection or Projection()
        site = Record(turf=True)
        user = Actor(site)
        chips = Chips(user, count)
        user.held = chips
        oven = Oven(p, site)
        return p, oven, chips, user

    def test_chip_batch_identity_and_capacity_are_not_full_wood(self):
        p, oven, chips, user = self.fixture()
        fields = chip_fields()
        for name in ('matter', 'recipes', 'build_type'):
            self.assertEqual(fields[name], 'null')
        self.assertEqual(fields['stacktype'], CHIPS)
        self.assertEqual(fields['value'], '0')
        self.assertEqual(fields['flammable'], 'FALSE')
        self.assertEqual(fields['icon'], "'icons/obj/materials.dmi'")
        self.assertEqual(fields['icon_state'], '"sheet-wood"')
        self.assertEqual(chips.max_amount * p.run('/proc/wood_chip_logs_per_batch', Record()), 50)
        machine = Machine(p)
        self.assertFalse(machine.can_grind_input(chips))
        for kind in (WOOD, '/obj/item/stack/material/woodplank', '/obj/item/stack/bark'):
            ordinary = Stock(user, 1, kind)
            self.assertFalse(p.run(STACK + '/proc/transfer_to', chips, S=ordinary, _amount=1))
            self.assertIsNone(p.run(STACK + '/attackby', chips, W=ordinary, user=user))
            self.assertEqual((chips.amount, ordinary.amount), (1, 1))
        self.assertNotIn(CHIPS + '/', SHEETS_SOURCE)
        self.assertIsNone(chips.material)

    def test_each_grinder_batch_and_leftover_has_equal_raw_log_fuel(self):
        for count in range(5, 51):
            with self.subTest(logs=count):
                p = Projection()
                machine = Machine(p)
                stock = machine.inserted
                stock.amount = count
                self.assertTrue(machine.start())
                p.advance(15)
                self.assertEqual(stock.amount + 5 * p.outputs[0].amount, count)
                actor = Actor(machine.loc)
                raw = Stock(actor, count)
                actor.held = raw
                raw_oven = Oven(p, machine.loc, fuel=4, paid_wood=4)
                raw_oven.load(raw, actor)
                chip_oven = Oven(p, machine.loc, fuel=4, paid_wood=4)
                chips = p.outputs[0]
                chips.loc = actor
                actor.held = chips
                chip_oven.load(chips, actor)
                self.assertTrue(chips.gcDestroyed)
                self.assertEqual(chips.debits, [count // 5])
                self.assertLessEqual(chip_oven.fuel, raw_oven.fuel)
                self.assertEqual(chip_oven.account.wood_remaining, chip_oven.fuel)
                if stock.amount:
                    stock.loc = actor
                    actor.held = stock
                    chip_oven.load(stock, actor)
                self.assertEqual((chip_oven.fuel, chip_oven.account.wood_remaining),
                                 (raw_oven.fuel, raw_oven.account.wood_remaining))
                before = chip_oven.fuel
                chip_oven.load(chips, actor)
                self.assertFalse(chip_oven.refuel(chips, actor))
                self.assertEqual(chip_oven.fuel, before)

    def test_normal_split_and_capped_merge_preserve_total_fuel(self):
        for count in range(1, 10):
            with self.subTest(split=count):
                p, oven, whole, user = self.fixture(10)
                split = p.run(STACK + '/proc/split', whole, _amount=count)
                self.assertEqual(split.amount + whole.amount, 10)
                user.held = split
                oven.load(split, user)
                user.held = whole
                oven.load(whole, user)
                self.assertEqual((oven.fuel, oven.account.wood_remaining), (50, 50))
        p, oven, chips, user = self.fixture(8)
        other = Chips(user, 5)
        self.assertEqual(p.run(STACK + '/proc/merge', other, S=chips), 2)
        self.assertEqual((chips.amount, other.amount), (10, 3))
        oven.load(chips, user)
        user.held = other
        oven.load(other, user)
        self.assertEqual((oven.fuel, oven.account.wood_remaining), (65, 65))

    def test_invalid_counts_and_failed_debit_give_no_fuel_or_ash_credit(self):
        for count in (-1, 0, 0.5, 10.5, 11, None, '5'):
            p, oven, chips, user = self.fixture(count)
            self.assertFalse(oven.refuel(chips, user))
            self.assertEqual((oven.fuel, oven.account.wood_remaining), (0, 0))
            self.assertFalse(chips.debits)
        p, oven, chips, user = self.fixture(10)
        chips.refuse_debit = True
        self.assertFalse(oven.refuel(chips, user))
        self.assertEqual((oven.fuel, oven.account.wood_remaining), (0, 0))
        self.assertEqual(chips.amount, 10)

    def test_inaccessible_or_deleted_fuel_preserves_input(self):
        changes = (
            lambda o, c, u: setattr(c, 'loc', o.loc),
            lambda o, c, u: setattr(u, 'held', None),
            lambda o, c, u: setattr(u, 'adjacent', False),
            lambda o, c, u: setattr(u, 'z', 2),
            lambda o, c, u: setattr(u, 'stat', 1),
            lambda o, c, u: setattr(u, 'enabled', False),
            lambda o, c, u: setattr(c, 'gcDestroyed', True),
            lambda o, c, u: setattr(c, 'gc_destroyed', True),
            lambda o, c, u: setattr(o, 'gcDestroyed', True),
            lambda o, c, u: setattr(o, 'loc', None),
        )
        for change in changes:
            p, oven, chips, user = self.fixture()
            change(oven, chips, user)
            self.assertFalse(oven.refuel(chips, user))
            self.assertFalse(chips.debits)
            self.assertEqual((oven.fuel, oven.account.wood_remaining), (0, 0))
        p, oven, chips, user = self.fixture()
        self.assertFalse(oven.refuel(chips, None))
        self.assertFalse(oven.refuel(Stock(user), user))

    def test_fuel_and_residue_mutations_expose_amplification_or_unpaid_credit(self):
        for before, after in (
            ('fuel += log_units', 'fuel += log_units + 1'),
            ('account.wood_remaining += log_units', 'account.wood_remaining += log_units + 1'),
            ('if (!account || !chips.use(batches))', 'if (!account)'),
        ):
            with self.subTest(mutation=before):
                self.assertEqual(OVEN_SOURCE.count(before), 1)
                p, oven, chips, user = self.fixture(projection=Projection(oven=OVEN_SOURCE.replace(before, after, 1)))
                self.assertTrue(oven.refuel(chips, user))
                self.assertFalse(oven.fuel == 5 and oven.account.wood_remaining == 5 and chips.debits == [1])


if __name__ == '__main__':
    unittest.main(verbosity=2)
