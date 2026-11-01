"""Offline crafting-view policy and physical wait checks, not client rendering."""
import ast
import hashlib
import importlib.util
import json
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
FLOOR = 'code/game/turfs/floor_attackby.dm'


def replace_reviewed_once(source, current, previous):
    """Inverse only an exact reviewed addition, refusing omission or drift."""
    if source.count(current) != 1:
        raise AssertionError('reviewed projection edit missing or ambiguous: ' + current)
    return source.replace(current, previous, 1)


def restore_crafting_projection(path, source):
    # The original crafting reference stays fixed. Later independently reviewed
    # changes are recognized exactly, not erased by broad pattern substitution.
    if path == WAIT:
        edits = (
            ('\n\tvar/original_step_x = user.step_x\n\tvar/original_step_y = user.step_y', ''),
            ('\t\t\t// A stationary action also stops on physical movement within its tile.\n\t\t\t// Explicit can_move actions retain their existing contract.\n', ''),
            ('user.loc != original_loc || user.step_x != original_step_x || user.step_y != original_step_y', 'user.loc != original_loc'),
        )
    elif path == FLOOR:
        # #3451: admission before announcements/effects. #3458: one owned work
        # image around the same wait, with release cleanup and unchanged reward.
        wait = 'do_after(actor, 240 / actor.getStatCoeff("strength") / tool:usespeed, wall, needhand = FALSE, mining_context = src)'
        edits = (
            ('\tif (!user || !user.may_do_after)\n\t\treturn\n\tif (has_snow_cover() || busy', '\tif (has_snow_cover() || busy'),
            ('\tvar/datum/progressbar/progressbar\n\tvar/datum/resource_work_animation/work_animation\n', '\tvar/datum/progressbar/progressbar\n'),
            ('/datum/pickaxe_mining_action/proc/release()\n\tif (work_animation)\n\t\twork_animation.stop()\n\t\twork_animation = null\n', '/datum/pickaxe_mining_action/proc/release()\n'),
            ('\t\t\twork_animation = actor.prepare_resource_work_animation(tool, wall, 240 / actor.getStatCoeff("strength") / tool:usespeed)\n'
             + '\t\t\tvar/completed = ' + wait + '\n'
             + '\t\t\tif (work_animation)\n\t\t\t\twork_animation.stop()\n\t\t\t\twork_animation = null\n'
             + '\t\t\tif (completed && valid(actor, wall))', '\t\t\tif (' + wait + ' && valid(actor, wall))'),
        )
    else:
        edits = ()
    for current, previous in edits:
        source = replace_reviewed_once(source, current, previous)
    return source


def verify_crafting_projection(module, references, path, raw_source, enabled):
    symbols = {module.FEATURE} if enabled else set()
    projected = module.project(raw_source, symbols)[0]
    restored = restore_crafting_projection(path, projected)
    mode = 'enabled_sha256' if enabled else 'disabled_sha256'
    if hashlib.sha256(restored.encode()).hexdigest() != references[path][mode]:
        raise AssertionError('unreviewed crafting projection drift: ' + path + ' ' + mode)
    if not enabled and hashlib.sha256(projected.encode()).hexdigest() != module.DISABLED_SHA256[path]:
        raise AssertionError('current disabled whole-file projection drift: ' + path)


def gather_projection_inputs():
    spec = importlib.util.spec_from_file_location('crafting_gather_projection', ROOT / 'scripts/gameplay_bridge/gather_context.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    frozen = json.loads(read('tests/human_subtile/crafting_gather_baseline.json'))
    if frozen['base_sha'] != BASE or set(frozen['source_files']) != set(module.PATHS):
        raise AssertionError('original crafting reference identity changed')
    return module, frozen['source_files']


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
        module, references = gather_projection_inputs()
        for path in module.PATHS:
            for enabled in (False, True):
                with self.subTest(path=path, enabled=enabled):
                    verify_crafting_projection(module, references, path, read(path), enabled)

    def test_projection_inverse_requires_admission_and_owned_animation(self):
        module, references = gather_projection_inputs()
        source = read(FLOOR)
        controls = (
            ('\tif (!user || !user.may_do_after)\n\t\treturn\n', ''),
            ('!user.may_do_after', 'user.may_do_after'),
            ('\tvar/datum/resource_work_animation/work_animation\n', ''),
            ('\tif (work_animation)\n\t\twork_animation.stop()\n\t\twork_animation = null\n', '\tif (work_animation)\n\t\twork_animation = null\n'),
            ('prepare_resource_work_animation(tool, wall,', 'prepare_resource_work_animation(null, wall,'),
            ('var/completed = do_after(actor, 240 /', 'var/completed = do_after(actor, 120 /'),
            ('wall.mining_proc(actor)', 'wall.mining_proc(null)'),
        )
        for before, after in controls:
            self.assertEqual(source.count(before), 1, before)
            mutated = source.replace(before, after, 1)
            for enabled in (False, True):
                with self.subTest(control=before, enabled=enabled), self.assertRaises(AssertionError):
                    verify_crafting_projection(module, references, FLOOR, mutated, enabled)

    def test_projection_controls_reject_wait_and_enabled_context_regressions(self):
        module, references = gather_projection_inputs()
        controls = (
            (WAIT, 'original_step_y = user.step_y', 'original_step_y = 0'),
            (WAIT, '!gameplay_lease.claim_gather_wait(user, target)', 'FALSE'),
            (FLOOR, 'grass_cutting_wait(user, gameplay_context)', 'grass_cutting_wait(user)'),
            (FLOOR, '!istype(gameplay_context, /datum/gameplay_action_lease)', 'FALSE'),
            ('code/modules/gameplay_bridge/bridge.dm', 'survival_action(kind, target, A["recipe"], worker_context)', 'survival_action(kind, target, A["recipe"])'),
            ('code/modules/gameplay_bridge/mechanics.dm', 'wait_claimed || !matches_gather_wait(user, wait_target)', 'FALSE'),
        )
        for path, before, after in controls:
            source = read(path)
            self.assertEqual(source.count(before), 1, before)
            with self.subTest(path=path, control=before), self.assertRaises(AssertionError):
                verify_crafting_projection(module, references, path, source.replace(before, after, 1), True)

    def test_all_projection_modes_reject_unreviewed_file_changes(self):
        module, references = gather_projection_inputs()
        for path in module.PATHS:
            for enabled in (False, True):
                with self.subTest(path=path, enabled=enabled), self.assertRaises(AssertionError):
                    verify_crafting_projection(module, references, path, read(path) + '// unexpected drift\n', enabled)

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
        # Focus on the contracts this suite owns, not whole-file historical
        # parity: independently tested precision movement extends this module.
        source = read(HUMAN)
        for contract in (
            'owner && client == owner && owner.mob == src && owner.canmove && owner.moving',
            'if (!enabled && (step_x || step_y))',
            'human_subtile_transaction || human_subtile_pulse || subtile_pull_ownership.owners[src]',
            'return human_subtile_pull_travel(n, direct, deadline)',
            'human_subtile_position = human_subtile_snapshot()',
            'T.initial_prone = prone',
            'T.initial_lying = lying',
            'T.wait_paid_interval()',
        ):
            self.assertIn(contract, source)

    def test_atlas_and_focus_paths_are_not_rewritten(self):
        for path in ('code/game/mob/crafting_atlas.dm', 'code/datums/browser.dm'):
            self.assertEqual(read(path), baseline(path))
        skin = read('interface/skin.dmf')
        self.assertIn('mainwindow.macro=macro input.focus=true', skin)
        self.assertIn('mainwindow.macro=hotkeymode mapwindow.map.focus=true', skin)
        atlas = block('code/game/mob/crafting_atlas.dm', '/datum/crafting_atlas_reference/proc/show(', '/datum/crafting_atlas_reference/proc/render_html(')
        self.assertNotIn('set_using_object', atlas)


if __name__ == '__main__':
    unittest.main(verbosity=2)
