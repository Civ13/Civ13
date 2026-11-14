"""Tool qualities stay equivalent to the item paths they replaced.

is_tool(I, TOOL_X) replaced istype(I, <base path>) checks. That swap is exact
only while each quality is declared by the reviewed set of types below (and
inherited by their subtypes). Adding a quality to a new tool is the point of
the system: add the type to EXPECTED in the same PR so the reviewer sees which
call sites the new tool now satisfies.

Some call sites in source-pinned files still use istype on a base tool path.
LEGACY_CEILING only goes down: new code asks is_tool().
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
EXPECTED = {
    'TOOL_WRENCH': {'/obj/item/weapon/wrench'},
    'TOOL_HAMMER': {'/obj/item/weapon/hammer'},
    'TOOL_CROWBAR': {'/obj/item/weapon/crowbar'},
    'TOOL_WIRECUTTER': {'/obj/item/weapon/wirecutters'},
    'TOOL_SCREWDRIVER': {'/obj/item/weapon/screwdriver'},
    'TOOL_WELDER': {'/obj/item/weapon/weldingtool'},
    'TOOL_KNIFE': {'/obj/item/weapon/material/kitchen/utensil/knife'},
    'TOOL_HATCHET': {'/obj/item/weapon/material/hatchet'},
    'TOOL_SHOVEL': {'/obj/item/weapon/material/shovel'},
    'TOOL_PICKAXE': {'/obj/item/weapon/material/pickaxe'},
    'TOOL_CHISEL': {'/obj/item/weapon/chisel'},
}
BASES = {next(iter(paths)): flag for flag, paths in EXPECTED.items()}
LEGACY = re.compile(r'istype\((?!src\b)[A-Za-z_][\w.]*, */obj/item/weapon/('
                    + '|'.join(re.escape(p[len('/obj/item/weapon/'):]) for p in BASES) + r')\)')
LEGACY_CEILING = 71
DECL = re.compile(r'^(/[\w/]+)\r?\n((?:[ \t]+[^\n]*\r?\n|\r?\n)*)', re.M)


def sources():
    for path in sorted((ROOT / 'code').rglob('*.dm')):
        yield path, path.read_text(encoding='utf-8', errors='replace')


class ToolQualityTest(unittest.TestCase):
    def test_flags_are_distinct_bits(self):
        text = (ROOT / 'code/__defines/tools.dm').read_text()
        flags = dict(re.findall(r'#define (TOOL_\w+)\s+\(1<<(\d+)\)', text))
        self.assertEqual(set(flags), set(EXPECTED))
        self.assertEqual(len(set(flags.values())), len(flags))

    def test_declarations_match_reviewed_types(self):
        found = {flag: set() for flag in EXPECTED}
        for path, text in sources():
            for typepath, body in DECL.findall(text):
                m = re.search(r'^\ttool_flags\s*=\s*([^\n/]+)', body, re.M)
                if m:
                    for flag in re.findall(r'TOOL_\w+', m[1]):
                        found.setdefault(flag, set()).add(typepath)
        self.assertEqual(found, EXPECTED)

    def test_is_tool_refuses_non_items(self):
        text = (ROOT / 'code/_helpers/tools.dm').read_text()
        self.assertIn('if (!isitem(A))\n\t\treturn FALSE', text)
        self.assertIn('(I.tool_flags & quality) == quality', text)

    def test_legacy_base_path_checks_only_shrink(self):
        count = sum(len(LEGACY.findall(text)) for _, text in sources())
        self.assertLessEqual(count, LEGACY_CEILING, 'use is_tool(I, TOOL_X) instead of istype on a base tool path')


if __name__ == '__main__':
    unittest.main()
