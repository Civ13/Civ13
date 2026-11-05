"""Offline crafting-view policy and physical wait checks, not client rendering."""
import ast
import hashlib
import importlib.util
import json
from pathlib import Path
import re
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
# The reviewed master merged into this branch, including #3370's movement rule.
BASE = '01566713425d9e923b6ed2e18332113d48f6bc67'
HUMAN = 'code/game/mob/living/carbon/human/subtile_movement.dm'
STACK = 'code/game/objects/items/stacks/stack.dm'
WAIT = 'code/_helpers/mobs.dm'
FLOOR = 'code/game/turfs/floor_attackby.dm'
BRIDGE = 'code/modules/gameplay_bridge/bridge.dm'


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
    elif path == BRIDGE:
        # #3233: agent observations share the geometric line-of-sight gate.
        edits = (
            ('\t// Same geometric line-of-sight authority as hover and examine: an entity\n'
             '\t// masked on the actor\'s screen is not reported to the agent either.\n'
             '\tif (!los_read_allowed(actor, A, "observe"))\n\t\treturn FALSE\n', ''),
        )
    elif path == FLOOR:
        # Mining balance is a separately checked production change. Invert only
        # this exact body so the original crafting reference remains frozen.
        mining_start = source.index('/turf/proc/mining_proc(')
        mining_end = source.index('/turf/floor/dirt/underground/attack_hand(', mining_start)
        mining = source[mining_start:mining_end]
        if hashlib.sha256(mining.encode()).hexdigest() != 'b7ca03e37e23238abe88c7ef8abb778c89eacfb721c31f2ca9c249eb1b2fe392':
            raise AssertionError('unreviewed mining yield projection drift')
        previous = read('tests/human_subtile/fixtures/mining_before_multi_drop.dm.txt').rstrip('\n') + '\n' * 2
        source = source[:mining_start] + previous + source[mining_end:]
        # #3451: admission before announcements/effects. #3458: one owned work
        # image around the same wait, with release cleanup and unchanged reward.
        wait = 'do_after(actor, 240 / actor.getStatCoeff("strength") / tool:usespeed, wall, needhand = FALSE, mining_context = src)'
        edits = (
            # #3685: agent-controlled characters count as connected grass cutters.
            ('\t// An agent-controlled character has no client but is driven like a player.\n\treturn user && (user.client || agent_character_for(user))\n',
             '\treturn user && user.client\n'),
            ('\tif (!user || !user.may_do_after)\n\t\treturn\n\tif (has_snow_cover() || busy', '\tif (has_snow_cover() || busy'),
            ('\tvar/datum/progressbar/progressbar\n\tvar/datum/resource_work_animation/work_animation\n', '\tvar/datum/progressbar/progressbar\n'),
            ('/datum/pickaxe_mining_action/proc/release()\n\tif (work_animation)\n\t\twork_animation.stop()\n\t\twork_animation = null\n', '/datum/pickaxe_mining_action/proc/release()\n'),
            ('\t\t\twork_animation = actor.prepare_resource_work_animation(tool, wall, 240 / actor.getStatCoeff("strength") / tool:usespeed)\n'
             + '\t\t\tvar/completed = ' + wait + '\n'
             + '\t\t\tif (work_animation)\n\t\t\t\twork_animation.stop()\n\t\t\t\twork_animation = null\n'
             + '\t\t\tif (completed && valid(actor, wall))', '\t\t\tif (' + wait + ' && valid(actor, wall))'),
            # #888: shared-turf stock and tunnel-entrance rechecks after the wait.
            ('\t\t\t\t\t\tif (!T || T.available_dirt <= 0) // someone else took the last dirt during the wait\n\t\t\t\t\t\t\tH.shoveling = FALSE\n\t\t\t\t\t\t\treturn\n', ''),
            ('\t\t\t\t\t\tif (!T || T.available_sand <= 0) // someone else took the last sand during the wait\n\t\t\t\t\t\t\tH.shoveling = FALSE\n\t\t\t\t\t\t\treturn\n', ''),
            ('\t\t\t\tif (!TB.is_diggable || (locate(/obj/structure/multiz) in user.loc) || (locate(/obj/structure/multiz) in TB))\n\t\t\t\t\treturn // another digger finished this entrance during the wait\n',
             '\t\t\t\tif (!TB.is_diggable)\n\t\t\t\t\treturn\n'),
            ('\t\t\t\tvar/turf/below = locate(user.x, user.y, user.z-1)\n\t\t\t\tif (!TO.is_diggable || (locate(/obj/structure/multiz) in user.loc) || (below && (locate(/obj/structure/multiz) in below)))\n\t\t\t\t\treturn // another digger finished this entrance during the wait\n',
             '\t\t\t\tif (!TO.is_diggable)\n\t\t\t\t\treturn\n'),
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


def block(path, start, end):
    source = read(path)
    return source[source.index(start):source.index(end, source.index(start))]

ATLAS = 'code/game/mob/crafting_atlas.dm'
BROWSER = 'code/datums/browser.dm'
SKIN = 'interface/skin.dmf'
CONTRACTS = json.loads(read('tests/human_subtile/crafting_ui_contracts.json'))


def section(source, start, end=None):
    if source.count(start) != 1:
        raise AssertionError('missing or ambiguous contract start: ' + start)
    tail = source[source.index(start):]
    if end is None:
        next_proc = re.search(r"\n/(?![/*])", tail)
        return (tail[:next_proc.start()] if next_proc else tail).rstrip() + "\n"
    if tail.count(end) != 1:
        raise AssertionError('missing or ambiguous contract end: ' + end)
    return tail[:tail.index(end)]


def once(source, fragment):
    if source.count(fragment) != 1:
        raise AssertionError('missing or ambiguous contract: ' + fragment)


def ordered(source, *fragments):
    positions = []
    for fragment in fragments:
        once(source, fragment)
        positions.append(source.index(fragment))
    if positions != sorted(positions):
        raise AssertionError('contract order changed')


def passive(source):
    # This suite owns movement/focus effects, not recipe content or HTML.
    for forbidden in ('set_using_object', 'unset_using_object', 'forceMove',
                      'step_x =', 'step_y =', 'pixel_x =', 'pixel_y =',
                      'winset(', 'focus='):
        if forbidden in source:
            raise AssertionError('active UI side effect: ' + forbidden)


def required_flow(source):
    """Fingerprint direct cost references and their indentation-based owners.

    This is a source contract for the current procedure, not DM execution.
    Other recipe/output statements do not enter this fingerprint.
    """
    source = re.sub(r'/\*.*?\*/', '', source, flags=re.S)
    parents, references = [], []
    for raw in source.splitlines():
        code = raw.split('//', 1)[0].rstrip()
        if not code.strip():
            continue
        indent = len(code) - len(code.lstrip('\t'))
        code = code.strip()
        while parents and parents[-1][0] >= indent:
            parents.pop()
        identifiers = re.sub(r'"(?:\\.|[^"\\])*"', '""', code)
        if re.search(r'\brequired\b', identifiers):
            references.append({'ancestors': [owner for _, owner in parents],
                               'statement': code})
        parents.append((indent, code))
    return references


def verify_stack_contract(source):
    menu = section(source, '/obj/item/stack/proc/list_recipes', '// Custom qdel')
    ordered(menu, 'if (!recipes)\n\t\treturn',
            'if (!src || amount <= 0)\n\t\tuser << browse(null, "window=stack")',
            'user.set_using_object(src)',
            'user << browse(t1, "window=stack")', 'onclose(user, "stack")')
    # Owning the menu is deliberate; movement/focus changes are not.
    passive(menu.replace('user.set_using_object(src)', ''))
    produce = section(source, '/obj/item/stack/proc/produce_recipe', '/obj/item/stack/Topic')
    once(produce, 'var/required = quantity*recipe.req_amount')
    if required_flow(produce) != CONTRACTS['required_flow']:
        raise AssertionError('required value/reference ownership changed')
    admission = section(produce, '\tif (!can_use(required))\n',
                        '\n\tif (recipe.one_per_turf')
    if admission != CONTRACTS['stack_admission']:
        raise AssertionError('insufficient-material admission/refusal changed')
    once(produce, CONTRACTS['stack_debit_entry'])
    once(produce, CONTRACTS['stack_wait'])
    once(produce, CONTRACTS['stack_refund'])
    debit = 'if (use(required, (joinery || carving) ? null : H))'
    if len(re.findall(r'(?<![.A-Za-z0-9_])(?:src\.)?use\(', '\n'.join(line.split('//', 1)[0] for line in produce.splitlines()))) != 1:
        raise AssertionError('primary debit count changed')
    ordered(produce, 'if (!can_use(required))', CONTRACTS['stack_wait'],
            debit, 'O = new recipe.result_type(user.loc, recipe.use_material)',
            'O = new recipe.result_type(user.loc)', CONTRACTS['stack_refund'])
    topic = section(source, '/obj/item/stack/Topic', '// The normal menu')
    if topic != CONTRACTS['stack_topic']:
        raise AssertionError('crafting admission/ownership/refresh changed')


def verify_focus_contract(sources):
    atlas = section(sources[ATLAS], '/datum/crafting_atlas_reference/proc/show(',
                    '/datum/crafting_atlas_reference/proc/render_html(')
    passive(atlas)
    ordered(atlas, 'if (!viewer || !viewer.client)\n\t\treturn',
            'if (world.time < viewer.client.atlas_last_request + 10)\n\t\treturn',
            'viewer.client.atlas_last_request = world.time', 'if (!load_catalog())',
            'if (crafting_atlas_presenter && crafting_atlas_presenter.open(',
            'viewer << browse(render_html(')
    once(atlas, '"window=crafting_atlas;size=1000x700"')
    browser = sources[BROWSER]
    once(browser, 'var/window_options = "focus=0;can_close=1;')
    for key, start, end in (
        ('browser_open', '/datum/browser/proc/open(', '/datum/browser/proc/close('),
        ('browser_close', '/datum/browser/proc/close(', '// This will allow'),
        ('onclose', '/proc/onclose(', '// the on-close client verb'),
        ('windowclose', '/client/verb/windowclose(', None),
    ):
        if section(browser, start, end) != CONTRACTS[key]:
            raise AssertionError('browser focus/close contract changed: ' + key)
    for contract in ('mainwindow.macro=macro input.focus=true',
                     'mainwindow.macro=hotkeymode mapwindow.map.focus=true'):
        once(sources[SKIN], contract)


def verify_wait_contract(source):
    restored = restore_crafting_projection(WAIT, source)
    wait = section(restored, '/mob/var/may_do_after', '//Returns a list')
    if wait != CONTRACTS['legacy_wait']:
        raise AssertionError('wait signature/timing/claims/cleanup changed')



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
            ('var/iron_chance = map.ordinal_age >= 1 ? 32 : 0', 'var/iron_chance = 32'),
            ('var/geology_allowed = prob(100 * legacy_remaining / no_ore_chance)', 'var/geology_allowed = TRUE'),
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
        self.assertEqual(unlinked, CONTRACTS['legacy_unlinked'])
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
        verify_wait_contract(read(WAIT))

    def test_crafting_charges_refunds_refresh_and_close_paths_unchanged(self):
        verify_stack_contract(read(STACK))

    def test_crafting_contract_rejects_charge_refund_and_close_mutations(self):
        source = read(STACK)
        controls = (
            ('var/required = quantity*recipe.req_amount', 'var/required = recipe.req_amount'),
            ('buildtime = round(buildtime)', 'buildtime = 1'),
            ('buildtime /= H.getStatCoeff("strength")', 'buildtime *= H.getStatCoeff("strength")'),
            ('if (!do_after(user, buildtime))', 'if (do_after(user, buildtime))'),
            ('H.put_in_hands(O)', 'H.drop_from_inventory(O)'),
            ('handReturnMap.Remove(H.key)', 'handReturnMap.Remove(user)'),
            ('if (required > 0)', 'if (required > 1)'),
            ('new type(get_turf(H), required)', 'new type(get_turf(H), 1)'),
            ('user.set_using_object(src)', 'user.set_using_object(null)'),
            ('onclose(user, "stack")', 'onclose(user, "wrong")'),
            ('if (H.can_build_recipe)', 'if (!H.can_build_recipe)'),
            ('if (src && usr.using_object == src) //do not reopen closed window', 'if (src) //do not reopen closed window'),
            ('H.can_build_recipe = FALSE', 'H.can_build_recipe = TRUE'),
        )
        for before, after in controls:
            self.assertEqual(source.count(before), 1, before)
            with self.subTest(control=before), self.assertRaises(AssertionError):
                verify_stack_contract(source.replace(before, after, 1))
        debit = 'if (use(required, (joinery || carving) ? null : H))'
        early = source.replace(debit, 'if (TRUE)', 1).replace(
            '\tif (recipe.time)\n', '\t' + debit + '\n\t\treturn\n\tif (recipe.time)\n', 1)
        with self.subTest(control='debit moved before wait'), self.assertRaises(AssertionError):
            verify_stack_contract(early)
        with self.subTest(control='double primary debit'), self.assertRaises(AssertionError):
            verify_stack_contract(source.replace(debit, 'use(required, H)\n\t' + debit, 1))


    def test_crafting_cost_envelope_rejects_required_reset_and_missing_refusal_return(self):
        source = read(STACK)
        debit = '\tif (use(required, (joinery || carving) ? null : H))'
        admission = section(source, '\tif (!can_use(required))\n',
                            '\n\tif (recipe.one_per_turf')
        self.assertEqual(admission.count('\n\t\treturn'), 1)
        mutants = (
            ('zero required before debit', source.replace(debit, '\trequired = 0\n' + debit, 1)),
            ('remove insufficient-material return',
             source.replace(admission, admission.replace('\n\t\treturn', '', 1), 1)),
            ('compound required reset', source.replace(debit, '\trequired *= 0\n' + debit, 1)),
            ('decrement required', source.replace(debit, '\trequired--\n' + debit, 1)),
            ('reset refund amount', source.replace(
                '\t\t\tvar/obj/structure/research_bench/RBN = O',
                '\t\t\tvar/obj/structure/research_bench/RBN = O\n\t\t\trequired = 0', 1)),
            ('broaden variable-cost owner', source.replace(
                '\tvar/inpt = 50\n\tif (recipe.result_type == /obj/structure/cannon/modern/tank)',
                '\tvar/inpt = 50\n\tif (TRUE)', 1)),
            ('qualified primary debit before wait', source.replace(
                '\tif (recipe.time)\n', '\tsrc.use(1, H)\n\tif (recipe.time)\n', 1)),
        )
        for name, mutated in mutants:
            with self.subTest(control=name), self.assertRaises(AssertionError):
                verify_stack_contract(mutated)

    def test_wait_contract_rejects_signature_claim_timing_and_cleanup_mutations(self):
        source = read(WAIT)
        for before, after in (
            ('needhand = TRUE, progress = TRUE', 'needhand = FALSE, progress = TRUE'),
            ('check_for_repeats = TRUE', 'check_for_repeats = FALSE'),
            ('!gameplay_lease.claim_gather_wait(user, target)', 'FALSE'),
            ('user.may_do_after = FALSE', 'user.may_do_after = TRUE'),
            ('endtime = world.time + delay', 'endtime = world.time + 1'),
            ('user.may_do_after = TRUE', 'user.may_do_after = FALSE'),
            ('qdel(progbar)', 'progbar = null'),
        ):
            # qdel(progbar) also belongs to do_mob; mutate the selected wait only.
            start = source.index('/mob/var/may_do_after')
            prefix, wait = source[:start], source[start:]
            expected = 2 if before.startswith(('needhand =', 'check_for_repeats =')) else 1
            self.assertEqual(wait.count(before), expected, before)
            with self.subTest(control=before), self.assertRaises(AssertionError):
                verify_wait_contract(prefix + wait.replace(before, after))

    def test_player_authority_optout_cadence_save_and_prone_unchanged(self):
        # Focus on the contracts this suite owns, not whole-file historical
        # parity: independently tested precision movement extends this module.
        source = read(HUMAN)
        for contract in (
            'owner && client == owner && owner.mob == src && owner.canmove && owner.moving',
            'if (!enabled && (step_x || step_y))',
            'human_subtile_transaction || human_subtile_pulse || subtile_pull_ownership.owners[src]',
            'return human_subtile_pull_travel(n, direct, deadline)',
            'T.initial_prone = prone',
            'T.initial_lying = lying',
            'T.wait_paid_interval()',
        ):
            self.assertIn(contract, source)
        # Saves are tile-only and never stop a walking body: no offset capsule
        # is exported, and movement offsets are always runtime-only.
        save = source.split('/mob/living/human/before_save()', 1)[1].split('/mob/living/human/proc/human_subtile_destination_clear', 1)[0]
        self.assertNotIn('human_subtile_position = human_subtile_snapshot()', save)
        self.assertNotIn('human_subtile_transaction.cancelled = TRUE', save)
        self.assertIn('human_subtile_position = null', save)
        runtime = source.split('/mob/living/human/persistence_runtime_var(key)', 1)[1].split('/mob/living/human/proc/human_subtile_prepare_import', 1)[0]
        self.assertIn('\tif (key == "step_x" || key == "step_y") return TRUE\n', runtime)
        self.assertNotIn('#ifdef', runtime)


    def test_atlas_and_focus_paths_are_not_rewritten(self):
        verify_focus_contract({path: read(path) for path in (ATLAS, BROWSER, SKIN)})

    def test_focus_contract_rejects_active_ui_and_broken_close_mutations(self):
        sources = {path: read(path) for path in (ATLAS, BROWSER, SKIN)}
        controls = (
            (ATLAS, '\tviewer.client.atlas_last_request = world.time',
             '\tviewer.set_using_object(src)\n\tviewer.client.atlas_last_request = world.time'),
            (ATLAS, '\tviewer.client.atlas_last_request = world.time',
             '\twinset(viewer, null, "focus=1")\n\tviewer.client.atlas_last_request = world.time'),
            (BROWSER, 'var/window_options = "focus=0;', 'var/window_options = "focus=1;'),
            (BROWSER, 'open(var/use_onclose = TRUE)', 'open(var/use_onclose = FALSE)'),
            (BROWSER, 'onclose(user, window_id, ref)', 'onclose(user, window_id, null)'),
            (BROWSER, 'browse(null, "window=[window_id]")', 'browse(null, "window=wrong")'),
            (BROWSER, 'Topic("close=1", list("close"="1"), hsrc)', 'Topic("close=0", list("close"="0"), hsrc)'),
            (BROWSER, 'mob.unset_using_object()', 'mob.set_using_object(src)'),
            (SKIN, 'mainwindow.macro=macro input.focus=true', 'mainwindow.macro=macro input.focus=false'),
            (SKIN, 'mainwindow.macro=hotkeymode mapwindow.map.focus=true', 'mainwindow.macro=hotkeymode mapwindow.map.focus=false'),
        )
        for path, before, after in controls:
            self.assertEqual(sources[path].count(before), 1, before)
            changed = dict(sources, **{path: sources[path].replace(before, after, 1)})
            with self.subTest(path=path, control=before), self.assertRaises(AssertionError):
                verify_focus_contract(changed)

    def test_scoped_contracts_allow_unrelated_procedure_and_recipe_content_changes(self):
        stack = read(STACK)
        self.assertEqual(stack.count('Amount Left:'), 1)
        catalog = 'else if (recipe.result_type == /obj/item/stack/money/silvercoin)\n\t\tproduced = 10'
        self.assertEqual(stack.count(catalog), 1)
        stack = stack.replace(catalog, catalog.replace('produced = 10', 'produced = 12'))
        verify_stack_contract(stack.replace('Amount Left:', 'Stock Remaining:') + '\n/obj/item/stack/proc/unrelated_ui_probe()\n\treturn\n')
        verify_wait_contract(read(WAIT) + '\n/proc/unrelated_wait_probe()\n\treturn\n')
        sources = {path: read(path) for path in (ATLAS, BROWSER, SKIN)}
        self.assertIn('Full web atlas', sources[ATLAS])
        sources[ATLAS] = sources[ATLAS].replace('Full web atlas', 'Complete web reference')
        sources[ATLAS] += '\n/proc/unrelated_atlas_probe()\n\treturn\n'
        sources[BROWSER] += '\n/proc/unrelated_browser_probe()\n\treturn\n'
        verify_focus_contract(sources)



if __name__ == '__main__':
    unittest.main(verbosity=2)
