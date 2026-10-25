"""Offline generated-fixture dependency tests, not native cleanup evidence."""
import os
from pathlib import Path
import unittest
from audit_offline import install
install()
from prepare import adapt_probe, VARIANTS, INPUTS, generated_files, digest, validate_inventory_bytes


class FixtureSpeciesTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        root=Path(__file__).resolve().parent
        cls.source=Path(os.environ.get('TREE_TEST_SOURCE',root.parents[1]/'prepared/inputs'))
        cls.original=(cls.source/'tests/tree_planting/probe.dm').read_text()

    def test_each_variant_supplies_real_species_without_masking_cleanup(self):
        for variant in VARIANTS:
            with self.subTest(variant=variant):
                adapted=adapt_probe(self.original,'a'*64,variant)
                self.assertEqual(adapted.count('species = new /datum/species/human'),1)
                self.assertIn('/mob/living/human/tree_tester/New()\n\tspecies = new /datum/species/human\n\treturn\n',adapted)
                start='/proc/tree_uproot_fixture('; end='/proc/tree_fixture()'
                self.assertEqual(adapted.split(start)[1].split(end)[0],self.original.split(start)[1].split(end)[0])
                for forbidden in ('tree_tester/update_icons','tree_tester/drop_from_inventory','tree_tester/update_inv_', 'tree_tester/Destroy','icon_update = FALSE'):
                    self.assertNotIn(forbidden,adapted)

    def test_missing_or_duplicate_constructor_anchor_fails_closed(self):
        anchor='/mob/living/human/tree_tester/New()\n\treturn\n'
        for changed in (self.original.replace(anchor,''),self.original+anchor):
            with self.assertRaises(ValueError):adapt_probe(changed,'a'*64,'baseline')

    def test_production_fixture_remains_unmodified_and_same_assertions(self):
        self.assertNotIn('species = new /datum/species/human',self.original)
        from oracle import inventory,expected
        self.assertEqual([len(inventory()[x]) for x in ('roundtrip','writer','reader')],[84,3,25])
        self.assertEqual(len(expected('uprooting','roundtrip')),2)
