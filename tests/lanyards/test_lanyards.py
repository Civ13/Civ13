"""Offline checks for lanyards and wrist loops (code/modules/1713/lanyards.dm)."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/lanyards.dm'
OBJ_STATES = ('wrist_thong', 'sword_knot', 'neck_cord', 'fob_chain', 'pistol_lanyard', 'retention_lanyard')
WORN_STATES = ('neck_cord', 'fob_chain', 'pistol_lanyard', 'retention_lanyard')
RESEARCH = {
    '/obj/item/wrist_loop': 'basic_tools',
    '/obj/item/wrist_loop/sword_knot': 'steel_blades',
    '/obj/item/clothing/accessory/storage/lanyard': 'weaving',
    '/obj/item/clothing/accessory/storage/lanyard/fob_chain': 'optics_instruments',
    '/obj/item/clothing/accessory/storage/lanyard/pistol': 'cartridge_ammo',
    '/obj/item/clothing/accessory/storage/lanyard/retention': 'synthetics',
}


def dmi_description(path):
    from PIL import Image
    return Image.open(path).info['Description']


class LanyardTest(unittest.TestCase):
    def setUp(self):
        self.text = SOURCE.read_text(encoding='utf-8')

    def test_sprites_exist(self):
        obj = dmi_description(ROOT / 'icons/obj/lanyards.dmi')
        worn = dmi_description(ROOT / 'icons/mob/lanyards.dmi')
        for state in OBJ_STATES:
            self.assertIn(f'state = "{state}"', obj)
            self.assertIn(f'icon_state = "{state}"', self.text)
        for state in WORN_STATES:
            self.assertRegex(worn, rf'state = "{state}"\n\tdirs = 4')

    def test_recipes_and_research(self):
        recipes = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
        nodes = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
        for path, node in RESEARCH.items():
            self.assertRegex(recipes, rf',{re.escape(path)},1,')
            self.assertIn(f'"{path}" = "{node}",', nodes)

    def test_historical_fit(self):
        # Flintlock pistols had no butt ring; long guns, bows and spears use slings.
        self.assertNotIn('/obj/item/weapon/gun/projectile/flintlock', self.text)
        for banned in ('/gun/projectile/boltaction', '/weapon/bow', '/material/spear'):
            self.assertNotIn(banned, self.text)
        self.assertIn('never_fits = list(/obj/item/weapon/material/twohanded)', self.text)
        self.assertIn('never_fits = list(/obj/item/weapon/material/sword/tes13/twohanded)', self.text)

    def test_tethered_items_are_caught_not_thrown(self):
        self.assertIn('/mob/living/human/throw_item(atom/target)', self.text)
        self.assertIn('addtimer(CALLBACK(src, PROC_REF(tether_catch), user), 1)', self.text)
        self.assertNotIn('spawn', self.text)
        # Dead holders and items handed to someone else are released.
        self.assertIn('H.stat == DEAD', self.text)
        # No object pointers are kept, so saves stay pointer-free.
        self.assertNotRegex(self.text, r'var/obj/item/[a-z_/]*tethered')

    def test_wrist_catch_admission_and_postconditions(self):
        catch = self.text.split('/obj/item/proc/tether_catch(', 1)[1].split('/obj/item/on_enter_storage(', 1)[0]
        attempt = catch.index('H.put_in_active_hand(src)')
        self.assertLess(catch.index('!H.restrained()'), attempt)
        self.assertLess(catch.index('wrist_looped = FALSE', catch.index('!H.restrained()')), attempt)
        self.assertLess(catch.index('lanyard_tied = FALSE', catch.index('!H.restrained()')), attempt)
        self.assertLess(attempt, catch.index('loc == H && H.item_is_in_hands(src)'))
        self.assertLess(catch.index('loc == H && H.item_is_in_hands(src)'), catch.index('wrist_looped = TRUE'))

    def test_storage_exit_releases_and_only_draw_routes_restore(self):
        items = (ROOT / 'code/game/objects/items.dm').read_text(encoding='utf-8')
        exit_hook = items.split('/obj/item/proc/on_exit_storage(', 1)[1].split('/obj/item/proc/', 1)[0]
        self.assertIn('lanyard_tied = FALSE', exit_hook)
        draw = self.text.split('/obj/item/proc/restore_lanyard_draw(', 1)[1].split('/mob/living/human/proc/lanyard_for', 1)[0]
        for guard in ('loc != H', '!H.item_is_in_hands(src)', 'L.hold != S', 'C.loc == H',
                      'C == H.w_uniform || C == H.wear_suit || C == H.belt', 'L.loc == C', 'L in C.accessories'):
            self.assertLess(draw.index(guard), draw.index('lanyard_tied = TRUE'))
        click = items.split('/obj/item/attack_hand(', 1)[1].split('/obj/item/attackby(', 1)[0]
        self.assertEqual(click.count('restore_lanyard_draw(drawn_from, holder)'), 2)
        drag = (ROOT / 'code/_onclick/inventory_drag.dm').read_text(encoding='utf-8')
        self.assertRegex(drag, r'if \(inventory_drag_put_in_hand\(slot, user\)\)\n\s+restore_lanyard_draw\(origin, user\)')
        modern = (ROOT / 'code/modules/storage_window/storage_window.dm').read_text(encoding='utf-8')
        self.assertEqual(modern.count('I.restore_lanyard_draw(source, H)'), 2)

    def test_belt_takes_belt_lanyards(self):
        belt = (ROOT / 'code/modules/1713/belt_pouches.dm').read_text(encoding='utf-8')
        self.assertIn('/obj/item/clothing/accessory/storage/lanyard/fob_chain', belt)
        self.assertIn('/obj/item/clothing/accessory/storage/lanyard/retention', belt)

    def test_included_after_belt_pouches(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertLess(dme.index('belt_pouches.dm'), dme.index('lanyards.dm'))


if __name__ == '__main__':
    unittest.main()
