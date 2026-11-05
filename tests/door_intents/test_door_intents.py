"""Offline projection of door hand intents from production DM, without starting BYOND."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
DOOR = (ROOT / 'code/game/objects/structures/door.dm').read_text()
KEY_DOOR = (ROOT / 'code/game/objects/structures/key_doors/key_door.dm').read_text()


def proc_body(source, header):
    start = source.index(header + '(')
    lines = source[start:].splitlines()[1:]
    body = []
    for line in lines:
        if line and not line.startswith('\t'):
            break
        body.append(line)
    return body


def interact(state=False, intent='help', locked=False, switching=False):
    """Evaluate door_intent_interact's if/return ladder against synthetic state."""
    values = {
        '!user || !istype(user) || isSwitchingStates': switching,
        'state': state,
        'user.a_intent == I_HELP': intent == 'help',
        'door_hand_locked(user)': locked,
        'user.a_intent == I_DISARM || user.a_intent == I_GRAB': intent in ('disarm', 'grab'),
    }
    skip_depth = None
    for line in proc_body(DOOR, '/obj/structure/simple_door/proc/door_intent_interact'):
        if not line.strip():
            continue
        depth = len(line) - len(line.lstrip('\t'))
        if skip_depth is not None:
            if depth > skip_depth:
                continue
            skip_depth = None
        text = line.strip()
        match = re.fullmatch(r'if \((.*)\)', text)
        if match:
            condition = match.group(1)
            assert condition in values, condition
            if not values[condition]:
                skip_depth = depth
            continue
        match = re.fullmatch(r'return (\w+)(?:\(user\))?', text)
        assert match, text
        return match.group(1)
    raise AssertionError('door_intent_interact fell through')


class DoorIntentContract(unittest.TestCase):
    def test_closed_door_follows_intent(self):
        self.assertEqual(interact(intent='help'), 'TryToSwitchState')
        self.assertEqual(interact(intent='help', locked=True), 'door_rattle')
        for intent in ('disarm', 'grab'):
            with self.subTest(intent=intent):
                self.assertEqual(interact(intent=intent), 'door_knock')
                self.assertEqual(interact(intent=intent, locked=True), 'door_knock')
        self.assertEqual(interact(intent='harm'), 'door_kick')
        self.assertEqual(interact(intent='harm', locked=True), 'door_kick')

    def test_open_door_closes_on_every_intent_even_when_locked(self):
        # A key locked while open, or a faction outsider, still closes the door.
        for intent in ('help', 'disarm', 'grab', 'harm'):
            for locked in (False, True):
                with self.subTest(intent=intent, locked=locked):
                    self.assertEqual(interact(state=True, intent=intent, locked=locked), 'TryToSwitchState')

    def test_switching_door_ignores_hands(self):
        self.assertEqual(interact(switching=True, state=True), 'FALSE')

    def test_faction_doors_take_no_kick_damage(self):
        kick = proc_body(KEY_DOOR, '/obj/structure/simple_door/key_door/door_kick')
        self.assertIn('\tif (. && door_takes_kick_damage())', kick)
        self.assertIn('\t\tupdate_damage(-10)', kick)
        faction = proc_body(KEY_DOOR, '/obj/structure/simple_door/key_door/faction_door/door_takes_kick_damage')
        self.assertEqual([line.strip() for line in faction if line.strip()], ['return FALSE'])
        ordinary = proc_body(KEY_DOOR, '/obj/structure/simple_door/key_door/proc/door_takes_kick_damage')
        self.assertEqual([line.strip() for line in ordinary if line.strip()],
                         ['return !istype(src, /obj/structure/simple_door/key_door/custom)'])


if __name__ == '__main__':
    unittest.main()


STAMPS = (ROOT / 'code/modules/persistence/world_time_stamps.dm').read_text()


class DoorRebootTimers(unittest.TestCase):
    """world.time restarts at zero after a reboot, so saved stamps must not block doors."""

    def test_bump_and_knock_stamps_are_not_saved(self):
        self.assertIn('\t"last_bumped" = list(/atom),\n', STAMPS)
        self.assertIn('\t"next_attack_hand" = list(/obj/structure/simple_door),\n', STAMPS)

    def test_future_bump_stamp_is_cleared_before_the_cooldown(self):
        body = [line.strip() for line in proc_body(DOOR, '/obj/structure/simple_door/proc/TryToSwitchState')]
        reset = body.index('if (user.last_bumped > world.time)')
        self.assertEqual(body[reset + 1], 'user.last_bumped = FALSE')
        self.assertLess(reset, body.index('if (user.last_bumped && world.time - user.last_bumped <= 60)'))

    def test_future_noise_stamp_is_cleared(self):
        body = [line.strip() for line in proc_body(DOOR, '/obj/structure/simple_door/proc/door_noise_ready')]
        reset = body.index('if (next_attack_hand > world.time + 10)')
        self.assertEqual(body[reset + 1], 'next_attack_hand = -1')
        self.assertLess(reset, body.index('if (world.time < next_attack_hand)'))


class FactionDoorLockpick(unittest.TestCase):
    """A faction door ignores its keyslot, so a picked lock must open the door itself."""

    def test_lockpick_goes_to_the_faction_pick(self):
        body = [line.strip() for line in proc_body(KEY_DOOR, '/obj/structure/simple_door/key_door/faction_door/attackby') if line.strip()]
        self.assertEqual(body[:3], ['if (istype(W, /obj/item/weapon/lockpick))', 'faction_door_pick(W, user)', 'return'])
        self.assertEqual(body[-1], 'return ..()')

    def test_successful_pick_opens_the_door_after_rechecking(self):
        body = [line.strip() for line in proc_body(KEY_DOOR, '/obj/structure/simple_door/key_door/faction_door/proc/faction_door_pick')]
        recheck = body.index('if (QDELETED(src) || QDELETED(W) || state || isSwitchingStates || !H.Adjacent(src))')
        self.assertLess(body.index('if (!do_after(H, 35*H.getStatCoeff("dexterity"), src))'), recheck)
        opened = body.index('Open()')
        self.assertLess(recheck, opened)
        self.assertEqual(body[opened - 3], 'if (prob(H.getStatCoeff("dexterity")*35))')
        self.assertNotIn('keyslot.locked = FALSE', body)
