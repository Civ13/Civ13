"""Offline projections of belt constructors and the actual storage admission proc.

Engine type checks and item creation are modeled; this is not a BYOND runtime test.
"""
import importlib.util
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('adapter', ROOT / 'tests/save_movement/source_adapter.py')
A = importlib.util.module_from_spec(spec)
spec.loader.exec_module(A)
A.FIELDS += ('storage_cost', 'w_class', 'max_w_class', 'max_storage_space',
             'can_hold', 'cant_hold', 'storage_slots', 'anchored', 'type')
BELT = (ROOT / 'code/game/objects/items/weapons/storage/belt.dm').read_text(encoding='utf8')
STORAGE = (ROOT / 'code/game/objects/items/weapons/storage/storage.dm').read_text(encoding='utf8')
SIZES = (ROOT / 'code/__defines/inventory_sizes.dm').read_text(encoding='utf8')
CONSTANTS = {name: int(value) for name, value in re.findall(r'(?m)^#define (ITEM_SIZE_\w+)\s+(\d+)\s*$', SIZES)}
BASE = '/obj/item/weapon/storage/belt'
STAR = '/obj/item/weapon/material/thrown/star'
KUNAI = '/obj/item/weapon/material/thrown/kunai_normal'
HATCHET = '/obj/item/weapon/material/hatchet/steel'


def constructor(source, subtype):
    """Translate every simple constructor statement; fail if its shape changes."""
    body = A.extract(source, BASE + subtype + '/New')
    lines = [line.strip() for line in body.splitlines() if line.strip()]
    if not lines or lines.pop(0) != '..()':
        raise AssertionError('Constructor must invoke its parent first')
    result = []
    for line in lines:
        match = re.fullmatch(r'new (/\w+(?:/\w+)*)\((src)?\)', line)
        if not match:
            raise AssertionError('Unsupported constructor statement: ' + line)
        result.append((match[1], match[2] == 'src'))
    return result


def type_block(source, path):
    match = re.search(r'(?m)^' + re.escape(path) + r'\s*\n((?:\t[^\n]*\n|\s*\n)*)', source)
    if not match:
        raise AssertionError('Missing declaration: ' + path)
    return match[1]


def setting(source, subtype, name):
    result = None
    for path in (BASE, BASE + subtype):
        match = re.search(r'(?m)^\t' + name + r'\s*=\s*(\d+)\s*$', type_block(source, path))
        if match:
            result = int(match[1])
    if result is None:
        raise AssertionError('Missing inherited setting: ' + name)
    return result


def whitelist(source):
    block = type_block(source, BASE + '/throwing')
    match = re.search(r'(?s)\bcan_hold\s*=\s*list\((.*?)\)', block)
    if not match:
        raise AssertionError('Missing throwing belt type list')
    return re.findall(r'/[A-Za-z_]+(?:/[A-Za-z_]+)*', match[1])


class DMList(list):
    @property
    def len(self):
        return len(self)

    def __getitem__(self, key):
        return None if isinstance(key, str) else super().__getitem__(key)


class Item:
    def __init__(self, path, size=1):
        self.type = path
        self.w_class = size
        self.storage_cost = None
        self.anchored = False
        self.extraction_surface_source = None
        self.get_storage_cost = lambda: item_cost(self)


item_cost = A.project(STORAGE, '/obj/item/proc/get_storage_cost', 'src', dict(CONSTANTS), method=True)


class StorageType:
    pass


class Bag:
    def __init__(self, source, subtype, contents):
        self.loc = None
        self.storage_slots = setting(source, subtype, 'storage_slots')
        self.max_w_class = setting(source, subtype, 'max_w_class')
        self.max_storage_space = setting(source, subtype, 'max_storage_space')
        self.w_class = 3
        self.contents = DMList(contents)
        self.can_hold = DMList(whitelist(source) if subtype == '/throwing' else [])
        self.cant_hold = DMList()


def admission():
    proc = A.extract(STORAGE, '/obj/item/weapon/storage/proc/can_be_inserted')
    proc = proc.replace('/obj/item/weapon/storage)', 'StorageType)')
    env = {'usr': None, 'StorageType': StorageType, 'typed_iter': lambda values, kind: values,
           'istype': lambda item, kind=Item: isinstance(item, kind), 'to_chat': lambda *args: None,
           'is_type_in_list': lambda item, types: any(item.type == t or item.type.startswith(t + '/') for t in types),
           'instances_of_type_in_list': lambda item, contents: sum(x.type == item.type for x in contents)}
    return A.project('/fixture(W, stop_messages)\n' + proc + '\n', '/fixture',
                     'src,W,stop_messages', env, method=True)


class PrefilledBelts(unittest.TestCase):
    def test_sapper_hatchet_is_created_in_belt_with_other_tools(self):
        items = constructor(BELT, '/utility/sapper')
        self.assertEqual(sum(path == HATCHET for path, _ in items), 1)
        self.assertTrue(all(in_belt for _, in_belt in items))
        self.assertIn(('/obj/item/weapon/wrench', True), items)
        mutant = BELT.replace('new ' + HATCHET + '(src)', 'new ' + HATCHET + '()', 1)
        self.assertIn((HATCHET, False), constructor(mutant, '/utility/sapper'))

    def test_ninja_belt_reaccepts_its_star_and_existing_kunai(self):
        entries = constructor(BELT, '/throwing/ninja')
        thrown = (ROOT / 'code/game/objects/items/weapons/material/thrown.dm').read_text(encoding='utf8')
        for path in (STAR, KUNAI):
            self.assertRegex(type_block(thrown, path), r'(?m)^\tw_class = ITEM_SIZE_TINY$')
        self.assertEqual(sum(path == STAR and located for path, located in entries), 6)
        self.assertEqual(sum(path == KUNAI and located for path, located in entries), 6)
        accept = admission()
        remaining = [Item(path) for path, _ in entries][1:]
        bag = Bag(BELT, '/throwing', remaining)
        self.assertTrue(accept(bag, Item(STAR), True))
        self.assertTrue(accept(bag, Item(KUNAI), True))
        self.assertFalse(accept(bag, Item('/obj/item/weapon/pen'), True))
        bag.contents.append(Item(STAR))
        self.assertFalse(accept(bag, Item(KUNAI), True))
        mutant = BELT.replace('\t\t' + STAR + ',\n', '', 1)
        self.assertFalse(accept(Bag(mutant, '/throwing', remaining), Item(STAR), True))

    def test_press_belt_reaccepts_removed_pen_with_capacity_guard(self):
        entries = constructor(BELT, '/press')
        self.assertEqual(len(entries), 8)
        self.assertTrue(all(located for _, located in entries))
        pen = '/obj/item/weapon/pen'
        self.assertEqual(entries[0][0], pen)
        sources = (
            ('code/game/objects/items/pen.dm', pen, 1),
            ('code/game/objects/items/paper/photography.dm', '/obj/item/camera_film', 1),
            ('code/game/objects/items/clipboard.dm', '/obj/item/weapon/clipboard', 2),
            ('code/modules/reagents/reagent_containers/spray.dm', '/obj/item/weapon/reagent_containers/spray', 2),
            ('code/game/objects/items/paper/photography.dm', '/obj/item/camera', 2),
            ('code/game/objects/items/weapons/storage/storage.dm', '/obj/item/weapon/storage', 3),
            ('code/modules/1713/telephone.dm', '/obj/item/weapon/telephone/mobile', 2),
        )
        for filename, path, size in sources:
            source = (ROOT / filename).read_text(encoding='utf8')
            token = next(key for key, value in CONSTANTS.items() if value == size)
            self.assertRegex(type_block(source, path), r'(?m)^\tw_class = ' + token + r'$')
        remaining = [Item(path, size) for (path, _), size in zip(entries[1:], (1, 1, 2, 2, 2, 3, 2))]
        accept = admission()
        bag = Bag(BELT, '/press', remaining)
        self.assertTrue(accept(bag, Item(pen), True))
        bag.contents.append(Item(pen))
        self.assertFalse(accept(bag, Item(pen), True))
        original_limit = setting(BELT, '', 'storage_slots')
        bag.storage_slots = original_limit
        bag.contents.pop()
        self.assertFalse(accept(bag, Item(pen), True))


if __name__ == '__main__':
    unittest.main()
