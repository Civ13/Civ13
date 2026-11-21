"""Source guards for divine casting on persistent worlds (covenant.dm, #5142)."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
TEXT = (ROOT / 'code/modules/divine/covenant.dm').read_text()
VERB = (ROOT / 'code/modules/admin/verbs/divine_patron.dm').read_text()
BOOK = (ROOT / 'code/modules/divine/divine_book.dm').read_text()


def body(text, path):
    return text.split(path, 1)[1].split('\n/', 1)[0]


class Covenant(unittest.TestCase):
    def test_built_and_admin_verb_registered(self):
        dme = (ROOT / 'civ13.dme').read_text()
        self.assertIn('#include "code\\modules\\divine\\covenant.dm"', dme)
        self.assertIn('#include "code\\modules\\admin\\verbs\\divine_patron.dm"', dme)
        self.assertLess(dme.index('divine\\ritual.dm'), dme.index('divine\\covenant.dm'))
        self.assertIn('/client/proc/cmd_admin_divine_patron,', (ROOT / 'code/modules/admin/admin_verbs.dm').read_text())
        verb = body(VERB, '/client/proc/cmd_admin_divine_patron()')
        self.assertLess(verb.index('check_rights(R_ADMIN)'), verb.index('input('))

    def test_beseech_only_for_followers(self):
        # Never a default verb: only an initiated character gets it.
        self.assertNotIn('/mob/living/human/verb/', TEXT)
        refresh = body(TEXT, '/mob/living/human/proc/divine_refresh_verbs()')
        self.assertIn('divine_patron', refresh)
        self.assertIn('verbs -= /mob/living/human/proc/divine_beseech', refresh)
        self.assertIn('divine_refresh_verbs()', body(TEXT, '/mob/living/human/Login()'))

    def test_every_use_waits_for_the_god(self):
        beseech = body(TEXT, '/mob/living/human/proc/divine_beseech()')
        self.assertIn('divine_alert_operators(R)', beseech)
        for forbidden in ('approve(', 'consume(', 'divine_dispatch('):
            self.assertNotIn(forbidden, beseech)
        grant = body(TEXT, '/proc/divine_grant(')
        self.assertIn('operator_allowed(C)', grant)
        self.assertIn('divine_claim_of(C) != R.covenant.deity_id', grant)
        self.assertLess(grant.index('input('), grant.index('R.approve(C)'))
        topic = body(TEXT, '/datum/divine_use_request/Topic(')
        self.assertIn('src in divine_pending_requests', topic)

    def test_dispatch_is_synchronous_and_single_use(self):
        dispatch = body(TEXT, '/proc/divine_dispatch(')
        for forbidden in ('sleep(', 'spawn(', 'input(', 'alert(', 'WWinput('):
            self.assertNotIn(forbidden, dispatch)
        self.assertLess(dispatch.index('divine_problem(spell)'), dispatch.index('R.consume('))
        self.assertLess(dispatch.index('R.consume('), dispatch.index('divine_slot_spent = TRUE'))
        self.assertLess(dispatch.index('divine_slot_spent = TRUE'), dispatch.index('switch (spell)'))
        self.assertIn('divine_finish_request(R)', dispatch)

    def test_lifecycle_breaks_pending_prayers(self):
        for path in ('/mob/living/human/Move()', '/mob/living/human/Logout()', '/mob/living/human/Login()'):
            hook = body(TEXT, path)
            self.assertIn('divine_break_covenant(', hook)
            self.assertIn('divine_leave_vigil()', hook)
        self.assertIn('invalidate()', body(TEXT, '/mob/living/human/proc/divine_break_covenant('))

    def test_runtime_state_never_saved(self):
        for name in ('divine_covenant', 'divine_request', 'divine_vigil_member'):
            self.assertIn(f'var/tmp/datum/', TEXT)
            self.assertIn(f'key == "{name}"', body(TEXT, '/mob/living/human/persistence_runtime_var('))
        self.assertIn('var/divine_patron = null', TEXT)

    def test_bounded_effects(self):
        dispatch = body(TEXT, '/proc/divine_dispatch(')
        for forbidden in ('revive', 'gib(', 'rejuvenate', 'death(', 'adjustOxyLoss', 'adjustToxLoss'):
            self.assertNotIn(forbidden, dispatch)
        # Base effects, raised at most x1.75 by a matching attuned component (strength 3).
        self.assertIn('target.heal_overall_damage(round(15 * bonus), round(15 * bonus))', dispatch)
        self.assertIn('target.adjustHalLoss(round(20 * bonus))', dispatch)
        altars = (ROOT / 'code/modules/divine/arcane_altars.dm').read_text(encoding='utf-8')
        self.assertIn('return 1 + 0.25 * component.arcane_strength', altars)
        self.assertIn('clamp(round(strength), 1, 3)', (ROOT / 'code/modules/divine/arcane_materials.dm').read_text(encoding='utf-8'))

    def test_ordinary_gear_only(self):
        # Focus and components are ordinary items; nothing magical is created.
        for forbidden in ('/obj/item/weapon/material/magic', 'new /obj', 'icon_state', '\n\tdesc =', '\n\tname ='):
            self.assertNotIn(forbidden, TEXT)
        self.assertIn('istype(I, /obj/item/weapon/branch)', body(TEXT, '/mob/living/human/proc/divine_focus()'))

    def test_gods_book_text_for_own_followers(self):
        gate = body(BOOK, '/obj/item/weapon/book/divine/divine_journal_reader_allowed(')
        self.assertIn('..()', gate)
        self.assertIn('divine_book_key(H.divine_patron) == divine_book_key(divine_deity)', gate)

    def test_waits_for_save_and_load(self):
        problem = body(TEXT, '/mob/living/human/proc/divine_problem(')
        for check in ('persistence_player_restore_ready', 'persistence_save_in_progress', 'persistence_active_operation'):
            self.assertIn(check, problem)


if __name__ == '__main__':
    unittest.main()
