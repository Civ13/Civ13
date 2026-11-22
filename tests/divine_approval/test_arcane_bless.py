"""Offline source contract for blessings; does not execute DM."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(rel):
    return (ROOT / rel).read_text(encoding='utf-8')


TEXT = read('code/modules/divine/arcane_bless.dm')
COVENANT = read('code/modules/divine/covenant.dm')


def body(text, header):
    return text.split(header, 1)[1].split('\n/', 1)[0]


class ArcaneBlessSource(unittest.TestCase):
    def test_included_and_taught(self):
        self.assertIn('#include "code\\modules\\divine\\arcane_bless.dm"', read('civ13.dme'))
        self.assertIn('"bless" = "Bless"', COVENANT)

    def test_fields_saved_and_item_unchanged(self):
        decl = body(TEXT, '\n/obj/item\n')
        for var in ('arcane_bless_stat', 'arcane_bless_tier', 'arcane_bless_base', 'arcane_blesser'):
            self.assertIn('var/' + var, decl)
            self.assertNotIn('tmp/' + var, decl)
        for forbidden in ('.name =', '.icon_state =', '.desc =', 'visible_message(', 'to_world('):
            self.assertNotIn(forbidden, TEXT)

    def test_tiers_and_costs(self):
        self.assertIn('list(50, 150, 400)', TEXT)
        self.assertIn('#define ARCANE_BLESS_MAX 3', TEXT)
        raise_ = body(TEXT, '/obj/item/proc/arcane_bless_raise(')
        self.assertIn('1 + 0.05 * tier', raise_)
        self.assertIn('base[key] + 3 * tier', raise_)
        self.assertIn('ARCANE_ARMOR_CAP', raise_)
        self.assertIn('#define ARCANE_ARMOR_CAP 90', TEXT)
        self.assertIn('1 + 0.2 * tier', raise_)
        self.assertIn('1 + 0.08 *', body(TEXT, '/proc/arcane_bless_speed('))

    def test_never_adds_a_stat(self):
        stats = body(TEXT, '/proc/arcane_bless_stats(')
        self.assertIn('I.force > 0', stats)
        self.assertIn('I.armor[key] > 0', stats)
        self.assertIn('base[key] > 0', body(TEXT, '/obj/item/proc/arcane_bless_raise('))

    def test_altar_standing_caps_the_tier(self):
        problem = body(TEXT, '/mob/living/human/proc/arcane_bless_problem(')
        self.assertIn('arcane_bless_ceiling(altar)', problem)
        self.assertIn('arcane_bless_sacrifice(I, stat)', problem)

    def test_god_approves_before_sacrifice(self):
        self.assertIn('return arcane_bless_problem(arcane_bless_pick)', body(COVENANT, '/mob/living/human/proc/divine_problem('))
        dispatch = body(COVENANT, '/proc/divine_dispatch(')
        self.assertLess(dispatch.index('R.consume('), dispatch.index('caster.arcane_bless_apply(R.target)'))
        apply = body(TEXT, '/mob/living/human/proc/arcane_bless_apply(')
        self.assertIn('qdel(S)', apply)
        self.assertIn('arcane_altar_worship(src)', apply)
        self.assertIn('log_admin(', apply)
        self.assertNotIn('ward_refill', TEXT)  # a sacrifice never also refills a repository

    def test_hooks(self):
        self.assertIn('arcane_bless_speed(tool)', body(read('code/modules/materials/work_speed.dm'), '/proc/work_delay('))
        self.assertIn('arcane_bless_examine(H)', read('code/modules/divine/arcane_materials.dm'))
        enchant = read('code/modules/divine/arcane_enchant.dm')
        self.assertIn('"unbless"', enchant)
        self.assertIn('I.arcane_bless_end()', enchant)

    def test_defines_are_file_local(self):
        for line in TEXT.splitlines():
            if line.startswith('#define '):
                self.assertIn('#undef ' + line.split()[1], TEXT)


if __name__ == '__main__':
    unittest.main()
