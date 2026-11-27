"""Source and real DMI metadata checks for the modular furniture draft."""
from pathlib import Path
import re
import struct
import unittest
import zlib

ROOT = Path(__file__).resolve().parents[2]
DM = (ROOT / 'code/modules/1713/modular_furniture.dm').read_text()
RECIPES = (ROOT / 'config/crafting/material_recipes_global.txt').read_text()
RESEARCH = (ROOT / 'code/modules/research_tree/research_node.dm').read_text()
STOOL = ROOT / 'code/game/objects/structures/stool_bed_chair_nest'


def sprite_metadata(path):
    data = path.read_bytes()
    for offset in range(8, len(data)):
        if data[offset:offset + 4] == b'zTXt':
            count = struct.unpack('>I', data[offset - 4:offset])[0]
            key, value = data[offset + 4:offset + 4 + count].split(b'\0', 1)
            if key == b'Description':
                return zlib.decompress(value[1:]).decode()
    raise ValueError('Missing compressed DMI metadata')


class ModularFurnitureTests(unittest.TestCase):
    def test_real_recipe_and_basic_furniture_gate(self):
        self.assertIn('furniture project,/obj/item/furniture_project,4,60,0,1,furniture', RECIPES)
        self.assertIn('"/obj/item/furniture_project" = "basic_furniture"', RESEARCH)
        self.assertIn('crafting_node_allowed(H, "basic_furniture")', DM)

    def test_paid_optional_upholstery_cannot_be_double_installed_or_removed_after_cut(self):
        load = DM.split('/obj/item/furniture_project/attackby', 1)[1].split('/obj/item/furniture_project/proc/site_clear', 1)[0]
        self.assertLess(load.index('working || cut || has_cloth'), load.index('C.use(1)'))
        self.assertLess(load.index('C.use(1)'), load.index('has_cloth = TRUE'))
        self.assertIn('if (!cut && has_cloth)', DM)
        self.assertIn('has_cloth ? "cloth" : null', DM)

    def test_finish_is_paid_once_and_validated_after_wait(self):
        assembly = DM.split('/obj/item/furniture_project/proc/assemble(', 1)[1]
        self.assertRegex(assembly, r'wait_for_furniture\(.*\).*\|\| !ready\(H, origin, save_epoch\).*\|\| !site_clear')
        self.assertLess(assembly.index('!design_allowed(H)'), assembly.index('new result_type'))
        self.assertLess(assembly.index('QDELETED(F)'), assembly.index('qdel(src)'))

    def test_style_and_raw_materials_are_separate(self):
        bed = (STOOL / 'bed.dm').read_text()
        self.assertIn('furniture_finish_color(furniture_finish)', bed)
        self.assertIn('F.furniture_finish = design_finish', DM)
        self.assertIn('new result_type(origin, "wood",', DM)
        saved = (ROOT / 'code/modules/1713/furniture_fabric_dye.dm').read_text()
        self.assertIn('if (padding_color || furniture_finish)', saved)

    def test_reuses_existing_directional_art(self):
        self.assertIn('list(SOUTH, NORTH, EAST, WEST)', DM)
        meta = sprite_metadata(ROOT / 'icons/obj/bed_chair.dmi')
        dirs = dict(re.findall(r'state = "([^"]+)"\s+dirs = (\d+)', meta))
        self.assertEqual({s: dirs.get(s) for s in ('chair', 'chair_padding', 'bed', 'bed_padding')},
                         {'chair': '4', 'chair_padding': '4', 'bed': '1', 'bed_padding': '1'})
