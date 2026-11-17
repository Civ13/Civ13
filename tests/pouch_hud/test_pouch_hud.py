"""Offline projection of HUD inventory visibility; no BYOND client or game."""
from pathlib import Path
import importlib.util
from types import MethodType
import re
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
HUD = (ROOT / 'code/_onclick/hud/base_screen_objects.dm').read_text(encoding='utf8')
ICONS = (ROOT / 'code/game/mob/living/carbon/human/update_icons.dm').read_text(encoding='utf8')
MOB_INV = (ROOT / 'code/game/mob/inventory.dm').read_text(encoding='utf8')
HUMAN_INV = (ROOT / 'code/game/mob/living/carbon/human/inventory.dm').read_text(encoding='utf8')
ITEMS = (ROOT / 'code/game/objects/items.dm').read_text(encoding='utf8')
APPAREL = (ROOT / 'code/modules/1713/apparel_imperial.dm').read_text(encoding='utf8')
SKIN = (ROOT / 'interface/skin.dmf').read_text(encoding='utf8')

spec = importlib.util.spec_from_file_location('pouch_source_adapter', ROOT / 'tests/save_movement/source_adapter.py')
A = importlib.util.module_from_spec(spec)
spec.loader.exec_module(A)
A.FIELDS += ('parentmob', 'HUDinventory', 'HUDfrippery', 'hidden_inventory_update')


def body(source, declaration):
    match = re.search(r'^' + re.escape(declaration) + r'\([^\n]*\)[ \t]*(?://[^\n]*)?\n', source, re.M)
    if not match:
        raise AssertionError('missing procedure ' + declaration)
    tail = source[match.end():]
    end = re.search(r'^/(?![/*])', tail, re.M)
    return tail[:end.start()] if end else tail


def inventory_cases(source):
    """Parse every arm of the actual DM switch and fail on unexpected syntax."""
    proc = body(source, '/obj/screen/toggle_inventory/proc/hidden_inventory_update')
    case = re.compile(r'^\t\tif \((slot_\w+)\)\n'
                      r'\t\t\tif \(H\.(\w+)\)\s+H\.(\w+)\.screen_loc\s*=\s*'
                      r'\(inv_elem\.invisibility == 101\)\s*\?\s*null\s*:\s*inv_elem\.screen_loc\s*$', re.M)
    rows = case.findall(proc)
    declared = re.findall(r'^\t\tif \((slot_\w+)\)', proc, re.M)
    if len(rows) != len(declared) or any(a != b for _, a, b in rows):
        raise AssertionError('unsupported inventory visibility branch')
    return {slot: field for slot, field, _ in rows}


def update_from_source(source, slot, human, inventory_slot):
    field = inventory_cases(source).get(slot)
    item = getattr(human, field, None) if field else None
    if item:
        item.screen_loc = None if inventory_slot.invisibility == 101 else inventory_slot.screen_loc


def toggle_methods(human, source=HUD):
    """Execute the actual hide/show control flow against inert screen adapters."""
    toggle = SimpleNamespace(parentmob=human)
    toggle.hidden_inventory_update = lambda slot: update_from_source(source, slot.slot_id, human, slot)
    env = {'typed_iter': lambda values, kind: values, 'TOGGLE_INVENTORY_FLAG': 1}
    for name in ('hideobjects', 'showobjects'):
        projected = A.project(source, '/obj/screen/toggle_inventory/proc/' + name,
                              'src', env, method=True)
        setattr(toggle, name, MethodType(projected, toggle))
    return toggle


def hidden_id_case(source):
    return re.sub(r'^\t\tif \(slot_wear_id\)\n\t\t\tif \(H\.wear_id\)[^\n]*\n', '', source, count=1, flags=re.M)


class PouchVisibility(unittest.TestCase):
    def test_hidden_equip_then_show_recovers_same_pouch(self):
        slot = SimpleNamespace(invisibility=101, screen_loc='pouch-slot')
        pouch = SimpleNamespace(screen_loc=None)
        human = SimpleNamespace(wear_id=pouch, contents=[pouch])
        slot.invisibility = 0
        update_from_source(HUD, 'slot_wear_id', human, slot)
        self.assertEqual(pouch.screen_loc, 'pouch-slot')
        self.assertIs(human.wear_id, pouch)
        self.assertEqual(human.contents, [pouch])

    def test_actual_hide_show_loops_restore_pouch_without_touching_hand(self):
        slot = SimpleNamespace(slot_id='slot_wear_id', invisibility=0,
                               screen_loc='pouch-slot', hideflag=1)
        pouch = SimpleNamespace(screen_loc='hand-slot')
        hand_item = SimpleNamespace(screen_loc='other-hand')
        human = SimpleNamespace(wear_id=None, r_hand=hand_item,
                                HUDinventory=[slot], HUDfrippery=[])
        toggle = toggle_methods(human)
        toggle.hideobjects()
        self.assertEqual(slot.invisibility, 101)
        # Equipment admission and assignment are engine boundaries; bind their
        # actual source path below and model the resulting hidden slot position.
        human.wear_id = pouch
        pouch.screen_loc = None if slot.invisibility == 101 else slot.screen_loc
        toggle.showobjects()
        self.assertEqual(pouch.screen_loc, 'pouch-slot')
        self.assertEqual(hand_item.screen_loc, 'other-hand')
        toggle.hideobjects()
        self.assertIsNone(pouch.screen_loc)
        toggle.showobjects()
        self.assertEqual(pouch.screen_loc, 'pouch-slot')

    def test_existing_item_tracks_hide_show_and_repeated_toggles(self):
        slot = SimpleNamespace(invisibility=101, screen_loc='pouch-slot')
        pouch = SimpleNamespace(screen_loc='pouch-slot')
        human = SimpleNamespace(wear_id=pouch)
        for visibility, expected in ((101, None), (0, 'pouch-slot'), (101, None), (0, 'pouch-slot')):
            slot.invisibility = visibility
            update_from_source(HUD, 'slot_wear_id', human, slot)
            self.assertEqual(pouch.screen_loc, expected)
            self.assertIs(human.wear_id, pouch)

    def test_no_pouch_and_other_item_are_unchanged(self):
        other = SimpleNamespace(screen_loc='hand-slot')
        human = SimpleNamespace(wear_id=None, r_hand=other)
        update_from_source(HUD, 'slot_wear_id', human, SimpleNamespace(invisibility=0, screen_loc='pouch-slot'))
        self.assertIsNone(human.wear_id)
        self.assertEqual(other.screen_loc, 'hand-slot')

    def test_old_missing_case_reproduces_both_visibility_errors(self):
        old = hidden_id_case(HUD)
        self.assertNotIn('slot_wear_id', inventory_cases(old))
        pouch = SimpleNamespace(screen_loc=None)
        slot = SimpleNamespace(invisibility=0, screen_loc='pouch-slot')
        human = SimpleNamespace(wear_id=pouch)
        update_from_source(old, 'slot_wear_id', human, slot)
        self.assertIsNone(pouch.screen_loc)
        pouch.screen_loc = 'pouch-slot'; slot.invisibility = 101
        update_from_source(old, 'slot_wear_id', human, slot)
        self.assertEqual(pouch.screen_loc, 'pouch-slot')

    def test_offline_registration_does_not_admit_other_native_tests(self):
        import importlib.util
        from unittest.mock import patch
        spec = importlib.util.spec_from_file_location('pouch_selector', ROOT / 'scripts/select-ci.py')
        selector = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(selector)
        only = b'tests/pouch_hud/test_pouch_hud.py\0'
        with patch.object(selector.subprocess, 'check_output', return_value=only):
            self.assertEqual(selector.introduced_tests('a'*40, 'b'*40, 'pull_request'), [])
        with patch.object(selector.subprocess, 'check_output', return_value=only+b'tests/pouch_hud/test_native.py\0'):
            self.assertEqual(selector.introduced_tests('a'*40, 'b'*40, 'pull_request'), ['tests/pouch_hud'])
        ci = (ROOT / 'scripts/ci_baseline.py').read_text(encoding='utf8')
        self.assertIn("'pouch_hud': {'files': ('tests/pouch_hud/test_pouch_hud.py',)", ci)

    def test_production_route_and_default_style_are_source_bound(self):
        self.assertRegex(SKIN, r'name = "E"\s*\n\s*command = "quick-equip"')
        self.assertIn('equip_to_appropriate_slot(I)', body(HUMAN_INV, '/mob/living/human/verb/quick_equip'))
        priorities = MOB_INV.split('var/list/slot_equipment_priority = list(', 1)[1].split(')', 1)[0]
        self.assertLess(priorities.index('slot_wear_id'), priorities.index('slot_belt'))
        pouch = APPAREL.split('/obj/item/clothing/accessory/storage/coinpouch\n', 1)[1].split('\n/obj/', 1)[0]
        self.assertIn('slot_flags = SLOT_ID | SLOT_BELT | SLOT_POCKET', pouch)
        self.assertIn('wear_id.screen_loc = find_inv_position(slot_wear_id)', body(ICONS, '/mob/living/human/update_inv_wear_id'))
        self.assertIn('(HUDinv.invisibility == 101) ? null : HUDinv.screen_loc', body(ICONS, '/mob/living/human/proc/find_inv_position'))
        style = (ROOT / 'code/_onclick/hud/hud_civstyle.dm').read_text(encoding='utf8')
        self.assertRegex(style, r'"id"\s*=\s*list\([^\n]*"hideflag"\s*=\s*TOGGLE_INVENTORY_FLAG')
        gear = (ROOT / 'code/game/mob/living/carbon/human/species/species_hud.dm').read_text(encoding='utf8')
        self.assertRegex(gear, r'"id"\s*=\s*slot_wear_id')
        self.assertIn('if (!H.w_uniform', body(ITEMS, '/obj/item/proc/mob_can_equip'))


    def test_belt_stays_on_without_clothes_and_dead_slots_are_gone(self):
        unequip = body(HUMAN_INV, '/mob/living/human/u_equip')
        uniform = unequip.split('else if (W == w_uniform)', 1)[1].split('else if', 1)[0]
        self.assertIn('drop_from_inventory(wear_id)', uniform)
        self.assertIn('drop_from_inventory(l_store)', uniform)
        self.assertNotIn('belt', uniform.replace('// The belt is buckled', ''))
        # A belt never needed clothes to put on, so it must not need them to stay on.
        equip_rules = body(ITEMS, '/obj/item/proc/mob_can_equip')
        self.assertNotIn('if (slot_belt)', equip_rules)
        defines = (ROOT / 'code/predefines.dm').read_text(encoding='utf8')
        for dead in ('slot_s_store', 'slot_legs', 'slot_l_arm', 'slot_r_arm'):
            self.assertNotIn('#define ' + dead, defines)
        # Slot numbers are saved in HUD layouts, so the live ones keep their values.
        self.assertRegex(defines, r'#define slot_shoulder\s+22\b')
        self.assertRegex(defines, r'#define slot_accessory\s+25\b')
        equip = body(HUMAN_INV, '/mob/living/human/equip_to_slot')
        self.assertEqual(equip.count('if (slot_shoulder)'), 1)
        self.assertEqual(ITEMS.count('"[slot_shoulder]" = SLOT_SHOULDER'), 1)

    def test_attachment_strip_is_wired_to_worn_clothing(self):
        acc = (ROOT / 'code/game/objects/items/clothing/clothing_accessories.dm').read_text(encoding='utf8')
        strip = (ROOT / 'code/_onclick/hud/attachment_strip.dm').read_text(encoding='utf8')
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf8')
        self.assertIn('#include "code\\_onclick\\hud\\attachment_strip.dm"', dme)
        hand = body(acc, '/obj/item/clothing/attack_hand')
        # One attachment keeps opening directly; several open the strip, and only for a real client.
        self.assertIn('accessories.len > 1 && ishuman(user) && user.client', hand)
        self.assertLess(hand.index('toggle_attachment_strip(src)'), hand.index('A.attack_hand(user)'))
        offer = body(acc, '/obj/item/clothing/attackby')
        loop = offer.split('for (var/obj/item/clothing/accessory/A in accessories)', 1)[1].split('return', 1)[0]
        self.assertIn('A.attackby(I, user)', loop)
        self.assertIn('if (QDELETED(I) || I.loc != user)\n\t\t\t\tbreak', loop)
        self.assertIn('refresh_attachment_strip(src)', body(acc, '/obj/item/clothing/proc/remove_accessory'))
        usable = body(strip, '/obj/screen/attachment/proc/usable_attachment')
        self.assertIn('attachment_strip_valid(attachment, host, H)', usable)
        click = body(strip, '/obj/screen/attachment/Click')
        self.assertLess(click.index('usable_attachment(usr)'), click.index('attachment_strip_use(H, A, C)'))
        # Shift-click examines a tile's attachment instead of using it.
        self.assertLess(click.index('modifiers["shift"]'), click.index('attachment_strip_use(H, A, C)'))
        self.assertIn('attachment_strip_examine(H, A)', click)
        # Drag to a hand or the floor, and the right-click menu, take it off.
        drop = body(strip, '/obj/screen/attachment/MouseDrop')
        self.assertIn('usable_attachment(usr)', drop)
        self.assertIn('attachment_strip_take_off(H, A, C, hand_tile.slot_id)', drop)
        self.assertIn('attachment_strip_set_down(H, A, C, T)', drop)
        for verb in ('examine_attachment', 'take_off_attachment'):
            text = body(strip, '/obj/screen/attachment/verb/' + verb)
            self.assertIn('set src in usr.client.screen', text)
            self.assertIn('usable_attachment(usr)', text)
        # The first strip a client opens says how to examine and take things off.
        self.assertIn('attachment_strip_hint_shown', body(strip, '/mob/living/human/proc/show_attachment_strip'))
        use = body(strip, '/proc/attachment_strip_use')
        self.assertIn('A.attackby(I, H)', use)
        self.assertIn('A.attack_hand(H)', use)
        # Plain accessories (necklaces) come off from an empty-hand click; storage opens.
        self.assertLess(use.index('A.strip_click_removes'), use.index('C.remove_accessory(H, A)'))
        # The hover tooltip names the drawn accessory only while the tile still shows it.
        hover = body(strip, '/obj/screen/attachment/hover_item')
        self.assertIn('(src in C.attachment_strip)', hover)
        self.assertIn('attachment_strip_valid(attachment, host, viewer)', hover)
        # The tiles live on the client, so nothing about them is saved with the body.
        self.assertIn('/client/var/list/attachment_strip', strip)
        self.assertNotIn('/mob/living/human/var', strip)

    def test_hip_slot_is_named_drawn_and_takes_belt_pouches(self):
        for style in ('civ', 'fof', 'liteweb', 'new'):
            text = (ROOT / f'code/_onclick/hud/hud_{style}style.dm').read_text(encoding='utf8')
            self.assertRegex(text, r'"id" =\s+list\("loc" = [^\n]*"name" = "Hip",[^\n]*"state" = "id"')
        pouches = (ROOT / 'code/modules/1713/belt_pouches.dm').read_text(encoding='utf8')
        pouch = pouches.split('/obj/item/clothing/accessory/storage/belt_pouch\n', 1)[1].split('\n/obj/', 1)[0]
        self.assertIn('slot_flags = SLOT_BELT | SLOT_POCKET | SLOT_ID', pouch)
        # A pouch has no held state, so the hip slot draws it by its icon state.
        self.assertIn('wear_id.item_state ? wear_id.item_state : wear_id.icon_state', body(ICONS, '/mob/living/human/update_inv_wear_id'))
        worn = (ROOT / 'code/game/mob/living/carbon/human/worn_storage.dm').read_text(encoding='utf8')
        self.assertIn('items = list(belt, wear_id)', worn)
        self.assertIn('items = list(back, belt, wear_id, w_uniform, wear_suit, l_store, r_store)', worn)
        # The slot tile art is owned by its script; the committed sheets must match it.
        spec = importlib.util.spec_from_file_location('create_hip_slot', ROOT / 'tests/sprites/create_hip_slot.py')
        hip = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(hip)
        self.assertEqual(hip.main(['--check']), 0)

if __name__ == '__main__':
    unittest.main()