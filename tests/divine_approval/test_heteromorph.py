"""Source guards for heteromorph forms (heteromorph.dm): staff-only, logged, hidden."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
TEXT = (ROOT / 'code/modules/divine/heteromorph.dm').read_text()
VERB = (ROOT / 'code/modules/admin/verbs/divine_patron.dm').read_text()
FORM = (ROOT / 'code/modules/divine/heteromorph_form.dm').read_text()


def body(text, path):
    return text.split(path, 1)[1].split('\n/', 1)[0]


class Heteromorph(unittest.TestCase):
    def test_built_and_reachable_from_divine_patron(self):
        dme = (ROOT / 'civ13.dme').read_text()
        self.assertIn('#include "code\\modules\\divine\\heteromorph.dm"', dme)
        verb = body(VERB, '/client/proc/cmd_admin_divine_patron()')
        self.assertIn('divine_heteromorph_menu()', verb)
        menu = body(VERB, '/client/proc/divine_heteromorph_menu()')
        self.assertLess(menu.index('check_rights(R_ADMIN)'), menu.index('input('))
        self.assertIn('heteromorph_grant(K, colour, ckey)', menu)
        self.assertIn('heteromorph_revoke(ckey)', menu)

    def test_prompts_stay_in_admin_code(self):
        for forbidden in ('input(', 'alert(', 'sleep(', 'spawn('):
            self.assertNotIn(forbidden, TEXT)
        for forbidden in ('input(', 'alert('):
            self.assertNotIn(forbidden, FORM)

    def test_dragonoid_is_staff_only_and_world_gated(self):
        dragon = body(TEXT, '/datum/heteromorph/dragonoid')
        self.assertIn('id = "dragonoid"', dragon)
        self.assertIn('staff_only = TRUE', body(TEXT, '/datum/heteromorph\n'))
        problem = body(TEXT, '/mob/living/human/proc/heteromorph_grant_problem(')
        self.assertIn('K.staff_only && !heteromorph_staff_run()', problem)
        self.assertIn('K.origin != heteromorph_world_origin()', problem)
        grant = body(TEXT, '/mob/living/human/proc/heteromorph_grant(')
        self.assertLess(grant.index('heteromorph_grant_problem(K)'), grant.index('heteromorph_id = K.id'))
        self.assertIn('R_ADMIN', body(TEXT, '/mob/living/human/proc/heteromorph_staff_run()'))
        self.assertIn('K.staff_only && !heteromorph_staff_run()', body(TEXT, '/mob/living/human/proc/heteromorph_active()'))

    def test_every_change_is_shown_to_staff(self):
        log = body(TEXT, '/proc/heteromorph_log(')
        self.assertIn('log_admin(', log)
        self.assertIn('message_admins(', log)
        self.assertIn('heteromorph_log(', body(TEXT, '/mob/living/human/proc/heteromorph_grant('))
        self.assertIn('heteromorph_log(', body(TEXT, '/mob/living/human/proc/heteromorph_revoke('))

    def test_state_is_saved_and_clue_is_close_range(self):
        for var in ('heteromorph_id', 'heteromorph_colour', 'heteromorph_granted_by', 'heteromorph_cooldown_until'):
            self.assertIn('\tvar/%s = ' % var, TEXT)
            self.assertNotIn('var/tmp/%s' % var, TEXT)
        clue = body(TEXT, '/mob/living/human/proc/heteromorph_examine(')
        self.assertIn('get_dist(user, src) > 1', clue)
        self.assertIn('heteromorph_active()', clue)
        examine = (ROOT / 'code/game/mob/living/carbon/human/examine.dm').read_text()
        self.assertIn('heteromorph_examine(user)', examine)


class TrueForm(unittest.TestCase):
    def test_built_with_fable_art(self):
        dme = (ROOT / 'civ13.dme').read_text()
        self.assertIn('#include "code\\modules\\divine\\heteromorph_form.dm"', dme)
        self.assertTrue((ROOT / 'icons/mob/heteromorph_dragon.dmi').exists())
        self.assertTrue((ROOT / 'tests/sprites/create_heteromorph_dragon.py').exists())
        self.assertIn('form_type = /mob/living/simple_animal/heteromorph_form/dragon', FORM)

    def test_change_and_return_never_sleep(self):
        for path in ('/mob/living/human/proc/heteromorph_become_form(',
                     '/mob/living/simple_animal/heteromorph_form/proc/heteromorph_return(',
                     '/proc/heteromorph_return_all('):
            proc = body(FORM, path)
            for forbidden in ('sleep(', 'do_after(', 'spawn('):
                self.assertNotIn(forbidden, proc)
        take = body(FORM, '/mob/living/human/proc/heteromorph_take_form()')
        self.assertLess(take.index('heteromorph_form_problem(K)'), take.index('do_after('))
        self.assertLess(take.rindex('heteromorph_form_problem(K)'), take.index('heteromorph_become_form(K)'))
        self.assertLess(take.index('do_after('), take.rindex('heteromorph_form_problem(K)'))

    def test_low_health_returns_instead_of_dying(self):
        self.assertIn('heteromorph_return(TRUE', body(FORM, '/mob/living/simple_animal/heteromorph_form/updatehealth()'))
        death = body(FORM, '/mob/living/simple_animal/heteromorph_form/death(')
        self.assertIn('heteromorph_return(TRUE', death)
        self.assertNotIn('..(', death)
        self.assertIn('heteromorph_return(TRUE', body(FORM, '/mob/living/simple_animal/heteromorph_form/gib()'))
        destroy = body(FORM, '/mob/living/simple_animal/heteromorph_form/Destroy()')
        self.assertIn('heteromorph_body.forceMove(get_turf(src))', destroy)

    def test_saves_only_ever_see_the_human(self):
        save = (ROOT / 'code/modules/persistence/saving.dm').read_text()
        capture = body(save, '/map_storage/proc/save_world_contents(')
        self.assertLess(capture.index('heteromorph_return_all('), capture.index('prepare_player_ownership()'))
        for var in ('heteromorph_body', 'heteromorph_started', 'heteromorph_leaving'):
            self.assertIn('var/tmp/', FORM.split(var, 1)[0].rsplit('\n', 1)[1])

    def test_every_change_is_logged_and_verb_is_gated(self):
        self.assertIn('heteromorph_log(', body(FORM, '/mob/living/human/proc/heteromorph_become_form('))
        self.assertIn('heteromorph_log(', body(FORM, '/mob/living/simple_animal/heteromorph_form/proc/heteromorph_return('))
        refresh = body(FORM, '/mob/living/human/proc/heteromorph_refresh_verbs()')
        self.assertIn('heteromorph_active()', refresh)
        covenant = (ROOT / 'code/modules/divine/covenant.dm').read_text()
        self.assertIn('heteromorph_refresh_verbs()', body(covenant, '/mob/living/human/proc/divine_refresh_verbs()'))

    def test_balance_numbers_are_in_config(self):
        import json
        row = json.loads((ROOT / 'config/heteromorph_balance.json').read_text())['dragonoid']
        for key in ('health', 'transform_seconds', 'max_minutes', 'cooldown_minutes', 'revert_fraction'):
            self.assertIsInstance(row[key], (int, float))
            self.assertIn('"%s"' % key, FORM)


if __name__ == '__main__':
    unittest.main()
