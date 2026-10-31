"""Offline checks of the completion bridge; these do not execute BYOND."""
from pathlib import Path
from types import SimpleNamespace
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/mob/living/simple_animal/subtile_movement.dm'


def section(text, start, end):
    return text.split(start, 1)[1].split(end, 1)[0]


def predicate(expression, context):
    """Evaluate the actual side-effect-free DM guard with fixture values."""
    expression = expression.replace('&&', ' and ').replace('||', ' or ')
    expression = re.sub(r'!(?!=)', ' not ', expression).strip()
    return bool(eval(expression, {'__builtins__': {}}, context))


def receipt_guards(source):
    valid = section(source, '/datum/npc_subtile_transaction/proc/valid()\n',
                    '/datum/npc_subtile_transaction/proc/advance()')
    finish = section(source, '/datum/npc_subtile_transaction/proc/finish()\n',
                     '/mob/living/simple_animal/proc/npc_subtile_take_pulse')
    valid_guard = next(line.strip()[len('return '):] for line in valid.splitlines()
                       if line.strip().startswith('return '))
    reached = next(line.strip().split(' = ', 1)[1] for line in finish.splitlines()
                   if line.strip().startswith('var/reached = '))
    final = next(line.strip()[3:] for line in finish.splitlines()
                 if line.strip().startswith('if (reached &&'))
    return valid_guard, reached, final


class CompletionBridge(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding='utf-8')
        self.transaction = object()
        self.position = {'x': 5, 'y': 5, 'z': 1, 'sx': 0, 'sy': 0}
        self.actor = SimpleNamespace(npc_subtile_transaction=self.transaction,
            npc_subtile_enabled=True, move_gen=1, target_obj='prey',
            target_mob='prey', following_mob=None, stance='attack',
            npc_subtile_ready=lambda: True, npc_subtile_intent_valid=lambda owner: owner is None,
            npc_subtile_snapshot=lambda: self.position.copy())
        self.context = dict(cancelled=False, actor=self.actor, src=self.transaction,
            isDeleted=lambda actor: False, persistence_save_in_progress=False,
            world=SimpleNamespace(time=4, tick_lag=.5), end_time=4,
            generation=1, target='prey', combat_target='prey', following=None,
            stance='attack', expected=self.position.copy(),
            human_subtile_same=lambda a, b: a == b, remaining_x=0, remaining_y=0,
            failed_pulse=False,
            finish_error=None, intent_owner=None)

    def result(self):
        valid_guard, reached_guard, final_guard = receipt_guards(self.source)
        self.context['valid'] = lambda: predicate(valid_guard, self.context)
        reached = predicate(reached_guard, self.context)
        # finish releases the transaction before the completion hook.
        self.actor.npc_subtile_transaction = None
        self.context['reached'] = reached
        return predicate(final_guard, self.context)

    def test_complete_step_is_not_confused_with_first_pulse(self):
        self.assertTrue(self.result())
        self.setUp()
        self.context['remaining_x'] = 30
        self.assertFalse(self.result())
        self.setUp()
        self.context['remaining_y'] = 2
        self.assertFalse(self.result())

    def test_interruptions_and_hook_changes_refuse_arrival(self):
        mutations = (
            lambda: self.context.update(cancelled=True),
            lambda: self.context.update(failed_pulse=True),
            lambda: self.context.update(persistence_save_in_progress=True),
            lambda: setattr(self.actor, 'move_gen', 2),
            lambda: setattr(self.actor, 'target_mob', 'other'),
            lambda: setattr(self.actor, 'npc_subtile_enabled', False),
            lambda: setattr(self.actor, 'npc_subtile_ready', lambda: False),
            lambda: self.position.update(sx=2),
            lambda: self.context.update(finish_error=object()),
        )
        for mutate in mutations:
            with self.subTest(mutate=mutate):
                self.setUp()
                mutate()
                self.assertFalse(self.result())

    def test_completion_hook_cannot_replace_owner_or_relocate(self):
        valid_guard, reached_guard, final_guard = receipt_guards(self.source)
        for mutation in ('position', 'owner', 'target'):
            with self.subTest(mutation=mutation):
                self.setUp()
                self.context['valid'] = lambda: predicate(valid_guard, self.context)
                self.context['reached'] = predicate(reached_guard, self.context)
                self.assertTrue(self.context['reached'])
                self.actor.npc_subtile_transaction = None
                if mutation == 'position':
                    self.position['sx'] = 2
                elif mutation == 'owner':
                    self.actor.npc_subtile_transaction = object()
                else:
                    self.actor.target_mob = 'other'
                self.assertFalse(predicate(final_guard, self.context))

    def test_pulse_must_be_consumed_and_match_requested_displacement(self):
        advance = section(self.source, '/datum/npc_subtile_transaction/proc/advance()\n',
                          '/datum/npc_subtile_transaction/proc/perform_rest(')
        self.assertIn('if (P.armed || actual_x != dx || actual_y != dy)', advance)
        self.assertRegex(advance, r'failed_pulse = TRUE\s+return FALSE')
        self.assertIn('!failed_pulse', receipt_guards(self.source)[1])

    def test_pulse_only_never_falls_back_to_legacy_move(self):
        admit = section(self.source, '/mob/living/simple_animal/proc/ai_step(',
                        '/mob/living/simple_animal/proc/ai_step_wait(')
        for block in (admit.split('if (!npc_subtile_enabled', 1)[1].split('\n\tif ((step_x', 1)[0],
                      admit.split('if ((step_x', 1)[1].split('\n\tvar/datum/', 1)[0]):
            self.assertRegex(block, r'if \(pulse_only\)\s+return FALSE')
            self.assertLess(block.index('if (pulse_only)'), block.index('return Move('))
        waiter = section(self.source, '/mob/living/simple_animal/proc/ai_step_wait(',
                         '/datum/npc_subtile_pulse\n')
        self.assertIn('ai_step(destination, interval, TRUE, receipt, intent_owner)', waiter)
        self.assertIn('T = receipt["transaction"]', waiter)
        self.assertNotIn('T = npc_subtile_transaction', waiter)
        self.assertIn('return T.wait_for_completion()', waiter)

    def test_receipt_captures_admitted_transaction_before_move_callbacks(self):
        admit = section(self.source, '/mob/living/simple_animal/proc/ai_step(',
                        '/mob/living/simple_animal/proc/ai_step_wait(')
        self.assertLess(admit.index('npc_subtile_transaction = T'),
                        admit.index('receipt["transaction"] = T'))
        self.assertLess(admit.index('receipt["transaction"] = T'),
                        admit.index('T.advance()'))

    def test_finish_wakes_waiters_after_cleanup_even_on_hook_error(self):
        finish = section(self.source, '/datum/npc_subtile_transaction/proc/finish()\n',
                         '/mob/living/simple_animal/proc/npc_subtile_take_pulse')
        self.assertIn('catch (var/exception/npc_finish_error)', finish)
        self.assertLess(finish.index('actor = null'), finish.index('finished = TRUE'))
        self.assertLess(finish.index('finished = TRUE'), finish.index('throw finish_error'))
        waiter = section(self.source, '/datum/npc_subtile_transaction/proc/wait_for_completion()\n',
                         '/datum/npc_subtile_transaction/proc/valid()')
        self.assertIn('while (!finished)', waiter)
        self.assertIn('return arrived', waiter)


if __name__ == '__main__':
    unittest.main()
