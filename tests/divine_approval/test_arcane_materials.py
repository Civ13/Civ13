"""Offline source contract for magic materials (hidden virtue on ordinary items); does not execute DM."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(rel):
    return (ROOT / rel).read_text(encoding='utf-8')


TEXT = read('code/modules/divine/arcane_materials.dm')


def body(text, header):
    return text.split(header, 1)[1].split('\n/', 1)[0]


class ArcaneMaterialsSource(unittest.TestCase):
    def test_included(self):
        self.assertIn('#include "code\\modules\\divine\\arcane_materials.dm"', read('civ13.dme'))

    def test_virtue_is_plain_saved_fields_on_items(self):
        decl = body(TEXT, '\n/obj/item\n')
        for var in ('arcane_aspect', 'arcane_strength', 'arcane_gathered_at', 'arcane_gatherer'):
            self.assertIn('var/' + var, decl)
            self.assertNotIn('tmp/' + var, decl)

    def test_virtue_fades(self):
        virtue = body(TEXT, '/obj/item/proc/arcane_virtue()')
        self.assertIn('ARCANE_FADE', virtue)
        self.assertIn('arcane_clear()', virtue)
        self.assertIn('#define ARCANE_FADE 12096000', TEXT)

    def test_attune_is_gated(self):
        attune = body(TEXT, '/mob/living/human/proc/arcane_attune(')
        for gate in ('arcane_magic_user()', 'verified_discord_id(ckey)', 'arcane_knows(aspect)', 'arcane_gather_ready()', 'persistence_save_in_progress'):
            self.assertIn(gate, attune)
        self.assertIn('log_admin(', attune)
        self.assertIn('magic_allowed()', body(TEXT, '/mob/living/human/proc/arcane_magic_user()'))

    def test_only_magic_users_see_it(self):
        examine = body(TEXT, '/obj/item/proc/arcane_examine(')
        self.assertIn('arcane_magic_user()', examine)
        items = read('code/game/objects/items.dm')
        self.assertIn('arcane_examine(user)', items)

    def test_stacks_keep_virtues_apart(self):
        self.assertIn('return arcane_same_virtue(src, S)', body(read('code/modules/1713/coin_mint.dm'), '/obj/item/stack/proc/stack_compatible('))
        self.assertIn('arcane_copy_virtue(src, S)', body(read('code/game/objects/items/stacks/stack.dm'), '/obj/item/stack/proc/split('))

    def test_rest_resets_gathering(self):
        self.assertIn('arcane_rested()', body(read('code/modules/divine/covenant.dm'), '/mob/living/human/proc/divine_rested()'))

    def test_gathering_hooks(self):
        self.assertIn('arcane_note_strike(x, y)', body(read('code/modules/1713/weather_lightning.dm'), '/proc/weather_lightning(x, y)'))
        self.assertIn('H.arcane_felled_tree(fell_at)', read('code/game/objects/structures/wild.dm'))
        self.assertIn('drawer.arcane_drew_water(RG)', read('code/game/turfs/floor_attackby.dm'))
        felled = body(TEXT, '/mob/living/human/proc/arcane_felled_tree(')
        self.assertIn('arcane_storm_near(T)', felled)
        self.assertIn('split(planks)', felled)
        self.assertIn('"Early Morning"', body(TEXT, '/mob/living/human/proc/arcane_drew_water('))

    def test_defines_are_file_local(self):
        for line in TEXT.splitlines():
            if line.startswith('#define '):
                self.assertIn('#undef ' + line.split()[1], TEXT)

    def test_hidden_from_players(self):
        # Hidden mechanic: no wiki/changelog wording in the file's player text.
        self.assertNotIn('to_world(', TEXT)
        self.assertNotIn('visible_message(', TEXT)


if __name__ == '__main__':
    unittest.main()
