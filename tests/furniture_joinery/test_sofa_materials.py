"""Fixed-art sofa material conservation, using bounded production-body adapters."""
import importlib.util
import json
from pathlib import Path
import re
import sys
from types import SimpleNamespace as NS
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests/primitive_woodworking'))
from source_adapter import block, compile_body
BED = (ROOT / 'code/game/objects/structures/stool_bed_chair_nest/bed.dm').read_text()
BASES = ('/obj/structure/bed/sofa', '/obj/structure/bed/chair/sofa')
KINDS = tuple(base + suffix for base in BASES for suffix in ('', '/left', '/right'))


def disassembly_setting(kind):
    value = True  # /obj/structure default
    chairs = (ROOT / 'code/game/objects/structures/stool_bed_chair_nest/chairs.dm').read_text()
    parts = kind.split('/')
    for end in range(2, len(parts) + 1):
        path = '/'.join(parts[:end])
        for source in (BED, chairs):
            if re.search('^' + re.escape(path) + r'\n', source, re.M):
                match = re.search(r'\tnot_disassemblable = (TRUE|FALSE)', block(source, path + '\n'))
                if match:
                    value = match[1] == 'TRUE'
    return value


def material_stack(material='cloth', amount=3):
    stack = NS(type='/obj/item/stack/material/' + material, amount=amount,
               material=NS(name=material, flags=1))
    stack.use = lambda count: setattr(stack, 'amount', stack.amount - count)
    return stack


def padding_parent(sofa, stock):
    # Execute the stack branch only. Chat/interpolation and uninitialized DM
    # locals are explicit adapters; retain material flag checks, debit and call.
    source = block(BED, '/obj/structure/bed/attackby(')
    source = source[:source.index('\n\telse if (istype(W, /obj/item/weapon/wirecutters))')]
    source = re.sub(r'(?m)^(\t+)to_chat\(.*$', r'\1fixture_chat()', source)
    source = source.replace('var/padding_type //', 'var/padding_type = null //')
    source = source.replace('"[M.material.name]"', 'M.material.name')
    action, _ = compile_body(source, '/obj/structure/bed/attackby(', 'self,W,user',
        dict(istype=lambda obj, kind: getattr(obj, 'type', '').startswith(kind),
             MATERIAL_PADDING=1, fixture_chat=lambda: None),
        ('padding_material', 'loc', 'add_padding'))
    action(sofa, stock, None)


class SofaMaterials(unittest.TestCase):
    def test_all_six_fixed_art_types_refuse_stacks_without_debit(self):
        for kind in KINDS:
            parent = next(base for base in BASES if kind == base or kind.startswith(base + '/'))
            # /bed/chair/sofa is not a descendant of /bed/sofa.
            source = block(BED, parent + '/attackby(')
            for material in ('cloth', 'leather', 'steel'):
                with self.subTest(kind=kind, material=material):
                    calls = []
                    stock = material_stack(material)
                    action, _ = compile_body(source, parent + '/attackby(', 'self,W,user',
                        dict(istype=lambda obj, path: obj.type.startswith(path),
                             to_chat=lambda *args: None, SPAN_NOTICE=lambda text: text,
                             parent_new=lambda: calls.append('parent')))
                    action(NS(), stock, None)
                    self.assertEqual((stock.amount, calls), (3, []))
                    action(NS(), NS(type='/obj/item/weapon/wrench'), None)
                    self.assertEqual(calls, ['parent'])

    def test_existing_noop_padding_path_is_an_explicit_loss_control(self):
        for parent in BASES:
            source = block(BED, parent + '/add_padding(')
            self.assertEqual(source.splitlines()[1].strip(), 'return')
            sofa = NS(padding_material=None, loc=NS(type='/turf'), add_padding=lambda kind: None)
            stock = material_stack()
            padding_parent(sofa, stock)
            self.assertEqual(stock.amount, 2)
            self.assertIsNone(sofa.padding_material)

    def test_supported_bed_padding_still_pays_and_records_material(self):
        for material in ('cloth', 'leather'):
            bed = NS(padding_material=None, loc=NS(type='/turf'))
            bed.add_padding = lambda kind: setattr(bed, 'padding_material', kind)
            stock = material_stack(material)
            padding_parent(bed, stock)
            self.assertEqual((stock.amount, bed.padding_material), (2, material))

    def test_actual_hammer_dispatch_preserves_sofas_and_unrelated_bed(self):
        spec = importlib.util.spec_from_file_location('sofa_refund_adapter', Path(__file__).with_name('test_bedroll.py'))
        helper = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(helper)
        for parent in BASES:
            self.assertIn('not_disassemblable = TRUE', block(BED, parent + '\n'))
            for suffix in ('', '/left', '/right'):
                with self.subTest(kind=parent + suffix):
                    f = helper.Bedding()
                    sofa = NS(loc='floor', contents=[], not_disassemblable=disassembly_setting(parent + suffix), deleted=False)
                    hammer = NS(type='/obj/item/weapon/hammer')
                    action = helper.procedure('', f.env, hammer=True)
                    action(sofa, None, hammer)
                    self.assertFalse(sofa.deleted)
                    self.assertEqual(f.objects, [])
                    # The old inherited FALSE enters the real wood-producing branch.
                    sofa.not_disassemblable = False
                    action(sofa, None, hammer)
                    self.assertTrue(sofa.deleted)
                    self.assertEqual(f.objects[-1].type, '/obj/item/stack/material/wood')
        self.assertIn('not_disassemblable = FALSE', block(BED, '/obj/structure/bed\n'))
        self.assertFalse(disassembly_setting('/obj/structure/bed/wood'))

    def test_existing_sofa_costs_research_and_art_are_preserved(self):
        rows = [r for r in json.loads((Path(__file__).parent / 'legacy-furniture.json').read_text())
                if any(',' + base + suffix + ',' in r['row'] for base in BASES for suffix in ('', '/left', '/right'))]
        self.assertTrue(rows)
        for row in rows:
            self.assertIn(row['row'], (ROOT / row['file']).read_text().splitlines())
        nodes = (ROOT / 'code/modules/research_tree/research_node.dm').read_text()
        for kind in KINDS[:3]:
            self.assertIn('"' + kind + '" = "fine_furniture"', nodes)
        for base in BASES:
            self.assertIn("icon = 'icons/obj/junk.dmi'", block(BED, base + '\n'))

    def test_nonwood_comfy_frame_cannot_use_generic_wood_recovery(self):
        chairs = (ROOT / 'code/game/objects/structures/stool_bed_chair_nest/chairs.dm').read_text()
        self.assertIn('not_disassemblable = TRUE', block(chairs, '/obj/structure/bed/chair/comfy\n'))
        self.assertIn('..(newloc,"steel","leather")', block(chairs, '/obj/structure/bed/chair/comfy/brown/New('))
        for subtype in re.findall(r'^(/obj/structure/bed/chair/comfy[^\s(]*)\n', chairs, re.M):
            self.assertTrue(disassembly_setting(subtype), subtype)


if __name__ == '__main__':
    unittest.main()
