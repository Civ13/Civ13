"""Offline, source-bound checks for maintenance admission; no native world."""
import re
from pathlib import Path
from types import SimpleNamespace
import sys
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts/nomads-lifecycle'))
import supervisor


def condition(expression, values):
    expression = expression.replace('||', ' or ').replace('&&', ' and ')
    expression = re.sub(r'!(?!=)', 'not ', expression).replace('TRUE', 'True')
    return eval(expression, {'__builtins__': {}}, values)


class MaintenanceAdmissionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.lifecycle = (ROOT / 'code/modules/persistence/nomads_lifecycle.dm').read_text()
        cls.admin = (ROOT / 'code/modules/persistence/admin.dm').read_text()
        handler = cls.lifecycle.split('/datum/nomads_lifecycle_control/proc/handle(', 1)[1]
        typed = re.search(r'if\(action == "maintenance_save_shutdown"\)\s+if\(([^\n]+)\)\s+return json_encode\(snapshot\(FALSE, "maintenance_operation_mismatch"\)\)', handler)
        if not typed:
            raise AssertionError('Typed pending-operation guard missing')
        cls.guard = typed.group(1)
        cls.assert_source_order(handler)

    @classmethod
    def assert_source_order(cls, handler):
        session = handler.index('input["session"] != boot_session()')
        typed = handler.index('if(action == "maintenance_save_shutdown")')
        reserve = handler.index('busy = TRUE // Reserve')
        if not session < typed < reserve or re.search(r'\b(?:sleep|spawn)\s*\(', handler[session:reserve]):
            raise AssertionError('Session, typed admission and reservation must be synchronous')
        if 'else if(maintenance_operation)\n\t\treturn json_encode(snapshot(FALSE, "maintenance_operation_pending"))' not in handler:
            raise AssertionError('Generic shutdown is not fenced during maintenance')

    def rejects(self, pending, announcing=False, operation='d' * 32):
        return condition(self.guard, {'maintenance_operation': pending,
                                     'maintenance_announcing': announcing,
                                     'input': {'operation': operation}})

    def test_expiry_between_status_and_submit_never_admits_shutdown(self):
        operation, session = 'd' * 32, 'e' * 32
        pending = operation
        events = []
        class InertSupervisor:
            config = {'port': 1714}
            token = 'a' * 32
            state = {'revision': 'f' * 40}
            def status(inner):
                return {'ready': True, 'busy': False, 'error': None, 'clients': 1,
                        'restart_hold': False, 'restart_intent': False,
                        'maintenance_operation': pending, 'session': session}
            def alive(inner):
                return True
            def record(inner, *args, **kwargs):
                pass
        def submit(port, token, action, sent_operation, sent_session):
            nonlocal pending
            self.assertEqual((action, sent_operation, sent_session),
                             ('maintenance_save_shutdown', operation, session))
            pending = None  # Expiry after supervisor status, before game admission.
            if self.rejects(pending, operation=sent_operation):
                raise RuntimeError('maintenance_operation_mismatch')
            events.append('save or shutdown')
            return {'operation': sent_operation}
        with patch.object(supervisor, 'query', side_effect=submit):
            with self.assertRaisesRegex(RuntimeError, 'maintenance_operation_mismatch'):
                supervisor.Supervisor.stop_saved(InertSupervisor(), operation, expected_session=session, admin_operation=True)
        self.assertEqual(events, [])

    def test_typed_admission_requires_exact_pending_and_completed_warning(self):
        self.assertFalse(self.rejects('d' * 32))
        self.assertTrue(self.rejects(None))
        self.assertTrue(self.rejects('c' * 32))
        self.assertTrue(self.rejects('d' * 32, announcing=True))

    def test_prompt_rechecks_original_body_client_holder_and_rights(self):
        body = self.admin.split('/datum/admins/proc/save_update_resume()\n', 1)[1].split('\n/datum/admins/', 1)[0]
        prompt = body.index('WWinput(requester,')
        for binding in ('var/mob/requester = usr', 'var/client/requester_client = requester.client',
                        'var/datum/admins/requester_holder = requester_client.holder'):
            self.assertLess(body.index(binding), prompt)
        match = re.search(r'\n\tif\(([^\n]+check_rights\(R_SERVER, TRUE, requester\))\) return\n\tif\(!nomads_lifecycle', body[prompt:])
        self.assertIsNotNone(match)
        reject = match.group(1)
        holder = object()
        client = SimpleNamespace(holder=holder, mob=None)
        requester = SimpleNamespace(client=client)
        client.mob = requester
        values = dict(requester=requester, requester_client=client, requester_holder=holder,
                      usr=requester, src=holder, owner=client, R_SERVER=1,
                      check_rights=lambda *args: True)
        self.assertFalse(condition(reject, values))
        for key, replacement in [('usr', object()), ('owner', object()), ('src', object()),
                                 ('requester_holder', None), ('requester_client', None),
                                 ('requester', None), ('check_rights', lambda *args: False)]:
            changed = dict(values, **{key: replacement})
            with self.subTest(change=key):
                self.assertTrue(condition(reject, changed))
        for attribute, replacement in [('mob', object()), ('holder', object())]:
            old = getattr(client, attribute)
            setattr(client, attribute, replacement)
            with self.subTest(client_attribute=attribute):
                self.assertTrue(condition(reject, values))
            setattr(client, attribute, old)
        requester.client = object()
        self.assertTrue(condition(reject, values))


if __name__ == '__main__':
    unittest.main()
