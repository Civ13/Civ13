"""Offline source contracts for inventory drag-and-drop transfers; no BYOND runtime."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf8').replace('\r\n', '\n')


DME = read('civ13.dme')
DRAG = read('code/_onclick/inventory_drag.dm')
STORAGE = read('code/game/objects/items/weapons/storage/storage.dm')
INTERNAL = read('code/game/objects/items/weapons/storage/internal.dm')
CLOTHING = read('code/game/objects/items/clothing/clothing_accessories.dm')
KEYCHAIN = read('code/game/objects/structures/key_doors/keychain.dm')
MAIL = read('code/game/objects/structures/mail.dm')


def proc_body(source, header):
    """Return the tab-indented body that follows a top-level proc definition."""
    start = source.index(header + '(')
    body = []
    for line in source[start:].splitlines()[1:]:
        if line and not line.startswith('\t'):
            break
        body.append(line)
    return '\n'.join(body)


class InventoryDragTests(unittest.TestCase):
    def test_file_is_compiled_after_drag_drop(self):
        include = '#include "code\\_onclick\\inventory_drag.dm"'
        self.assertIn(include, DME)
        self.assertLess(DME.index('#include "code\\_onclick\\drag_drop.dm"'), DME.index(include))

    def test_item_drop_tries_transfer_before_default(self):
        body = proc_body(DRAG, '/obj/item/MouseDrop')
        self.assertLess(body.index('inventory_drag_transfer(over_object, usr)'), body.index('return ..()'))

    def test_transfer_requires_reach_and_shown_storage(self):
        body = proc_body(DRAG, '/obj/item/proc/inventory_drag_transfer')
        for guard in ('!ishuman(user)', 'H.incapacitated()', 'H.restrained()', 'extraction_surface_source',
                      '!inventory_drag_in_reach(src, H)', 'H.s_active != loc', 'slot.parentmob != H'):
            self.assertIn(guard, body)
        self.assertLess(body.index('inventory_drag_in_reach(src, H)'), body.index('istype(over, /obj/screen/inventory)'))

    def test_destinations_cover_hands_slots_and_storage(self):
        body = proc_body(DRAG, '/obj/item/proc/inventory_drag_transfer')
        self.assertIn('inventory_drag_to_hand(slot.slot_id, H)', body)
        self.assertIn('inventory_drag_to_slot(slot.slot_id, H)', body)
        self.assertIn('inventory_drag_to_storage(S, H)', body)
        target = proc_body(DRAG, '/obj/item/proc/inventory_drag_target_storage')
        for kind in ('/obj/screen/storage', '/obj/item/weapon/storage', 'user.s_active == over.loc'):
            self.assertIn(kind, target)

    def test_storage_insertion_keeps_storage_rules(self):
        body = proc_body(DRAG, '/obj/item/proc/inventory_drag_to_storage')
        order = ['inventory_drag_contains(src, S)', 'inventory_drag_in_reach(S, user)',
                 'S.accepts_inventory_drag(src, user)', 'S.can_be_inserted(src)', 'S.handle_item_insertion(src)']
        positions = [body.index(text) for text in order]
        self.assertEqual(positions, sorted(positions))
        # Leaving the source storage goes through remove_from_storage so its window updates.
        self.assertIn('from.remove_from_storage(src)', proc_body(DRAG, '/obj/item/proc/inventory_drag_take_out'))

    def test_hand_and_slot_moves_respect_equip_rules(self):
        hand = proc_body(DRAG, '/obj/item/proc/inventory_drag_to_hand')
        for guard in ('if (held)', 'user.lying', 'inventory_drag_hand_usable(slot, user)',
                      'user.canUnEquip(src)', 'inventory_drag_pickup_delay(user)', 'inventory_drag_put_back(origin)'):
            self.assertIn(guard, hand)
        slot = proc_body(DRAG, '/obj/item/proc/inventory_drag_to_slot')
        self.assertLess(slot.index('mob_can_equip(user, slot)'), slot.index('inventory_drag_take_out(user)'))
        self.assertIn('user.equip_to_slot_if_possible(src, slot)', slot)
        self.assertIn('inventory_drag_put_back(origin)', slot)
        delay = proc_body(DRAG, '/obj/item/proc/inventory_drag_pickup_delay')
        self.assertIn('do_after(user, equiptimer, src', delay)

    def test_storage_drop_reaches_transfer_before_worn_only_return(self):
        body = proc_body(STORAGE, '/obj/item/weapon/storage/MouseDrop')
        transfer = body.index('inventory_drag_transfer(over_object, usr)')
        self.assertLess(body.index('open(usr)'), transfer)
        self.assertLess(transfer, body.index('if (!(loc == usr) || (loc && loc.loc == usr))'))

    def test_clothing_drop_reaches_transfer_before_worn_only_return(self):
        body = proc_body(CLOTHING, '/obj/item/clothing/MouseDrop')
        self.assertLess(body.index('inventory_drag_transfer(over_object, usr)'), body.index('if (!(loc == usr))'))

    def test_internal_storage_hands_non_hand_drops_to_parent(self):
        body = proc_body(INTERNAL, '/obj/item/weapon/storage/internal/proc/handle_mousedrop')
        relay = body.index('if (!istype(over_object, /obj/screen/inventory/hand) || master_item.loc != user)')
        self.assertEqual(body[relay:].split('\n')[1].strip(), 'return TRUE')
        self.assertLess(relay, body.index('if (!(master_item.loc == user)'))

    def test_special_storages_opt_out_of_drag_insertion(self):
        self.assertEqual(proc_body(KEYCHAIN, '/obj/item/weapon/storage/belt/keychain/accepts_inventory_drag').strip(), 'return FALSE')
        self.assertEqual(proc_body(MAIL, '/obj/item/weapon/storage/envelope/accepts_inventory_drag').strip(), 'return opened')
        self.assertEqual(proc_body(DRAG, '/obj/item/weapon/storage/proc/accepts_inventory_drag').strip(), 'return TRUE')


if __name__ == '__main__':
    unittest.main()
