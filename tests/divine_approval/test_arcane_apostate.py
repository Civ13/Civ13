"""Offline source contract for apostates; does not execute DM."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(rel):
    return (ROOT / rel).read_text(encoding='utf-8')


TEXT = read('code/modules/divine/arcane_apostate.dm')
COVENANT = read('code/modules/divine/covenant.dm')
PATRON = read('code/modules/admin/verbs/divine_patron.dm')


def body(text, header):
    return text.split(header, 1)[1].split('\n/', 1)[0]


class ArcaneApostateSource(unittest.TestCase):
    def test_included(self):
        self.assertIn('#include "code\\modules\\divine\\arcane_apostate.dm"', read('civ13.dme'))

    def test_renounce_is_verified_once_per_life_and_slow(self):
        can = body(TEXT, '/mob/living/human/proc/arcane_can_renounce()')
        for gate in ('!arcane_renounced', 'magic_allowed()', 'verified_discord_id(ckey)', 'divine_patron'):
            self.assertIn(gate, can)
        self.assertIn('#define ARCANE_APOSTATE_KNEEL 6000', TEXT)
        renounce = body(TEXT, '/mob/living/human/proc/arcane_renounce()')
        self.assertEqual(renounce.count('player_alert('), 2)
        self.assertIn('do_after(src, ARCANE_APOSTATE_KNEEL', renounce)
        self.assertIn('kept.len < ARCANE_APOSTATE_KEEP', renounce)
        self.assertIn('#define ARCANE_APOSTATE_KEEP 2', TEXT)

    def test_renouncing_strips_ties_altars_and_teaching(self):
        become = body(TEXT, '/mob/living/human/proc/arcane_become_apostate(')
        for step in ('magic_repo_withdraw_all()', 'magic_registered_repos = null', 'arcane_altar_end()',
                     'divine_patron = null', 'divine_known = null', 'arcane_renounced = TRUE',
                     'divine_online_operators(former)', 'log_admin('):
            self.assertIn(step, become)

    def test_kept_invocations_fade_and_cost_material(self):
        self.assertIn('#define ARCANE_APOSTATE_USES 5', TEXT)
        self.assertIn('#define ARCANE_APOSTATE_DAYS 12096000', TEXT)
        kept = body(TEXT, '/mob/living/human/proc/arcane_apostate_kept()')
        self.assertIn('world.realtime >= fades', kept)
        problem = body(TEXT, '/mob/living/human/proc/arcane_apostate_problem(')
        for gate in ('magic_allowed()', 'divine_slot_ready()', 'divine_focus()', 'arcane_apostate_material()'):
            self.assertIn(gate, problem)
        self.assertIn('I.arcane_virtue()', body(TEXT, '/mob/living/human/proc/arcane_apostate_material()'))
        use = body(TEXT, '/mob/living/human/proc/arcane_apostate_beseech()')
        self.assertIn('divine_slot_spent = TRUE', use)
        self.assertIn('arcane_apostate_uses[spell]--', use)
        self.assertIn('log_admin(', use)
        self.assertNotIn('divine_alert_operators', use)

    def test_half_effect(self):
        use = body(TEXT, '/mob/living/human/proc/arcane_apostate_beseech()')
        self.assertIn('target.adjustHalLoss(-20)', use)
        self.assertIn('target.adjustHalLoss(10)', use)
        self.assertIn('target.adjustHalLoss(-round(40 * bonus))', COVENANT)
        self.assertIn('target.adjustHalLoss(round(20 * bonus))', COVENANT)

    def test_only_god_free_invocations_can_be_kept(self):
        self.assertIn('var/global/list/arcane_apostate_keepable = list("mercy", "affliction")', TEXT)

    def test_beseech_routes_apostates_and_offers_renounce(self):
        beseech = body(COVENANT, '/mob/living/human/proc/divine_beseech()')
        self.assertIn('arcane_apostate_beseech()', beseech)
        self.assertIn('arcane_can_renounce()', beseech)
        self.assertIn('arcane_renounce()', beseech)
        self.assertIn('arcane_apostate_can_pray()', body(COVENANT, '/mob/living/human/proc/divine_refresh_verbs()'))

    def test_marked_for_former_god_only(self):
        examine = body(TEXT, '/mob/living/human/proc/arcane_apostate_examine(')
        self.assertIn('H.arcane_magic_user()', examine)
        self.assertIn('divine_book_key(H.divine_patron) != arcane_apostate_of', examine)
        self.assertIn('Something about them feels wrong to you.', examine)
        self.assertIn('arcane_apostate_examine(user)', read('code/game/mob/living/carbon/human/examine.dm'))

    def test_coming_back(self):
        join = body(TEXT, '/mob/living/human/proc/arcane_apostate_may_join(')
        self.assertIn('arcane_apostate_of == claim', join)
        self.assertIn('ARCANE_APOSTATE_DAYS', join)
        self.assertIn('H.arcane_apostate_may_join(claim)', PATRON)
        self.assertIn('H.arcane_apostate_return(claim)', PATRON)
        self.assertIn('"List apostates"', PATRON)
        self.assertIn('arcane_list_apostates(claim)', PATRON)


if __name__ == '__main__':
    unittest.main()
