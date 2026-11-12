"""Chemical smoke skips other smoke and reagent containers (issue #4803)."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
FILES = ('code/game/objects/effects/chem/chemsmoke.dm',
         'code/game/objects/effects/chem/chemsmoke_types.dm')
SMOKE = '/obj/effect/effect/smoke/chem'
CONTAINER = '/obj/item/weapon/reagent_containers'
GUARD = re.compile(r'if \((.*istype\(AM, ' + re.escape(SMOKE) + r'\).*)\)\s*$')


def guards():
    found = []
    for name in FILES:
        for line in (ROOT / name).read_text(encoding='utf-8').splitlines():
            match = GUARD.search(line.strip())
            if match:
                found.append((name, match.group(1)))
    return found


def admits(expression, types):
    # Evaluate the DM guard for an atom whose type chain is `types`.
    py = expression
    for path in (SMOKE, CONTAINER):
        py = py.replace('istype(AM, %s)' % path, repr(path in types))
    py = py.replace('&&', ' and ').replace('||', ' or ').replace('!', ' not ')
    return eval(py)


class SmokeGuardTest(unittest.TestCase):
    def test_all_four_guards_found(self):
        self.assertEqual(len(guards()), 4)

    def test_guards_skip_smoke_and_containers_but_splash_mobs(self):
        for name, expression in guards():
            with self.subTest(file=name, guard=expression):
                self.assertTrue(admits(expression, ()))
                self.assertFalse(admits(expression, (SMOKE,)))
                self.assertFalse(admits(expression, (CONTAINER,)))


if __name__ == '__main__':
    unittest.main()
