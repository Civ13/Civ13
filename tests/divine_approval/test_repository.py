"""Source guards for magic repositories (repository.dm): hidden, god-granted, paid for, and capped."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
REPO = (ROOT / 'code/modules/divine/repository.dm').read_text()
COVENANT = (ROOT / 'code/modules/divine/covenant.dm').read_text()
PATRON = (ROOT / 'code/modules/admin/verbs/divine_patron.dm').read_text()
OBJS = (ROOT / 'code/game/objects/objs.dm').read_text()
CLICK = (ROOT / 'code/_onclick/click.dm').read_text()


def body(text, path):
    return text.split(path, 1)[1].split('\n/', 1)[0]


class Repository(unittest.TestCase):
    def test_built(self):
        dme = (ROOT / 'civ13.dme').read_text()
        self.assertIn('#include "code\\modules\\divine\\repository.dm"', dme)

    def test_start_is_an_invocation_the_god_approves(self):
        self.assertIn('"repository" = "Keep a repository"', COVENANT)
        # Beseech asks the god; the object only changes in dispatch, after Grant.
        dispatch = body(COVENANT, '/proc/divine_dispatch(')
        self.assertLess(dispatch.index('R.consume('), dispatch.index('caster.magic_repo_begin()'))
        self.assertIn('return magic_repo_begin_problem()', body(COVENANT, '/mob/living/human/proc/divine_problem('))
        self.assertIn('if ("repository")\n\t\t\treturn target == caster', body(COVENANT, '/proc/divine_target_legal('))
        self.assertIn('"repository-v1:', body(COVENANT, '/proc/divine_scope('))

    def test_grant_needs_the_whitelist(self):
        grant = body(REPO, '/mob/living/human/proc/magic_has_grant()')
        self.assertIn('"repository" in divine_known', grant)
        self.assertIn('magic_allowed()', grant)
        self.assertIn('magic_allowed()', body(REPO, '/mob/living/human/proc/magic_tie_to('))
        self.assertIn('magic_allowed()', body(REPO, '/obj/proc/magic_repo_examine('))

    def test_teaching_and_taking_back(self):
        teach = PATRON.split('if ("Teach an invocation", "Take back an invocation")', 1)[1].split('if ("Release a follower")', 1)[0]
        self.assertIn('H.magic_grant_received()', teach)
        self.assertIn('H.magic_repo_withdraw_all()', teach)
        self.assertIn('magic_skill_floor(MAGIC_REPO_SKILL_FLOOR)', body(REPO, '/mob/living/human/proc/magic_grant_received()'))
        self.assertIn('#define MAGIC_REPO_SKILL_FLOOR 5', REPO)

    def test_making_takes_time_and_costs(self):
        self.assertIn('#define MAGIC_REPO_MAKE_TIME 18000', REPO)
        channel = body(REPO, '/mob/living/human/proc/magic_channel()')
        self.assertIn('do_after(src, MAGIC_REPO_SITTING', channel)
        self.assertIn('nutrition = max(0, nutrition - max_nutrition / MAGIC_REPO_BODY_SHARE)', channel)
        self.assertIn('water = max(0, water - max_water / MAGIC_REPO_BODY_SHARE)', channel)
        self.assertIn('magic_repo_seed_source(I, per_minute_seed)', channel)
        self.assertIn('adaptStat("magic"', channel)
        # Progress is saved on the object, so channelling can be split into sittings.
        self.assertIn('I.magic_repo_progress += MAGIC_REPO_SITTING', channel)

    def test_capacity_from_size_and_skill(self):
        finish = body(REPO, '/mob/living/human/proc/magic_repo_finish(')
        self.assertIn('MAGIC_REPO_PERSONAL_CEILING * magic_repo_size_factor(I) * skill', finish)
        self.assertIn('max(0.05, magic_skill() / 100)', finish)

    def test_allowance_grows_with_skill(self):
        self.assertIn('min(5, 1 + round(magic_skill() / 25))', body(REPO, '/mob/living/human/proc/magic_repo_allowance()'))
        self.assertIn('magic_repos_kept().len >= magic_repo_allowance()', body(REPO, '/mob/living/human/proc/magic_repo_begin_problem()'))

    def test_refill_is_capped_and_never_feeds_a_dormant_repository(self):
        refill = body(REPO, '/proc/ward_refill(')
        self.assertLess(refill.index('magic_repo_dormant()'), refill.index('magic_repo_charge +='))
        self.assertIn('repo.magic_repo_capacity - repo.magic_repo_charge', refill)
        self.assertIn('magic_repo_follower_caps[source]', refill)
        self.assertIn('"devotion" = list("flat" = 150)', REPO)
        self.assertIn('"rite" = list("flat" = 400)', REPO)
        self.assertIn('"offering" = list("capacity" = 0.05)', REPO)

    def test_drain_reports_what_is_left(self):
        drain = body(REPO, '/proc/ward_drain(')
        self.assertIn('return repo.magic_repo_charge > 0 ? repo.magic_repo_charge : FALSE', drain)

    def test_tie_by_touch_keeps_the_click(self):
        hook_at = CLICK.index('magic_touch_hook(src, A)')
        self.assertLess(hook_at, CLICK.index('if (in_throw_mode)'))
        # The hook returns nothing the click waits on: the touch still happens.
        self.assertNotIn('if (magic_touch_hook(', CLICK)
        tie = body(REPO, '/mob/living/human/proc/magic_tie_to(')
        self.assertIn('divine_book_key(divine_patron) != O.magic_repo_deity', tie)
        self.assertIn('O.magic_repo_barred', tie)

    def test_ordinary_to_everyone_else(self):
        self.assertIn('magic_repo_examine(user)', body(OBJS, '/obj/examine('))
        examine = body(REPO, '/obj/proc/magic_repo_examine(')
        self.assertIn('magic_repo_is_keeper(user)', examine)
        # Nothing renames, re-describes or re-sprites the object.
        for forbidden in ('.name =', '.desc =', '.icon_state =', '.icon ='):
            self.assertNotIn(forbidden, REPO)
        verbs = body(REPO, '/mob/living/human/proc/magic_repo_refresh_verbs()')
        self.assertIn('magic_allowed()', verbs)
        self.assertIn('magic_repo_refresh_verbs()', body(COVENANT, '/mob/living/human/proc/divine_refresh_verbs()'))

    def test_saved_fields_are_plain(self):
        # Repository state lives in plain saved fields; runtime-only state is tmp.
        for name in ('magic_tie_ready', 'magic_channelling'):
            self.assertRegex(REPO, r'var/tmp/%s\b' % name)
        fields = REPO.split('\n/obj\n', 1)[1].split('/obj/after_load()', 1)[0]
        self.assertNotRegex(fields, r'var/(?!tmp/)(datum|obj|mob)/')


if __name__ == '__main__':
    unittest.main()
