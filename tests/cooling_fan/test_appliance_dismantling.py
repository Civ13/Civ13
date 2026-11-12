"""Source projection of appliance tool dispatch; engine effects are simulated."""
from pathlib import Path
import re
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
APPLIANCES = ROOT / 'code/game/objects/structures/appliances.dm'
TOOLS = ROOT / 'code/game/objects/items/weapons/tools.dm'


def project(source, kind):
    header = '/obj/structure/TV/' + kind + '/attackby('
    body = source.split(header, 1)[1].split('\n', 1)[1].split('\n/obj/', 1)[0]
    lines = ['def attack(src, tool):']
    for line in body.splitlines():
        code = line.strip().split(' //', 1)[0]
        if not code or code.startswith('/*') or code.startswith('//'):
            continue
        match = re.fullmatch(r'(if|else if) \(istype\(O,(/obj/item/weapon/[^)]+)\)\)', code)
        if match:
            statement = ('if' if match[1] == 'if' else 'elif') + ' matches(tool, ' + repr(match[2]) + '):'
        elif code.startswith(('playsound(', 'to_chat(')):
            statement = 'pass'
        elif code == 'anchored = !anchored':
            statement = 'src.anchored = not src.anchored'
        elif re.fullmatch(r'if \(do_after\(user,\d+,src\)\)', code):
            statement = 'if wait(src, ' + re.search(r'\d+', code)[0] + '):'
        elif re.fullmatch(r'for \(var/i=1, i<=\d+, i\+\+\)', code):
            statement = 'for i in range(' + re.search(r'<=([0-9]+)', code)[1] + '):'
        elif re.fullmatch(r'new /obj/item/stack/material/\w+\(loc\)', code):
            statement = 'src.materials.append(' + repr(code.split('/material/', 1)[1].split('(', 1)[0]) + ')'
        elif code == 'qdel(src)':
            statement = 'src.deleted = True'
        else:
            raise AssertionError('Unreviewed operation: ' + code)
        lines.append('    ' * (len(line) - len(line.lstrip('\t'))) + statement)
    env = {'matches': lambda tool, kind: tool == kind or tool.startswith(kind + '/')}
    exec('\n'.join(lines), env)
    return env


class ApplianceDismantlingTest(unittest.TestCase):
    def setUp(self):
        self.source = APPLIANCES.read_text(encoding='utf-8')

    def run_tool(self, kind, tool, completed=True):
        env = project(self.source, kind)
        obj = SimpleNamespace(anchored=True, materials=[], deleted=False, waits=[])
        env['wait'] = lambda obj, ticks: obj.waits.append(ticks) or completed
        env['attack'](obj, '/obj/item/weapon/' + tool)
        return obj

    def test_tool_hierarchy(self):
        tool_source = TOOLS.read_text(encoding='utf-8')
        modern = tool_source.split('/obj/item/weapon/hammer/modern\n', 1)[1].split('\n/obj/', 1)[0]
        self.assertNotIn('parent_type', modern)

    def test_modern_and_ordinary_salvage(self):
        cases = [('television', 'hammer/modern', 20, {'iron': 4, 'electronics': 3}),
                 ('television', 'hammer', 30, {'iron': 2, 'electronics': 1}),
                 ('television', 'hammer/tribalhammer', 30, {'iron': 2, 'electronics': 1}),
                 ('grandfather', 'hammer/modern', 20, {'wood': 6, 'glass': 2}),
                 ('grandfather', 'hammer', 30, {'wood': 3}),
                 ('grandfather', 'hammer/tribalhammer', 30, {'wood': 3})]
        for kind, tool, ticks, expected in cases:
            with self.subTest(kind=kind, tool=tool):
                obj = self.run_tool(kind, tool)
                self.assertEqual(obj.waits, [ticks])
                self.assertCountEqual(obj.materials, [material for material, count in expected.items() for _ in range(count)])
                self.assertTrue(obj.deleted)

    def test_interrupted_wait_and_wrench(self):
        for kind in ('television', 'grandfather'):
            for tool in ('hammer', 'hammer/modern'):
                obj = self.run_tool(kind, tool, completed=False)
                self.assertEqual(obj.materials, [])
                self.assertFalse(obj.deleted)
            obj = self.run_tool(kind, 'wrench')
            self.assertFalse(obj.anchored)
            self.assertEqual((obj.waits, obj.materials, obj.deleted), ([], [], False))

    def test_old_branch_order_misroutes_clawhammer(self):
        modern = '\telse if (istype(O,/obj/item/weapon/hammer/modern))'
        general = '\telse if (istype(O,/obj/item/weapon/hammer))'
        for kind, rough in (('television', ['iron', 'iron', 'electronics']),
                            ('grandfather', ['wood', 'wood', 'wood'])):
            header = '/obj/structure/TV/' + kind + '/attackby('
            prefix, rest = self.source.split(header, 1)
            before, rest = rest.split(modern, 1)
            modern_body, rest = rest.split(general, 1)
            general_body, after = rest.split('\n/obj/', 1)
            old_order = prefix + header + before + general + general_body + modern + modern_body + '\n/obj/' + after
            env = project(old_order, kind)
            obj = SimpleNamespace(anchored=True, materials=[], deleted=False, waits=[])
            env['wait'] = lambda obj, ticks: obj.waits.append(ticks) or True
            env['attack'](obj, '/obj/item/weapon/hammer/modern')
            self.assertEqual(obj.waits, [30])
            self.assertCountEqual(obj.materials, rough)


if __name__ == '__main__':
    unittest.main()
