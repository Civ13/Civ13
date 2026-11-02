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


if __name__ == '__main__':
    unittest.main()