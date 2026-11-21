"""Source guards for heteromorph forms (heteromorph.dm): staff-only, logged, hidden."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
TEXT = (ROOT / 'code/modules/divine/heteromorph.dm').read_text()
VERB = (ROOT / 'code/modules/admin/verbs/divine_patron.dm').read_text()


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


if __name__ == '__main__':
    unittest.main()
