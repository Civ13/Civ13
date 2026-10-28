"""Source-derived save/interruption policy; not native lifecycle execution."""
import itertools
from pathlib import Path
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
PREFIX = 'code/game/mob/living/carbon/human/'
BASE = '9785cba5f66892596742f40dad8cc44500c30e53'


def read(name):
    return (ROOT / name).read_text(encoding='utf-8')


def section(text, start, end=None):
    value = text[text.index(start):]
    return value[:value.index(end)] if end else value


def expression(text, replacements, allowed):
    """Translate boolean syntax only; reject unknown names/statements."""
    for original, projected in replacements.items():
        text = text.replace(original, projected)
    text = text.replace('&&', ' and ').replace('||', ' or ')
    text = re.sub(r'!(?!=)', ' not ', text).strip()
    if set(re.findall(r'[A-Za-z_]\w*', text)) - set(allowed) - {'not', 'and', 'or'}:
        raise ValueError('Unknown projected checkpoint expression')
    return compile(text, '<actual-pull-lifecycle-policy>', 'eval')


class PullLifecycleContracts(unittest.TestCase):
    def test_checkpoint_truth_table_holds_active_partial_and_invalid_survivors(self):
        text = read(PREFIX + 'pull_pair_lifecycle.dm')
        body = section(text, '/datum/subtile_pull_pair/proc/checkpoint_ready()',
                       '/datum/subtile_pull_pair/proc/lifecycle_stop')
        policy = body.split('\treturn ', 1)[1].splitlines()[0].strip()
        replacements = {}
        for actor in ('leader', 'follower'):
            replacements['isDeleted(' + actor + ')'] = actor + '_deleted'
            replacements['subtile_pull_shape(' + actor + ', TRUE)'] = actor + '_aligned'
        names = ('intent_running', 'native_inflight', 'completion_running', 'issued', 'intent_completed',
                 'leader', 'leader_deleted', 'leader_aligned',
                 'follower', 'follower_deleted', 'follower_aligned')
        code = expression(policy, replacements, names)
        actors = {'absent': (False, False, False), 'deleted': (True, True, False),
                  'aligned': (True, False, True), 'offset': (True, False, False),
                  'contained': (True, False, False), 'invalid_shape': (True, False, False)}
        cases = 0
        for running, native, completing, issued, completed in itertools.product((False, True), repeat=5):
            stage = (running, native, completing, issued, completed)
            for leader, follower in itertools.product(actors, repeat=2):
                values = dict(zip(names, (*stage, *actors[leader], *actors[follower])))
                actual = bool(eval(code, {'__builtins__': {}}, values))
                expected = stage == (False, False, False, False, True) and {leader, follower} <= {'absent', 'deleted', 'aligned'}
                self.assertEqual(actual, expected, (stage, leader, follower))
                cases += 1
        self.assertEqual(cases, 1152)

    def test_interrupted_receipt_rejects_unconsumed_or_foreign_displacement(self):
        text = read(PREFIX + 'pull_pair_lifecycle.dm')
        guard = re.search(r'\tif \((!human_subtile_same\(actual, P.before\).*?)\)\n\t\treturn FALSE', text).group(1)
        code = expression(guard, {'human_subtile_same(actual, P.before)': 'before',
                                 'human_subtile_same(actual, P.after)': 'after', 'P.armed': 'armed'},
                          ('before', 'after', 'armed'))
        for actual, armed in itertools.product((0, 1, 2, 4), (False, True)):
            rejected = bool(eval(code, {'__builtins__': {}}, dict(before=actual == 0, after=actual == 2, armed=armed)))
            self.assertEqual(not rejected, actual == 0 or (actual == 2 and not armed))
        receipt = section(text, '/datum/subtile_pull_pair/proc/record_interrupted_pulse',
                          '/datum/subtile_pull_pair/proc/save_checkpoint')
        self.assertLess(receipt.index('human_subtile_same(other_expected'), receipt.index('leader_expected = actual'))
        self.assertIn('P.member != member', receipt)
        self.assertIn('!subtile_pull_shape(member)', receipt)

    def test_save_admission_precedes_operation_identity_flags_and_backend(self):
        persistence = read('code/modules/persistence/functions.dm')
        body = section(persistence, '/proc/begin_persistence_operation(', '/datum/persistence_world_operation\n')
        hold = body.index('if(kind == "save" && !subtile_pull_ownership.save_ready())')
        for mutation in ('var/datum/persistence_world_operation/operation = new',
                         'persistence_active_operation = operation', 'persistence_save_in_progress = TRUE'):
            self.assertLess(hold, body.index(mutation))
        self.assertIn('Map save held: a smooth pull requires an aligned checkpoint.', body)
        ready = section(read(PREFIX + 'pull_pair_lifecycle.dm'),
                        '/datum/subtile_pull_ownership/proc/save_ready()',
                        '/datum/subtile_pull_ownership/proc/retire_member')
        self.assertIn('for (var/atom/movable/member in owners)', ready)
        self.assertIn('!istype(P) || P.registry != src', ready)
        self.assertIn('!(member == P.leader || member == P.follower) || !P.checkpoint_ready()', ready)
        for forbidden in ('sleep(', 'spawn(', 'cancel(', 'finish_intent(', 'owners -=', '.Move('):
            self.assertNotIn(forbidden, ready)

    def test_retirement_drops_deleted_actor_keys_and_refs_but_keeps_partial_survivor(self):
        lifecycle = read(PREFIX + 'pull_pair_lifecycle.dm')
        retire = section(lifecycle, '/datum/subtile_pull_pair/proc/retire_member',
                         '/datum/subtile_pull_pair/proc/record_interrupted_pulse')
        self.assertLess(retire.index('cancel("participant_deleted")'), retire.index('registry.owners -= member'))
        self.assertIn('registry.owners[member] == src', retire)
        self.assertIn('controller = null', retire)
        self.assertIn('orphaned = TRUE', retire)
        for actor in ('leader', 'follower'):
            for suffix in ('', '_expected', '_origin'):
                self.assertIn(actor + suffix + ' = null', retire)
        self.assertNotIn('registry.owners -= leader', retire)
        self.assertNotIn('registry.owners -= follower', retire)
        destroy = section(read('code/game/atoms_movable.dm'), '/atom/movable/Destroy()', '// called by mobs')
        self.assertLess(destroy.index('subtile_pull_ownership.retire_member(src)'), destroy.index('. = ..()'))
        recovery = section(read(PREFIX + 'pull_pair_producer.dm'),
                           '/datum/subtile_pull_pair/proc/recovery_ready', '/datum/subtile_pull_pair/proc/begin_recovery')
        self.assertIn('if (orphaned || !registry', recovery)

    def test_logout_stop_and_direct_export_revoke_before_hooks_and_require_unwind(self):
        text = read(PREFIX + 'pull_pair_lifecycle.dm')
        stop = section(text, '/datum/subtile_pull_pair/proc/lifecycle_stop', '/datum/subtile_pull_pair/proc/retire_member')
        self.assertLess(stop.index('cancel(reason)'), stop.index('finish_intent()'))
        self.assertIn('restore_follower_glide()', stop)
        self.assertIn('if (forget_controller)\n\t\tcontroller = null', stop)
        self.assertIn('if (!intent_running && !native_inflight && !completion_running)', stop)
        logout = read('code/game/mob/living/logout.dm')
        self.assertIn('paired_move.lifecycle_stop("controller_left", TRUE)', logout)
        client = section(read('code/modules/client/client_procs.dm'), '/client/Del()', '\n/client/')
        self.assertIn('if (paired_move && paired_move.controller == src)', client)
        self.assertLess(client.index('paired_move.lifecycle_stop("controller_deleted", TRUE)'),
                        client.index('human_subtile_release_visuals()'))
        self.assertIn('paired_move.lifecycle_stop("pull_stopped")', read('code/game/mob/living/living.dm'))
        save = section(text, '/datum/subtile_pull_pair/proc/save_checkpoint')
        self.assertLess(save.index('if (intent_running || native_inflight || completion_running || issued)'), save.index('lifecycle_stop("save_checkpoint", TRUE)'))
        self.assertIn('cancel("save_inflight")', save)
        original_hook = section(read(PREFIX + 'pull_pair_producer.dm'), '/atom/movable/before_save_context')
        self.assertLess(original_hook.index('if (!P.save_checkpoint())'), original_hook.index('return ..()'))

    def test_native_exception_unwind_and_controller_predicate_stay_explicit(self):
        producer = read(PREFIX + 'pull_pair_producer.dm')
        attempt = section(producer, '/datum/subtile_pull_pair/proc/attempt', '/datum/subtile_pull_pair/proc/recovery_valid_after')
        self.assertLess(attempt.index('native_inflight = TRUE'), attempt.index('member.Move('))
        catch = section(attempt, 'catch (var/exception/pull_native_error)', '\n\tnative_inflight = FALSE')
        self.assertIn('native_inflight = FALSE', catch)
        self.assertIn('record_interrupted_pulse(member, P)', catch)
        self.assertIn('throw pull_native_error', catch)
        finish = section(producer, '/datum/subtile_pull_pair/proc/finish_intent()',
                         '/datum/subtile_pull_pair/proc/settle_intent()')
        self.assertIn('if (intent_running || native_inflight || completion_running || intent_completed)', finish)
        self.assertIn('\t\ttry\n\t\t\tleader.living_movement_completed()\n\t\tcatch (var/exception/pull_living_hook_error)', finish)
        self.assertIn('\t\t\ttry\n\t\t\t\tleader.human_movement_completed()\n\t\t\tcatch (var/exception/pull_human_hook_error)', finish)
        self.assertLess(finish.index('completion_running = TRUE'), finish.index('leader.living_movement_completed()'))
        # Hook failures are executed by test_completion_hooks.py; here pin order.
        tail = section(finish, 'leader.human_movement_completed()')
        self.assertLess(tail.index('completion_running = FALSE'), tail.index('intent_completed = TRUE'))
        self.assertLess(tail.index('intent_completed = TRUE'), tail.index('settle_intent()'))
        self.assertLess(tail.index('settle_intent()'), tail.index('throw hook_error'))
        self.assertEqual(finish.count('settle_intent()'), 1)
        kernel = read(PREFIX + 'pull_pair_ownership.dm')
        old = subprocess.check_output(['git', 'show', BASE + ':' + PREFIX + 'pull_pair_ownership.dm'], cwd=ROOT).decode().replace('\r\n', '\n')
        start = '/datum/subtile_pull_pair/proc/controller_allowed()'
        end = '/datum/subtile_pull_pair/proc/prepare('
        self.assertEqual(section(kernel, start, end), section(old, start, end))
        old_producer = subprocess.check_output(['git', 'show', BASE + ':' + PREFIX + 'pull_pair_producer.dm'], cwd=ROOT).decode().replace('\r\n', '\n')
        for start, end in (('/datum/subtile_pull_pair/proc/perform_intent()', '/proc/subtile_pull_recovery_plan'),
                           ('/proc/subtile_pull_recovery_plan', '/datum/subtile_pull_pair/proc/finish_intent')):
            self.assertEqual(section(producer, start, end), section(old_producer, start, end))

    def test_release_requires_unwound_native_state_and_valid_survivor_shapes(self):
        release = section(read(PREFIX + 'pull_pair_ownership.dm'),
                          '/datum/subtile_pull_pair/proc/release()', '/datum/subtile_pull_capability\n')
        self.assertLess(release.index('if (intent_running || native_inflight || completion_running || issued)'),
                        release.index('cancel("released")'))
        self.assertIn('leader && !isDeleted(leader) && !subtile_pull_shape(leader, TRUE)', release)
        self.assertIn('follower && !isDeleted(follower) && !subtile_pull_shape(follower, TRUE)', release)
        for forbidden in ('forceMove(', 'loc =', 'step_x =', 'step_y =', 'sleep(', 'spawn('):
            self.assertNotIn(forbidden, release)


if __name__ == '__main__':
    unittest.main(verbosity=2)
