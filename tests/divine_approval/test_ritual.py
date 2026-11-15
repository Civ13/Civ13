"""Structural contracts; native semantics are covered by the optional DM probe."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
TEXT = (ROOT / 'code/modules/divine/ritual.dm').read_text()

def body(path):
    return TEXT.split(path, 1)[1].split('\n/', 1)[0]

class RitualContract(unittest.TestCase):
    def test_included_without_entrypoints_or_effects(self):
        self.assertIn('divine/ritual.dm', (ROOT/'civ13.dme').read_text().replace('\\', '/'))
        for forbidden in ('/verb/', '/Topic(', 'visible_message(', 'to_chat(', 'spawn(', 'sleep(', 'var/global', ' in world'):
            self.assertNotIn(forbidden, TEXT)
    def test_bounded_copied_roster(self):
        ctor = body('/datum/divine_use_request/ritual/New')
        for check in ('enrolled.len < 3', 'enrolled.len > 8', 'grant.caster in enrolled', 'session in sessions', 'member in participants', 'participants += member', 'participant_sessions[member] = session', 'participant_origins[member] = get_turf(member)'):
            self.assertIn(check, ctor)
        self.assertNotIn('participants = enrolled', ctor)
    def test_connected_and_conscious(self):
        gate = body('/datum/divine_use_request/ritual/proc/participant_ready')
        for check in ('!QDELETED(member)', 'member.stat == CONSCIOUS', '!member.incapacitated(INCAPACITATION_DISABLED_NO_REST)', 'member.client', 'member.client.mob == member'):
            self.assertIn(check, gate)
    def test_context_stays_bound(self):
        gate = body('/datum/divine_use_request/ritual/current')
        for check in ('!..()', 'QDELETED(focus)', 'get_active_hand() != focus', 'get_inactive_hand() != focus', 'participant_identity(member) != participant_sessions[member]', 'location != participant_origins[member]', 'location.z != caster_origin.z', 'get_dist(location, caster_origin) > channel_radius', 'view(channel_radius, caster_origin)', 'member in visible_members', 'invalidate_channel()'):
            self.assertIn(check, gate)
    def test_deleted_or_removed_roster_entries_fail_closed(self):
        gate = body('/datum/divine_use_request/ritual/current')
        for check in ('participants.len != roster_count', 'participant_sessions.len != roster_count', 'participant_origins.len != roster_count', 'for (var/entry in participants)', '!istype(entry, /mob/living)'):
            self.assertIn(check, gate)
        self.assertNotIn('for (var/mob/living/member in participants)', gate)
    def test_start_requires_approval_and_never_extends_it(self):
        gate = body('/datum/divine_use_request/ritual/proc/start_channel')
        for check in ('state != "approved"', 'channel_started', 'world.time + channel_duration >= deadline', 'channel_ready_at = world.time + channel_duration'):
            self.assertIn(check, gate)
        self.assertNotIn('deadline =', gate)
    def test_completion_uses_parent_single_use_contract(self):
        gate = body('/datum/divine_use_request/ritual/consume')
        self.assertIn('!current() || !channel_started || world.time < channel_ready_at', gate)
        self.assertIn('return ..(subject, spell, destination, scope)', gate)
    def test_explicit_event_invalidation_is_terminal(self):
        gate = body('/datum/divine_use_request/ritual/proc/invalidate_channel')
        self.assertIn('state = "cancelled"', gate)
        self.assertNotIn('state = "requested"', gate)
    def test_no_saved_state_or_live_producers(self):
        source = (ROOT/'code/modules/divine/approval.dm').read_text()
        self.assertIn('/datum/divine_use_request\n\tshould_save = FALSE', source)
        self.assertNotIn('new /datum/divine_use_request/ritual', TEXT)

if __name__ == '__main__':
    unittest.main()
