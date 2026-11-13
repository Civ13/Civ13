"""Offline checks for the handloading table (issue #4443, ammo casings).

Every modern caliber in docs/firearm-coverage.json must either be loadable by
hand or be listed below with the reason it is not, so a new cartridge cannot
quietly become impossible to resupply. Needs no BYOND.
"""
import json
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
TABLE = ROOT / 'code/modules/projectiles/handloading.dm'
CASINGS = ROOT / 'code/modules/projectiles/_ammo_casing.dm'
MANIFEST = ROOT / 'docs/firearm-coverage.json'

# Calibers that are deliberately not hand-loadable, with the reason.
EXCLUDED = {
    'a127': 'heavy machine-gun round; big brass, factory or loadout supply only',
    'a145': 'heavy machine-gun round; big brass, factory or loadout supply only',
    'a15115': 'heavy machine-gun round; big brass, factory or loadout supply only',
    'a50cal': 'heavy machine-gun round; big brass, factory or loadout supply only',
    'a792x94': 'anti-tank rifle round; big brass, factory or loadout supply only',
    'a20': 'autocannon shell, not a small-arms cartridge',
    'a25': 'autocannon shell, not a small-arms cartridge',
    'a30': 'autocannon shell, not a small-arms cartridge',
    'a35': 'autocannon shell, not a small-arms cartridge',
    'a77x58_wood': 'wooden training bullet for the training rifle',
    'a44p': 'legacy test caliber whose round is named "Bugged bullet"',
}


def casing_calibers():
    """typepath => caliber, following parents for inherited values."""
    own = {}
    current = None
    for line in CASINGS.read_text(encoding='utf-8-sig').splitlines():
        header = re.match(r'^(/obj/item/ammo_casing[\w/]*)\s*$', line)
        if header:
            current = header[1]
            own.setdefault(current, None)
            continue
        if line[:1] not in ('\t', ' '):
            current = None
            continue
        value = re.match(r'\s+caliber\s*=\s*"([^"]*)"', line)
        if current and value:
            own[current] = value[1]
    resolved = {}
    for path in own:
        probe = path
        while probe and own.get(probe) is None:
            probe = probe.rsplit('/', 1)[0] if probe.count('/') > 3 else None
        resolved[path] = own.get(probe) if probe else None
    return resolved


def table_rows():
    text = TABLE.read_text(encoding='utf-8-sig')
    return re.findall(r'new /datum/handload_cartridge\("([^"]+)", (/obj/item/ammo_casing[\w/]*), (HANDLOAD_\w+), "(\w+)"', text)


class HandloadingTableTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.calibers = casing_calibers()
        cls.rows = table_rows()
        cls.manifest = json.loads(MANIFEST.read_text(encoding='utf-8'))

    def test_rows_name_real_cartridges(self):
        self.assertGreater(len(self.rows), 40)
        for label, path, _, _ in self.rows:
            with self.subTest(label=label):
                self.assertIn(path, self.calibers)
                self.assertTrue(self.calibers[path])

    def test_labels_are_unique(self):
        labels = [row[0] for row in self.rows]
        self.assertEqual(len(labels), len(set(labels)))

    def test_research_nodes_are_firearm_nodes(self):
        nodes = {row[3] for row in self.rows}
        self.assertLessEqual(nodes, {'rifling', 'cartridge_ammo', 'selfloading_firearms', 'automatic_weapons'})

    def test_one_casing_size_per_caliber(self):
        sizes = {}
        for label, path, size, _ in self.rows:
            caliber = self.calibers[path]
            with self.subTest(label=label):
                self.assertEqual(sizes.setdefault(caliber, size), size, 'spent brass of one caliber must give one size back')

    def test_every_modern_caliber_is_loadable_or_excused(self):
        loadable = {self.calibers[path] for _, path, _, _ in self.rows}
        for caliber in self.manifest['modern_calibers']:
            with self.subTest(caliber=caliber):
                self.assertTrue(caliber in loadable or caliber in EXCLUDED,
                                f'{caliber} has no handloading row; add one or a reason to EXCLUDED')

    def test_exclusions_are_current(self):
        loadable = {self.calibers[path] for _, path, _, _ in self.rows}
        for caliber in EXCLUDED:
            with self.subTest(caliber=caliber):
                self.assertIn(caliber, self.manifest['modern_calibers'])
                self.assertNotIn(caliber, loadable)


if __name__ == '__main__':
    unittest.main()
