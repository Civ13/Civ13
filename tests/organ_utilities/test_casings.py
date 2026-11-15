"""Offline source-contract checks; not native DM or real-client acceptance."""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
PATH = 'code/modules/1713/animal_harvest.dm'
ANCHOR = '/obj/item/weapon/reagent_containers/food/snacks/meat/offal/intestines/attackby('

def block(source):
    return source[source.index(ANCHOR):source.index('// One bounded stack per carcass.')]

def audit(source):
    body = block(source)
    required = [
        'user.a_intent != I_GRAB)\n\t\treturn ..()',
        'user.stat != CONSCIOUS || user.get_active_hand() != W',
        '(loc != user && loc != site)',
        '!map || map.ordinal_age < 1',
        '!raw || roasted || boiled || bitecount || !can_cut_preserved_meat() || radiation > 0 || germ_level > GERM_LEVEL_AMBIENT',
        'reagents.get_reagent_amount("protein") < 2',
        'R.id != "protein"',
        '!user.canUnEquip(src)',
        'user.remove_from_mob(src)',
        'QDELETED(src) || loc != site',
        'qdel(src)\n\tnew /obj/item/stack/sausagecasing(site, 1)',
    ]
    for guard in required:
        if guard not in body:
            raise AssertionError('Missing admission/payment contract: ' + guard)
    if body.count('new /obj/item/stack/sausagecasing') != 1:
        raise AssertionError('More than one output')
    if 'do_after(' in body or 'sleep(' in body or 'spawn(' in body:
        raise AssertionError('Unexpected asynchronous window')
    return required

class Casings(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = (ROOT / PATH).read_text()
    def test_admission_and_paid_output(self):
        audit(self.source)
    def test_each_removed_guard_is_detected(self):
        for guard in audit(self.source):
            with self.subTest(guard=guard), self.assertRaises(AssertionError):
                audit(self.source.replace(guard, '// omitted', 1))
    def test_duplicate_output_is_detected(self):
        output = 'new /obj/item/stack/sausagecasing(site, 1)'
        with self.assertRaises(AssertionError):
            audit(self.source.replace(output, output + '\n\t' + output))
    def test_wait_introduction_is_detected(self):
        with self.assertRaises(AssertionError):
            audit(self.source.replace('\tqdel(src)\n\tnew /obj/item/stack/sausagecasing', '\tsleep(1)\n\tqdel(src)\n\tnew /obj/item/stack/sausagecasing'))
    def test_existing_food_inheritance_and_art(self):
        declaration = self.source.split(ANCHOR)[0].split('/offal/intestines\n')[1]
        self.assertIn("icon = 'icons/obj/food/pocket_stronghold_food.dmi'", declaration)
        self.assertNotIn('parent_type', declaration)
    def test_fresh_ambient_germs_are_accepted(self):
        import re
        atoms = (ROOT / 'code/game/atoms.dm').read_text()
        self.assertIn('germ_level = GERM_LEVEL_AMBIENT', atoms)
        predicate = re.search(r'germ_level > ([A-Z_]+)', block(self.source))[1]
        self.assertEqual(predicate, 'GERM_LEVEL_AMBIENT')
        defines = (ROOT / 'code/predefines.dm').read_text()
        ambient = int(re.search(r'#define GERM_LEVEL_AMBIENT\s+(\d+)', defines)[1])
        expression = re.search(r'germ_level > [A-Z_]+', block(self.source))[0]
        self.assertFalse(eval(expression, {}, {'germ_level': ambient, predicate: ambient}))
        self.assertTrue(eval(expression, {}, {'germ_level': ambient + 1, predicate: ambient}))

    def test_catalog_contract(self):
        spec = importlib.util.spec_from_file_location('catalog', ROOT / 'scripts/atlas/catalog_metadata.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        records, calls = [], []
        def add(*args):
            calls.append(args)
            records.append({})
        module.add_intestine_casings({PATH: self.source}, add, records)
        self.assertEqual(len(calls), 1)
        self.assertEqual(calls[0][2], [('/obj/item/weapon/reagent_containers/food/snacks/meat/offal/intestines', 1)])
        self.assertEqual(calls[0][3], [('/obj/item/stack/sausagecasing', 1)])
        self.assertEqual(records[0]['min_era'], 1)
        with self.assertRaises(ValueError):
            module.add_intestine_casings({PATH: self.source.replace('map.ordinal_age < 1', 'map.ordinal_age < 0')}, add, records)

if __name__ == '__main__':
    unittest.main()
