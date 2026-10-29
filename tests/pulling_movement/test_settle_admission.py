"""Settle and save-admission ordering: executed source projections only.

Each DM statement of resolve_aligned() and of the save branch of
begin_persistence_operation() is translated one-to-one; an unknown statement
fails the projection. Fake members run movement callbacks that relocate,
re-offset, start native work or re-enter, as Entered/Crossed callbacks can.
Generated-source controls restore each original defect and must be caught.
None of this launches BYOND, a world or a client.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
PREFIX = 'code/game/mob/living/carbon/human/'


def read(name):
    return (ROOT / name).read_text(encoding='utf-8').replace('\r\n', '\n')


def section(text, start, end):
    value = text[text.index(start):]
    return value[:value.index(end)]


def translate(lines, exact, patterns=()):
    out = []
    for line in lines:
        value = line.strip()
        if not value or value.startswith('//'):
            continue
        depth = len(line) - len(line.lstrip('\t'))
        if value in exact:
            projected = exact[value]
        else:
            for pattern, template in patterns:
                match = re.fullmatch(pattern, value)
                if match:
                    projected = template.format(*match.groups())
                    break
            else:
                raise ValueError('Unprojected statement: ' + value)
        out.append('    ' * depth + projected)
    return out


def boolean(expression, names):
    text = expression.replace('&&', ' and ').replace('||', ' or ')
    text = re.sub(r'!(?!=)', ' not ', text)
    for original, projected in names.items():
        text = text.replace(original, projected)
    return text


RESOLVE_START = '/datum/subtile_pull_pair/proc/resolve_aligned('
RESOLVE_END = '// TRUE only when every quiet pair settled.'
RESOLVE_NAMES = {
    'persistence_active_operation': 'G.active', 'persistence_save_in_progress': 'G.saving',
    'admission.backend_started': 'admission.backend_started',
    'isDeleted(member)': 'member.deleted', 'isturf(member.loc)': 'member.on_turf()',
    'subtile_pull_shape(member, TRUE)': 'member.aligned()',
    'member.loc': 'member.loc', 'member.step_x': 'member.step_x', 'member.step_y': 'member.step_y',
    'targets[member]': 'targets[member]',
}


def resolve_statements(text):
    body = section(text, RESOLVE_START, RESOLVE_END).rstrip().splitlines()[1:]
    exact = {
        'return TRUE': 'return True', 'return FALSE': 'return False', 'continue': 'continue',
        'settling = TRUE': 'P.settling = True', 'settling = FALSE': 'P.settling = False',
        'cancel(reason)': 'P.cancel(reason)', 'restore_follower_glide()': 'pass',
        'var/list/targets = list()': 'targets = {}',
        'for (var/atom/movable/member in list(leader, follower))': 'for member in [m for m in (P.leader, P.follower) if m is not None]:',
        'for (var/atom/movable/member in targets)': 'for member in list(targets):',
        'var/atom/destination = member.loc': 'destination = member.loc',
        'var/list/target = subtile_pull_nearest_tile(subtile_pull_snapshot(member))': 'target = member.nearest()',
        'destination = locate(target["x"], target["y"], target["z"])': 'destination = G.locate(target)',
        'targets[member] = destination': 'targets[member] = destination',
        'var/atom/destination = targets[member]': 'destination = targets[member]',
        'member.forceMove(destination)': 'member.forceMove(destination)',
        'member.step_x = 0': 'member.step_x = 0', 'member.step_y = 0': 'member.step_y = 0',
        'recovery_required = TRUE': 'P.recovery_required = True',
        'failure = "settle_interrupted"': 'P.failure = "settle_interrupted"',
        'failure = "settle_position_changed"': 'P.failure = "settle_position_changed"',
        'drop_lease()': 'P.drop_lease()',
    }
    pair_names = ('released', 'settling', 'intent_running', 'native_inflight', 'completion_running', 'issued')

    def condition(expression):
        text = boolean(expression, RESOLVE_NAMES)
        for name in pair_names:
            text = re.sub(r'(?<![.\w])' + name + r'\b', 'P.' + name, text)
        if set(re.findall(r'(?<![.\w])[A-Za-z_]\w*', text)) - {'not', 'and', 'or', 'P', 'G', 'admission', 'member', 'targets', 'destination'}:
            raise ValueError('Unknown projected name in: ' + expression)
        return 'if ' + text + ':'

    lines = translate(body, exact, ((r'if \((.*)\)', '{}'),))
    projected = []
    for line, original in zip(lines, [l for l in body if l.strip() and not l.strip().startswith('//')]):
        value = original.strip()
        if value.startswith('if ('):
            line = line[:len(line) - len(line.lstrip())] + condition(value[4:-1])
        projected.append(line)
    source = 'def resolve(P, G, reason, admission=None):\n' + '\n'.join('    ' + l for l in projected)
    namespace = {}
    exec(compile(source, '<actual-resolve-aligned>', 'exec'), {'__builtins__': {'list': list}}, namespace)
    return namespace['resolve']


class Turf:
    def __init__(self, x, y):
        self.x, self.y = x, y


class World:
    def __init__(self):
        self.turfs = {(x, y): Turf(x, y) for x in range(12) for y in range(12)}
        self.active = None
        self.saving = False

    def locate(self, target):
        return self.turfs.get((target['x'], target['y']))


class Member:
    def __init__(self, world, x, y, sx=0, sy=0, on_move=None):
        self.world, self.loc, self.step_x, self.step_y = world, world.turfs[(x, y)], sx, sy
        self.deleted, self.on_move, self.moves = False, on_move, 0

    def on_turf(self):
        return isinstance(self.loc, Turf)

    def aligned(self):
        return self.on_turf() and not self.step_x and not self.step_y

    def nearest(self):
        return dict(x=self.loc.x + (self.step_x >= 16), y=self.loc.y + (self.step_y >= 16))

    def forceMove(self, destination):
        self.loc, self.moves = destination, self.moves + 1
        if self.on_move:
            self.on_move(self)


class Pair:
    def __init__(self, leader, follower):
        self.leader, self.follower = leader, follower
        self.released = self.settling = self.intent_running = self.native_inflight = False
        self.completion_running = self.recovery_required = False
        self.issued = None
        self.failure = None

    def cancel(self, reason):
        self.failure = reason

    def drop_lease(self):
        self.released = True
        self.leader = self.follower = None


class Operation:
    backend_started = False


class SettleValidation(unittest.TestCase):
    def setUp(self):
        self.text = read(PREFIX + 'pull_pair_lifecycle.dm')
        self.resolve = resolve_statements(self.text)

    def pair(self, on_move=None):
        world = World()
        # Leader 18px into the next tile east; follower 16px behind it.
        leader = Member(world, 5, 5, sx=18, on_move=on_move)
        follower = Member(world, 4, 5, sx=18)
        return world, Pair(leader, follower)

    def test_clean_settle_aligns_both_and_releases(self):
        world, pair = self.pair()
        leader, follower = pair.leader, pair.follower
        self.assertTrue(self.resolve(pair, world, 'unrecoverable'))
        self.assertTrue(pair.released)
        self.assertEqual((leader.loc, follower.loc), (world.turfs[(6, 5)], world.turfs[(5, 5)]))
        self.assertTrue(leader.aligned() and follower.aligned())

    def test_callbacks_that_change_final_positions_keep_the_lease(self):
        def relocate(member):
            member.loc = member.world.turfs[(9, 9)]

        def offset(member):
            member.step_x = 4

        def start_native(member):
            pair.native_inflight = True

        for callback, failure in ((relocate, 'settle_position_changed'), (offset, 'settle_position_changed'),
                                  (start_native, 'settle_interrupted')):
            with self.subTest(callback=callback.__name__):
                world, pair = self.pair(callback)
                self.assertFalse(self.resolve(pair, world, 'recovery_timeout'))
                self.assertFalse(pair.released)
                self.assertTrue(pair.recovery_required)
                self.assertEqual(pair.failure, failure)
                self.assertFalse(pair.settling)

    def test_reentry_while_a_callback_sleeps_is_refused(self):
        inner = []

        def reenter(member):
            inner.append(self.resolve(pair, world, 'recovery_timeout'))

        world, pair = self.pair(reenter)
        self.assertTrue(self.resolve(pair, world, 'recovery_timeout'))
        self.assertEqual(inner, [False])
        self.assertEqual(pair.released, True)

    def test_only_the_reserving_unstarted_save_may_settle(self):
        world, pair = self.pair()
        world.saving = True
        self.assertFalse(self.resolve(pair, world, 'save_admission'))
        foreign, own = Operation(), Operation()
        world.active = foreign
        self.assertFalse(self.resolve(pair, world, 'save_admission', own))
        own.backend_started = True
        world.active = own
        self.assertFalse(self.resolve(pair, world, 'save_admission', own))
        self.assertFalse(pair.released)
        own.backend_started = False
        self.assertTrue(self.resolve(pair, world, 'save_admission', own))

        def end_reservation(member):
            world.active = None

        world, pair = self.pair(end_reservation)
        own = Operation()
        world.saving, world.active = True, own
        self.assertFalse(self.resolve(pair, world, 'save_admission', own))
        self.assertEqual(pair.failure, 'settle_interrupted')

    def test_generated_original_resolver_is_caught_releasing_a_relocated_pair(self):
        body = section(self.text, RESOLVE_START, RESOLVE_END)
        validation = body[body.index('\tsettling = FALSE\n'):body.index('\tdrop_lease()\n')]
        original = self.text.replace(validation, '\tsettling = FALSE\n', 1)
        resolve = resolve_statements(original)

        def relocate(member):
            member.loc = member.world.turfs[(9, 9)]

        world, pair = self.pair(relocate)
        self.assertTrue(resolve(pair, world, 'recovery_timeout'))
        self.assertTrue(pair.released, 'control should reproduce the unchecked release')


ADMISSION_START = '\tif((persistence_restart.startup_hold || persistence_restart.busy || persistence_restart.exists()) && !restart_owner) return null\n'
ADMISSION_END = '\treturn operation\n'


def admission_statements(text):
    body = section(text, '/proc/begin_persistence_operation(', '/datum/persistence_world_operation\n')
    segment = body[body.index(ADMISSION_START) + len(ADMISSION_START):body.index(ADMISSION_END) + len(ADMISSION_END)]
    segment = re.sub(r'#ifdef CIV13_VARIABLE_OBSERVABILITY\n.*?#endif\n', '', segment, flags=re.S)
    exact = {
        'var/datum/persistence_world_operation/operation = new': 'operation = G.new_operation()',
        'operation.storage = storage': 'operation.storage = storage',
        'operation.kind = kind': 'operation.kind = kind',
        'persistence_active_operation = operation': 'G.active = operation',
        'persistence_save_in_progress = TRUE': 'G.saving = True',
        'persistence_admission_identity = operation.admission_identity': 'G.identity = operation',
        'if(kind == "save" && (!subtile_pull_ownership.resolve_quiet("save_admission", operation) || !operation.current(storage, kind) || !subtile_pull_ownership.save_ready()))':
            'if kind == "save" and (not G.resolve_quiet("save_admission", operation) or not operation.current(storage, kind) or not G.save_ready()):',
        'subtile_pull_ownership.resolve_quiet("save_admission")': 'G.resolve_quiet("save_admission", None)',
        'if(kind == "save" && !subtile_pull_ownership.save_ready())': 'if kind == "save" and not G.save_ready():',
        'if(kind == "save")': 'if kind == "save":',
        'operation.withdraw()': 'operation.withdraw()',
        'return null': 'return None', 'return operation': 'return operation',
    }
    patterns = ((r'to_chat\(world, (.*)\)', 'G.announce({!r})'),)
    lines = segment.rstrip().splitlines()
    source = 'def admit(G, storage, kind):\n' + '\n'.join('    ' + l for l in translate(lines, exact, patterns))
    namespace = {}
    exec(compile(source, '<actual-save-admission>', 'exec'), {'__builtins__': {}}, namespace)
    return namespace['admit']


class AdmissionWorld:
    def __init__(self, settled=True, ready=True):
        self.active = None
        self.saving = False
        self.settled, self.ready = settled, ready
        self.observed, self.messages, self.nested = [], [], []

    def new_operation(self):
        world = self

        class Op:
            backend_started = False

            def current(self, storage, kind):
                return world.active is self and self.storage == storage and self.kind == kind

            def withdraw(self):
                if world.active is not self or self.backend_started:
                    return False
                world.active, world.saving = None, False
                return True
        return Op()

    def resolve_quiet(self, reason, admission):
        # Movement callbacks run here; a nested request must find the hold.
        self.observed.append((self.active, self.saving, admission))
        self.nested.append(self.active is None and not self.saving)
        return self.settled

    def save_ready(self):
        return self.ready

    def announce(self, message):
        self.messages.append(message)


class SaveAdmission(unittest.TestCase):
    def setUp(self):
        self.text = read('code/modules/persistence/functions.dm')

    def test_quiet_pairs_settle_under_the_reserved_unstarted_operation(self):
        admit = admission_statements(self.text)
        world = AdmissionWorld()
        operation = admit(world, 'storage', 'save')
        self.assertIsNotNone(operation)
        self.assertEqual(world.observed, [(operation, True, operation)])
        self.assertEqual(world.nested, [False])
        self.assertTrue(world.active is operation and world.saving)
        self.assertIn('SAVING THE MAP', world.messages[-1])

    def test_failed_settle_or_hold_withdraws_the_reservation_without_announcing(self):
        admit = admission_statements(self.text)
        for settled, ready in ((False, True), (True, False)):
            with self.subTest(settled=settled, ready=ready):
                world = AdmissionWorld(settled, ready)
                self.assertIsNone(admit(world, 'storage', 'save'))
                self.assertIsNone(world.active)
                self.assertFalse(world.saving)
                self.assertEqual(len(world.messages), 1)
                self.assertIn('Map save held', world.messages[0])

    def test_loads_do_not_settle_pull_pairs(self):
        admit = admission_statements(self.text)
        world = AdmissionWorld(settled=False, ready=False)
        self.assertIsNotNone(admit(world, 'storage', 'load'))
        self.assertEqual(world.observed, [])

    def test_withdraw_releases_only_an_unstarted_current_operation(self):
        withdraw = section(self.text, '\tproc/withdraw()', '\tproc/finish(success)')
        self.assertIn('if(persistence_active_operation != src || backend_started) return FALSE', withdraw)
        self.assertIn('persistence_active_operation = null', withdraw)
        finish = section(self.text, '\tproc/finish(success)', '/datum/persistence_world_operation/New()')
        recompute = 'persistence_save_in_progress = persistence_load_recovery_required || storage.dimension_recovery_required || storage.dimension_budget_hold || persistence_restart.startup_hold'
        self.assertIn(recompute, withdraw)
        self.assertIn(recompute, finish)

    def test_generated_original_order_is_caught_settling_before_reservation(self):
        body = section(self.text, '/proc/begin_persistence_operation(', '/datum/persistence_world_operation\n')
        hold = body[body.index('\t// Reserve admission before settling'):body.index('\tif(kind == "save")\n\t\tto_chat(world, "<FONT')]
        original_hold = ('\tif(kind == "save")\n\t\tsubtile_pull_ownership.resolve_quiet("save_admission")\n'
                         '\tif(kind == "save" && !subtile_pull_ownership.save_ready())\n'
                         '\t\tto_chat(world, SPAN_WARNING("Map save held: a smooth pull requires an aligned checkpoint."))\n'
                         '\t\treturn null\n')
        operation = '\tvar/datum/persistence_world_operation/operation = new\n'
        original = body.replace(hold, '', 1).replace(operation, original_hold + operation, 1)
        admit = admission_statements(self.text.replace(body, original, 1))
        world = AdmissionWorld()
        self.assertIsNotNone(admit(world, 'storage', 'save'))
        self.assertEqual(world.nested, [True], 'control should settle with no reservation held')


if __name__ == '__main__':
    unittest.main(verbosity=2)
