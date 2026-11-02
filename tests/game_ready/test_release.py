"""Complete load-completion tail projection with injected release effects; no BYOND."""
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('ready_release_adapter', ROOT/'tests/save_movement/source_adapter.py')
A = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(A)


def completion_tail():
    source = (ROOT/'code/modules/persistence/functions.dm').read_text(encoding='utf-8-sig')
    wrapper = source.split('/datum/controller/gameticker/proc/loadmap(', 1)[1].split('/map_storage/proc/capture_round_state(', 1)[0]
    start = wrapper.rindex('\n\tif(operation.finish(TRUE)')
    return wrapper[start:].split('\n// The completion marker', 1)[0].strip('\n')


def project(tail, observer=None):
    # Map this one global observation field to an injected state object.
    mapped = tail.replace('persistence_startup_recovery_status', 'state.startup_status')
    return A.project('/proc/complete_load()\n'+mapped+'\n', '/proc/complete_load',
                     'operation,storage,state,game_ready_hook=None,ready_ticket=None,transaction=None,ready_round=None,ready_generation=None', {'call':lambda path:observer})


class Release:
    def __init__(self, state, result=True, error=False):
        self.state, self.result, self.error = state, result, error
        self.calls = []
    def finish(self, success):
        self.calls.append(success)
        if self.error:
            raise RuntimeError('injected release failure')
        if self.state.active is not self:
            return False
        if self.result == 1:
            self.state.active = None
        return self.result


class LoadReleaseContracts(unittest.TestCase):
    def case(self, tail=None, result=True, owner=True, error=False):
        state = SimpleNamespace(startup_status='pending', active=None)
        storage = SimpleNamespace(last_error=None)
        op = Release(state, result, error)
        state.active = op if owner else object()
        original = state.active
        call = project(completion_tail() if tail is None else tail)
        return call, op, storage, state, original

    def test_only_affirmative_owned_release_completes(self):
        for result in (True, 1):
            call, op, storage, state, _ = self.case(result=result)
            self.assertEqual(call(op, storage, state), 1)
            self.assertEqual(op.calls, [True])
            self.assertIsNone(state.active)
            self.assertIsNone(state.startup_status)
            self.assertIsNone(storage.last_error)

    def test_negative_null_or_nonaffirmative_release_keeps_startup_unresolved(self):
        for result in (False, None, 2):
            with self.subTest(result=result):
                call, op, storage, state, original = self.case(result=result)
                self.assertIs(call(op, storage, state), False)
                self.assertIs(state.active, original)
                self.assertEqual(state.startup_status, 'unresolved')
                self.assertEqual(storage.last_error, 'World-save operation release was not confirmed.')
                self.assertEqual(op.calls, [True])

    def test_lost_owner_cannot_release_another_operation_or_claim_completion(self):
        call, op, storage, state, original = self.case(owner=False)
        self.assertIs(call(op, storage, state), False)
        self.assertIs(state.active, original)
        self.assertEqual(state.startup_status, 'unresolved')
        self.assertIsNotNone(storage.last_error)

    def test_observer_sees_exact_identity_only_after_affirmative_release(self):
        for owner in (False, True):
            call, op, storage, state, original = self.case(owner=owner)
            events = []
            def observe(*args):
                events.append((args, state.startup_status))
            call = project(completion_tail(), observe)
            ticket, transaction = object(), object()
            result = call(op, storage, state, game_ready_hook=object(), ready_ticket=ticket,
                          transaction=transaction, ready_round='saved-round',
                          ready_generation='round-v2:'+'b'*32)
            if owner:
                self.assertEqual(result, 1)
                self.assertEqual(events, [(('loaded', ticket, op, storage, transaction,
                    'saved-round', 'round-v2:'+'b'*32), None)])
            else:
                self.assertIs(result, False)
                self.assertEqual([event[0][0] for event in events], ['load_failed'])

    def test_release_exception_propagates_without_clearing_startup(self):
        call, op, storage, state, original = self.case(error=True)
        with self.assertRaisesRegex(RuntimeError, 'injected release'):
            call(op, storage, state)
        self.assertIs(state.active, original)
        self.assertEqual(state.startup_status, 'pending')

    def test_frozen_old_tail_demonstrates_false_success_after_lost_release(self):
        legacy = (ROOT/'tests/game_ready/fixtures/legacy_load_completion.dm').read_text()
        call, op, storage, state, original = self.case(legacy, owner=False)
        self.assertEqual(call(op, storage, state), 1)
        self.assertIs(state.active, original)
        self.assertIsNone(state.startup_status)

    def test_removing_failure_return_is_rejected_by_the_release_oracle(self):
        tail = completion_tail()
        self.assertEqual(tail.count('\n\t\treturn FALSE'), 1)
        mutant = tail.replace('\n\t\treturn FALSE', '', 1)
        call, op, storage, state, _ = self.case(mutant, owner=False)
        with self.assertRaises(AssertionError):
            self.assertIs(call(op, storage, state), False)


if __name__ == '__main__':
    unittest.main()
