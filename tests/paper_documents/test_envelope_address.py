"""Offline envelope-address guards. No native prompt, client or inventory test."""
import re
from types import SimpleNamespace
import unittest

import projection as vm

SOURCE = (vm.ROOT / 'code/game/objects/structures/mail.dm').read_text(encoding='utf-8')
PATH = '/obj/item/weapon/storage/envelope'


class EnvelopeAddress(unittest.TestCase):
    def setUp(self):
        # Expose only implicit DM member access and Adjacent to the existing
        # audited projection helper; execute the entire production predicate.
        fields = r'(?<![\w.])(gc_destroyed|opened|loc|addressee|sender|Adjacent)\b'
        body = vm.body(SOURCE, PATH + '/proc/addressing_current')
        translated = SOURCE.replace(body, re.sub(fields, r'self.\1', body), 1)
        vm.ALLOWED |= {'agent_character_for'}
        vm.METHODS |= {'incapacitated'}
        env = {
            'agent_character_for': lambda writer: writer.agent,
            'isturf': lambda target: getattr(target, 'turf', False),
        }
        self.current = vm.project(
            translated, PATH + '/proc/addressing_current',
            'self,writer,writer_client,writer_agent,pen,expected_loc,expected_addressee,expected_sender', env,
        )
        self.writer = SimpleNamespace(gc_destroyed=False, incapacitated=lambda: False, agent=None)
        self.client = SimpleNamespace(mob=self.writer)
        self.writer.client = self.client
        self.pen = SimpleNamespace(gc_destroyed=False, loc=self.writer)
        self.writer.get_active_hand = lambda: self.pen
        self.envelope = SimpleNamespace(
            gc_destroyed=False, opened=False, loc=self.writer, sender=None, addressee=None, Adjacent=lambda writer: True,
        )

    def check_current(self, expected_loc, addressee=None, sender=None, client='original', agent=None):
        if client == 'original':
            client = self.client
        return self.current(self.envelope, self.writer, client, agent, self.pen, expected_loc, addressee, sender)

    def test_addressing_admits_held_or_adjacent_ground_envelopes(self):
        self.assertTrue(self.check_current(self.writer))
        self.envelope.loc = ground = SimpleNamespace(turf=True)
        self.assertTrue(self.check_current(ground))
        self.assertFalse(self.check_current(self.writer))
        self.envelope.Adjacent = lambda writer: False
        self.assertFalse(self.check_current(ground))

    def test_addressing_preserves_registered_agent_prompt_route(self):
        self.writer.client = None
        self.writer.agent = agent = object()
        self.assertTrue(self.check_current(self.writer, client=None, agent=agent))
        self.assertFalse(self.check_current(self.writer, client=None))
        self.writer.agent = object()
        self.assertFalse(self.check_current(self.writer, client=None, agent=agent))

    def test_addressing_requires_current_actor_tool_and_unmodified_label_state(self):
        for target, name, value in (
            (self.writer, 'gc_destroyed', True),
            (self.writer, 'incapacitated', lambda: True),
            (self.writer, 'client', None),
            (self.client, 'mob', None),
            (self.pen, 'loc', None),
            (self.pen, 'gc_destroyed', True),
            (self.writer, 'get_active_hand', lambda: None),
            (self.envelope, 'gc_destroyed', True),
            (self.envelope, 'opened', True),
            (self.envelope, 'addressee', 'Someone'),
            (self.envelope, 'sender', 'Anyone'),
        ):
            with self.subTest(field=name):
                previous = getattr(target, name)
                setattr(target, name, value)
                self.assertFalse(self.check_current(self.writer))
                setattr(target, name, previous)
        self.envelope.sender = 'Existing partial label'
        self.assertTrue(self.check_current(self.writer, sender=self.envelope.sender))
        self.envelope.addressee = 'Existing recipient'
        self.assertFalse(self.check_current(self.writer, self.envelope.addressee, self.envelope.sender))

    def test_each_prompt_leaves_both_fields_unmodified_until_final_commit(self):
        attack = vm.body(SOURCE, PATH + '/attackby')
        address = attack.split('if(istype(W, /obj/item/weapon/pen))', 1)[1].split('if(istype(W, /obj/item/weapon/stamp/mail))', 1)[0]
        guard = 'addressing_current(user, writer_client, writer_agent, pen, expected_loc, expected_addressee, expected_sender)'
        self.assertEqual(address.count(guard), 3)
        self.assertEqual(address.count('addressee = write_to'), 1)
        self.assertEqual(address.count('sender = write_from'), 1)
        markers = [
            'if (!' + guard,
            'var/write_to = sanitize(player_input(user,',
            'if (!write_to || !' + guard,
            'var/write_from = sanitize(player_input(user,',
            'if (!write_from || !' + guard,
            'addressee = write_to',
            'sender = write_from',
            'desc += ',
        ]
        positions = [address.index(marker) for marker in markers]
        self.assertEqual(positions, sorted(positions))
        self.assertEqual(address.count('null, "text", null, TRUE), 128)'), 2)


if __name__ == '__main__':
    unittest.main()
