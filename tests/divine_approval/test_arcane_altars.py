"""Offline source contract for altars and materials in casting; does not execute DM."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(rel):
    return (ROOT / rel).read_text(encoding='utf-8')


TEXT = read('code/modules/divine/arcane_altars.dm')
COVENANT = read('code/modules/divine/covenant.dm')


def body(text, header):
    return text.split(header, 1)[1].split('\n/', 1)[0]


class ArcaneAltarsSource(unittest.TestCase):
    def test_included(self):
        self.assertIn('#include "code\\modules\\divine\\arcane_altars.dm"', read('civ13.dme'))

    def test_dedication_is_hidden_saved_fields(self):
        decl = body(TEXT, '\n/obj\n')
        for var in ('arcane_altar_deity', 'arcane_altar_by', 'arcane_altar_spot', 'arcane_altar_days', 'arcane_altar_worshippers'):
            self.assertIn(var, decl)
            self.assertNotIn('tmp/' + var, decl)
        for forbidden in ('.name =', '.icon_state =', '.desc =', 'visible_message(', 'to_world('):
            self.assertNotIn(forbidden, TEXT)

    def test_moving_ends_it(self):
        self.assertIn('arcane_spot_key() != arcane_altar_spot', body(TEXT, '/obj/proc/arcane_altar_live()'))

    def test_dedication_is_gated_and_limited(self):
        dedicate = body(TEXT, '/mob/living/human/proc/arcane_dedicate(')
        for gate in ('verified_discord_id(ckey)', 'persistence_save_in_progress', 'ARCANE_ALTARS_EACH', 'do_after('):
            self.assertIn(gate, dedicate)
        self.assertIn('#define ARCANE_ALTARS_EACH 3', TEXT)
        self.assertIn('arcane_magic_user()', body(TEXT, '/mob/living/human/proc/arcane_tend_altar()'))

    def test_standing_and_neglect(self):
        self.assertIn('list(25, 50, 75, 100)', TEXT)
        self.assertIn('list(list(0, 0), list(5, 0), list(15, 3), list(40, 5))', TEXT)
        self.assertIn('#define ARCANE_ALTAR_NEGLECT 12096000', TEXT)
        self.assertIn('ARCANE_ALTAR_NEGLECT', body(TEXT, '/obj/proc/arcane_altar_standing()'))

    def test_offerings_go_through_ward_refill(self):
        offer = body(TEXT, '/mob/living/human/proc/arcane_offer_at(')
        self.assertIn('ward_refill(target, amount, "offering", src)', offer)
        self.assertIn('R.magic_repo_deity == god', offer)
        self.assertIn('arcane_altar_percent()', offer)
        # Nothing is used up when the repository takes nothing.
        self.assertLess(offer.index('if (!added)'), offer.index('qdel(I)'))

    def test_only_its_gods_magic_users_see_it(self):
        self.assertIn('arcane_altar_examine(user)', read('code/game/objects/objs.dm'))
        examine = body(TEXT, '/obj/proc/arcane_altar_examine(')
        self.assertIn('arcane_magic_user()', examine)
        self.assertIn('divine_book_key(H.divine_patron) != arcane_altar_live()', examine)

    def test_materials_in_casting(self):
        dispatch = body(COVENANT, '/proc/divine_dispatch(')
        self.assertLess(dispatch.index('arcane_component_bonus(component, spell)'), dispatch.index('qdel(component)'))
        self.assertIn('DIVINE_REST_FALLBACK / 4', dispatch)
        self.assertIn('arcane_storm_focus(I)', body(COVENANT, '/mob/living/human/proc/divine_focus()'))
        self.assertIn('arcane_refresh_verbs()', body(COVENANT, '/mob/living/human/proc/divine_refresh_verbs()'))

    def test_defines_are_file_local(self):
        for line in TEXT.splitlines():
            if line.startswith('#define '):
                self.assertIn('#undef ' + line.split()[1], TEXT)


if __name__ == '__main__':
    unittest.main()
