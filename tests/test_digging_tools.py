"""Source-derived admission regressions. No compiler, game, server or network.

These tests evaluate only production type predicates and selected research IDs.
They do not emulate DM scheduling, native type inference or client collisions.
"""
import ast
from pathlib import Path
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
BASE = '9af7d9a0382967735c92f9d8a836002bd410803c'
FLOOR = 'code/game/turfs/floor_attackby.dm'
TRENCH = 'code/modules/1713/trench.dm'
PICK = '/obj/item/weapon/material/pickaxe'
SHOVEL = '/obj/item/weapon/material/shovel'
UTENSIL = '/obj/item/weapon/material/kitchen/utensil'


def source(path):
    return (ROOT / path).read_text(encoding='utf-8')


def baseline(path):
    return subprocess.check_output(['git', 'show', BASE + ':' + path], cwd=ROOT).decode().replace('\r\n', '\n')


def procedure(text, name):
    start = text.index(name)
    end = re.search(r'\n/[^/]', text[start + len(name):])
    return text[start:] if end is None else text[start:start + len(name) + end.start()]


def type_gate(expression, variable, item_type):
    """Evaluate the actual explicit istype/boolean predicate, fail on other syntax."""
    pattern = r'istype\(' + variable + r',\s*(/[\w/]+)\)'
    expression = re.sub(pattern, lambda m: str(item_type is not None and
                        (item_type == m[1] or item_type.startswith(m[1] + '/'))), expression)
    expression = expression.replace('&&', ' and ').replace('||', ' or ').replace('!', ' not ')

    def visit(node):
        if isinstance(node, ast.Constant) and type(node.value) is bool:
            return node.value
        if isinstance(node, ast.UnaryOp) and isinstance(node.op, ast.Not):
            return not visit(node.operand)
        if isinstance(node, ast.BoolOp):
            values = [visit(v) for v in node.values]
            if isinstance(node.op, ast.And):
                return all(values)
            if isinstance(node.op, ast.Or):
                return any(values)
        raise AssertionError('unsupported production type predicate: ' + expression)
    return visit(ast.parse(expression.strip(), mode='eval').body)


def mining_gates(text):
    click_end = text.index('start_pickaxe_mining(H, C)')
    click_start = text.rindex('else if (', 0, click_end) + len('else if (')
    click = text[click_start:text.index('\n', click_start)].rstrip()[:-1]
    shared = procedure(text, '/turf/proc/start_pickaxe_mining(')
    reject_line = next(row.strip() for row in shared.splitlines() if 'P.loc != H' in row)
    reject = reject_line[len('if ('):reject_line.index(' || P.loc != H')]
    return click, reject


class DiggingToolRules(unittest.TestCase):
    def assert_mining_matrix(self, text):
        click, reject = mining_gates(text)
        for tool in (PICK, PICK + '/bone', PICK + '/stone', PICK + '/steel', PICK + '/jackhammer',
                     UTENSIL, UTENSIL + '/knife', UTENSIL + '/knife/shank/wood',
                     UTENSIL + '/spoon', UTENSIL + '/fork', SHOVEL, '/obj/item', None):
            expected = tool is not None and (tool == PICK or tool.startswith(PICK + '/'))
            self.assertEqual(type_gate(click, 'C', tool), expected, 'click admission: ' + str(tool))
            self.assertEqual(not type_gate(reject, 'P', tool), expected, 'shared action admission: ' + str(tool))

    def test_click_and_shared_action_accept_pickaxes_reject_knives_and_non_tools(self):
        self.assert_mining_matrix(source(FLOOR))
        # Bind representative subtype cases to actual production declarations.
        for path in (PICK, PICK + '/bone', PICK + '/stone', PICK + '/steel', PICK + '/jackhammer', SHOVEL):
            self.assertIn('\n' + path + '\n', source('code/modules/1713/tools.dm'))
        kitchen = source('code/game/objects/items/weapons/material/kitchen.dm')
        self.assertIn('\n' + UTENSIL + '/knife/shank/wood\n', kitchen)
        self.assertIn('\n' + UTENSIL + '/spoon\n', kitchen)

    def test_held_bump_selection_checks_both_hands_without_switching(self):
        held = procedure(source(FLOOR), '/mob/living/human/proc/held_mining_pickaxe()')
        self.assertEqual(held.count('istype(P, ' + PICK + ')'), 2)
        self.assertEqual(held.count('P.loc == src'), 2)
        self.assertLess(held.index('get_active_hand()'), held.index('get_inactive_hand()'))
        # Knife in active hand may use a real pickaxe in inactive hand; knife
        # alone, carried tools and empty hands cannot satisfy the held gates.
        for active, inactive, selected in ((UTENSIL + '/knife/shank/wood', None, None),
                                          (UTENSIL + '/knife/shank/wood', PICK, PICK),
                                          (PICK + '/bone', PICK, PICK + '/bone'),
                                          ('/obj/item', None, None), (None, None, None)):
            candidates = (t for t in (active, inactive) if type_gate('istype(P, ' + PICK + ')', 'P', t))
            self.assertEqual(next(candidates, None), selected)
        self.assertNotIn('swap_hand', held)
        self.assertNotIn('contents', held)
        bump = procedure(source(FLOOR), '/mob/living/human/proc/try_bump_mining(')
        for gate in ('!A.density', '!bump_mining_authority()', 'world.time <= next_click',
                     'held_mining_pickaxe()', 'if (!P)', 'start_pickaxe_mining(src, P, TRUE)'):
            self.assertIn(gate, bump)

    def assert_trench_research(self, text):
        blocks = re.findall(r'(?m)^/turf/floor/(?:dirt|beach/sand)/attackby\([^\n]*\n.*?(?=\n/|\Z)', text, re.S)
        self.assertEqual(len(blocks), 3)  # Includes both existing dirt overloads.
        for block in blocks:
            node = re.search(r'map\.is_node_done\([^\n]*, "([\w_]+)"\)', block)[1]
            self.assertIn('istype(C, ' + SHOVEL + ') && user.a_intent == I_HARM', block)
            self.assertIn('if (map && !map.is_node_done(', block)
            self.assertLess(block.index('map.is_node_done'), block.index('do_after('))
            for done, allowed in (({'field_defenses'}, True), ({'gunsmithing'}, False),
                                  (set(), False), ({'field_defenses', 'gunsmithing'}, True)):
                self.assertEqual(node in done, allowed)
            self.assertIn("haven't researched Field Defenses yet.", block)

    def test_trenches_use_field_defenses_without_gunsmithing_bypass(self):
        self.assert_trench_research(source(TRENCH))
        nodes = source('code/modules/research_tree/research_node.dm')
        self.assertIn('"' + SHOVEL + '/trench" = "field_defenses"', nodes)

    def test_collection_research_backend_catalog_and_mining_work_remain_unchanged(self):
        floor = source(FLOOR)
        old = baseline(FLOOR)
        start = '\telse if (istype(C, ' + SHOVEL + ') || istype(C, ' + UTENSIL + '/spoon))'
        end = '\telse if (istype(C, ' + PICK + ')'
        self.assertEqual(floor[floor.index(start):floor.index(end)], old[old.index(start):old.index(end)])
        self.assertEqual(procedure(floor, '/datum/pickaxe_mining_action/proc/perform()'),
                         procedure(old, '/datum/pickaxe_mining_action/proc/perform()'))
        research = 'code/modules/research_tree/research_node.dm'
        strip_comments = lambda text: re.sub(r'(?m)^\s*//[^\n]*\n', '', text)
        self.assertEqual(strip_comments(source(research)), strip_comments(baseline(research)))
        backend = 'code/modules/research_tree/research_faction.dm'
        self.assertEqual(source(backend), baseline(backend))

    def test_original_wrong_research_and_utensil_admission_fail_the_same_oracles(self):
        old_click, old_reject = mining_gates(baseline(FLOOR))
        wood_knife = UTENSIL + '/knife/shank/wood'
        self.assertTrue(type_gate(old_click, 'C', wood_knife))
        self.assertFalse(type_gate(old_reject, 'P', wood_knife))
        with self.assertRaises(AssertionError):
            self.assert_trench_research(baseline(TRENCH))
        with self.assertRaises(AssertionError):
            self.assert_mining_matrix(baseline(FLOOR))
        # Also catch a one-sided fix: each admission boundary must reject knives.
        current = source(FLOOR)
        for fixed, mutant in (
                ('else if (istype(C, ' + PICK + '))',
                 'else if (istype(C, ' + PICK + ') || istype(C, ' + UTENSIL + '))'),
                ('if (!istype(P, ' + PICK + ') || P.loc',
                 'if ((!istype(P, ' + PICK + ') && !istype(P, ' + UTENSIL + ')) || P.loc')):
            self.assertIn(fixed, current)
            with self.assertRaises(AssertionError):
                self.assert_mining_matrix(current.replace(fixed, mutant, 1))

    def test_ci_runs_only_offline_admission_tests(self):
        workflow = source('.github/workflows/test.yml')
        step = workflow.split('- name: Test digging tool and research admission offline', 1)[1].split('- name:', 1)[0]
        self.assertIn("contains(fromJSON(needs.changes.outputs.new_tests), 'tests/test_digging_tools.py')", step)
        self.assertIn('python3 -B -m unittest discover -s tests -p test_digging_tools.py -v', step)
        self.assertNotIn('byond', step.lower())


if __name__ == '__main__':
    unittest.main()
