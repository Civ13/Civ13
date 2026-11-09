"""Offline scalar/loop projection of production tablet coordination and accounting.

prepare() is an injected holder/constructor adapter. Actual apply(), balanced(),
ready(), valid(), metadata copy/equality and construction/year guards execute
from DM source. Staging API details have static checks, not native acceptance.
"""
import ast
import copy
import math
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE_PATH = ROOT / 'code/modules/reagents/tablet_press.dm'
SOURCE = SOURCE_PATH.read_text(encoding='utf-8')
STACK_SOURCE = (ROOT / 'code/game/objects/items/stacks/stack.dm').read_text()


class Record:
    def __init__(self, **fields):
        self.__dict__.update(fields)


class Returned(Exception):
    def __init__(self, value):
        self.value = value


class DMList:
    """One-based ordered/associative list adapter for metadata procedures."""
    def __init__(self, *values):
        self.items = list(values)
        self.associations = {}

    @property
    def len(self):
        return len(self.items)

    @len.setter
    def len(self, value):
        self.items[value:] = []
        self.items.extend([None] * (value - len(self.items)))

    def __getitem__(self, key):
        if isinstance(key, int):
            return self.items[key - 1]
        return self.associations.get(key)

    def __setitem__(self, key, value):
        if isinstance(key, int):
            self.items[key - 1] = value
        else:
            if key not in self.items:
                self.items.append(key)
            self.associations[key] = value

    def __contains__(self, value):
        return any(value is row or (not isinstance(value, DMList) and value == row)
                   for row in self.items)

    def Copy(self):
        out = DMList(*self.items)
        out.associations = dict(self.associations)
        return out
TX = '/datum/tablet_transfer/proc/'


class Frame(Record):
    def __contains__(self, kind):
        return kind in self.occupied


class Project:
    def __init__(self, source=SOURCE):
        self.source = source + '\n' + STACK_SOURCE
        self.globals = dict(persistence_admission_identity=0,
                            persistence_save_in_progress=False,
                            persistence_active_operation=None,
                            persistence_load_recovery_required=False)
        self.map = Record(age='1844', research=True)
        self.map.is_node_done = lambda _faction, _node: self.map.research
        self.globals |= dict(map=self.map, istext=lambda x: isinstance(x, str),
                             isnull=lambda x: x is None,
                             islist=lambda x: isinstance(x, DMList),
                             list=lambda *items: DMList(*items),
                             length=len,
                             text2num=self.number,
                             canonical_year=lambda x: str(int(x)) if x == int(x) else str(x),
                             locate=lambda kind: kind,
                             get_dist=lambda a, b: 0 if a.loc is b.loc else 2,
                             usr=None,
                             TRUE=True, FALSE=False, null=None,
                             isnum=lambda value: isinstance(value, (int, float)),
                             isturf=lambda value: bool(value and getattr(value, 'turf', False)),
                             get_turf=lambda value: value.loc if value and getattr(value.loc, 'turf', False) else None,
                             istype=lambda value, kind: bool(value and value.type == kind),
                             round=math.floor,
                             qdel=lambda value: (setattr(value, 'gcDestroyed', True), setattr(value, 'loc', None)),
                             tablet_metadata_equal=lambda a, b: type(a) is type(b) and a == b)
        self.globals['tablet_press_year_allowed'] = lambda: self.run(
            '/proc/tablet_press_year_allowed', Record())
        self.globals['tablet_press_build_allowed'] = lambda user, result_path: self.run(
            '/proc/tablet_press_build_allowed', Record(), user=user, result_path=result_path)
        self.globals['tablet_press_finite'] = lambda value: self.run(
            '/proc/tablet_press_finite', Record(), value=value)

    @staticmethod
    def number(value):
        try:
            return float(value)
        except (TypeError, ValueError):
            return None

    def expression(self, text, receiver, local):
        text = text.replace('"[year]"', 'canonical_year(year)')
        text = re.sub(r'(/(?:obj|mob|material|datum)(?:/\w+)+)', lambda m: repr(m[1]), text)
        text = text.replace('T ? T.volume - target.volumes[T] : 0',
                            '(T.volume - target.volumes[T] if T else 0)')
        text = text.replace('&&', ' and ').replace('||', ' or ')
        text = re.sub(r'!(?!=)', ' not ', text).strip()
        tree = ast.parse(text, mode='eval')
        allowed = (ast.Expression, ast.BoolOp, ast.And, ast.Or, ast.UnaryOp,
                   ast.Not, ast.USub, ast.Compare, ast.Eq, ast.NotEq, ast.Lt,
                   ast.LtE, ast.Gt, ast.GtE, ast.BinOp, ast.Mult, ast.Div,
                   ast.Add, ast.Sub, ast.Call, ast.Name, ast.Load, ast.Attribute,
                   ast.Constant, ast.Subscript, ast.In, ast.IfExp)
        if any(not isinstance(node, allowed) for node in ast.walk(tree)):
            raise AssertionError('Unsupported DM expression: ' + text)
        env = receiver.__dict__ | self.globals | local | {'src': receiver}
        return eval(compile(tree, '<tablet DM projection>', 'eval'), {'__builtins__': {}}, env)

    def run(self, path, receiver, **arguments):
        match = re.search(r'^' + re.escape(path) + r'\([^\n]*\)\n(.*?)(?=^/|\Z)',
                          self.source, re.M | re.S)
        if not match:
            raise AssertionError('Missing production procedure: ' + path)
        lines = [(len(line) - len(line.lstrip('\t')),
                  re.split(r'\s+//', line.strip(), maxsplit=1)[0])
                 for line in match[1].splitlines()
                 if line.strip() and not line.strip().startswith('//')]
        try:
            self.execute(lines, receiver, dict(arguments))
        except Returned as result:
            return result.value

    def execute(self, lines, receiver, local):
        index = 0
        branch_taken = None
        while index < len(lines):
            indent, line = lines[index]
            end = index + 1
            while end < len(lines) and lines[end][0] > indent:
                end += 1
            child = lines[index + 1:end]
            evaluate = lambda value: self.expression(value, receiver, local)
            loop = re.fullmatch(r'for \(var/(?:[\w]+/)*(\w+) in (.+)\)', line)
            counted = re.fullmatch(r'for \(var/(\w+) = (.+), \1 <= (.+), \1\+\+\)', line)
            if counted:
                for value in range(int(evaluate(counted[2])), int(evaluate(counted[3])) + 1):
                    local[counted[1]] = value
                    self.execute(child, receiver, local)
            elif loop:
                for value in list(evaluate(loop[2])):
                    local[loop[1]] = value
                    self.execute(child, receiver, local)
            elif line.startswith('if ('):
                branch_taken = bool(evaluate(line[4:-1]))
                if branch_taken:
                    self.execute(child, receiver, local)
            elif line.startswith('else if ('):
                if branch_taken is None:
                    raise AssertionError('Unpaired else-if')
                if not branch_taken and evaluate(line[9:-1]):
                    self.execute(child, receiver, local)
                    branch_taken = True
            elif line == 'else':
                if branch_taken is None:
                    raise AssertionError('Unpaired else')
                if not branch_taken:
                    self.execute(child, receiver, local)
                branch_taken = None
            elif line.startswith('return'):
                raise Returned(evaluate(line[7:]) if line != 'return' else None)
            else:
                if line.endswith('++'):
                    line = line[:-2] + ' += 1'
                if re.fullmatch(r'var/[\w/]+', line):
                    line += ' = null'
                declaration = re.fullmatch(r'var/(\S+) = (.+)', line)
                assignment = re.fullmatch(r'([\w.]+(?:\[[^\]]+\])?) ([-+*/]?)= (.+)', line)
                if declaration or assignment:
                    if declaration:
                        name, expression = declaration.groups()
                        name, operator = name.rsplit('/', 1)[-1], ''
                    else:
                        name, operator, expression = assignment.groups()
                    value = evaluate(expression)
                    if operator:
                        previous = evaluate(name)
                        value = {'+': lambda: previous + value, '-': lambda: previous - value,
                                 '*': lambda: previous * value, '/': lambda: previous / value}[operator]()
                    if name.endswith(']'):
                        container, key = name.split('[', 1)
                        evaluate(container)[evaluate(key[:-1])] = value
                    elif '.' in name:
                        parent, _, key = name.rpartition('.')
                        setattr(evaluate(parent), key, value)
                    elif declaration or name in local:
                        local[name] = value
                    else:
                        setattr(receiver, name, value)
                else:
                    evaluate(line)
            index = end


def reagent(kind, amount, data=None):
    return Record(id=kind, type='/datum/reagent/' + kind, volume=amount,
                  data=data, reagent_state='solid' if kind == 'calcium_carbonate' else 'liquid',
                  holder=None)


def buffer(*items):
    out = Record(reagent_list=list(items), total_volume=sum(r.volume for r in items),
                 maximum_volume=120, my_atom=None)
    for row in items:
        row.holder = out
    return out


class State(Record):
    """Holder adapter: no native holder, callback or serializer is simulated."""
    def __init__(self, value):
        super().__init__(buffer=value, owner=value.my_atom, order=list(value.reagent_list),
                         volumes={r: r.volume for r in value.reagent_list},
                         data_refs={r: r.data for r in value.reagent_list},
                         types={r: r.type for r in value.reagent_list},
                         ids={r: r.id for r in value.reagent_list},
                         phases={r: r.reagent_state for r in value.reagent_list},
                         total=value.total_volume, maximum=value.maximum_volume,
                         original=value.reagent_list)

    def valid(self):
        return (self.buffer.reagent_list is self.original
                and self.buffer.total_volume == self.total
                and self.buffer.my_atom is self.owner
                and self.buffer.reagent_list == self.order
                and all(r.volume == self.volumes[r] and r.data is self.data_refs[r]
                        and r.holder is self.buffer for r in self.order))

    def restore(self):
        self.buffer.reagent_list = self.original
        self.buffer.total_volume = self.total
        for row in self.order:
            row.volume = self.volumes[row]
            row.holder = self.buffer


class Case:
    def __init__(self, source=SOURCE, carbonate=5, aspirin=20, extra=()):
        self.project = Project(source)
        self.site = Frame(turf=True, occupied=[])
        self.actor = Record(loc=self.site, z=1, stat=0, civilization='test')
        self.actor.restrained = lambda: False
        self.source_buffer = buffer(reagent('calcium_carbonate', carbonate),
                                    reagent('aspirin', aspirin), *extra)
        self.target_buffer = buffer()
        self.product = Record(type='/obj/item/weapon/reagent_containers/pill',
                              loc=None, reagents=self.target_buffer)
        self.machine = Record(loc=self.site, beaker=None, reagents=self.source_buffer,
                              anchored=True, z=1, gcDestroyed=False, gc_destroyed=False)
        self.machine.can_operate = lambda user: self.project.run(
            '/obj/structure/chem_master/tablet_press/proc/can_operate', self.machine, user=user)
        self.source_buffer.my_atom = self.machine
        self.action = Record(machine=self.machine, actor=self.actor, site=self.site,
                             vessel=None, product=self.product, committed=False,
                             prepared=False, save_epoch=0,
                             source=State(self.source_buffer), target=State(self.target_buffer),
                             cost={'calcium_carbonate': 1, 'aspirin': 4},
                             partial_acceptance=False, fail_after_apply=False)
        self.machine.tablet_action = self.action
        self.action.valid = lambda: self.run('valid')
        self.action.prepare = self.prepare
        self.action.ready = lambda: self.run('ready')
        self.action.apply = self.apply
        self.action.balanced = lambda: self.run('balanced')
        self.action.rollback = lambda: self.run('rollback')
        self.action.sum_volume = lambda order: self.project.run(
            TX + 'sum_volume', self.action, order=order)
        self.action.staging = Record()

    def run(self, name):
        return self.project.run(TX + name, self.action)

    def prepare(self):
        a = self.action
        if not a.valid() or a.partial_acceptance:
            return False
        if any(r.volume != math.floor(r.volume) or r.volume < a.cost[r.id]
               for r in a.source.order if r.id in a.cost):
            return False
        # This adapter models constructors and API acceptance only. Production
        # arithmetic, per-datum checks and rollback run below from DM source.
        a.source_items = {r.id: r for r in a.source.order if r.id in a.cost}
        a.target_items = {key: next((r for r in a.target.order if r.id == key), None)
                          for key in a.cost}
        a.metadata = {key: Record(value=copy.deepcopy(a.source_items[key].data))
                      for key in a.cost}
        a.source_after = list(a.source.order)
        a.target_after = list(a.target.order)
        a.after_volumes = {r: r.volume for r in a.source.order + a.target.order}
        a.retired = []
        a.created = []
        for key, count in a.cost.items():
            paid = a.source_items[key]
            existing = a.target_items[key]
            if existing and (existing.type != paid.type or type(existing.data) is not type(paid.data)
                             or existing.data != paid.data):
                return False
            a.after_volumes[paid] -= count
            if not a.after_volumes[paid]:
                a.source_after.remove(paid)
                a.retired.append(paid)
            incoming = reagent(key, count, copy.deepcopy(paid.data))
            incoming.holder = a.staging
            if existing:
                a.after_volumes[existing] += count
            else:
                a.created.append(incoming)
                a.target_after.append(incoming)
                a.after_volumes[incoming] = count
        a.prepared = True
        return True

    def apply(self):
        self.run('apply')
        if self.action.fail_after_apply:
            self.target_buffer.total_volume += 1
            self.action.created[0].volume += 1

    def commit(self):
        return self.run('commit_staged')


class TabletProtocolTests(unittest.TestCase):
    def test_operation_checks_historical_research_actor_and_level(self):
        for fault in ('none', 'year', 'research', 'level', 'restrained', 'deleted'):
            case = Case()
            if fault == 'year': case.project.map.age = '1843'
            elif fault == 'research': case.project.map.research = False
            elif fault == 'level': case.actor.z = 2
            elif fault == 'restrained': case.actor.restrained = lambda: True
            elif fault == 'deleted': case.machine.gcDestroyed = True
            self.assertEqual(bool(case.commit()), fault == 'none', fault)
            if fault != 'none':
                self.assertEqual(case.source_buffer.total_volume, 25)
                self.assertEqual(case.target_buffer.total_volume, 0)

    def test_payload_admission_executes_exact_production_whitelist(self):
        p = Project()
        for value in ('aspirin', 'calcium_carbonate', 'chlorine', 'ethanol', 'pethanol',
                      'calcium_chloride', 'paracetamol', None):
            admitted = p.run('/proc/tablet_reagent_type', Record(), id=value)
            expected = '/datum/reagent/' + value if value in ('aspirin', 'calcium_carbonate') else None
            self.assertEqual(admitted, expected)

    def test_exact_debit_credit_and_unrelated_identity(self):
        extras = [reagent('ethanol', 2, {'source': 'first'}),
                  reagent('pethanol', 3), reagent('chlorine', 2),
                  reagent('trace', 0.005, {'keep': [0, '']})]
        case = Case(extra=extras)
        old = [(x, x.volume, x.data) for x in extras]
        self.assertTrue(case.commit())
        self.assertEqual([r.volume for r in case.source_buffer.reagent_list[:2]], [4, 16])
        self.assertEqual([(r.id, r.volume) for r in case.target_buffer.reagent_list],
                         [('calcium_carbonate', 1), ('aspirin', 4)])
        for row, volume, data in old:
            self.assertIn(row, case.source_buffer.reagent_list)
            self.assertEqual(row.volume, volume)
            self.assertIs(row.data, data)
            self.assertIs(row.holder, case.source_buffer)

    def test_zero_remainders_and_five_tablet_conservation(self):
        carbonate, aspirin, credited = 5, 20, 0
        for _ in range(5):
            case = Case(carbonate=carbonate, aspirin=aspirin)
            self.assertTrue(case.commit())
            carbonate -= 1
            aspirin -= 4
            credited += case.target_buffer.total_volume
        self.assertEqual((carbonate, aspirin, credited), (0, 0, 25))
        self.assertEqual(case.source_buffer.reagent_list, [])

    def test_duplicate_commit_does_not_pay_twice(self):
        case = Case()
        self.assertTrue(case.commit())
        before = case.source_buffer.total_volume
        self.assertFalse(case.commit())
        self.assertEqual(case.source_buffer.total_volume, before)

    def test_partial_staging_and_fractional_inputs_preserve_sources(self):
        for carbonate, aspirin, partial in [(0, 4, False), (1, 3, False),
                                             (1.5, 4, False), (1, 4, True)]:
            case = Case(carbonate=carbonate, aspirin=aspirin)
            case.action.partial_acceptance = partial
            original = case.source_buffer.reagent_list
            self.assertFalse(case.commit())
            self.assertIs(case.source_buffer.reagent_list, original)
            self.assertEqual([r.volume for r in original], [carbonate, aspirin])
            self.assertEqual(case.target_buffer.total_volume, 0)

    def test_stale_owner_epoch_buffer_and_movement_reject(self):
        for fault in ('owner', 'epoch', 'buffer', 'move', 'anchor', 'collector', 'save'):
            case = Case()
            if fault == 'owner':
                case.machine.tablet_action = Record()
            elif fault == 'epoch':
                case.project.globals['persistence_admission_identity'] += 1
            elif fault == 'buffer':
                case.machine.reagents = buffer()
            elif fault == 'move':
                case.machine.loc = Frame(turf=True, occupied=[])
            elif fault == 'anchor':
                case.machine.anchored = False
            elif fault == 'collector':
                case.machine.beaker = Record()
            else:
                case.project.globals['persistence_save_in_progress'] = True
            self.assertFalse(case.commit(), fault)
            self.assertEqual(case.source_buffer.total_volume, 25)
            self.assertEqual(case.target_buffer.total_volume, 0)

    def test_metadata_changed_after_staging_rejects(self):
        case = Case()
        case.source_buffer.reagent_list[0].data = {'nested': [0, '']}
        case.action.source = State(case.source_buffer)
        self.assertTrue(case.prepare())
        case.source_buffer.reagent_list[0].data['nested'][0] = 7
        self.assertFalse(case.action.ready())

    def test_raw_metadata_falsy_and_nested_independence(self):
        for value in (None, 0, '', [], {'nested': [0, '', []]}):
            case = Case()
            case.source_buffer.reagent_list[0].data = value
            case.action.source = State(case.source_buffer)
            self.assertTrue(case.commit())
            copied = case.target_buffer.reagent_list[0].data
            self.assertEqual(copied, value)
            self.assertIs(type(copied), type(value))
            if isinstance(value, (dict, list)):
                self.assertIsNot(copied, value)

    def test_measured_failure_rolls_back_same_objects(self):
        case = Case(extra=[reagent('ethanol', 2)])
        original = case.source_buffer.reagent_list
        case.action.fail_after_apply = True
        self.assertFalse(case.commit())
        self.assertIs(case.source_buffer.reagent_list, original)
        self.assertEqual([r.volume for r in original], [5, 20, 2])
        self.assertTrue(all(r.holder is case.source_buffer for r in original))
        self.assertEqual(case.target_buffer.reagent_list, [])
        self.assertEqual(case.target_buffer.total_volume, 0)

    def test_loading_merges_only_matching_metadata_and_preserves_other_stock(self):
        for mismatch in (False, True):
            case = Case()
            existing = reagent('calcium_carbonate', 2, {'wrong': 1} if mismatch else None)
            other = reagent('ethanol', 3)
            target = buffer(existing, other)
            beaker = Record(loc=case.machine, reagents=target)
            target.my_atom = beaker
            case.machine.beaker = case.action.vessel = beaker
            case.action.product = None
            case.action.target = State(target)
            case.action.cost = {'calcium_carbonate': 1}
            case.target_buffer = target
            self.assertEqual(case.commit(), not mismatch)
            self.assertIs(target.reagent_list[0], existing)
            self.assertEqual(existing.volume, 2 if mismatch else 3)
            self.assertIs(target.reagent_list[1], other)
            self.assertEqual(other.volume, 3)

    def test_committed_wrapper_publishes_before_notifications(self):
        block = SOURCE.split('/datum/tablet_transfer/proc/commit()\n', 1)[1].split('\n/', 1)[0]
        self.assertLess(block.index('product.loc = site'), block.index('finish()'))
        self.assertIn('if (!commit_staged())', block)

    def test_constructor_parameters_reject_dm_range_keyword(self):
        def check(source):
            match = re.search(r'^/datum/tablet_transfer/New\((.*)\)$', source, re.M)
            self.assertIsNotNone(match)
            names = [parameter.strip().rsplit('/', 1)[-1]
                     for parameter in match[1].split(',')]
            self.assertNotIn('to', names)
        check(SOURCE)
        # The offline holder adapter must not hide this hosted compiler fault.
        declaration = re.search(r'^/datum/tablet_transfer/New.*$', SOURCE, re.M)[0]
        parameters = list(re.finditer(r'datum/reagents/\w+', declaration))
        self.assertEqual(len(parameters), 2)
        target = parameters[1]
        mutant = declaration[:target.start()] + 'datum/reagents/to' + declaration[target.end():]
        with self.assertRaises(AssertionError):
            check(SOURCE.replace(declaration, mutant, 1))

    def test_prepare_has_exact_acceptance_and_metadata_controls(self):
        block = SOURCE.split('/datum/tablet_transfer/proc/prepare()\n', 1)[1].split('\n/', 1)[0]
        for required in ('accepted["amount"] != amount', 'incoming.volume != amount',
                         '!tablet_metadata_equal(incoming.data, R.data)',
                         'new(R.data)', 'R.volume != round(R.volume)',
                         'registered.type != path'):
            self.assertIn(required, block)
        metadata = SOURCE.split('/datum/tablet_metadata/New', 1)[1].split('/datum/tablet_buffer_state', 1)[0]
        self.assertIn('path[path.len] = original', metadata)
        self.assertIn('isnull(left) && isnull(right)', metadata)
        self.assertNotIn('get_data(', metadata)

    def test_no_hook_or_family_api_inside_apply_or_rollback(self):
        for name in ('apply', 'rollback'):
            block = SOURCE.split(TX + name + '()\n', 1)[1].split('\n/', 1)[0]
            for forbidden in ('trans_id_to', 'trans_to_holder', 'remove_reagent',
                              'update_total', 'on_reagent_change', 'handle_reactions',
                              'spawn(', 'sleep(', 'input(', 'qdel('):
                self.assertNotIn(forbidden, block)
        self.assertIn('R.volume = after_volumes[R]', SOURCE)

    def test_legacy_href_and_ejection_contract(self):
        block = SOURCE.split('/obj/structure/chem_master/tablet_press/Topic', 1)[1].split('\n/', 1)[0]
        self.assertNotIn('..()', block)
        self.assertNotIn('clear_reagents', block)
        self.assertNotIn('createpill', block)
        self.assertIn('tablet_action || !can_operate(user)', block)
        self.assertNotIn('new /obj/item/weapon/reagent_containers/pill/aspirin', SOURCE)


class MetadataSourceTests(unittest.TestCase):
    def clone(self, value, source=SOURCE):
        p = Project(source)
        meta = Record(ok=True, value=None)
        meta.copy_value = lambda raw, ancestors, depth, budget: p.run(
            '/datum/tablet_metadata/proc/copy_value', meta,
            input=raw, ancestors=ancestors, depth=depth, budget=budget)
        p.run('/datum/tablet_metadata/New', meta, input=value)
        return meta

    def equal(self, left, right, source=SOURCE):
        p = Project(source)
        p.globals['tablet_metadata_equal'] = lambda a, b: p.run(
            '/proc/tablet_metadata_equal', Record(), left=a, right=b)
        return p.globals['tablet_metadata_equal'](left, right)

    def test_actual_copy_preserves_falsy_empty_order_and_associations(self):
        values = [None, 0, '', DMList(), DMList(0, '', DMList())]
        associative = DMList('source', 'nested')
        associative['source'] = ''
        associative['nested'] = DMList(0, '')
        values.append(associative)
        for original in values:
            meta = self.clone(original)
            self.assertTrue(meta.ok)
            self.assertTrue(self.equal(meta.value, original))
            if isinstance(original, DMList):
                self.assertIsNot(meta.value, original)
        self.assertFalse(self.equal(None, 0))
        self.assertFalse(self.equal(None, ''))
        self.assertFalse(self.equal(DMList(), None))
        self.assertFalse(self.equal(DMList(0, ''), DMList('', 0)))

    def test_actual_copy_is_deep_and_rejects_cycles_references_and_bounds(self):
        original = DMList(DMList(0))
        meta = self.clone(original)
        meta.value[1][1] = 9
        self.assertEqual(original[1][1], 0)
        cycle = DMList(); cycle.len = 1; cycle[1] = cycle
        for unsupported in (cycle, Record(), DMList(*range(129)), 'x' * 4097,
                            DMList(DMList(DMList(DMList(DMList())))), float('nan')):
            self.assertFalse(self.clone(unsupported).ok)


class TabletAcquisitionTests(unittest.TestCase):
    def test_construction_retains_material_site_research_year_and_stock(self):
        for fault in ('none', 'year', 'research', 'stock', 'material', 'location',
                      'interrupted_owner', 'occupied', 'quantity', 'epoch'):
            case = Case()
            material = Record(type='/material/electronics')
            stock = Record(loc=case.site, material=material, amount=20, max_amount=50,
                           gcDestroyed=False, gc_destroyed=False)
            stock.crafting_stack_accessible = lambda actor: actor is case.actor
            action = Record(stock=stock, actor=case.actor, site=case.site,
                            source_loc=case.site, stock_material=material, amount=20,
                            recipe=Record(result_type='/obj/structure/chem_master/tablet_press/constructed',
                                          req_amount=20), quantity=1, save_epoch=0)
            valid = lambda: case.project.run('/datum/tablet_press_construction/proc/valid', action)
            self.assertTrue(valid())
            if fault == 'year': case.project.map.age = '1843'
            elif fault == 'research': case.project.map.research = False
            elif fault == 'stock': stock.amount = 19
            elif fault == 'material': stock.material = Record(type='/material/electronics')
            elif fault == 'location': stock.loc = Frame(turf=True, occupied=[])
            elif fault == 'interrupted_owner': case.actor.stat = 1
            elif fault == 'occupied': case.site.occupied.append(action.recipe.result_type)
            elif fault == 'quantity': action.quantity = 2
            elif fault == 'epoch': case.project.globals['persistence_admission_identity'] = 1
            self.assertEqual(valid(), fault == 'none', fault)

    def test_actual_stack_debit_keeps_twenty_admission_and_eighteen_discount(self):
        for religion, expected in [('Production', 2), ('other', 0)]:
            p = Project()
            stock = Record(amount=20, loc=Record())
            stock.can_use = lambda used: stock.amount >= used
            human = Record(religion_check=lambda: religion)
            self.assertTrue(p.run('/obj/item/stack/proc/use', stock, used=20, H=human))
            self.assertEqual(stock.amount, expected)

    def test_strict_canonical_year_boundary(self):
        p = Project()
        for age, expected in [('1842', False), ('1843', False), ('1844', True),
                              ('1900', True), ('1844junk', False), ('AD1844', False),
                              ('1844.5', False), ('01844', False), ('5000 B.C.', False),
                              (1844, False), ('', False), (None, False)]:
            p.map.age = age
            self.assertEqual(p.globals['tablet_press_year_allowed'](), expected, age)

    def test_research_is_independent_of_year_and_discount(self):
        p = Project()
        actor = Record(civilization='test')
        kind = '/obj/structure/chem_master/tablet_press/constructed'
        for age, research, expected in [('1844', False, False), ('1843', True, False),
                                        ('1900', True, True)]:
            p.map.age, p.map.research = age, research
            self.assertEqual(p.globals['tablet_press_build_allowed'](actor, kind), expected)
        rows = (ROOT/'config/crafting/material_recipes_global.txt').read_text()
        self.assertIn('tablet press,' + kind + ',20,120,1,1,none,100,0,0,8,null', rows)
        stack = (ROOT/'code/game/objects/items/stacks/stack.dm').read_text()
        self.assertIn('if (use(required, (joinery || carving) ? null : H))', stack)
        self.assertIn('amount < 20', SOURCE)  # admission is not discounted to18.

    def test_catalog_wait_interruption_and_predebit_guard(self):
        menu = (ROOT/'code/game/objects/items/stacks/civ_recipes.dm').read_text()
        stack = (ROOT/'code/game/objects/items/stacks/stack.dm').read_text()
        self.assertIn('&& !tablet_press_year_allowed()', menu)
        self.assertIn('if (!do_after(user, buildtime) || !crafting_recipe_allowed(H, "[recipe.result_type]"))', stack)
        self.assertGreaterEqual(stack.count('press_construction.valid()'), 3)
        self.assertLess(stack.rindex('press_construction.valid()'),
                        stack.index('if (use(required, (joinery || carving) ? null : H))'))
        self.assertIn('save_epoch != persistence_admission_identity', SOURCE)
        self.assertIn('stock.amount != amount', SOURCE)
        self.assertIn('stock.material != stock_material', SOURCE)
        self.assertIn('stock.crafting_stack_accessible(actor)', SOURCE)

    def test_exact_research_global_only_and_no_salvage(self):
        kind = '/obj/structure/chem_master/tablet_press/constructed'
        research = (ROOT/'code/modules/research_tree/research_node.dm').read_text()
        self.assertIn('"' + kind + '" = "pharmacology"', research)
        for path in (ROOT/'config/crafting').glob('*.txt'):
            if path.name != 'material_recipes_global.txt':
                self.assertNotIn(',' + kind + ',', path.read_text())
        self.assertIn(kind + '\n\tnot_disassemblable = TRUE', SOURCE)

    def test_aspirin_menu_is_held_for_policy(self):
        lab = (ROOT/'code/modules/reagents/laboratory.dm').read_text()
        self.assertNotIn('/datum/chemical_reaction/aspirin', lab)


class MutationControls(unittest.TestCase):
    def test_source_mutations_are_detected(self):
        mutations = [
            ('date', 'year > 1843', 'year >= 1843', 'date'),
            ('research', 'map.is_node_done(user.civilization, "pharmacology")', 'TRUE', 'research'),
            ('debit', 'R.volume = after_volumes[R]', 'R.volume = R.volume', 'positive'),
            ('credit', 'target.buffer.total_volume = sum_volume(target_after)',
             'target.buffer.total_volume = 0', 'positive'),
            ('rollback', 'source.restore()', 'target.restore()', 'rollback'),
            ('acceptance', 'accepted["amount"] != amount', 'FALSE', 'source'),
            ('owner', 'machine.tablet_action != src', 'FALSE', 'owner'),
            ('epoch', 'save_epoch != persistence_admission_identity', 'FALSE', 'epoch'),
            ('metadata', 'if (!R || !tablet_metadata_equal(R.data, data.value))',
             'if (!R)', 'metadata'),
            ('metadata_null', 'return isnull(left) && isnull(right)',
             'return !left && !right', 'null'),
            ('metadata_alias', 'var/copied = copy_value(key, path, depth + 1, budget)',
             'var/copied = key', 'alias'),
        ]
        for name, old, new, mode in mutations:
            with self.subTest(mutation=name):
                self.assertIn(old, SOURCE)
                altered = SOURCE.replace(old, new, 1)
                if mode == 'date':
                    p = Project(altered); p.map.age = '1843'
                    detected = p.globals['tablet_press_year_allowed']() is not False
                elif mode == 'research':
                    p = Project(altered); p.map.research = False
                    detected = p.globals['tablet_press_build_allowed'](
                        Record(civilization='test'),
                        '/obj/structure/chem_master/tablet_press/constructed') is not False
                elif mode == 'source':
                    detected = 'accepted["amount"] != amount' not in altered
                elif mode == 'null':
                    detected = MetadataSourceTests().equal(None, 0, altered)
                elif mode == 'alias':
                    original = DMList(DMList(0))
                    copied = MetadataSourceTests().clone(original, altered).value
                    copied[1][1] = 9
                    detected = original[1][1] != 0
                else:
                    case = Case(altered)
                    if mode == 'owner':
                        case.machine.tablet_action = Record()
                        detected = bool(case.commit())
                    elif mode == 'epoch':
                        case.project.globals['persistence_admission_identity'] = 1
                        detected = bool(case.commit())
                    elif mode == 'metadata':
                        case.source_buffer.reagent_list[0].data = {'x': [0]}
                        case.action.source = State(case.source_buffer)
                        self.assertTrue(case.prepare())
                        case.source_buffer.reagent_list[0].data['x'][0] = 1
                        detected = bool(case.action.ready())
                    elif mode == 'rollback':
                        case.action.fail_after_apply = True
                        case.commit()
                        detected = case.source_buffer.total_volume != 25
                    else:
                        detected = not case.commit()
                self.assertTrue(detected, name)


if __name__ == '__main__':
    unittest.main()
