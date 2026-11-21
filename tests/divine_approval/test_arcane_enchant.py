"""Offline source contract for enchantments woven by Imbue; does not execute DM."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(rel):
    return (ROOT / rel).read_text(encoding='utf-8')


TEXT = read('code/modules/divine/arcane_enchant.dm')
COVENANT = read('code/modules/divine/covenant.dm')


def body(text, header):
    return text.split(header, 1)[1].split('\n/', 1)[0]


class ArcaneEnchantSource(unittest.TestCase):
    def test_included_and_taught(self):
        self.assertIn('#include "code\\modules\\divine\\arcane_enchant.dm"', read('civ13.dme'))
        self.assertIn('"imbue" = "Imbue"', COVENANT)

    def test_fields_are_saved_and_plain(self):
        decl = body(TEXT, '\n/obj/item\n')
        for var in ('arcane_enchant', 'arcane_charges', 'arcane_enchanter', 'arcane_enchanted_at'):
            self.assertIn('var/' + var, decl)
            self.assertNotIn('tmp/' + var, decl)
        # Nothing renames or re-skins the item.
        for forbidden in ('.name =', '.icon_state =', '.desc ='):
            self.assertNotIn(forbidden, TEXT)

    def test_god_approves_and_materials_are_used_up_after_recheck(self):
        self.assertIn('return arcane_imbue_problem(arcane_imbue_pick)', body(COVENANT, '/mob/living/human/proc/divine_problem('))
        dispatch = body(COVENANT, '/proc/divine_dispatch(')
        self.assertLess(dispatch.index('caster.divine_problem(spell)'), dispatch.index('R.consume('))
        self.assertLess(dispatch.index('R.consume('), dispatch.index('caster.arcane_imbue_apply(R.target)'))
        self.assertIn('(spell == "imbue" || spell == "bless") ? null : caster.divine_component()', dispatch)
        apply = body(TEXT, '/mob/living/human/proc/arcane_imbue_apply(')
        self.assertIn('qdel(M)', apply)
        self.assertIn('log_admin(', apply)

    def test_target_is_the_held_item(self):
        legal = body(COVENANT, '/proc/divine_target_legal(')
        self.assertLess(legal.index('spell == "imbue"'), legal.index('!istype(target)'))
        self.assertIn('ismob(target)', body(COVENANT, '/proc/divine_alert_operators('))

    def test_cap_of_five_asks_which_to_let_go(self):
        self.assertIn('#define ARCANE_ENCHANT_CAP 5', TEXT)
        choose = body(TEXT, '/mob/living/human/proc/arcane_imbue_choose()')
        self.assertIn('own.len >= ARCANE_ENCHANT_CAP', choose)
        self.assertIn('arcane_enchant_end()', choose)

    def test_index_follows_items(self):
        self.assertIn('arcane_enchant_forget()', body(read('code/game/objects/items.dm'), '/obj/item/Destroy()'))
        self.assertIn('arcane_enchant_loaded()', read('code/processes/abandoned_items.dm'))

    def test_effects_are_hooked(self):
        self.assertIn('arcane_critical_check(health <= config.health_threshold_crit)', read('code/game/mob/living/carbon/human/human_life.dm'))
        self.assertIn('arcane_cleansing_pour(target)', body(read('code/modules/reagents/reagent_containers.dm'), '/obj/item/weapon/reagent_containers/proc/standard_pour_into('))
        crit = body(TEXT, '/mob/living/human/proc/arcane_critical_check(')
        self.assertIn('arcane_was_critical', crit)
        self.assertIn('arcane_enchant_spend(', crit)

    def test_only_magic_users_see_it(self):
        self.assertIn('arcane_enchant_examine(H)', body(read('code/modules/divine/arcane_materials.dm'), '/obj/item/proc/arcane_examine('))
        self.assertNotIn('visible_message(', TEXT)
        self.assertNotIn('to_world(', TEXT)

    def test_staff_list_and_strip(self):
        patron = read('code/modules/admin/verbs/divine_patron.dm')
        self.assertIn('"List enchantments", "Strip enchantment"', patron)
        self.assertIn('arcane_enchantments_of(H.ckey)', patron)

    def test_defines_are_file_local(self):
        for line in TEXT.splitlines():
            if line.startswith('#define '):
                self.assertIn('#undef ' + line.split()[1], TEXT)


if __name__ == '__main__':
    unittest.main()
