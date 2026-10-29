"""Offline crafting-view policy and physical wait checks, not client rendering."""
import ast
import hashlib
import importlib.util
from pathlib import Path
import re
import subprocess
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
# The reviewed master merged into this branch, including #3370's movement rule.
BASE = '01566713425d9e923b6ed2e18332113d48f6bc67'
HUMAN = 'code/game/mob/living/carbon/human/subtile_movement.dm'
STACK = 'code/game/objects/items/stacks/stack.dm'
WAIT = 'code/_helpers/mobs.dm'


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


def baseline(path):
    return subprocess.check_output(['git', 'show', BASE + ':' + path], cwd=ROOT).decode().replace('\r\n', '\n')


def block(path, start, end):
    source = read(path)
    return source[source.index(start):source.index(end, source.index(start))]


def expression(source):
    """Translate only the tiny boolean contract; no DM runtime emulation claim."""
    source = source.replace('&&', ' and ').replace('||', ' or ')
    source = re.sub(r'!(?!=)', ' not ', source).strip()
    tree = ast.parse(source, mode='eval')
    allowed = (ast.Expression, ast.BoolOp, ast.And, ast.Or, ast.UnaryOp, ast.Not,
               ast.Compare, ast.Eq, ast.NotEq, ast.Gt, ast.Name, ast.Load,
               ast.Attribute, ast.Call, ast.Constant)
    if any(not isinstance(node, allowed) for node in ast.walk(tree)):
        raise ValueError('Unsupported policy syntax')
    return compile(tree, '<source-derived boolean contract>', 'eval')


class CraftingMovementContracts(unittest.TestCase):
    def test_all_four_gather_projections_are_verified_against_reviewed_master(self):
        spec = importlib.util.spec_from_file_location('crafting_gather_projection', ROOT / 'scripts/gameplay_bridge/gather_context.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        for path in module.PATHS:
            for enabled in (False, True):
                symbols = {module.FEATURE} if enabled else set()
                old = module.project(baseline(path), symbols)[0]
                current = module.project(read(path), symbols)[0]
                restored = current
                if path == WAIT:
                    restored = restored.replace('\n\tvar/original_step_x = user.step_x\n\tvar/original_step_y = user.step_y', '')
                    restored = restored.replace('\t\t\t// A stationary action also stops on physical movement within its tile.\n\t\t\t// Explicit can_move actions retain their existing contract.\n', '')
                    restored = restored.replace('user.loc != original_loc || user.step_x != original_step_x || user.step_y != original_step_y', 'user.loc != original_loc')
                self.assertEqual(restored, old, path)
                if not enabled:
                    self.assertEqual(hashlib.sha256(current.encode()).hexdigest(), module.DISABLED_SHA256[path])

    def test_held_stack_policy_accepts_only_current_owned_valid_recipe_view(self):
        source = block(STACK, '/obj/item/stack/allows_smooth_movement_ui', '/obj/item/stack/proc/list_recipes')
        code = expression(next(line.strip()[7:] for line in source.splitlines() if line.strip().startswith('return ')))
        user = SimpleNamespace(deleted=False)
        stack = SimpleNamespace(deleted=False, loc=user)
        user.using_object = stack
        hand = [stack]
        user.get_active_hand = lambda: hand[0]
        values = dict(user=user, src=stack, recipes=True, amount=5, loc=user,
                      QDELETED=lambda value: value.deleted)
        self.assertTrue(eval(code, {'__builtins__': {}}, values))
        for changed in ('missing_user', 'deleted_user', 'deleted_stack', 'no_recipes',
                        'depleted', 'ground', 'transferred', 'inactive', 'other_window'):
            with self.subTest(changed=changed):
                user.deleted = stack.deleted = False
                user.using_object = hand[0] = stack
                current = dict(values)
                if changed == 'missing_user': current['user'] = None
                if changed == 'deleted_user': user.deleted = True
                if changed == 'deleted_stack': stack.deleted = True
                if changed == 'no_recipes': current['recipes'] = None
                if changed == 'depleted': current['amount'] = 0
                if changed in ('ground', 'transferred'): current['loc'] = object()
                if changed == 'inactive': hand[0] = object()
                if changed == 'other_window': user.using_object = object()
                self.assertFalse(eval(code, {'__builtins__': {}}, current))

    def test_admission_keeps_master_pulling_and_open_menu_rule(self):
        # #3370 is the accepted rule: pulling and every using_object except a
        # mounted gun keep smooth movement. The recipe-view contract never gates.
        unlinked = block(HUMAN, '/mob/living/human/proc/human_subtile_unlinked()', '\n\n')
        self.assertEqual(unlinked, '/mob/living/human/proc/human_subtile_unlinked()\n\treturn ' +
                         block(HUMAN, '!buckled && !riding', '\n'))
        self.assertEqual(unlinked, baseline(HUMAN)[baseline(HUMAN).index('/mob/living/human/proc/human_subtile_unlinked()'):][:len(unlinked)])
        self.assertNotRegex(unlinked, r'!pulling\b')
        self.assertIn('!istype(using_object, /obj/item/weapon/gun/projectile/automatic/stationary)', unlinked)
        for gate in ('!using_object &&', 'allows_smooth_movement_ui', 'human_subtile_object_use_supported'):
            self.assertNotIn(gate, unlinked)
        human = read(HUMAN)
        self.assertNotIn('human_subtile_object_use_supported', human)
        for guard in ('!pulledby', '!buckled', '!riding', '!using_drone', '!control_object', '!using_cannon'):
            self.assertIn(guard, unlinked)
        self.assertIn('/atom/movable/proc/allows_smooth_movement_ui(mob/living/human/user)\n\treturn FALSE', human)

    def test_generated_old_allowlist_is_caught_restricting_pulling_and_menus(self):
        unlinked = block(HUMAN, '/mob/living/human/proc/human_subtile_unlinked()', '\n\n')
        rule = block(HUMAN, '!buckled && !riding', '\n')
        names = ('buckled', 'riding', 'riding_mob', 'using_drone', 'control_object', 'incorporeal_move',
                 'pulling', 'pulledby', 'grab_list', 'grabbed_by', 'using_cannon', 'football')

        def admitted(expression, pulling, menu):
            text = expression.replace('(!grab_list || !grab_list.len)', 'True').replace('(!grabbed_by || !grabbed_by.len)', 'True')
            text = text.replace('!istype(using_object, /obj/item/weapon/gun/projectile/automatic/stationary)', 'not mounted')
            text = text.replace('human_subtile_object_use_supported()', 'not menu').replace('!using_object', 'not menu')
            values = {name: False for name in names}
            values.update(pulling=pulling, menu=menu, mounted=False)
            code = compile(text.replace('&&', ' and ').replace('!', ' not ').strip(), '<rule>', 'eval')
            return bool(eval(code, {'__builtins__': {}}, values))

        for pulling, menu in ((True, False), (False, True), (True, True)):
            self.assertTrue(admitted(rule, pulling, menu), (pulling, menu))
        old = ('!buckled && !riding && !riding_mob && !using_drone && !control_object && !incorporeal_move && !pulling && !pulledby && '
               '(!grab_list || !grab_list.len) && (!grabbed_by || !grabbed_by.len) && human_subtile_object_use_supported() && !using_cannon && !football')
        self.assertFalse(admitted(old, True, False), 'control should refuse a pulling human')
        self.assertFalse(admitted(old, False, True), 'control should refuse an unlisted open menu')
        self.assertNotEqual(old, rule)
        self.assertIn(rule, unlinked)

    def test_prepared_fixture_matches_generic_object_eligibility(self):
        fixture = read('tests/human_subtile/crafting_ui.dm')
        expected = ('crafting_ui_movement_assert(H.human_subtile_eligible(EAST) && '
                    '!generic.allows_smooth_movement_ui(H), "crafting_nonstack_view_keeps_eligibility")')
        self.assertIn(expected, fixture)
        old = expected.replace('H.human_subtile_eligible(EAST)', '!H.human_subtile_eligible(EAST)', 1)
        self.assertNotIn(old, fixture, 'control must catch the old restrictive fixture assertion')
        self.assertEqual(fixture.count('crafting_nonstack_view_keeps_eligibility'), 1)

    def test_stale_recipe_view_closes_before_admission_without_snap_or_focus(self):
        source = block(HUMAN, '/mob/living/human/proc/human_subtile_prepare_ui_movement()', '/mob/living/human/proc/human_subtile_input_supported')
        self.assertIn('!istype(using_object, /obj/item/stack) || using_object.allows_smooth_movement_ui(src)', source)
        self.assertIn('human_subtile_enabled || human_subtile_default_pending || human_subtile_offset_owned', source)
        self.assertIn('unset_using_object()', source)
        self.assertIn('browse(null, "window=stack")', source)
        for forbidden in ('step_x =', 'step_y =', 'forceMove', 'winset', 'focus='):
            self.assertNotIn(forbidden, source)
        move = read('code/game/mob/mob_movement.dm')
        self.assertLess(move.index('subtile_input_actor.human_subtile_prepare_ui_movement()'),
                        move.index('subtile_input_actor.human_subtile_input_supported(direct)'))

    def test_source_derived_stationary_wait_cancels_both_offset_axes(self):
        source = read(WAIT)
        line = next(line.strip() for line in source.splitlines() if 'if (user.loc != original_loc ||' in line)
        code = expression(line[4:-1])
        anchor = object()
        original = dict(original_loc=anchor, original_step_x=6, original_step_y=8)
        for loc, sx, sy, cancels in ((anchor, 6, 8, False), (anchor, 8, 8, True),
                                     (anchor, 6, 10, True), (object(), 6, 8, True),
                                     (anchor, 0, 8, True)):
            values = dict(original, user=SimpleNamespace(loc=loc, step_x=sx, step_y=sy))
            self.assertEqual(bool(eval(code, {'__builtins__': {}}, values)), cancels)
        self.assertRegex(source, r'if \(!can_move\)\n\t\t\t//[^\n]*\n\t\t\t//[^\n]*\n\t\t\tif \(user.loc')

    def test_wait_signature_timing_context_claims_and_cleanup_unchanged(self):
        source = read(WAIT)
        source = source.replace('\n\tvar/original_step_x = user.step_x\n\tvar/original_step_y = user.step_y', '')
        source = source.replace('\t\t\t// A stationary action also stops on physical movement within its tile.\n\t\t\t// Explicit can_move actions retain their existing contract.\n', '')
        source = source.replace('user.loc != original_loc || user.step_x != original_step_x || user.step_y != original_step_y', 'user.loc != original_loc')
        self.assertEqual(source, baseline(WAIT))

    def test_crafting_charges_refunds_refresh_and_close_paths_unchanged(self):
        source = read(STACK)
        added = block(STACK, '/obj/item/stack/allows_smooth_movement_ui', '/obj/item/stack/proc/list_recipes')
        self.assertEqual(source.replace(added, ''), baseline(STACK))
        self.assertIn('user.set_using_object(src)', source)
        self.assertIn('onclose(user, "stack")', source)
        self.assertIn('if (src && usr.using_object == src) //do not reopen closed window', source)
        self.assertIn('if (!do_after(user, buildtime))', source)

    def test_player_authority_optout_cadence_save_and_prone_unchanged(self):
        source = read(HUMAN)
        added = block(HUMAN, '// Identifies a still-valid passive recipe view.', '/mob/living/human/proc/human_subtile_input_supported')
        self.assertEqual(source.replace(added, ''), baseline(HUMAN))
        self.assertEqual(read('code/_onclick/click.dm'), baseline('code/_onclick/click.dm'))
        self.assertEqual(read('code/pathfinding.dm'), baseline('code/pathfinding.dm'))

    def test_atlas_and_focus_paths_are_not_rewritten(self):
        for path in ('code/game/mob/crafting_atlas.dm', 'interface/skin.dmf', 'code/datums/browser.dm'):
            self.assertEqual(read(path), baseline(path))
        atlas = block('code/game/mob/crafting_atlas.dm', '/datum/crafting_atlas_reference/proc/show(', '/datum/crafting_atlas_reference/proc/render_html(')
        self.assertNotIn('set_using_object', atlas)


if __name__ == '__main__':
    unittest.main(verbosity=2)
