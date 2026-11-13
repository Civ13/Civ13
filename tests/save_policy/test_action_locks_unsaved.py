"""A character's in-progress action locks must stay out of world saves.

Persistence saves tmp vars too. A Gaia save taken while a player was
practising kept scholar_practising = TRUE on the saved body, so after every
restore the character was told "You are already practising" and could never
practise again (2026-11-13). Every busy/practising lock declared on a mob must
be named by a persistence_runtime_var override, which skips it on save and on
load (so bodies already saved with the lock load clean).
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
LOCK = re.compile(r'^/mob[\w/]*/var/tmp/(\w*(?:busy|practising)\w*)\b', re.M)
OVERRIDE = re.compile(r'^/mob[\w/]*/persistence_runtime_var\(key\)\n((?:\t.*\n|\n)*)', re.M)


def sources():
    for path in sorted((ROOT / 'code').rglob('*.dm')):
        yield path, path.read_text(encoding='utf-8', errors='replace')


def mob_action_locks():
    locks = {}
    for path, text in sources():
        for name in LOCK.findall(text):
            locks[name] = path.relative_to(ROOT).as_posix()
    return locks


def excluded_keys():
    keys = set()
    for _, text in sources():
        for body in OVERRIDE.findall(text):
            keys.update(re.findall(r'"(\w+)"', body))
    return keys


class ActionLocksUnsavedTest(unittest.TestCase):
    def test_known_locks_are_found(self):
        locks = mob_action_locks()
        for name in ('scholar_practising', 'tree_climb_busy', 'cpr_revival_busy'):
            self.assertIn(name, locks)

    def test_every_mob_action_lock_is_runtime_state(self):
        missing = {name: path for name, path in mob_action_locks().items() if name not in excluded_keys()}
        self.assertEqual(missing, {}, 'mob action locks saved with the body')

    def test_practice_lock_override(self):
        text = (ROOT / 'code/modules/research_tree/scholar_practice.dm').read_text(encoding='utf-8')
        override = '/mob/living/human/persistence_runtime_var(key)\n\treturn key == "scholar_practising" || ..()'
        self.assertTrue(override in text, 'scholar_practising is saved with the body')


if __name__ == '__main__':
    unittest.main()
