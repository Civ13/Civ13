"""Worn glasses must add their flash protection and tint (issue 5474).

Offline source check; does not execute BYOND. It walks the slot branches of
update_equipment_vision() and totals what each worn item contributes.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
HELPERS = ROOT / 'code/game/mob/living/carbon/human/human_helpers.dm'
GLASSES = ROOT / 'code/game/objects/items/clothing/glasses/glasses.dm'
PROTECTION = {'FLASH_PROTECTION_NONE': 0, 'FLASH_PROTECTION_MODERATE': 1, 'FLASH_PROTECTION_MAJOR': 2}


def proc_body(text, header):
    start = text.index(header + '\n') + len(header) + 1
    end = re.compile(r'^\S', re.M).search(text, start)
    return text[start:end.start() if end else len(text)]


def slot_branches(body):
    """Map each slot var to the proc lines run under its istype() branch."""
    branches, slot = {}, None
    for line in body.splitlines():
        match = re.match(r'\tif \(istype\((\w+),', line)
        if match:
            slot = match.group(1)
            branches[slot] = []
        elif slot and line.startswith('\t\t'):
            branches[slot].append(line.split('//', 1)[0].strip())
        elif line.strip():
            slot = None
    return branches


def adds_protection(lines, slot):
    names = {slot}
    for line in lines:
        alias = re.match(r'var/[\w/]+/(\w+) = (\w+)$', line)
        if alias and alias.group(2) in names:
            names.add(alias.group(1))
        call = re.match(r'add_clothing_protection\((\w+)\)$', line)
        if call and call.group(1) in names:
            return True
    return False


def declared_protection(text, path):
    block = text[text.index(path + '\n'):]
    block = block[:re.compile(r'^\S', re.M).search(block, len(path) + 1).start()]
    found = re.search(r'flash_protection = (\w+)', block)
    return PROTECTION[found.group(1)] if found else 0


def worn_total(branches, worn):
    return sum(item for slot, item in worn.items() if adds_protection(branches.get(slot, []), slot))


class GlassesFlashProtection(unittest.TestCase):
    def setUp(self):
        body = proc_body(HELPERS.read_text(encoding='utf-8'), '/mob/living/human/proc/update_equipment_vision()')
        self.assertIn('flash_protection = FALSE', body)
        self.branches = slot_branches(body)
        self.glasses = GLASSES.read_text(encoding='utf-8')

    def test_every_vision_slot_adds_its_protection(self):
        self.assertEqual(set(self.branches), {'head', 'eyes', 'wear_mask'})
        for slot, lines in self.branches.items():
            self.assertTrue(adds_protection(lines, slot), slot)

    def test_sunglasses_alone_protect_the_wearer(self):
        for path, level in (('/obj/item/clothing/glasses/sunglasses', 1),
                            ('/obj/item/clothing/glasses/sunglasses/large', 2)):
            item = declared_protection(self.glasses, path)
            self.assertEqual(item, level, path)
            self.assertEqual(worn_total(self.branches, {'eyes': item}), level, path)
            self.assertEqual(worn_total(self.branches, {'eyes': item, 'head': 1}), level + 1, path)

    def test_switched_off_optics_clear_their_own_protection(self):
        toggle = proc_body(self.glasses, '/obj/item/clothing/glasses/attack_self(mob/living/human/user)')
        self.assertEqual(toggle.count('flash_protection = FLASH_PROTECTION_NONE'), 2)
        self.assertEqual(toggle.count('tint = TINT_NONE'), 2)
        self.assertEqual(toggle.count('flash_protection = initial(flash_protection)'), 1)

    def test_check_catches_the_missing_glasses_branch(self):
        broken = [line for line in self.branches['eyes'] if not line.startswith('add_clothing_protection')]
        self.assertFalse(adds_protection(broken, 'eyes'))


if __name__ == '__main__':
    unittest.main()
