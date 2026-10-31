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


if __name__ == '__main__':
    unittest.main()
