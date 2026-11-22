"""Heavy casings take powder from the container the player used (#6843)."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/projectiles/ammo_crafting.dm'
HANDLERS = (
    '/obj/item/stack/ammopart/casing/grenade/attackby(',
    '/obj/item/stack/ammopart/casing/booster/attackby(',
    '/obj/item/stack/ammopart/casing/artillery/attackby(',
    '/obj/item/stack/ammopart/casing/artillery/wired/advanced/filled/attackby(',
    '/obj/item/stack/ammopart/casing/tank/attackby(',
)


def block(text, header):
    start = text.index('\n' + header) + 1
    end = re.search(r'\n(?=\S)', text[start:])
    return text[start:start + end.start() if end else len(text)]


class PowderLoadingContainerTests(unittest.TestCase):
    def setUp(self):
        self.text = SOURCE.read_text(encoding='utf-8-sig').replace('\r\n', '\n')

    def test_each_casing_fills_from_the_used_container(self):
        for header in HANDLERS:
            with self.subTest(header=header):
                body = block(self.text, header)
                powder = body[:body.index('\n\t\treturn\n')]
                self.assertIn('fill_gunpowder_from(W, user,', powder)
                self.assertNotIn('l_hand', powder)
                self.assertNotIn('r_hand', powder)

    def test_helper_charges_only_the_given_container(self):
        helper = block(self.text, '/obj/item/stack/ammopart/casing/proc/fill_gunpowder_from(')
        self.assertNotIn('_hand', helper)
        check = helper.index('RC.reagents.has_reagent("gunpowder", needed)')
        remove = helper.index('RC.reagents.remove_reagent("gunpowder", needed)')
        self.assertLess(check, remove)
        self.assertLess(remove, helper.index('gunpowder = needed'))


if __name__ == '__main__':
    unittest.main()
