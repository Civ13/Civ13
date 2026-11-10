"""Execute the jail key production branches with small Python adapters, not BYOND."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/game/objects/structures/door.dm').read_text(encoding='utf-8')
PARENT = '/obj/structure/simple_door/key_door/custom/jail/'
KEY = '/obj/item/weapon/key'
CHAIN = '/obj/item/weapon/storage/belt/keychain'


def body(source, path):
    match = re.search(r'^' + re.escape(path) + r'\([^\n]*\)\n((?:\t[^\n]*\n|\n)*)', source, re.M)
    if not match:
        raise AssertionError('missing procedure: ' + path)
    return match.group(1)


def helper(source):
    """Translate only reviewed syntax from the actual DM helper; unknown code fails closed."""
    out = ['def run(door, W, user):']
    for raw in body(source, PARENT + 'proc/jail_key_interact').splitlines():
        if not raw.strip():
            continue
        depth = len(raw) - len(raw.lstrip('\t'))
        text = raw.strip()
        if text.startswith(('if (', 'else if (')) and text.endswith(')'):
            condition = text[text.index('(') + 1:-1]
            condition = re.sub(r'istype\(W, (/[^)]+)\)', lambda m: f"istype(W, {m[1]!r})", condition)
            condition = re.sub(r'\bcustom_code\b', 'door.custom_code', condition)
            condition = re.sub(r'\blocked\b', 'door.locked', condition)
            if not re.fullmatch(r"[\w. /,()!='\-]+", condition):
                raise AssertionError('unreviewed condition: ' + condition)
            text = ('elif ' if text.startswith('else') else 'if ') + condition + ':'
        elif text == 'for (var/obj/item/weapon/key/KK in W.contents)':
            text = 'for KK in (x for x in W.contents if istype(x, KEY)):'
        elif text == 'locked = !locked':
            text = 'door.locked = not door.locked'
        elif text == 'locked = locked':  # Negative control.
            text = 'door.locked = door.locked'
        elif text in ('return TRUE', 'return FALSE'):
            text = text.replace('TRUE', 'True').replace('FALSE', 'False')
        elif text.startswith('visible_message('):
            text = text.replace('visible_message(', 'door.visible_message(', 1)
        elif text.startswith('playsound('):
            text = text.replace("'sound/effects/door_lock_unlock.ogg'", '"sound/effects/door_lock_unlock.ogg"')
        elif text.startswith('to_chat('):
            pass
        else:
            raise AssertionError('unreviewed statement: ' + text)
        out.append('    ' * depth + text)
    env = {'istype': lambda obj, kind: obj.kind == kind, 'KEY': KEY,
           'playsound': lambda *args: args[0].sounds.append(args[1:]),
           'get_turf': lambda user: user, 'to_chat': lambda user, msg: user.messages.append(msg)}
    exec(compile('\n'.join(out), '<projected jail key helper>', 'exec'), env)
    return env['run']


def dispatch(source, door, item, user):
    """Project the callers' key branch and its return/fallthrough contract."""
    lines = [line.strip() for line in body(source, PARENT + door.kind + '/attackby').splitlines() if line.strip()]
    assert lines[:3] == [f'if (istype(W, {KEY}) || istype(W, {CHAIN}))',
                         'if (jail_key_interact(W, user))', 'return']
    assert lines[-1] == 'return TRUE // for key_doors'
    if item.kind in (KEY, CHAIN):
        if helper(source)(door, item, user):
            return None
        return True
    return 'other interaction'


class Actor:
    def __init__(self):
        self.messages = []
        self.sounds = []


class Item:
    def __init__(self, kind, code=None, contents=()):
        self.kind, self.code, self.contents = kind, code, list(contents)


class Door:
    def __init__(self, kind, locked):
        self.kind, self.locked, self.custom_code = kind, locked, 'a'
        self.messages = []

    def visible_message(self, text):
        self.messages.append(text)


class JailKeys(unittest.TestCase):
    def check(self, item, locked, expected, returned, message=None, source=SOURCE):
        for kind in ('woodjail', 'steeljail'):
            with self.subTest(kind=kind, item=item.kind, locked=locked):
                door, user = Door(kind, locked), Actor()
                self.assertEqual(dispatch(source, door, item, user), returned)
                self.assertEqual(door.locked, expected)
                self.assertEqual(user.messages, [] if message is None else [message])
                if returned is None:
                    verb = 'unlocks' if locked else 'locks'
                    self.assertEqual(door.messages, [f"<span class = 'notice'>[user] {verb} the door.</span>"])
                    self.assertEqual(user.sounds, [('sound/effects/door_lock_unlock.ogg', 100)])
                else:
                    self.assertEqual(door.messages, [])
                    self.assertEqual(user.sounds, [])

    def test_single_key_and_chain_matches_both_lock_states(self):
        for locked in (False, True):
            for item in (Item(KEY, 'a'), Item(CHAIN, contents=[Item(KEY, 'a')]),
                         Item(CHAIN, contents=[Item(KEY, 'x'), Item(KEY, 'a'), Item(KEY, 'a')])):
                self.check(item, locked, not locked, None)

    def test_mismatch_and_keychain_code_quirk(self):
        for locked in (False, True):
            self.check(Item(KEY, 'x'), locked, locked, True, 'This key does not match this lock!')
            self.check(Item(CHAIN, 'x'), locked, locked, True, 'None of the keys match this lock!')
            self.check(Item(CHAIN, 'a', [Item(KEY, 'x')]), locked, locked, True)
            self.check(Item('other'), locked, locked, 'other interaction')

    def test_negative_controls_detect_omitted_toggle_and_matching_chain_key(self):
        missing_toggle = SOURCE.replace('locked = !locked', 'locked = locked', 1)
        missing_loop = SOURCE.replace('if (KK.code == custom_code)', 'if (KK.code != custom_code)', 1)
        for kind in ('woodjail', 'steeljail'):
            door = Door(kind, False)
            self.assertIsNone(dispatch(missing_toggle, door, Item(KEY, 'a'), Actor()))
            self.assertFalse(door.locked)
            door = Door(kind, False)
            self.assertTrue(dispatch(missing_loop, door, Item(CHAIN, contents=[Item(KEY, 'a')]), Actor()))
            self.assertFalse(door.locked)


if __name__ == '__main__':
    unittest.main()
