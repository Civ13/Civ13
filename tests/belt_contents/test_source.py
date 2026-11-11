"""Offline source contract for prefilled belts (#4544, #4545, #4546); does not execute DM."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
BELT = ROOT / "code/game/objects/items/weapons/storage/belt.dm"


def block(source, header):
    return source.split(header, 1)[1].split('\n/', 1)[0]


def created(source, path):
    """Item paths a belt's New() creates, with their constructor argument."""
    return re.findall(r'new (/obj/[\w/]+)\(([^)]*)\)', block(source, path + '/New()'))


def slots(source, path, inherited=7):
    match = re.search(r'storage_slots = (\d+)', block(source, path + '\n'))
    return int(match.group(1)) if match else inherited


def can_hold(source, path):
    return re.findall(r'(/obj/[\w/]+)', block(source, path + '\n').split('can_hold', 1)[1])


class BeltContentsSource(unittest.TestCase):
    def setUp(self):
        self.source = BELT.read_text(encoding="utf-8")

    def test_sapper_tools_all_start_in_the_belt(self):
        items = created(self.source, '/obj/item/weapon/storage/belt/utility/sapper')
        self.assertEqual(len(items), 7)
        self.assertTrue(all(arg == 'src' for _, arg in items), items)

    def test_press_belt_has_a_slot_for_every_initial_item(self):
        items = created(self.source, '/obj/item/weapon/storage/belt/press')
        self.assertGreaterEqual(slots(self.source, '/obj/item/weapon/storage/belt/press'), len(items))
        old = self.source.replace('\tname = "press belt"\n\tstorage_slots = 8\n', '\tname = "press belt"\n', 1)
        self.assertLess(slots(old, '/obj/item/weapon/storage/belt/press'), len(items))

    def test_ninja_belt_accepts_its_own_contents(self):
        accepted = can_hold(self.source, '/obj/item/weapon/storage/belt/throwing')
        for path, _ in created(self.source, '/obj/item/weapon/storage/belt/throwing/ninja'):
            self.assertTrue(any(path == a or path.startswith(a + '/') for a in accepted), path)


if __name__ == "__main__":
    unittest.main()
