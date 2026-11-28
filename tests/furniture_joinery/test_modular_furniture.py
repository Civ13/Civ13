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
PARTS = (ROOT / 'code/modules/1713/furniture_upholstery.dm').read_text()


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

    def test_project_and_finished_refits_charge_only_the_selected_part(self):
        load = DM.split('/obj/item/furniture_project/proc/fit_project_upholstery(', 1)[1].split('/obj/item/furniture_project/proc/site_clear', 1)[0]
        self.assertLess(load.index('if (cut ||'), load.index('S.use(1)'))
        self.assertLess(load.index('S.use(1)'), load.index('design_part_a = record'))
        refit = PARTS.split('/obj/structure/bed/proc/commit_modular_upholstery(', 1)[1]
        self.assertLess(refit.index('if (previous !='), refit.index('furniture_upholstery_pay(W'))
        self.assertLess(refit.index('furniture_upholstery_pay(W'), refit.index('furniture_refund_upholstery(previous, site)'))
        self.assertIn('furniture_upholstery_b = record', refit)
        self.assertIn('furniture_upholstery_kind(record) == kind && S.use(1)', PARTS)

    def test_portable_stool_has_one_paid_slot_and_reuses_existing_art(self):
        self.assertIn('if ("Stool") return /obj/item/weapon/stool/wood/modular', DM)
        self.assertIn('if ("Stool") return list("Seat")', PARTS)
        self.assertIn('shape == "Stool" && design_part_b && furniture_refund_upholstery', DM)
        self.assertIn('furniture_design_layers("Stool", furniture_finish, furniture_upholstery_a, null)', PARTS)
        commit = PARTS.split('/obj/item/weapon/stool/wood/modular/proc/commit_modular_seat(', 1)[1]
        self.assertLess(commit.index('furniture_upholstery_a != previous'), commit.index('furniture_upholstery_pay(W'))
        self.assertLess(commit.index('furniture_upholstery_pay(W'), commit.index('furniture_refund_upholstery(previous, site)'))

    def test_finish_is_paid_once_and_validated_after_wait(self):
        assembly = DM.split('/obj/item/furniture_project/proc/assemble(', 1)[1]
        self.assertRegex(assembly, r'wait_for_furniture\(.*\).*\|\| !ready\(H, origin, save_epoch\).*\|\| !site_clear')
        self.assertLess(assembly.index('!design_allowed(H)'), assembly.index('new result_type'))
        self.assertLess(assembly.index('QDELETED(F)'), assembly.index('qdel(src)'))

    def test_style_and_raw_materials_are_separate(self):
        bed = (STOOL / 'bed.dm').read_text()
        self.assertIn('if (render_modular_furniture()) return', bed)
        self.assertIn('B.furniture_finish = design_finish', DM)
        self.assertIn('new result_type(origin, "wood")', DM)
        saved = (ROOT / 'code/modules/1713/furniture_fabric_dye.dm').read_text()
        self.assertIn('if (padding_color || modular_furniture_shape)', saved)
        self.assertIn('B.furniture_upholstery_a = design_part_a', DM)
        self.assertIn('B.furniture_upholstery_b = design_part_b', DM)

    def test_reuses_existing_directional_art(self):
        self.assertIn('list(SOUTH, NORTH, EAST, WEST)', DM)
        meta = sprite_metadata(ROOT / 'icons/obj/bed_chair.dmi')
        dirs = dict(re.findall(r'state = "([^"]+)"\s+dirs = (\d+)', meta))
        self.assertEqual({s: dirs.get(s) for s in ('chair', 'chair_padding', 'bed', 'bed_padding')},
                         {'chair': '4', 'chair_padding': '4', 'bed': '1', 'bed_padding': '1'})
        masks = sprite_metadata(ROOT / 'icons/obj/furniture_upholstery.dmi')
        self.assertEqual(dict(re.findall(r'state = "([^"]+)"\s+dirs = (\d+)', masks)),
                         {'chair_seat': '4', 'chair_back': '4', 'bed_mattress': '1', 'bed_cover': '1'})
        self.assertIn('furniture_design_layers(design_shape, design_finish, design_part_a, design_part_b)', DM)
        self.assertIn('furniture_design_layers(modular_furniture_shape, furniture_finish, furniture_upholstery_a, furniture_upholstery_b)', PARTS)
