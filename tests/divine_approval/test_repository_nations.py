"""Source guards for repository_nations.dm: nation draw order, staff tools and gods playing their own Nomads."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
NATIONS = (ROOT / 'code/modules/divine/repository_nations.dm').read_text()
TIERS = (ROOT / 'code/modules/divine/repository_tiers.dm').read_text()
COVENANT = (ROOT / 'code/modules/divine/covenant.dm').read_text()
WHITELIST = (ROOT / 'code/modules/divine/magic_whitelist.dm').read_text()
PATRON = (ROOT / 'code/modules/admin/verbs/divine_patron.dm').read_text()
STAFF = (ROOT / 'code/modules/admin/verbs/divine_repositories.dm').read_text()


def body(text, path):
    return text.split(path, 1)[1].split('\n/', 1)[0]


class RepositoryNations(unittest.TestCase):
    def test_built(self):
        dme = (ROOT / 'civ13.dme').read_text()
        self.assertIn('#include "code\\modules\\divine\\repository_nations.dm"', dme)
        self.assertIn('#include "code\\modules\\admin\\verbs\\divine_repositories.dm"', dme)

    def test_national_first_then_consenting_members(self):
        draw = body(NATIONS, '/proc/ward_draw_nation(')
        self.assertIn('for (var/pass in 1 to 2)', draw)
        self.assertIn('pass == 1 ? O.magic_repo_tier != 5 : (O.magic_repo_tier == 5 || !O.magic_repo_nation_share)', draw)
        self.assertIn('O.magic_repo_dormant()', draw)
        self.assertIn('ward_drain(O, take)', draw)
        self.assertIn('var/magic_repo_nation_share = FALSE', NATIONS)
        # Only the maker lends it, from the keeper menu.
        self.assertIn('O.magic_repo_maker != magic_key()', body(NATIONS, '/mob/living/human/proc/magic_repo_nation_option('))
        self.assertIn('magic_repo_nation_toggle(O)', body(TIERS, '/mob/living/human/proc/magic_repo_keeper_menu('))

    def test_staff_tools_are_admin_only_and_logged(self):
        tend = body(STAFF, '/client/proc/divine_tend_repositories()')
        self.assertIn('check_rights(R_ADMIN)', tend)
        for action in ('"Set charge"', '"Set tier"', '"Wake it"', '"Make it ordinary"', '"Jump to it"'):
            self.assertIn(action, tend)
        self.assertIn('log_admin(', tend)
        self.assertIn('message_admins(', tend)
        self.assertIn('divine_tend_repositories()', PATRON)

    def test_gods_worship_themselves_on_nomads(self):
        own = body(NATIONS, '/mob/living/human/proc/divine_is_own_god()')
        self.assertIn('map.nomads', own)
        self.assertIn('divine_identity_is_staff(key)', own)
        self.assertIn('divine_self_worship()', body(COVENANT, '/mob/living/human/Login()'))
        allowed = body(WHITELIST, '/mob/living/human/proc/magic_allowed()')
        self.assertLess(allowed.index('divine_is_own_god()'), allowed.index('magic_whitelisted(magic_key())'))

    def test_self_approval_is_shown_to_staff(self):
        grant = body(COVENANT, '/proc/divine_grant(')
        self.assertLess(grant.index('R.approve(C)'), grant.index('divine_note_self_approval(R, C)'))
        note = body(NATIONS, '/proc/divine_note_self_approval(')
        self.assertIn('caster.magic_key() != C.ckey', note)
        self.assertIn('log_admin(', note)
        self.assertIn('message_admins(', note)


if __name__ == '__main__':
    unittest.main()
