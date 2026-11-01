"""Offline destruction-chain characterization; no engine or collector launch."""
from itertools import product
from pathlib import Path
import re
import sys
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests/save_movement'))
from source_adapter import project

BASE = '/obj/structure/multiz/ladder'
SOURCE = ROOT / 'code/modules/multiz/structures.dm'
BEFORE = Path(__file__).with_name('fixtures') / 'destroy_before.txt'


def definitions(text, path):
    """Retain every complete same-type definition in textual include order."""
    result = []
    for match in re.finditer(r'^' + re.escape(path) + r'/Destroy\(\)\n', text, re.M):
        body = []
        for line in text[match.end():].splitlines():
            if line.strip() and not line.startswith('\t'):
                break
            body.append(line)
        result.append('\n'.join(body).rstrip())
    return result


class Registry:
    def __init__(self, members, trace):
        self.members = members
        self.trace = trace

    def __isub__(self, owner):
        self.trace.append(('unregister', tuple(self.members)))
        # Explicit boundary model: native -= is not implemented by this test.
        for index in range(len(self.members) - 1, -1, -1):
            if self.members[index] == owner:
                self.members.pop(index)
                break
        return self


class Harness:
    def __init__(self, text, *, ww2=False, top=True, target=True, copies=1,
                 hint='parent-hint', delivery='retain'):
        self.trace = []
        self.owner = SimpleNamespace(target='peer' if target else None, istop=top)
        self.registry = SimpleNamespace(members=Registry(['other'] + ['owner'] * copies, self.trace))
        self.hint = hint
        self.delivery = delivery
        chain = self.parent
        bodies = definitions(text, BASE)
        if ww2:
            bodies += definitions(text, BASE + '/ww2')
        for body in bodies:
            # Rename just this layer so the existing strict projector can accept
            # duplicate declarations without guessing which definition wins.
            body = re.sub(r'\btarget\b', 'owner.target', body)
            body = re.sub(r'\bistop\b', 'owner.istop', body)
            body = re.sub(r'\bsrc\b', '"owner"', body)
            body = body.replace('ladder_list', 'registry.members').replace('..()', 'parent()')
            env = dict(owner=self.owner, registry=self.registry, parent=chain, qdel=self.qdel)
            chain = project('/layer()\n' + body + '\n', '/layer', '', env)
        self.invoke = chain

    def parent(self):
        self.trace.append(('parent', tuple(self.registry.members.members)))
        return self.hint

    def qdel(self, target):
        self.trace.append(('qdel', target, tuple(self.registry.members.members)))
        if self.delivery == 'clear-target':
            self.owner.target = None
        elif self.delivery == 'clear-top':
            self.owner.istop = False

    def run(self):
        result = self.invoke()
        return result, self.trace, self.registry.members.members, self.owner.target, self.owner.istop


class DestroyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.before = BEFORE.read_text(encoding='utf-8')
        cls.after = SOURCE.read_text(encoding='utf-8')

    def test_preimage_and_single_definition_keep_ww2_layer(self):
        self.assertEqual(len(definitions(self.before, BASE)), 2)
        self.assertEqual(len(definitions(self.after, BASE)), 1)
        self.assertEqual(definitions(self.before, BASE + '/ww2'), definitions(self.after, BASE + '/ww2'))

    def test_before_after_matrix(self):
        cases = product((False, True), (False, True), (False, True), (0, 1, 2), (None, 'hint'))
        for ww2, top, target, copies, hint in cases:
            with self.subTest(ww2=ww2, top=top, target=target, copies=copies, hint=hint):
                options = dict(ww2=ww2, top=top, target=target, copies=copies, hint=hint)
                old = Harness(self.before, **options).run()
                new = Harness(self.after, **options).run()
                self.assertEqual(new, old)
                self.assertIsNone(new[0])
                self.assertEqual(sum(row[0] == 'parent' for row in new[1]), 1)
                self.assertEqual(new[2].count('other'), 1)

    def test_partner_cleanup_precedes_registry_then_parent(self):
        trace = Harness(self.after).run()[1]
        self.assertEqual(trace, [('qdel', 'peer', ('other', 'owner')),
                                 ('unregister', ('other', 'owner')), ('parent', ('other',))])

    def test_ww2_retains_two_requests_when_boundary_retains_target(self):
        self.assertEqual([row[0] for row in Harness(self.after, ww2=True).run()[1]],
                         ['qdel', 'qdel', 'unregister', 'parent'])

    def test_callback_state_changes_are_observed_by_next_layer(self):
        for delivery in ('clear-target', 'clear-top'):
            options = dict(ww2=True, delivery=delivery)
            old = Harness(self.before, **options).run()
            new = Harness(self.after, **options).run()
            self.assertEqual(new, old)
            self.assertEqual([row[0] for row in new[1]], ['qdel', 'unregister', 'parent'])

    def test_mutation_controls_detect_missing_effects_order_and_return(self):
        body = definitions(self.after, BASE)[0]
        variants = [body.replace('\t\tqdel(target)', '\t\t..()'),
                    body.replace('\tladder_list -= src\n', ''),
                    body.replace('\t..()', '\treturn null'),
                    body.replace('\tladder_list -= src\n', '').replace('\tif (', '\tladder_list -= src\n\tif (', 1),
                    body.replace('\t..()', '\treturn ..()')]
        expected = Harness(self.after).run()
        for mutant in variants:
            with self.subTest(mutant=mutant):
                self.assertNotEqual(Harness(BASE + '/Destroy()\n' + mutant + '\n').run(), expected)


if __name__ == '__main__':
    unittest.main()
