"""Source guards for repository tiers (repository_tiers.dm): god-granted rites, forms that cap the tier, neglect and seats."""
from pathlib import Path
import json
import unittest

ROOT = Path(__file__).resolve().parents[2]
TIERS = (ROOT / 'code/modules/divine/repository_tiers.dm').read_text()
REPO = (ROOT / 'code/modules/divine/repository.dm').read_text()
COVENANT = (ROOT / 'code/modules/divine/covenant.dm').read_text()
PATRON = (ROOT / 'code/modules/admin/verbs/divine_patron.dm').read_text()
BALANCE = json.loads((ROOT / 'config/magic_law_balance.json').read_text())

RITES = ('repository_strengthen', 'repository_attune', 'repository_move', 'repository_consecrate')


def body(text, path):
    return text.split(path, 1)[1].split('\n/', 1)[0]


class RepositoryTiers(unittest.TestCase):
    def test_built(self):
        dme = (ROOT / 'civ13.dme').read_text()
        self.assertIn('#include "code\\modules\\divine\\repository_tiers.dm"', dme)

    def test_balance_numbers_are_vals(self):
        tiers = BALANCE['tiers']
        self.assertEqual([t['ceiling'] for t in tiers], [100, 400, 1500, 5000, 15000])
        self.assertEqual([t['skill'] for t in tiers], [5, 20, 40, 60, 80])
        self.assertEqual([t['vigil'] for t in tiers], [1, 2, 3, 5, 8])
        self.assertEqual([t['full_days'] for t in tiers], [0, 7, 7, 14, 14])
        self.assertEqual([t['channel_minutes'] for t in tiers], [30, 120, 360, 720, 1440])
        self.assertEqual([t['verified'] for t in tiers], [False, False, True, True, True])
        self.assertEqual(BALANCE['neglect'], {'low_fraction': 0.1, 'low_days': 7, 'empty_days': 30})
        self.assertEqual(BALANCE['full_fraction'], 0.75)
        forms = dict(BALANCE['forms'])
        self.assertEqual(forms['/obj/structure/religious/statue'], 5)
        self.assertEqual(forms['/obj/structure/bed/chair/throne'], 4)
        self.assertEqual(forms['/obj/structure/table'], 3)
        self.assertEqual(forms['/obj/structure/painting_frame'], 2)
        self.assertIn('config/magic_law_balance.json', TIERS)

    def test_rites_come_with_the_grant_and_need_the_god(self):
        for rite in RITES:
            self.assertIn('"%s" = "' % rite, COVENANT)
            self.assertIn('"%s"' % rite, body(TIERS, 'var/global/list/magic_repo_rites'))
        allowed = body(TIERS, '/mob/living/human/proc/divine_spells_allowed()')
        self.assertIn('if ("repository" in .)', allowed)
        # Beseech offers them, the covenant allows them and dispatch applies them after Grant.
        self.assertIn('for (var/spell in divine_spells_allowed())', COVENANT)
        self.assertIn('operators, divine_spells_allowed())', COVENANT)
        self.assertIn('return magic_repo_rite_problem(spell)', body(COVENANT, '/mob/living/human/proc/divine_problem('))
        dispatch = body(COVENANT, '/proc/divine_dispatch(')
        self.assertLess(dispatch.index('R.consume('), dispatch.index('caster.magic_repo_rite_granted(spell)'))
        # Never taught on their own.
        self.assertIn('if (magic_repo_rite_spell(spell))', PATRON)

    def test_upgrade_conditions(self):
        up = body(TIERS, '/mob/living/human/proc/magic_repo_upgrade_problem(')
        self.assertIn('magic_repo_form_ceiling(O) < tier', up)
        self.assertIn('magic_skill() < magic_tier_value(tier, "skill", 100)', up)
        self.assertIn('world.realtime - O.magic_repo_full_since < days * MAGIC_TIER_DAY', up)
        self.assertIn('magic_repo_vigil_problem(O, tier)', up)
        self.assertIn('magic_repo_seat_problem(get_turf(O), tier, civilization, group)', up)
        self.assertIn('magic_repo_consent(', up)
        vigil = body(TIERS, '/mob/living/human/proc/magic_repo_vigil(')
        self.assertIn('account_verified(H.magic_key())', vigil)
        self.assertIn('O.magic_repo_registrants', vigil)

    def test_upgrades_are_channelled_from_stored_charge_only(self):
        rite = body(TIERS, '/mob/living/human/proc/magic_channel_rite(')
        self.assertIn('magic_repo_seed_source(O, per_sitting)', rite)
        self.assertNotIn('nutrition', rite)
        self.assertIn('O.magic_repo_progress += MAGIC_TIER_SITTING', rite)
        self.assertIn('magic_channel_rite(R)', body(REPO, '/mob/living/human/proc/magic_channel()'))
        finish = body(TIERS, '/mob/living/human/proc/magic_repo_rite_finish(')
        # Skill never goes down.
        self.assertIn('max(O.magic_repo_skill, O.magic_repo_rite_skill)', finish)

    def test_neglect(self):
        tick = body(TIERS, '/obj/proc/magic_repo_tick()')
        self.assertIn('magic_repo_set_tier(magic_repo_tier - 1)', tick)
        self.assertIn('magic_repo_tier == 1 && now - magic_repo_empty_since', tick)
        self.assertIn('magic_repo_unmake(', tick)
        # Still repositories never wither, and nothing is judged before the world has loaded.
        self.assertLess(tick.index('persistence_player_restore_ready'), tick.index('magic_repo_set_tier('))
        self.assertLess(tick.index('if (magic_repo_dormant())'), tick.index('magic_repo_set_tier('))
        for proc in ('/proc/ward_charge(', '/proc/ward_refill(', '/proc/ward_drain('):
            self.assertIn('magic_repo_tick()', body(REPO, proc))

    def test_seat_capture_and_consecration(self):
        self.assertIn('|| magic_repo_captured', body(REPO, '/obj/proc/magic_repo_dormant()'))
        seat = body(TIERS, '/obj/proc/magic_repo_check_seat()')
        self.assertIn('province_near_faction_seat(magic_repo_faction, T)', seat)
        self.assertIn('province_holder_of(c) != magic_repo_group', seat)
        granted = body(TIERS, '/mob/living/human/proc/magic_repo_rite_granted(')
        consecrate = granted.split('if ("repository_consecrate")', 1)[1]
        self.assertIn('O.magic_repo_captured = FALSE', consecrate)
        self.assertNotIn('magic_repo_charge', consecrate)

    def test_move_carries_everything_and_leaves_an_ordinary_thing(self):
        move = body(TIERS, '/mob/living/human/proc/magic_repo_rite_granted(').split('if ("repository_move")', 1)[1].split('if ("repository_consecrate")', 1)[0]
        self.assertIn('D.vars[v] = O.vars[v]', move)
        self.assertIn('O.vars[v] = initial(O.vars[v])', move)
        self.assertIn('magic_repo_index[D.magic_repo_id] = D', move)
        problem = body(TIERS, '/mob/living/human/proc/magic_repo_move_problem(')
        self.assertIn('magic_repo_form_ceiling(D) <= magic_repo_form_ceiling(O)', problem)

    def test_only_tied_keepers_count_and_the_maker_names_keepers(self):
        self.assertIn('(magic_key() in O.magic_repo_registrants)', body(REPO, '/mob/living/human/proc/magic_registered_repositories()'))
        menu = body(TIERS, '/mob/living/human/proc/magic_repo_keeper_menu(')
        self.assertIn('O.magic_repo_maker == magic_key()', menu)
        self.assertIn('O.magic_repo_barred |= key', menu)

    def test_stays_ordinary_to_everyone_else(self):
        for forbidden in ('.name =', '.desc =', '.icon_state =', '.icon ='):
            self.assertNotIn(forbidden, TIERS)
        self.assertIn('magic_repo_tier_examine(user)', body(REPO, '/obj/proc/magic_repo_examine('))

    def test_saved_fields_are_plain(self):
        fields = TIERS.split('\n/obj\n', 1)[1].split('\n/mob/living/human\n', 1)[0]
        self.assertNotRegex(fields, r'var/(?!tmp/)(datum|obj|mob)/')
        self.assertIn('var/tmp/obj/magic_rite_dest', TIERS)


if __name__ == '__main__':
    unittest.main()
