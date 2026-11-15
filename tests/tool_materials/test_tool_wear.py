"""Soft tools and tool wear (docs/material-roles.md, "Soft tools").

code/modules/materials/tool_wear.dm asks the thing being worked what it is
made of; a tool less firm than that waits first and takes heavy wear.

- The rule is asked once, before attackby(), and never on harm intent.
- Every material a target names exists and has a firmness.
- Tools in their usual material cut their usual work cleanly: an iron or
  stone chisel is not soft on stone, steel wirecutters are not soft on any
  wire, so today's tools behave as before.
- The softer tools the plan adds are caught: copper and bone chisels on
  stone, bronze wirecutters on iron wire.
- A plain tool has no health until it first wears, and breaks at 0.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/materials/tool_wear.dm').read_text(encoding='utf-8')
PROPERTIES = (ROOT / 'code/modules/materials/material_properties.dm').read_text(encoding='utf-8')
MATERIALS = (ROOT / 'code/modules/materials/materials.dm').read_text(encoding='utf-8', errors='ignore')
ATTACK = (ROOT / 'code/_onclick/item_attack.dm').read_text(encoding='utf-8')
DME = (ROOT / 'civ13.dme').read_text(encoding='utf-8')


def firmness():
    """material type path -> firmness, with inheritance from the parent path."""
    own = {}
    current = None
    for line in PROPERTIES.splitlines():
        head = re.match(r'^(/material[\w/]*)\s*$', line)
        if head:
            current = head.group(1)
            continue
        value = re.match(r'^\tfirmness = ([\d.]+)', line)
        if value and current:
            own[current] = float(value.group(1))
    return own


def firmness_of(name):
    """Firmness by material name, resolved through materials.dm type names."""
    own = firmness()
    path = None
    for match in re.finditer(r'^(/material/[\w/]+)\n((?:\t.*\n)+)', MATERIALS, re.M):
        if re.search(r'^\tname = "%s"' % re.escape(name), match.group(2), re.M):
            path = match.group(1)
            break
    if path is None:
        path = '/material/' + name
    while path and path not in own:
        path = path.rsplit('/', 1)[0]
    return own.get(path)


class ToolWearTests(unittest.TestCase):
    def test_compiled_after_the_files_it_wraps(self):
        self.assertIn('code\\modules\\materials\\tool_wear.dm', DME)
        self.assertLess(DME.index('code\\_helpers\\item_wear.dm'), DME.index('code\\modules\\materials\\tool_wear.dm'))
        self.assertLess(DME.index('code\\modules\\materials\\tool_materials.dm'),
                        DME.index('code\\modules\\materials\\tool_wear.dm'))

    def test_asked_once_before_attackby(self):
        self.assertEqual(ATTACK.count('tool_meets_work('), 1)
        self.assertLess(ATTACK.index('tool_meets_work(src, A, user)'), ATTACK.index('A.attackby(src, user'))
        self.assertLess(ATTACK.index('tool_meets_work(src, A, user)'), ATTACK.index('resolve_attack_turf(A, user'))

    def test_never_on_harm_intent_and_only_for_tools(self):
        body = SOURCE.split('/proc/tool_meets_work(', 1)[1].split('\n// What cuts what.', 1)[0]
        self.assertIn('user.a_intent == I_HARM', body)
        self.assertIn('!I.tool_flags', body)
        self.assertIn('do_after(user, SOFT_TOOL_DELAY, A)', body)

    def test_named_work_materials_exist(self):
        names = set(re.findall(r'\? \(?(?:[\w\[\]]+ \|\| )?"(\w+)"\)? : null', SOURCE))
        self.assertEqual(names, {'stone', 'marble', 'sandstone', 'copper', 'iron'})
        for name in names:
            self.assertIsNotNone(firmness_of(name), name)

    def test_usual_tools_are_not_soft_on_their_usual_work(self):
        for tool, work in (('iron', 'stone'), ('stone', 'stone'), ('iron', 'marble'), ('stone', 'sandstone'),
                           ('steel', 'iron'), ('steel', 'copper'), ('iron', 'iron')):
            self.assertGreaterEqual(firmness_of(tool), firmness_of(work), (tool, work))

    def test_softer_tools_are_caught(self):
        for tool, work in (('copper', 'stone'), ('bone', 'stone'), ('copper', 'marble'), ('bronze', 'iron'),
                           ('bone', 'sandstone')):
            self.assertLess(firmness_of(tool), firmness_of(work), (tool, work))

    def test_bronze_cuts_stone_and_copper_wire(self):
        self.assertGreaterEqual(firmness_of('bronze'), firmness_of('stone'))
        self.assertGreaterEqual(firmness_of('bronze'), firmness_of('copper'))

    def test_wear_is_lazy_and_breaks_at_zero(self):
        wear = SOURCE.split('/proc/tool_job_wear(', 1)[1].split('\n// A worn-out plain tool', 1)[0]
        self.assertIn('if (amount <= 0)\n\t\treturn FALSE', wear)
        self.assertLess(wear.index('if (amount <= 0)'), wear.index('I.health = TOOL_WEAR_LIFE'))
        self.assertIn('I.apply_wear(amount, WEAR_WORK)', wear)
        broke = SOURCE.split('/obj/item/check_health(consumed)', 1)[1].split('/obj/item/examine', 1)[0]
        self.assertIn('. = ..()', broke)
        self.assertIn('!tool_noun', broke)
        self.assertIn('qdel(src)', broke)

    def test_soft_wear_outlasts_a_few_jobs_only(self):
        life = float(re.search(r'#define TOOL_WEAR_LIFE (\d+)', SOURCE).group(1))
        soft = float(re.search(r'#define TOOL_WEAR_SOFT ([\d.]+)', SOURCE).group(1))
        self.assertTrue(10 <= life / soft <= 40)


if __name__ == '__main__':
    unittest.main()
