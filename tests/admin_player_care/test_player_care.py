"""Offline source contracts, not native/client gameplay acceptance."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
COMMANDS = ('cmd_admin_clean_player', 'cmd_admin_restore_mood')


def proc(path, signature):
    source = (ROOT / path).read_text()
    start = source.index(signature)
    # Column-zero comments inside the hygiene proc are not declarations.
    following = re.search(r'^/(?![/*])', source[start + len(signature):], re.M)
    end = start + len(signature) + following.start() if following else len(source)
    return source[start:end]


def command(name):
    return proc('code/modules/admin/verbs/random_verbs.dm', '/client/proc/' + name + '(')


def assert_authority_and_target(test, source):
    # Both checks must return before any target mutation/call; a stale context
    # menu or direct proc call must not rely on verb-list membership.
    guard = ('\tif (!check_rights(R_ADMIN, TRUE, src))\n\t\treturn\n'
             '\tif (!istype(H) || QDELETED(H) || H.gcDestroyed || !H.loc)\n\t\treturn\n')
    test.assertIn(guard, source)
    before, after = source.split(guard)
    test.assertNotRegex(before, r'\n\tH\.')
    test.assertNotRegex(after, r'\b(sleep|spawn|WWinput|WWalert|input|do_after)\s*\(')


class PlayerCareSourceContracts(unittest.TestCase):
    def test_only_admin_group_registers_human_context_actions(self):
        source = (ROOT / 'code/modules/admin/admin_verbs.dm').read_text()
        group = source.split('var/list/admin_verbs_admin = list(', 1)[1].split('\n)', 1)[0]
        for name in COMMANDS:
            with self.subTest(command=name):
                self.assertEqual(source.count('/client/proc/' + name), 1)
                self.assertIn('/client/proc/' + name, group)
                body = command(name)
                self.assertIn('(mob/living/human/H as mob in mob_list)', body)
                self.assertIn('set category = "Admin"', body)
        self.assertIn('if (holder.rights & R_ADMIN)\t\t\tverbs += admin_verbs_admin', source)
        self.assertIn('admin_verbs_admin,', source.split('/client/proc/remove_admin_verbs()', 1)[1])
        self.assertIn('set name = "Clean Player"', command(COMMANDS[0]))
        self.assertIn('set name = "Restore Mood"', command(COMMANDS[1]))

    def test_authority_target_and_no_yield(self):
        for name in COMMANDS:
            with self.subTest(command=name):
                assert_authority_and_target(self, command(name))

    def test_guard_omissions_are_detected(self):
        for name in COMMANDS:
            for guard in ('check_rights(R_ADMIN, TRUE, src)', 'istype(H)',
                          'QDELETED(H)', 'H.gcDestroyed', '!H.loc'):
                with self.subTest(command=name, omission=guard):
                    with self.assertRaises(AssertionError):
                        assert_authority_and_target(self, command(name).replace(guard, 'FALSE'))

    def test_clean_only_restores_hygiene_and_worn_clothing(self):
        body = command(COMMANDS[0])
        self.assertIn('H.set_hygiene(HYGIENE_LEVEL_CLEAN)', body)
        self.assertIn('for (var/obj/item/clothing/C in list(H.wear_suit, H.w_uniform, H.shoes))', body)
        self.assertIn('if (C && !QDELETED(C) && !C.gcDestroyed && C.loc == H)', body)
        assignments = re.findall(r'^\s*([HC]\.[\w\[\]]+) = (.+)$', body, re.M)
        self.assertEqual(assignments, [('C.dirtyness', '0'), ('C.fleas', 'FALSE'),
                                       ('H.overlays_standing[27]', 'null')])
        calls = re.findall(r'^\s*H\.(\w+)\(', body, re.M)
        self.assertEqual(calls, ['set_hygiene', 'update_icons'])
        setter = proc('code/game/mob/living/carbon/human/human_needs.dm',
                      '/mob/living/human/proc/set_hygiene(')
        self.assertIn('hygiene = min(HYGIENE_LEVEL_CLEAN, amount)', setter)

    def test_clean_matches_hygiene_sources_and_refreshes_without_tick(self):
        hygiene = proc('code/game/mob/living/carbon/human/human_needs.dm',
                       '/mob/living/human/proc/handle_hygiene()')
        self.assertIn('list(wear_suit,w_uniform,shoes)', hygiene)
        self.assertIn('overlays_standing[27] = img_nasties', hygiene)
        body = command(COMMANDS[0])
        self.assertLess(body.index('H.overlays_standing[27] = null'), body.index('H.update_icons()'))
        self.assertNotIn('H.handle_hygiene()', body)

    def test_mood_restores_baseline_preserves_boost_and_refreshes_modifier(self):
        body = command(COMMANDS[1])
        self.assertIn('H.mood = max(H.mood, initial(H.mood))\n\tH.handle_mood()', body)
        self.assertEqual(re.findall(r'^\s*H\.(\w+) = ', body, re.M), ['mood'])
        self.assertEqual(re.findall(r'^\s*H\.(\w+)\(', body, re.M), ['handle_mood'])
        defines = (ROOT / 'code/game/mob/living/carbon/carbon_defines.dm').read_text()
        self.assertIn('var/mood = 100', defines)
        handler = proc('code/game/mob/living/carbon/human/human_needs.dm',
                       '/mob/living/human/proc/handle_mood()')
        self.assertIn('if(90 to 10000)\n\t\t\tmood_modifier = 1.15', handler)
        self.assertNotRegex(handler, r'\bmood\s*[-+*/]?=')

    def test_ci_runs_player_contracts_separately_from_legacy_native_items(self):
        workflow = (ROOT / '.github/workflows/test.yml').read_text()
        block = workflow.split('      - name: Verify admin player care source contracts\n', 1)[1].split('      - name:', 1)[0]
        self.assertIn("contains(fromJSON(needs.changes.outputs.new_tests || '[]'), 'tests/admin_player_care')", block)
        self.assertIn("python3 -m unittest discover -s tests/admin_player_care -p 'test_player_care.py' -v", block)
        self.assertNotIn('continue-on-error', block)
        self.assertNotIn('byond-bin', block)

    def test_success_is_audited_once_after_effects(self):
        for name in COMMANDS:
            with self.subTest(command=name):
                body = command(name)
                self.assertEqual(body.count('\n\tlog_admin('), 1)
                self.assertEqual(body.count('\n\tmessage_admins('), 1)
                self.assertIn('[key_name(src)]', body)
                self.assertIn('[key_name(H)]', body)
                self.assertIn('[key_name_admin(H)]', body)
                self.assertGreater(body.index('\n\tlog_admin('), body.rindex('\n\tH.'))


def project_regeneration(source, refresh_hud=None, transforming=False):
    """Interpret only the real straight-line regeneration call/guard body.

    Call effects are injected counters; this cannot establish native pixels.
    Unknown syntax fails rather than silently omitting a production operation.
    """
    default = re.search(r'regenerate_icons\(refresh_hud = (TRUE|FALSE)\)', source)
    if default is None:
        raise AssertionError('Missing explicit default HUD policy')
    if refresh_hud is None:
        refresh_hud = default[1] == 'TRUE'
    enabled = {0: True}
    calls = []
    source = re.sub(r'/\*.*?\*/', '', source, flags=re.S)
    for raw in source.splitlines()[1:]:
        text = raw.split('//', 1)[0].strip()
        if not text:
            continue
        depth = len(raw) - len(raw.lstrip('\t'))
        active = enabled[depth - 1]
        if text.startswith('if ('):
            condition = re.fullmatch(r'if \((transforming|refresh_hud)\)', text)
            if condition is None:
                raise AssertionError(text)
            enabled[depth] = active and dict(transforming=transforming, refresh_hud=refresh_hud)[condition[1]]
        elif text == 'return':
            if active:
                break
        else:
            call = re.fullmatch(r'(\.\.|\w+)\((0)?\)', text)
            if call is None:
                raise AssertionError(text)
            if active:
                calls.append(call[1])
    return calls


class CleanRendererContracts(unittest.TestCase):
    def renderer(self):
        return proc('code/game/mob/living/carbon/human/update_icons.dm',
                    '/mob/living/human/regenerate_icons(')

    def clean_hud_argument(self, source):
        call = re.search(r'M\.regenerate_icons\((FALSE|TRUE)?\)', source)
        self.assertIsNotNone(call)
        return None if call[1] is None else call[1] == 'TRUE'

    def test_item_clean_keeps_human_appearance_refresh_without_hud_reset(self):
        body = command('cmd_admin_clean_item')
        argument = self.clean_hud_argument(body)
        self.assertIs(argument, False)
        self.assertLess(body.index('I.clean_blood()'), body.index('M.regenerate_icons('))
        calls = project_regeneration(self.renderer(), argument)
        # The injected HUD reset discards the private screens, reproducing the
        # actual show_HUD screen-list operation without claiming native rendering.
        screens = [object(), object(), object()]  # root master, relay, lighting
        before = tuple(screens)
        for call in calls:
            if call == 'update_hud':
                screens.clear()
        self.assertEqual(tuple(screens), before)
        self.assertNotIn('update_hud', calls)
        for name in ('update_body', 'update_hair', 'update_mutations', 'update_inv_shoes',
                     'update_inv_w_uniform', 'update_inv_wear_suit', 'update_inv_l_hand',
                     'update_inv_r_hand', 'update_inv_back', 'update_fire', 'update_surgery',
                     'update_bandaging', 'UpdateDamageIcon', 'update_icons'):
            self.assertIn(name, calls)
        self.assertEqual(calls[-1], 'update_icons')

    def test_ordinary_regeneration_still_refreshes_hud_and_all_same_appearance_calls(self):
        renderer = self.renderer()
        ordinary = project_regeneration(renderer)
        cosmetic = project_regeneration(renderer, False)
        self.assertEqual(ordinary.count('update_hud'), 1)
        self.assertEqual([c for c in ordinary if c != 'update_hud'], cosmetic)
        base = proc('code/game/mob/update_icons.dm', '/mob/proc/regenerate_icons(')
        self.assertIn('regenerate_icons(refresh_hud = TRUE)', base)
        self.assertIn('\n\treturn', base)

    def test_transforming_guard_still_aborts_both_routes(self):
        for refresh in (None, False, True):
            self.assertEqual(project_regeneration(self.renderer(), refresh, transforming=True), ['..'])

    def test_hud_reset_and_clean_call_omissions_reproduce_screen_withdrawal(self):
        renderer = self.renderer()
        unconditional = renderer.replace('\tif (refresh_hud)\n\t\tupdate_hud()', '\tupdate_hud()')
        self.assertIn('update_hud', project_regeneration(unconditional, False))
        old_command = command('cmd_admin_clean_item').replace('M.regenerate_icons(FALSE)', 'M.regenerate_icons()')
        self.assertIn('update_hud', project_regeneration(renderer, self.clean_hud_argument(old_command)))
        show = proc('code/game/mob/living/living_hud.dm', '/mob/living/proc/show_HUD()')
        self.assertIn('client.screen.Cut()', show)
        self.assertNotIn('root_tree_presenter', show)
        admission = proc('code/modules/visibility/root_tree_presenter.dm',
                         '/datum/root_tree_presenter/proc/planes_admitted()')
        self.assertIn('for(var/obj/screen/P in screens)', admission)
        self.assertIn('if(!(P in owner.screen))\n\t\t\treturn FALSE', admission)

    def test_clean_authorization_target_checks_and_audits_still_precede_effects(self):
        body = command('cmd_admin_clean_item')
        guard = ('\tif (!check_rights(R_ADMIN, TRUE, src))\n\t\treturn\n'
                 '\tif (!istype(I) || QDELETED(I) || I.gcDestroyed || !I.loc)\n\t\treturn\n')
        self.assertIn(guard, body)
        self.assertLess(body.index(guard), body.index('I.clean_blood()'))
        self.assertNotRegex(body, r'\b(sleep|spawn|WWinput|WWalert|input|do_after)\s*\(')
        for sink in ('log_admin', 'message_admins'):
            self.assertEqual(body.count('\n\t' + sink + '('), 1)
            self.assertGreater(body.index('\n\t' + sink + '('), body.index('M.regenerate_icons(FALSE)'))


if __name__ == '__main__':
    unittest.main()
