"""Source guards only: native behavioral probe is separate, not emulated here."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "code/modules/divine/approval.dm"
TEXT = SOURCE.read_text()

def body(path):
    return TEXT.split(path, 1)[1].split('\n/', 1)[0]

class Contract(unittest.TestCase):
    def test_disabled_and_no_entrypoints(self):
        self.assertNotIn('divine/approval.dm', (ROOT/'civ13.dme').read_text())
        self.assertNotIn('/Topic(', TEXT)
        self.assertNotIn('/verb/', TEXT)
        self.assertNotIn('var/global', TEXT)
        self.assertIn('var/active = FALSE', TEXT)
    def test_no_approval_restoration(self):
        self.assertEqual(TEXT.count('should_save = FALSE'), 2)
        self.assertNotIn('savefile', TEXT)
    def test_operator_gate(self):
        gate = body('/datum/divine_covenant_runtime/proc/operator_allowed')
        for check in ('current()', 'operator.holder', 'R_ADMIN', 'operator.ckey in operator_ckeys'):
            self.assertIn(check, gate)
    def test_knowledge_is_not_approval(self):
        ctor = body('/datum/divine_use_request/New')
        self.assertIn('state = "requested"', ctor)
        self.assertNotIn('state = "approved"', ctor)
        consume = body('/datum/divine_use_request/proc/consume')
        self.assertIn('state != "approved"', consume)
    def test_single_use_and_recheck(self):
        consume = body('/datum/divine_use_request/proc/consume')
        for check in ('current()', 'subject != covenant.caster', 'spell != spell_id',
                      'destination != target', 'scope != scope_key',
                      'operator_key(approver) != approver_ckey', 'approved_deity'):
            self.assertIn(check, consume)
        self.assertLess(consume.index('state = "consumed"'), consume.index('return TRUE'))
        self.assertNotIn('sleep(', consume)
        self.assertNotIn('spawn(', consume)
    def test_session_and_scope_change(self):
        gate = body('/datum/divine_covenant_runtime/proc/current')
        for check in ('caster.client == caster_client', 'caster_client.mob == caster'):
            self.assertIn(check, gate)
        gate = body('/datum/divine_use_request/proc/current')
        for check in ('world.time >= deadline', 'covenant.revision != covenant_revision',
                      'spell_id in covenant.allowed_spells', '!= caster_origin', '!= target_origin'):
            self.assertIn(check, gate)
    def test_bounded_pending_and_copied_config(self):
        self.assertIn('lifetime > 600', TEXT)
        self.assertIn('operators.Copy()', TEXT)
        self.assertIn('spells.Copy()', TEXT)
    def test_private_not_broadcast(self):
        self.assertNotIn('message_admins(', TEXT)
        self.assertNotIn('to_chat(', TEXT)
        self.assertNotIn('visible_message(', TEXT)
        self.assertIn('log_admin(', TEXT)

if __name__ == '__main__':
    unittest.main()
