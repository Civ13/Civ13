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


def recovery_environment(outputs):
    materials = (ROOT / 'code/modules/materials/materials.dm').read_text()
    def construct(kind, loc):
        item = NS(type=kind, loc=loc, amount=1)
        outputs.append(item)
        return item
    generic = block(materials, '/material/proc/place_sheet(').replace(
        'return new stack_type(target)', 'return construct(stack_type, target)')
    place, _ = compile_body(generic, '/material/proc/place_sheet(', 'self,target',
                            dict(construct=construct), ('stack_type',))
    def material(name):
        body = block(materials, '/material/' + name + '\n')
        stack = re.search(r'\tstack_type = (/[\w/]+)', body)
        datum = NS(type='/material/' + name, stack_type=stack[1] if stack else None)
        datum.place_sheet = lambda site: place(datum, site)
        return datum
    factory = block(BED, '/proc/furniture_padding_sheet(')
    factory = re.sub(r'return new (/[\w/]+)\(([^\n]*)\)',
                     lambda m: 'return construct(' + json.dumps(m[1]) + ', ' + m[2] + ')', factory)
    sheet, _ = compile_body(factory, '/proc/furniture_padding_sheet(', 'padding,site',
                            dict(construct=construct))
    return material, dict(furniture_padding_sheet=sheet, construct=construct,
                         get_turf=lambda obj: 'floor')


class SofaMaterials(unittest.TestCase):
    def test_padding_recovery_pays_exact_identity_or_keeps_unrecoverable_padding(self):
        for source, signature in ((BED, '/obj/structure/bed/proc/remove_padding('),
                ((ROOT / 'code/game/objects/structures/stool_bed_chair_nest/stools.dm').read_text(),
                 '/obj/item/weapon/stool/proc/remove_padding(')):
            for name, stack_name in (('cloth', 'cloth'), ('leather', 'leather'),
                                     ('cotton', 'cotton'), ('leather/dark', None)):
                with self.subTest(signature=signature, material=name):
                    outputs = []
                    make_material, env = recovery_environment(outputs)
                    material = make_material(name)
                    furniture = NS(padding_material=material, update_icon=lambda: None)
                    remove, _ = compile_body(source, signature, 'self',
                        env,
                        ('padding_material', 'update_icon'))
                    self.assertEqual(bool(remove(furniture)), bool(stack_name))
                    if stack_name:
                        self.assertIsNone(furniture.padding_material)
                        self.assertEqual([(x.type, x.amount) for x in outputs],
                                         [('/obj/item/stack/material/' + stack_name, 1)])
                        self.assertFalse(remove(furniture))
                        self.assertEqual(len(outputs), 1)
                    else:
                        self.assertIs(furniture.padding_material, material)
                        self.assertEqual(outputs, [])

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
                    sofa = NS(type=parent + suffix, padding_material=None, loc='floor', contents=[],
                              not_disassemblable=disassembly_setting(parent + suffix), deleted=False)
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

    def hammer_case(self, kind, padding_name, after=lambda obj: True):
        outputs = []
        make_material, env = recovery_environment(outputs)
        padding = make_material(padding_name) if padding_name else None
        furniture = NS(type=kind, padding_material=padding, material=make_material('wood'),
                       loc='floor', contents=[], not_disassemblable=False, deleted=False,
                       update_icon=lambda: None)
        env.update(qdel=lambda obj: setattr(obj, 'deleted', True),
                   do_after=lambda *args: after(furniture),
                   to_chat=lambda *args: None, SPAN_NOTICE=lambda text: text,
                   playsound=lambda *args: None,
                   istype=lambda obj, path: getattr(obj, 'type', '').startswith(path))
        stool = kind.startswith('/obj/item/weapon/stool')
        source = (ROOT / 'code/game/objects/structures/stool_bed_chair_nest/stools.dm').read_text() if stool else BED
        prefix = '/obj/item/weapon/stool' if stool else '/obj/structure/bed'
        remove, _ = compile_body(source, prefix + '/proc/remove_padding(', 'self', env,
                                ('padding_material', 'update_icon'))
        furniture.remove_padding = lambda: remove(furniture)
        hammer = NS(type='/obj/item/weapon/hammer')
        if stool:
            dismantle, _ = compile_body(source, prefix + '/proc/dismantle(', 'self', env,
                                        ('material', 'padding_material'))
            furniture.dismantle = lambda: dismantle(furniture)
            branch = block(source, prefix + '/attackby(')
            branch = branch[:branch.index('\n\telse if (istype(W,/obj/item/stack))')]
            action, _ = compile_body(branch, prefix + '/attackby(', 'self,W,user', env,
                                    ('padding_material', 'remove_padding', 'dismantle', 'loc'))
            action(furniture, hammer, None)
        else:
            spec = importlib.util.spec_from_file_location('padding_hammer_adapter', Path(__file__).with_name('test_bedroll.py'))
            helper = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(helper)
            helper.procedure('', env, hammer=True)(furniture, None, hammer)
        return furniture, padding, outputs

    def test_actual_hammer_paths_recover_padding_or_preserve_everything(self):
        for kind in ('/obj/structure/bed/wood', '/obj/item/weapon/stool/wood'):
            for name in ('cloth', 'leather', 'leather/dark', None):
                with self.subTest(kind=kind, padding=name):
                    furniture, padding, outputs = self.hammer_case(kind, name)
                    if name == 'leather/dark':
                        self.assertFalse(furniture.deleted)
                        self.assertIs(furniture.padding_material, padding)
                        self.assertEqual(outputs, [])
                    else:
                        self.assertTrue(furniture.deleted)
                        self.assertIsNone(furniture.padding_material)
                        expected = ['/obj/item/stack/material/wood']
                        if name:
                            expected.append('/obj/item/stack/material/' + name)
                        self.assertCountEqual([x.type for x in outputs], expected)
                        self.assertTrue(all(x.amount == 1 for x in outputs))

    def test_bed_hammer_cancellation_and_late_unmapped_padding_have_no_output(self):
        for after in (lambda obj: False,
                      lambda obj: setattr(obj, 'padding_material', NS(type='/material/leather/dark',
                                          place_sheet=lambda site: None)) or True):
            furniture, padding, outputs = self.hammer_case('/obj/structure/bed/wood', 'cloth', after)
            self.assertFalse(furniture.deleted)
            self.assertIsNotNone(furniture.padding_material)
            self.assertEqual(outputs, [])
        # The shared hammer path for non-bed structures stays outside the new guard.
        furniture, padding, outputs = self.hammer_case('/obj/structure/wooden_control', None)
        self.assertTrue(furniture.deleted)
        self.assertEqual([x.type for x in outputs], ['/obj/item/stack/material/wood'])

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
