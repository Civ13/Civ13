"""Execute restricted production predicates/worker flow with inert image clients.

No DM execution, real clock, renderer, process, network or native runner import.
"""
from pathlib import Path
import re
from types import SimpleNamespace as NS
import unittest

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT/'code/game/mob/animations.dm'


def proc(text, name):
    start = text.index(name)
    end = text.find('\n/', start + len(name))
    return text[start:end if end != -1 else len(text)]


def expression(dm):
    return re.sub(r'!(?!=)', 'not ', dm.replace('&&', 'and').replace('||', 'or')).replace('FALSE', 'False').replace('TRUE', 'True')


def valid(scope, text=None, require_wait=True):
    body = proc(text or PATH.read_text(), '/datum/resource_work_animation/proc/valid(')
    return bool(eval(expression(body.split('\treturn ', 1)[1].strip()), {}, scope | {'require_wait': require_wait}))


def worker(scope, text=None):
    """Project only the bounded while/if/assignment/sleep body from production."""
    body = proc(text or PATH.read_text(), '/datum/resource_work_animation/proc/run()')
    body = body.split('\ttry\n', 1)[1].split('\tcatch ', 1)[0]
    rows = []
    for line in body.splitlines():
        if not line.strip() or line.lstrip().startswith('//'):
            continue
        indent = len(line) - len(line.lstrip('\t')) - 2
        line = line.strip()
        if line.startswith(('while (', 'if (')):
            keyword, condition = line.split(' (', 1)
            line = keyword + ' ' + expression(condition[:-1]) + ':'
        elif line == 'sleep(1)':
            line = 'yield 1'
        elif line.startswith('var/next_strike = '):
            line = line.removeprefix('var/')
        elif line != 'show_strike()' and not line.startswith('next_strike = '):
            raise AssertionError('Unreviewed worker syntax: ' + line)
        rows.append('    ' * (indent + 1) + line)
    code = 'def run():\n' + '\n'.join(rows) + '\n    stop()\n'
    namespace = dict(scope)
    namespace.update(valid=lambda require_wait=True: valid(scope, text, require_wait))
    exec(code, namespace)
    return namespace['run']()


def state():
    actor = NS(gcDestroyed=False, gc_destroyed=False, stat=0,
               loc=object(), step_x=6, step_y=10, may_do_after=False)
    actor.incapacitated = lambda: False
    tool = NS(gcDestroyed=False, gc_destroyed=False, loc=actor)
    actor.l_hand, actor.r_hand = tool, None
    actor.get_active_hand = lambda: actor.l_hand
    controller = NS(mob=actor)
    actor.client = controller
    target = NS(gcDestroyed=False, gc_destroyed=False, loc=object())
    return dict(running=True, actor=actor, tool=tool, target=target,
                controller=controller, origin=actor.loc, sx=6, sy=10,
                active_tool=True, target_loc=target.loc, expires=30, world=NS(time=0))


class ResourceWorkAnimationTests(unittest.TestCase):
    def test_pending_busy_completion_and_deadline_gates(self):
        scope = state()
        self.assertTrue(valid(scope))
        scope['actor'].may_do_after = True
        self.assertFalse(valid(scope), 'Idle or completed wait displayed work')
        self.assertTrue(valid(scope, require_wait=False), 'Pending admission cannot poll')
        scope['actor'].may_do_after = False
        scope['world'].time = scope['expires']
        self.assertFalse(valid(scope), 'Visual survived its paid action deadline')
        guard = proc(PATH.read_text(), '/mob/proc/prepare_resource_work_animation(').split('\tif (', 1)[1].split(')\n', 1)[0]
        for busy in (False, True):
            self.assertEqual(bool(eval(expression(guard), {}, dict(may_do_after=not busy, tool=object(), target=object(), duration=30))), busy)

    def test_cancellation_lifecycle_and_physical_movement_matrix(self):
        changes = (
            lambda s: s.update(running=False),
            lambda s: setattr(s['actor'], 'stat', 2),
            lambda s: setattr(s['actor'], 'incapacitated', lambda: True),
            lambda s: setattr(s['actor'], 'gc_destroyed', True),
            lambda s: setattr(s['actor'], 'client', None),
            lambda s: setattr(s['controller'], 'mob', object()),
            lambda s: setattr(s['actor'], 'loc', object()),
            lambda s: setattr(s['actor'], 'step_x', 8),
            lambda s: setattr(s['actor'], 'step_y', 12),
            lambda s: setattr(s['tool'], 'loc', object()),
            lambda s: setattr(s['tool'], 'gcDestroyed', True),
            lambda s: setattr(s['actor'], 'l_hand', None),
            lambda s: setattr(s['actor'], 'get_active_hand', lambda: None),
            lambda s: setattr(s['target'], 'gc_destroyed', True),
            lambda s: setattr(s['target'], 'loc', object()),
        )
        for change in changes:
            scope = state()
            change(scope)
            self.assertFalse(valid(scope), change)
            self.assertFalse(valid(scope, require_wait=False), change)
        scope = state()
        scope['active_tool'] = False
        scope['actor'].r_hand, scope['actor'].l_hand = scope['tool'], object()
        self.assertTrue(valid(scope), 'Inactive-hand mining was changed')

    def test_worker_waits_for_admission_repeats_and_never_restarts_after_stop(self):
        scope = state()
        scope['actor'].may_do_after = True
        pulses, stopped = [], []
        scope.update(show_strike=lambda: pulses.append(scope['world'].time),
                     stop=lambda: stopped.append(True))
        run = worker(scope)
        self.assertEqual(next(run), 1)
        self.assertEqual(pulses, [])
        scope['actor'].may_do_after = False
        for tick in range(1, 13):
            scope['world'].time = tick
            next(run)
        self.assertEqual(pulses, [1, 6, 11])
        scope['running'] = False
        with self.assertRaises(StopIteration):
            next(run)
        self.assertEqual(stopped, [True])
        scope['actor'].may_do_after = False
        with self.assertRaises(StopIteration):
            next(run)
        self.assertEqual(pulses, [1, 6, 11])

    def test_rejected_wait_stops_pending_worker_before_first_image(self):
        scope = state()
        scope['actor'].may_do_after = True
        pulses = []
        scope.update(show_strike=lambda: pulses.append(True), stop=lambda: None)
        run = worker(scope)
        next(run)
        scope['running'] = False
        scope['actor'].may_do_after = False  # A later unrelated wait.
        with self.assertRaises(StopIteration):
            next(run)
        self.assertEqual(pulses, [])

    def test_stop_removes_only_owned_images_and_is_idempotent(self):
        class Images(set):
            def __isub__(self, image):
                self.discard(image)
                return self
        class Clients(list):
            def Cut(self):
                self.clear()
        owned, unrelated = object(), object()
        clients = [NS(images=Images((owned, unrelated))) for _ in range(2)]
        scope = state() | dict(strike=owned, viewing=Clients(clients))
        text = PATH.read_text()
        clear = proc(text, '/datum/resource_work_animation/proc/clear_strike()').split('\n', 1)[1]
        clear = clear.replace('for (var/client/C in viewing)', 'for C in viewing:').replace('null', 'None')
        stop = proc(text, '/datum/resource_work_animation/proc/stop()').split('\n', 1)[1].replace('FALSE', 'False').replace('null', 'None')
        def execute(body):
            exec('\n'.join(line[1:] for line in body.splitlines()), {}, scope)
        scope['clear_strike'] = lambda: execute(clear)
        execute(stop)
        execute(stop)
        self.assertTrue(all(client.images == {unrelated} for client in clients))
        self.assertFalse(scope['running'])
        for name in ('actor', 'tool', 'target', 'controller', 'origin', 'target_loc', 'strike'):
            self.assertIsNone(scope[name])

    def test_effect_owns_no_actor_or_camera_offsets_and_reuses_tool_art(self):
        text = PATH.read_text().split('// Call-local visual companion', 1)[1].split('/mob/proc/spin(', 1)[0]
        self.assertNotRegex(text, r'(?:actor|controller|tool|target)\.(?:pixel_[xyz]|step_[xy]|transform|glide_size|dir)\s*=(?!=)')
        self.assertNotIn('animate(actor', text)
        self.assertNotIn('animate(controller', text)
        self.assertNotIn('do_attack_animation(', text)
        self.assertIn('image(tool.icon, target, tool.icon_state, target.layer + 1)', text)
        self.assertIn('animate(strike,', text)
        self.assertIn('should_save = FALSE', text)
        self.assertIn('/datum/resource_work_animation/Destroy()\n\tstop()', text)

    def test_callers_preserve_paid_waits_outputs_and_synchronous_cleanup(self):
        mining = (ROOT/'code/game/turfs/floor_attackby.dm').read_text()
        perform = proc(mining, '/datum/pickaxe_mining_action/proc/perform()')
        self.assertIn('var/completed = do_after(actor, 240 / actor.getStatCoeff("strength") / tool:usespeed, wall, needhand = FALSE, mining_context = src)', perform)
        self.assertLess(perform.index('work_animation.stop()'), perform.index('if (completed && valid(actor, wall))'))
        self.assertEqual(perform.count('wall.mining_proc(actor)'), 1)
        release = proc(mining, '/datum/pickaxe_mining_action/proc/release()')
        self.assertLess(release.index('work_animation.stop()'), release.index('actor.may_do_after = TRUE'))
        self.assertIn('catch (var/exception/mining_error)\n\t\trelease()', perform)
        wood = proc((ROOT/'code/game/objects/structures/wild.dm').read_text(), '/obj/structure/wild/attackby(')
        self.assertIn('completed = do_after(user, 30*HT.chopping_speed, user.loc)', wood)
        self.assertIn('HT.health -= 0.25', wood)
        self.assertIn('H.adaptStat("strength", 1)', wood)
        self.assertEqual(wood.count('work_animation.stop()'), 2)
        self.assertIn('if (!timed_chop)\n\t\tuser.do_attack_animation(src)', wood)
        self.assertNotIn('do_attack_animation', wood.split('\n\telse\n', 1)[0])
        adapter = (ROOT/'tests/bump_mining/support.dm').read_text()
        self.assertIn('/mob/proc/prepare_resource_work_animation(', adapter)

    def test_missing_wait_gate_and_removed_cleanup_are_detected(self):
        text = PATH.read_text()
        scope = state()
        scope['actor'].may_do_after = True
        self.assertFalse(valid(scope, text))
        self.assertTrue(valid(scope, text.replace(' && (!require_wait || !actor.may_do_after)', '')))
        self.assertIn('\n\trunning = FALSE\n\tclear_strike()', proc(text, '/datum/resource_work_animation/proc/stop()'))


if __name__ == '__main__':
    unittest.main()
