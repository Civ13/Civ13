"""Exercise the DM construction completion with isolated wait and turf adapters."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/game/objects/items/stacks/rods.dm').read_text()


def project_completion(source):
    body = source.split('\t\tif (!do_after(usr, 10))', 1)[1].split('\n\treturn', 1)[0]
    statements = ['def complete():', '    if not wait():']
    translations = {
        'in_use = FALSE': 'in_use = False',
        'return': 'return',
        'if (locate(/obj/structure/grille) in usr.loc)': 'if occupied():',
        'to_chat(usr, "<span class=\'warning\'>There is already a grille here.</span>")': 'notify()',
        'var/obj/structure/grille/F = new /obj/structure/grille/ ( usr.loc )': 'place()',
        'to_chat(usr, "<span class=\'notice\'>You assemble a grille</span>")': 'notify()',
        'F.add_fingerprint(usr)': 'fingerprint()',
        'use(2)': 'use(2)',
    }
    for raw in body.splitlines():
        if not raw.strip():
            continue
        indent = len(raw) - len(raw.lstrip('\t')) - 1
        statement = raw.strip()
        if statement not in translations:
            raise AssertionError('Unreviewed grille completion statement: ' + statement)
        statements.append('    ' * indent + translations[statement])
    return '\n'.join(statements) + '\n'


class GrilleConstruction(unittest.TestCase):
    def make_completion(self, turf, rods, wait=True):
        env = {
            'wait': lambda: wait,
            'occupied': lambda: bool(turf),
            'place': lambda: turf.append('grille'),
            'use': lambda count: rods.__setitem__(0, rods[0] - count),
            'notify': lambda: None,
            'fingerprint': lambda: None,
        }
        exec(compile(project_completion(SOURCE), '<projected grille completion>', 'exec'), env)
        return env['complete']

    def test_second_concurrent_assembler_keeps_rods(self):
        turf, first_rods, second_rods = [], [2], [2]
        first = self.make_completion(turf, first_rods)
        second = self.make_completion(turf, second_rods)
        first()
        second()
        self.assertEqual(turf, ['grille'])
        self.assertEqual((first_rods, second_rods), ([0], [2]))

    def test_interrupted_wait_does_not_build_or_consume(self):
        turf, rods = [], [2]
        self.make_completion(turf, rods, wait=False)()
        self.assertEqual((turf, rods), ([], [2]))


if __name__ == '__main__':
    unittest.main()
