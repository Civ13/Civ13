"""Source contracts for applying stucco to the clay construction doorway."""
from pathlib import Path
import re
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests/save_movement'))
from source_adapter import extract

COVERS = ROOT / 'code/game/objects/covers_types'
BUILDABLE = (COVERS / 'covers_buildable.dm').read_text(encoding='utf-8')
RENDERED = (COVERS / 'covers_rendered.dm').read_text(encoding='utf-8')
CLAY_WALL = '/obj/covers/clay_wall'
RED_EARTH_DOORWAY = CLAY_WALL + '/redearth_doorway'


class StuccoDoorways(unittest.TestCase):
    def test_constructed_doorway_dispatches_to_its_own_stucco_handler(self):
        construction = extract(BUILDABLE, CLAY_WALL + '/incomplete/attackby')
        doorway = re.search(r'else if \(choice == "Doorway"\)\s+new (\S+?)\(', construction)
        self.assertIsNotNone(doorway)
        handler = extract(RENDERED, doorway[1] + '/attackby')
        self.assertRegex(
            handler,
            r'(?m)^\tif \(!istype\(W, /obj/item/weapon/stucco/generic\)\)\n'
            r'\t\treturn \.\.\(\)$',
        )
        self.assertNotIn('WWinput(', handler)
        self.assertRegex(
            handler,
            rf'(?m)^\tif \(do_after\(user, 20, src\)\)\n'
            rf'\t\t[^\n]*\n'
            rf'\t\tqdel\(W\)\n'
            rf'\t\tvar{RED_EARTH_DOORWAY}/S = new {RED_EARTH_DOORWAY}\(loc\)\n'
            rf'\t\tS\.dir = dir\n'
            rf'\t\tqdel\(src\)$',
        )

    def test_red_earth_finish_remains_an_open_doorway(self):
        doorway = re.search(rf'(?m)^{RED_EARTH_DOORWAY}\n((?:\t[^\n]+\n)+)', RENDERED)
        self.assertIsNotNone(doorway)
        for declaration in ('icon_state = "red_earth_doorway"', 'density = FALSE', 'opacity = FALSE'):
            self.assertIn('\t' + declaration + '\n', doorway[1])

    def test_rendered_doorway_rejects_more_stucco_without_wall_dispatch(self):
        handler = extract(RENDERED, RED_EARTH_DOORWAY + '/attackby')
        self.assertRegex(
            handler,
            r'(?m)^\tif \(istype\(W, /obj/item/weapon/stucco/generic\)\)\n'
            r'\t\tto_chat\(user, "[^"\n]+"\)\n'
            r'\t\treturn\n'
            r'\treturn \.\.\(\)\s*\Z',
        )

    def test_solid_clay_wall_keeps_the_wall_finish_menu(self):
        handler = extract(RENDERED, CLAY_WALL + '/attackby')
        self.assertIn(f'new {CLAY_WALL}/redearth(loc)', handler)
        self.assertIn('WWinput(', handler)


if __name__ == '__main__':
    unittest.main()
