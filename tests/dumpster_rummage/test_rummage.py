"""Source-projected dumpster rummage with fake engine boundaries."""
from pathlib import Path
from types import SimpleNamespace
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'save_movement'))
from source_adapter import extract, project, read

CRATES = 'code/game/objects/structures/crates_lockers/crates.dm'
DECLARATION = '/obj/structure/closet/crate/dumpster/attack_hand'
TAKEN = 'You take out \\the [picked].'


class Contents(list):
    @property
    def len(self):
        return len(self)


class Item:
    def __init__(self, name):
        self.name = name
        self.loc = 'dumpster'

    def forceMove(self, loc):
        self.loc = loc


def rummage(close_during_wait=False, wait_succeeds=True, source=None):
    """Run the production attack_hand body for a grab-intent rummage."""
    items = Contents([Item('can'), Item('rag')])
    env = {'contents': items, 'opened': True, 'locked': False, 'I_GRAB': 'grab',
           'src': 'dumpster', 'messages': []}
    env['ishuman'] = lambda user: True
    env['add_fingerprint'] = lambda user: None
    env['to_chat'] = lambda user, text: env['messages'].append(text)
    env['update_icon'] = lambda: None
    env['toggle'] = lambda user: env['messages'].append('toggled')
    env['pick'] = lambda choices: choices[0]

    def do_after(user, delay, target):
        if close_during_wait:
            env['opened'] = False
        return wait_succeeds
    env['do_after'] = do_after
    user = SimpleNamespace(a_intent='grab', loc='floor')
    handler = project(source or read(CRATES), DECLARATION, 'user', env)
    handler(user)
    return items, env


class DumpsterRummage(unittest.TestCase):
    def test_open_dumpster_rummage_takes_one_item(self):
        items, env = rummage()
        self.assertEqual([item.loc for item in items], ['floor', 'dumpster'])
        self.assertIn(TAKEN, env['messages'])

    def test_closing_during_wait_takes_nothing(self):
        items, env = rummage(close_during_wait=True)
        self.assertEqual([item.loc for item in items], ['dumpster', 'dumpster'])
        self.assertNotIn(TAKEN, env['messages'])

    def test_interrupted_wait_takes_nothing(self):
        items, _ = rummage(wait_succeeds=False)
        self.assertEqual([item.loc for item in items], ['dumpster', 'dumpster'])

    def test_negative_control_without_open_recheck(self):
        # The pre-fix condition removes an item from a dumpster closed during the wait.
        source = read(CRATES).replace('do_after(user,40,src) && opened && contents.len',
                                      'do_after(user,40,src) && contents.len')
        self.assertNotEqual(source, read(CRATES))
        items, _ = rummage(close_during_wait=True, source=source)
        self.assertEqual(items[0].loc, 'floor')


if __name__ == '__main__':
    unittest.main()
