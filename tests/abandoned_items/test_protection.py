"""Source-projected abandonment protection; no BYOND process or gameplay."""
import importlib.util
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/processes/abandoned_items.dm').read_text(encoding='utf-8-sig')
SPEC = importlib.util.spec_from_file_location('abandonment_adapter', ROOT / 'tests/save_movement/source_adapter.py')
ADAPTER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ADAPTER)
DECL = '/obj/item/proc/abandonment_protected'
STORAGE = '/obj/item/weapon/storage'
CASING = '/obj/item/ammo_casing'
MAG = '/obj/item/ammo_magazine'
GUN = '/obj/item/weapon/gun'
CLOSET = '/obj/structure/closet'


class Node:
    def __init__(self, kind='object', parent=None, deleted=False, opened=False, types=()):
        self.kind, self._loc, self.gcDestroyed, self.opened = kind, parent, deleted, opened
        self.types = set(types)
        self.loc_reads = 0

    @property
    def loc(self):
        self.loc_reads += 1
        return self._loc


class Contents:
    def __init__(self, count=0):
        self.len = count


def legacy(source):
    body = ADAPTER.extract(source, DECL)
    replacements = [
        ('\tvar/atom/container = loc\n', '\tvar/atom/container = loc\n\tvar/protected = FALSE\n'),
        ('\t\tif (isturf(container))\n\t\t\treturn FALSE', '\t\tif (isturf(container))\n\t\t\treturn protected'),
        (f'\t\tif (istype(container, {STORAGE}))\n\t\t\treturn TRUE', f'\t\tif (istype(container, {STORAGE}))\n\t\t\tprotected = TRUE'),
        (f'\t\telse if (istype(src, {CASING}) && (istype(container, {MAG}) || istype(container, {GUN})))\n\t\t\treturn TRUE', f'\t\telse if (istype(src, {CASING}) && (istype(container, {MAG}) || istype(container, {GUN})))\n\t\t\tprotected = TRUE'),
        ('\t\t\tif (!C.opened)\n\t\t\t\treturn TRUE', '\t\t\tif (!C.opened)\n\t\t\t\tprotected = TRUE'),
    ]
    for old, new in replacements:
        assert body.count(old) == 1, old
        body = body.replace(old, new, 1)
    return body


def project(body):
    loop = 'for (var/depth = 1, depth <= 64, depth++)'
    assert body.count(loop) == 1
    body = body.replace(loop, 'for (depth in depth_values)')
    for path in (STORAGE, CASING, MAG, GUN, CLOSET):
        body = body.replace(', ' + path + ')', ', ' + repr(path) + ')')
    env = {'ismob': lambda x: x.kind == 'mob', 'isturf': lambda x: x.kind == 'turf',
           'istype': lambda x, path: path in x.types}
    source = '/proc/projected_protection()\n' + body + '\n'
    return ADAPTER.project(source, '/proc/projected_protection',
        'src, anchored, nodrop, abstract, contents, pulledby, throwing, loc, depth_values', env)


def run(body, parent, casing=False, flags=()):
    src = Node(types=(CASING,) if casing else ())
    return bool(project(body)(src, 'anchored' in flags, 'nodrop' in flags, 'abstract' in flags,
        Contents(int('contents' in flags)), 'pulledby' in flags, 'throwing' in flags, parent, range(1, 65)))


def chain(*nodes):
    for a, b in zip(nodes, nodes[1:]):
        a._loc = b
    return nodes[0]


class AbandonmentProtectionTest(unittest.TestCase):
    def setUp(self):
        self.current = ADAPTER.extract(SOURCE, DECL)
        self.previous = legacy(SOURCE)

    def test_equivalence_and_boundaries(self):
        cases = [
            (None, False, (), True),
            (Node('turf'), False, (), False),
            (Node('mob'), False, (), True),
            (Node(deleted=True), False, (), True),
            (chain(Node(), Node('turf')), False, (), False),
            (chain(Node(types=(STORAGE,)), Node('turf')), False, (), True),
            (chain(Node(types=(CLOSET,), opened=True), Node('turf')), False, (), False),
            (chain(Node(types=(CLOSET,), opened=False), Node('turf')), False, (), True),
            (chain(Node(types=(MAG,)), Node('turf')), False, (), False),
            (chain(Node(types=(MAG,)), Node('turf')), True, (), True),
            (chain(Node(types=(GUN,)), Node('turf')), True, (), True),
            (chain(Node(types=(STORAGE,)), Node(deleted=True)), False, (), True),
            (chain(Node(), Node(types=(STORAGE,)), Node('mob')), False, (), True),
        ]
        cycle = Node()
        cycle._loc = cycle
        cases.append((cycle, False, (), True))
        for depth in (63, 64, 65):
            nodes = [Node() for _ in range(depth)] + [Node('turf')]
            cases.append((chain(*nodes), False, (), depth >= 64))
        for flag in ('anchored', 'nodrop', 'abstract', 'contents', 'pulledby', 'throwing'):
            cases.append((Node('turf'), False, (flag,), True))
        for parent, casing, flags, expected in cases:
            with self.subTest(parent=parent, casing=casing, flags=flags):
                self.assertEqual(run(self.previous, parent, casing, flags), expected)
                self.assertEqual(run(self.current, parent, casing, flags), expected)

    def test_mutation_controls(self):
        storage_guard = f'if (istype(container, {STORAGE}))'
        mutant = self.current.replace(storage_guard, 'if (FALSE)', 1)
        self.assertNotEqual(run(self.current, chain(Node(types=(STORAGE,)), Node('turf'))),
                            run(mutant, chain(Node(types=(STORAGE,)), Node('turf'))))
        head, tail = self.current.rsplit('return TRUE', 1)
        depth_mutant = head + 'return FALSE' + tail
        cycle = Node()
        cycle._loc = cycle
        self.assertNotEqual(run(self.current, cycle), run(depth_mutant, cycle))
        casing_mutant = self.current.replace(f'istype(src, {CASING}) && ', '', 1)
        self.assertNotEqual(run(self.current, chain(Node(types=(MAG,)), Node('turf'))),
                            run(casing_mutant, chain(Node(types=(MAG,)), Node('turf'))))
        closet_mutant = self.current.replace('if (!C.opened)', 'if (C.opened)', 1)
        self.assertNotEqual(run(self.current, chain(Node(types=(CLOSET,), opened=True), Node('turf'))),
                            run(closet_mutant, chain(Node(types=(CLOSET,), opened=True), Node('turf'))))

    def test_modeled_ancestor_reads(self):
        before = [Node(types=(STORAGE,)), Node(), Node('turf')]
        after = [Node(types=(STORAGE,)), Node(), Node('turf')]
        self.assertTrue(run(self.previous, chain(*before)))
        self.assertTrue(run(self.current, chain(*after)))
        self.assertEqual((sum(n.loc_reads for n in before), sum(n.loc_reads for n in after)), (2, 0))


if __name__ == '__main__':
    unittest.main()
