"""Equipped items must sit on their HUD slot, never mid-screen, after a HUD rebuild."""
from pathlib import Path
import re
import sys
from types import SimpleNamespace as NS
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'tests/save_movement'))
from source_adapter import extract, project

HUD = 'code/game/mob/living/carbon/human/human_hud.dm'
ICONS = 'code/game/mob/living/carbon/human/update_icons.dm'
SLOT_HEAD, SLOT_SHOES = 'slot_head', 'slot_shoes'


def source(path):
    return re.sub(r'/\*.*?\*/', '', (ROOT/path).read_text(encoding='utf-8-sig'), flags=re.S)


def proc(path, declaration, args, env, prefix=''):
    body = extract(source(path), declaration)
    return project(declaration+'('+args+')\n'+body+'\n', declaration, args, env)


class InventoryScreenLoc(unittest.TestCase):
    def mob(self, slots):
        mob = NS()
        mob.HUDinventory = slots
        mob.equipped = {}
        env = dict(HUDinventory=slots, src=mob, typed_iter=lambda values, kind: values,
                   get_equipped_item=lambda slot: mob.equipped.get(slot))
        return mob, env

    def test_missing_hud_slot_has_no_screen_position(self):
        find = extract(source(ICONS), '/mob/living/human/proc/find_inv_position')
        returns = re.findall(r'^\treturn (.+)$', find, re.M)
        # A placeholder position such as "7,7" drew the hat mid-screen.
        self.assertEqual(returns, ['null'])
        self.assertNotRegex(find, r'"\d+,\d+"')

    def test_rebuilt_hud_realigns_items_drawn_without_one(self):
        head = NS(slot_id=SLOT_HEAD, invisibility=0, screen_loc='WEST+1:8,4:11')
        shoes = NS(slot_id=SLOT_SHOES, invisibility=101, screen_loc='WEST:6,1:5')
        mob, env = self.mob([head, shoes])
        hat, boots = NS(screen_loc='7,7', loc=mob), NS(screen_loc='7,7', loc=mob)
        mob.equipped = {SLOT_HEAD: hat, SLOT_SHOES: boots}
        sync = proc(HUD, '/mob/living/human/proc/sync_inventory_screen_locs', '', env)
        sync()
        self.assertEqual(hat.screen_loc, 'WEST+1:8,4:11')
        self.assertIsNone(boots.screen_loc)

    def test_update_hud_syncs_before_showing_contents(self):
        hud = extract(source(HUD), '/mob/living/human/update_hud')
        self.assertLess(hud.index('check_HUD()'), hud.index('sync_inventory_screen_locs()'))
        self.assertLess(hud.index('sync_inventory_screen_locs()'), hud.index('client.screen |= contents'))


if __name__ == '__main__': unittest.main()
