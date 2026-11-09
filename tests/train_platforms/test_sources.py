"""Source contracts for walkable platform cars. Never launches BYOND."""
from pathlib import Path
import re
import struct
import sys
import zlib
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import run  # noqa: E402

SOURCE = (ROOT / 'code/modules/1713/train_platforms.dm').read_text(encoding='utf-8')
WARFARE = (ROOT / 'code/modules/1713/train_warfare.dm').read_text(encoding='utf-8')
TRAINS = (ROOT / 'code/modules/1713/trains.dm').read_text(encoding='utf-8')
RECIPES = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
NODES = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
KITS = ['/obj/structure/train_car_kit', '/obj/structure/train_car_kit/coach', '/obj/structure/train_car_kit/sleeper',
        '/obj/structure/train_car_kit/dining', '/obj/structure/train_car_kit/storage',
        '/obj/structure/train_car_kit/railgun', '/obj/structure/train_car_kit/armored',
        '/obj/structure/train_car_kit/flak']


def dmi_description(path):
    """The DMI metadata from a PNG's zTXt/tEXt chunk, without image libraries."""
    data = path.read_bytes()
    pos = 8
    while pos < len(data):
        length = struct.unpack('>I', data[pos:pos + 4])[0]
        kind = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if kind in (b'zTXt', b'tEXt') and body.startswith(b'Description\0'):
            rest = body[len(b'Description\0'):]
            return (zlib.decompress(rest[1:]) if kind == b'zTXt' else rest).decode('utf-8')
    return ''


class TrainPlatformSourceTests(unittest.TestCase):
    def test_included_once(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertEqual(dme.count('#include "code\\modules\\1713\\train_platforms.dm"'), 1)
        self.assertEqual(dme.count('#include "code\\modules\\1713\\train_warfare.dm"'), 1)

    def test_parts_are_rebuilt_not_saved(self):
        part = SOURCE[SOURCE.index('\n/obj/structure/train_part\n'):]
        self.assertIn('should_save = FALSE', part[:part.index('\n/obj/structure/train_part/')])
        self.assertIn('var/tmp/list/deck_parts', SOURCE)
        self.assertRegex(SOURCE, r'/obj/structure/trains/platform/after_load\(\)\n\t\.\.\(\)\n\tapply_layout\(\)')

    def test_locomotive_checks_clearance_before_moving(self):
        body = TRAINS[TRAINS.index('/obj/structure/trains/proc/process_rail_movement()'):]
        self.assertLess(body.index('train_consist_obstacle(src, tgtt, fdir)'), body.index('if (!src.Move(tgtt, fdir))'))

    def test_every_kit_is_craftable_and_researched(self):
        for kit in KITS:
            self.assertRegex(RECIPES, r'(?m)^RECIPE: /material/(iron|steel)/,[a-z ]+ kit,%s,' % re.escape(kit))
            self.assertRegex(NODES, r'"%s" = "(rail_steam|assembly_line|field_artillery|automatic_weapons)"' % re.escape(kit))
        self.assertRegex(RECIPES, r'(?m)^RECIPE: /material/steel/,armored locomotive,/obj/structure/trains/locomotive/coal/armored,')

    def test_kit_names_are_compiled_defaults(self):
        # Restored kits must not rename themselves in a constructor.
        self.assertNotIn('/obj/structure/train_car_kit/New(', SOURCE)
        self.assertNotIn('/obj/structure/train_car_kit/New(', WARFARE)
        for kind in ('coach', 'sleeper', 'dining', 'storage', 'railgun', 'armored', 'flak'):
            self.assertRegex(SOURCE + WARFARE, r'/obj/structure/train_car_kit/%s\n\tname = "[a-z ]+ kit"\n\tcar_kind = "%s"' % (kind, kind))

    def test_icon_states_exist(self):
        desc = dmi_description(ROOT / 'icons/obj/vehicles/train_platforms.dmi')
        states = set(re.findall(r'state = "([^"]+)"', desc))
        for kind in ('wood', 'floor', 'carpet', 'steel'):
            self.assertIn('deck_center_' + kind, states)
            self.assertIn('deck_side_' + kind, states)
        for style in ('wall', 'window', 'door', 'door_open', 'inner_door', 'inner_door_open', 'partition', 'rail'):
            self.assertIn('edge_' + style, states)
        for state in ('car_kit', 'edge_armor', 'edge_armor_door', 'edge_armor_door_open', 'brace_up', 'brace_down',
                      'wreck', 'loco_armor'):
            self.assertIn(state, states)
        gun = dmi_description(ROOT / 'icons/obj/vehicles/railway_gun.dmi')
        self.assertIn('state = "railway_gun"', gun)

    def test_railway_gun_needs_a_braced_car(self):
        topic = WARFARE[WARFARE.index('/obj/structure/cannon/modern/railway/Topic('):]
        self.assertLess(topic.index('fire_problem()'), topic.index('return ..()'))
        consist = SOURCE[SOURCE.index('/proc/train_consist_obstacle('):]
        consist = consist[:consist.index('\n/', 1)]
        self.assertIn('braced', consist)
        self.assertIn('wrecked', consist)

    def test_native_fixture_preparation(self):
        generated = run.sources()
        self.assertIn('#include "tests/train_platforms/probe.dm"', generated[run.PREFIX + '.dme'])
        self.assertNotRegex(generated[run.PREFIX + '.dme'], r'(?m)^#include ".*\.dmm"')


if __name__ == '__main__':
    unittest.main()
