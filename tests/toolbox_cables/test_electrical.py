"""Check the electrical toolbox's starting cable coils from source, not BYOND."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
TOOLBOX = ROOT / 'code/game/objects/items/weapons/storage/toolbox.dm'
CABLES = ROOT / 'code/modules/1713/machinery/cables_types.dm'
STACK = ROOT / 'code/game/objects/items/stacks/stack.dm'
COLOURS = ('red', 'yellow', 'green', 'blue', 'pink', 'orange', 'cyan', 'white')

# The pre-fix constructor, frozen as a negative control.
OLD_BODY = '''
		var/color = pick("red","yellow","green","blue","pink","orange","cyan","white")
		new /obj/item/stack/cable_coil(src,30,color)
		new /obj/item/stack/cable_coil(src,30,color)
'''


def electrical_new(text):
    start = text.index('/obj/item/weapon/storage/toolbox/electrical\n')
    end = text.find('\n/obj/', start + 1)
    return text[start:end if end != -1 else len(text)]


def coil_problems(body):
    """Return why the toolbox would not give two 30-piece coils of one chosen colour."""
    problems = []
    picked = re.search(r'var/(\w+) = pick\(([^)]*)\)', body)
    if not picked:
        return ['no colour pick']
    var, options = picked.group(1), [o.strip() for o in picked.group(2).split(',')]
    expected = ['/obj/item/stack/cable_coil/' + c for c in COLOURS]
    if options != expected:
        problems.append('pick is not the eight coloured coil types: %r' % options)
    calls = re.findall(r'new (\S+)\(src, *(\d+), *([^)]*)\)', body)
    if [c for c in calls if c[0] == var] != [(var, '30', 'FALSE')] * 2:
        problems.append('coils are not two new %s(src, 30, FALSE): %r' % (var, calls))
    return problems


class ElectricalToolboxCablesTest(unittest.TestCase):
    def test_stack_third_argument_is_merge_flag(self):
        self.assertIn('/obj/item/stack/New(var/loc, var/_amount=0, var/merge = can_stack)',
                      STACK.read_text(encoding='utf-8'))

    def test_coloured_subtypes_set_cable_colour(self):
        text = CABLES.read_text(encoding='utf-8')
        for colour in COLOURS:
            block = re.search(r'/obj/item/stack/cable_coil/%s\n((?:\t.*\n)+)' % colour, text)
            self.assertIsNotNone(block, colour)
            self.assertIn('cable_color = "%s"' % colour, block.group(1))

    def test_toolbox_uses_one_coloured_type_without_merge(self):
        self.assertEqual(coil_problems(electrical_new(TOOLBOX.read_text(encoding='utf-8'))), [])

    def test_negative_control_old_constructor_fails(self):
        self.assertTrue(coil_problems(OLD_BODY))


if __name__ == '__main__':
    unittest.main()
