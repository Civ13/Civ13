"""Dismantling, smashing or breaking a built object never gives back more
than its recipe cost, on any map's recipe list.

Player report (2026-11-17): a small mill cost 4 planks but a hammer took it
apart into 3 logs, which saw into 12 planks. scan.py projects every refund
path in the DM source against every RECIPE row; see its docstring.
"""
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import scan  # noqa: E402

# (built type, recipe list, refund proc owner, proc): why the refund is fine.
REVIEWED = {
    ('/obj/structure/simple_door/key_door/anyone/roman', 'crustacean',
     '/obj/structure/simple_door/key_door', 'update_damage'):
        'the marble route (2.5 marble) breaks into 2 cheaper stone',
}
# Procs that turn an item into salvage rather than refund a build.
SALVAGE = {
    ('/obj/item/clothing', 'check_health'): 'worn-out clothing falls apart into rags',
    ('/obj/item/clothing', 'secondary_attack_self'): 'ripping clothing into rags',
}


class DismantleRefundTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.report = scan.scan()

    def test_no_refund_exceeds_cost(self):
        problems = sorted({
            f'{path} ({stem}: {title}) via {owner}/{name} in {file}: {problem}'
            for path, owner, name, file, stem, title, problem in self.report
            if (path, stem, owner, name) not in REVIEWED and (owner, name) not in SALVAGE
        })
        self.assertEqual(problems, [], 'Refunds worth more than the build cost:\n' + '\n'.join(problems))

    def test_reviewed_exceptions_still_apply(self):
        seen = {(path, stem, owner, name) for path, owner, name, _, stem, _, _ in self.report}
        seen_procs = {(owner, name) for _, owner, name, _, _, _, _ in self.report}
        self.assertEqual(sorted(set(REVIEWED) - seen), [], 'Remove stale REVIEWED entries')
        self.assertEqual(sorted(set(SALVAGE) - seen_procs), [], 'Remove stale SALVAGE entries')


class ScannerTest(unittest.TestCase):
    """The scanner catches the reported dupe and its relatives."""

    def body(self, text):
        return [(len(l) - len(l.lstrip('\t')), l.strip()) for l in text.splitlines() if l.strip()]

    def refund(self, text, path='/obj/structure/thing', type_vars=None, rule=None):
        ctx = scan.Context(path, type_vars or {}, rule)
        return scan.proc_refund(self.body(text), ctx)[0]

    def test_small_mill_report(self):
        drops = self.refund('''
	if (is_tool(W, TOOL_HAMMER))
		hammer_action(H, W, 90, list("/obj/item/stack/material/wood"), list(3))
		return
''')
        self.assertEqual(drops, {'wood': 3})
        self.assertEqual(scan.compare({'woodplank': 4}, drops), ['wood worth 12 planks back for 4 spent'])
        self.assertEqual(scan.compare({'woodplank': 4}, {'woodplank': 3}), [])
        self.assertEqual(scan.compare({'wood': 4}, {'wood': 3}), [])

    def test_production_without_deletion_is_not_a_refund(self):
        self.assertEqual(self.refund('''
	if (istype(W, /obj/item/stack/material/wood))
		new /obj/item/stack/material/woodplank(loc, 4)
'''), {})

    def test_exclusive_branches_and_loops(self):
        drops = self.refund('''
	if (istype(O, /obj/item/weapon/hammer/modern))
		if (do_after(user, 20, src))
			for (var/i=1, i<=6, i++)
				new /obj/item/stack/material/wood(loc)
			qdel(src)
	else if (istype(O, /obj/item/weapon/hammer))
		if (do_after(user, 30, src))
			for (var/i=1, i<=3, i++)
				new /obj/item/stack/material/wood(loc)
			qdel(src)
''')
        self.assertEqual(drops, {'wood': 6})

    def test_type_conditions_and_vars(self):
        text = '''
	if (istype(src, /obj/structure/thing/plank))
		new /obj/item/stack/material/woodplank(loc)
		new /obj/item/stack/material/woodplank(loc)
		qdel(src)
	else if (material == "Wood")
		new buildstack(loc, 2)
		qdel(src)
'''
        tv = {'/obj/structure/thing': {'material': '"Wood"', 'buildstack': '/obj/item/stack/material/wood'}}
        self.assertEqual(self.refund(text, '/obj/structure/thing/plank', tv), {'woodplank': 2})
        self.assertEqual(self.refund(text, '/obj/structure/thing', tv), {'wood': 2})

    def test_returning_branch_does_not_continue(self):
        drops = self.refund('''
	if (destroy_type == 1)
		new /obj/item/stack/material/wood(loc)
		qdel(src)
		return
	new /obj/item/stack/material/wood(loc)
	new /obj/item/stack/material/wood(loc)
	qdel(src)
''')
        self.assertEqual(drops, {'wood': 2})

    def test_crafted_refund_rule(self):
        rule = scan.crafted_refund_rule({
            '/a': [('global', 'a', {'woodplank': 4.0}), ('carib', 'a', {'wood': 4.0})],
            '/b': [('global', 'b', {'wood': 2.0})],
            '/c': [('global', 'c', {'stone': 3.0})],
            '/d': [('global', 'd', {'stone': 3.0}), ('carib', 'd', {'iron': 3.0})],
            '/e': [('global', 'e', {'woodplank': 0.5})],
        })
        self.assertEqual(rule('/a', 'x'), scan.STACK + 'woodplank')
        self.assertEqual(rule('/b', 'x'), scan.STACK + 'wood')
        self.assertEqual(rule('/c', 'x'), scan.STACK + 'stone')
        self.assertIsNone(rule('/d', 'x'))
        self.assertIsNone(rule('/e', 'x'))
        self.assertEqual(rule('/none', 'x'), 'x')

    def test_generic_dismantle_uses_the_recipe(self):
        source = (scan.ROOT / 'code/game/objects/structures.dm').read_text(encoding='utf-8')
        generic = source.split('/obj/structure/attackby(', 1)[1].split('\n/', 1)[0]
        self.assertIn('crafted_refund_stack(type, /obj/item/stack/material/wood)', generic)
        self.assertNotIn('new /obj/item/stack/material/wood(', generic)


class LoadedPlatingBathTest(unittest.TestCase):
    """Source contracts for #7030: refuse paid inputs before teardown."""

    @classmethod
    def setUpClass(cls):
        structure = (scan.ROOT / 'code/game/objects/structures.dm').read_text(encoding='utf-8')
        plating = (scan.ROOT / 'code/modules/1713/electroplating.dm').read_text(encoding='utf-8')
        cls.attack = structure.split('/obj/structure/attackby(', 1)[1].split('\n/', 1)[0]
        cls.base_guard = structure.split('/obj/structure/proc/can_dismantle_with_hammer(', 1)[1].split('\n/', 1)[0]
        cls.bath_guard = plating.split('/obj/structure/plating_bath/can_dismantle_with_hammer(', 1)[1].split('\n/', 1)[0]
        cls.bath_attack = plating.split('/obj/structure/plating_bath/attackby(', 1)[1].split('\n/', 1)[0]

    def test_hammer_dispatch_still_uses_shared_teardown(self):
        self.assertIn(
            'if (is_tool(W, TOOL_WRENCH) || is_tool(W, TOOL_HAMMER))\n\t\treturn ..()',
            self.bath_attack,
        )
        self.assertEqual(self.base_guard.splitlines()[1], '\treturn TRUE')

    def test_refuses_loaded_attempt_before_starting_the_wait(self):
        self.assertIn(
            'else if (istype(O, /obj/item/weapon/hammer) && !not_disassemblable)\n'
            '\t\tif (!can_dismantle_with_hammer(user))\n\t\t\treturn\n\t\tplaysound',
            self.attack,
        )

    def test_rechecks_new_inputs_after_wait_before_any_refund_or_delete(self):
        wait = self.attack.index('if (do_ship_fixture_after(user, 25, src) && !QDELETED(src))')
        after_wait = self.attack[wait:]
        self.assertTrue(after_wait.startswith(
            'if (do_ship_fixture_after(user, 25, src) && !QDELETED(src))\n'
            '\t\t\tif (!can_dismantle_with_hammer(user))\n\t\t\t\treturn\n'
        ))
        self.assertLess(after_wait.index('can_dismantle_with_hammer'), after_wait.index('crafted_refund_stack'))
        self.assertLess(after_wait.index('crafted_refund_stack'), after_wait.index('qdel(src)'))

    def test_either_paid_input_refuses_but_empty_bath_uses_default(self):
        self.assertIn('\n\tif (anode || workpiece())\n', self.bath_guard)
        self.assertIn('\n\t\treturn FALSE\n\treturn ..()\n', self.bath_guard)


if __name__ == '__main__':
    unittest.main()
