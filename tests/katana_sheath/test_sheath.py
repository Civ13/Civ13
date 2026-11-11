"""Source-projected prefilled sheath regression; does not run the BYOND engine."""
import importlib.util
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('source_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)
SHEATHS = ROOT / 'code/game/objects/items/clothing/under/accessories/sheaths.dm'
STORAGE = ROOT / 'code/game/objects/items/clothing/under/accessories/storage.dm'
JOBS = ROOT / 'code/modules/1713/jobs/japanese.dm'


def spawn_prefilled(source):
    body = adapter.extract(source, '/obj/item/clothing/accessory/storage/sheath/katana/full/New')
    lines = [line.strip() for line in body.splitlines() if line.strip()]
    if len(lines) != 2 or lines[0] != '..()':
        raise AssertionError('Unexpected full sheath constructor')
    match = re.fullmatch(r'new\s*/obj/item/weapon/material/sword/katana\((src|hold)\)', lines[1])
    if not match:
        raise AssertionError('Unexpected katana constructor')
    # Fake parent creates the internal hold; the item constructor inserts into its loc.
    sheath, hold = [], []
    {'src': sheath, 'hold': hold}[match[1]].append('katana')
    return sheath, hold


class KatanaSheathTest(unittest.TestCase):
    def test_full_sheath_places_katana_in_drawable_container(self):
        sheath_source = SHEATHS.read_text(encoding='utf-8-sig')
        storage_source = STORAGE.read_text(encoding='utf-8-sig')
        self.assertRegex(storage_source, r'hold\s*=\s*new\s*/obj/item/weapon/storage/internal\(src\)')
        self.assertRegex(sheath_source, r'for\s*\(var/obj/item/weapon/W in H\.hold\)')
        sheath, hold = spawn_prefilled(sheath_source)
        self.assertEqual(sheath, [])
        self.assertEqual(hold, ['katana'])

    def test_old_constructor_is_a_negative_control(self):
        source = SHEATHS.read_text(encoding='utf-8-sig')
        body = adapter.extract(source, '/obj/item/clothing/accessory/storage/sheath/katana/full/New')
        old_body = body.replace('katana(hold)', 'katana(src)')
        self.assertNotEqual(body, old_body)
        sheath, hold = spawn_prefilled(source.replace(body, old_body, 1))
        self.assertEqual(sheath, ['katana'])
        self.assertEqual(hold, [])

    def test_job_loadouts_supply_one_accessible_katana(self):
        source = JOBS.read_text(encoding='utf-8-sig')
        for role in ('ija_sergeant', 'ija_sergeant_tanker', 'camp_officer', 'ijn_sergeant'):
            with self.subTest(role=role):
                body = adapter.extract(source, f'/datum/job/japanese/{role}/equip')
                full = len(re.findall(r'new\s*/obj/item/clothing/accessory/storage/sheath/katana/full\(null\)', body))
                empty = len(re.findall(r'new\s*/obj/item/clothing/accessory/storage/sheath/katana\(null\)', body))
                separate = len(re.findall(r'new\s*/obj/item/weapon/material/sword/katana\b', body))
                self.assertEqual(full + separate, 1)
                if role == 'ijn_sergeant':
                    self.assertEqual((full, empty, separate), (0, 1, 1))
                    self.assertIn('katana(H), slot_l_hand)', body)
                else:
                    self.assertEqual((full, empty, separate), (1, 0, 0))


if __name__ == '__main__':
    unittest.main()
