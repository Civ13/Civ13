"""Item wear goes through apply_wear()/check_health() in code/_helpers/item_wear.dm.

Material weapons, shields and clothing each subtracted health and called their
own check_health(), and only some went through electroplating. The helper keeps
today's numbers: blows are softened by plating, work and hits are not. The
ceiling only goes down: new wear calls apply_wear() instead of writing
`health -= plating_wear(...)` by hand. Repair (sharpening, honing, benches)
goes through repair_wear(), which never breaks the item.
"""
import importlib.util
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('item_wear_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)
HELPER = ROOT / 'code/_helpers/item_wear.dm'
HAND_PLATED_CEILING = 0
BREAKABLE = {
    'code/game/objects/items/weapons/material/material_weapons.dm': '/obj/item/weapon/material/check_health(consumed)',
    'code/game/objects/items/weapons/shields.dm': '/obj/item/weapon/shield/check_health(consumed)',
    'code/game/objects/items/clothing/clothing.dm': '/obj/item/clothing/check_health(consumed)',
}


class Item:
    def __init__(self, health=10, maxhealth=10, factor=1, finish=1):
        self.health = health
        self.maxhealth = maxhealth
        self.factor = factor
        self.finish = finish
        self.checked = []

    def plating_wear(self, amount):
        return amount * self.factor

    def finish_wear(self, amount):
        return amount * self.finish

    def check_health(self, consumed):
        self.checked.append((self.health, consumed))
        return self.health <= 0


def project(name, args):
    source = HELPER.read_text(encoding='utf-8')
    source = re.sub(r'(?<![.\w])(health|maxhealth)\b(?!\()', r'src.\1', source)
    for call in ('plating_wear', 'finish_wear', 'check_health'):
        source = re.sub(r'(?<![.\w/])' + call + r'\(', 'src.' + call + '(', source)
    env = {'WEAR_BLOW': 'blow', 'WEAR_WORK': 'work', 'WEAR_HIT': 'hit', 'isnull': lambda v: v is None}
    return adapter.project(source, '/obj/item/proc/' + name, args, env)


class ItemWearTest(unittest.TestCase):
    def test_only_blows_go_through_plating(self):
        apply_wear = project('apply_wear', 'src, amount, cause, consumed')
        for cause, expected in (('blow', 9.5), ('work', 9), ('hit', 9)):
            with self.subTest(cause=cause):
                item = Item(factor=0.5)
                self.assertFalse(apply_wear(item, 1, cause, False))
                self.assertEqual(item.health, expected)
                self.assertEqual(item.checked, [(expected, False)])

    def test_every_cause_goes_through_a_finish(self):
        # A lacquer or varnish finish (lacquer.dm) softens all wear, after plating.
        apply_wear = project('apply_wear', 'src, amount, cause, consumed')
        for cause, expected in (('blow', 9.75), ('work', 9.5), ('hit', 9.5)):
            with self.subTest(cause=cause):
                item = Item(factor=0.5, finish=0.5)
                self.assertFalse(apply_wear(item, 1, cause, False))
                self.assertEqual(item.health, expected)

    def test_wear_reports_a_break(self):
        apply_wear = project('apply_wear', 'src, amount, cause, consumed')
        item = Item(health=0.25)
        self.assertTrue(apply_wear(item, 0.25, 'work', True))
        self.assertEqual(item.checked, [(0, True)])

    def test_repair_strains_the_ceiling(self):
        repair = project('repair_wear', 'src, amount, strain')
        item = Item(health=50, maxhealth=100)
        self.assertTrue(repair(item, 25, 1))
        self.assertEqual((item.health, item.maxhealth), (75, 99))
        self.assertTrue(repair(item, 25, 1))
        self.assertEqual((item.health, item.maxhealth), (98, 98))
        worn = Item(health=1, maxhealth=1)
        self.assertFalse(repair(worn, 25, 1))
        self.assertEqual((worn.health, worn.maxhealth), (1, 1))

    def test_sharpening_never_breaks_a_fragile_tool(self):
        # A twine-bound flint axe has a ceiling of 2.5; the flint's strain of 4
        # used to break it on the first sharpening (live report 2026-11-17).
        repair = project('repair_wear', 'src, amount, strain')
        axe = Item(health=0.4, maxhealth=2.5)
        sharpened = 0
        while repair(axe, 6, 4):
            sharpened += 1
            self.assertEqual(axe.health, axe.maxhealth)
            self.assertGreaterEqual(axe.maxhealth, 1)
        self.assertGreaterEqual(sharpened, 5)
        self.assertGreater(axe.maxhealth, 0)
        self.assertGreater(axe.health, 0)

    def test_repair_callers_never_destroy_the_item(self):
        for path in ('code/game/objects/structures/repairing.dm', 'code/game/objects/structures/rocks.dm', 'code/modules/1713/worn_tools.dm'):
            text = (ROOT / path).read_text(encoding='utf-8')
            self.assertNotIn('breaks from strain', text, path)
            self.assertNotIn('breaks from the strain', text, path)
            self.assertNotRegex(text, r'maxhealth\s*-=\s*(damageamount|4)\b', path)

    def test_breakable_items_override_the_shared_check(self):
        for path, override in BREAKABLE.items():
            text = (ROOT / path).read_text(encoding='utf-8')
            self.assertIn(override, text, path)
            self.assertNotIn('/proc/check_health(', text, path)

    def test_hand_written_plated_wear_only_goes_down(self):
        count = 0
        for path in (ROOT / 'code').rglob('*.dm'):
            text = path.read_text(encoding='utf-8', errors='replace')
            count += len(re.findall(r'health\s*-=\s*plating_wear\(', text))
        self.assertLessEqual(count, HAND_PLATED_CEILING)


class HatchetWearTest(unittest.TestCase):
    @staticmethod
    def project(name, args, namespace):
        source = (ROOT / 'code/game/objects/items/weapons/material/misc.dm').read_text()
        source = source.replace('return ..()', 'return parent()')
        source = re.sub(
            r'(?<![./\w])\b(health|maxhealth|component_wear|material|loc|hatchet_(?:head|handle)_(?:hp|max)|tool_(?:head|handle)_condition)\b',
            r'src.\1', source,
        )
        for call in ('init_hatchet_wear', 'sync_hatchet_wear', 'plating_wear', 'finish_wear',
                     'break_hatchet', 'too_worn_to_repair'):
            # Only indent-level statements are relevant; leave DM declarations alone.
            source = re.sub(r'(?<![/\.\w])' + call + r'\(', 'src.' + call + '(', source)
        declaration = '/obj/item/weapon/material/hatchet/' + name
        env = dict(namespace, QDELETED=lambda obj: not obj.loc, WEAR_BLOW='blow', parent=lambda: 'unchanged')
        return adapter.project(source, declaration, args, env)

    def hatchet(self, head_hp, handle_hp, head_max=35, handle_max=35):
        from types import SimpleNamespace
        item = SimpleNamespace(hatchet_head_hp=head_hp, hatchet_handle_hp=handle_hp,
                               hatchet_head_max=head_max, hatchet_handle_max=handle_max,
                               component_wear=True, material=True, loc=True, failures=[])
        item.init_hatchet_wear = lambda: None
        sync = self.project('proc/sync_hatchet_wear', 'src', {})
        item.sync_hatchet_wear = lambda: sync(item)
        item.plating_wear = lambda amount: amount / 2
        item.finish_wear = lambda amount: amount
        item.break_hatchet = lambda consumed: (item.failures.append((item.hatchet_head_hp, consumed)),
                                               setattr(item, 'loc', False))
        worn = self.project('too_worn_to_repair', 'src, strain', {})
        item.too_worn_to_repair = lambda strain: worn(item, strain)
        return item

    def test_handle_failure_keeps_the_worn_head_and_cannot_pay_twice(self):
        wear = self.project('apply_wear', 'src, amount, cause, consumed', {})
        axe = self.hatchet(18, .25)
        self.assertTrue(wear(axe, .25, 'work', False))
        self.assertEqual(axe.failures, [(17.75, False)])
        self.assertTrue(wear(axe, .25, 'work', False))
        self.assertEqual(len(axe.failures), 1)

    def test_head_failure_does_not_restore_the_head_or_ignore_blow_plating(self):
        wear = self.project('apply_wear', 'src, amount, cause, consumed', {})
        axe = self.hatchet(.25, 20)
        self.assertFalse(wear(axe, .25, 'blow', False))
        self.assertTrue(wear(axe, .25, 'work', True))
        self.assertEqual(axe.hatchet_handle_hp, 19.625)
        self.assertEqual(axe.failures, [(0, True)])

    def test_sharpen_only_changes_head_and_never_restores_handle(self):
        repair = self.project('repair_wear', 'src, amount, strain', {})
        axe = self.hatchet(10, 3)
        self.assertTrue(repair(axe, 8, 2))
        self.assertEqual((axe.hatchet_head_hp, axe.hatchet_head_max), (18, 33))
        self.assertEqual((axe.hatchet_handle_hp, axe.hatchet_handle_max), (3, 35))
        self.assertAlmostEqual(axe.health, 3)

    def test_recovery_keeps_material_grade_condition_and_binding(self):
        misc = (ROOT / 'code/game/objects/items/weapons/material/misc.dm').read_text()
        body = adapter.extract(misc, '/obj/item/weapon/material/hatchet/proc/break_hatchet')
        self.assertIn('if (hatchet_head_hp > 0 || !hatchet_brittle_head())', body)
        self.assertIn('P.hatchet_stock_grade = hatchet_stock_grade', body)
        self.assertIn('P.health = hatchet_head_hp', body)
        self.assertIn('P.maxhealth = hatchet_head_max', body)
        self.assertIn('F.recovered_hatchet_head_hp = hatchet_head_hp', body)
        self.assertIn('material.place_shard(T)', body)
        assembly = (ROOT / 'code/game/objects/items/weapons/material/ooga_booga_weapons.dm').read_text()
        bind = adapter.extract(assembly, '/obj/item/weapon/branch/proc/assemble_flint_axe')
        self.assertLess(bind.index('binding.use(1)'), bind.index('new(get_turf(user))'))
        self.assertIn('axe.hatchet_head_hp = recovered_head_hp', bind)

    def test_spent_head_must_be_sharpened_and_parts_travel_whole(self):
        parts = (ROOT / 'code/game/objects/structures/blacksmithing/parts.dm').read_text()
        assembly = adapter.extract(parts, '/obj/item/weapon/material/part/proc/assemble_work_tool')
        self.assertLess(assembly.index('&& health <= 0'), assembly.index('new result'))
        repair = adapter.extract(parts, '/obj/item/weapon/material/part/axehead/hatchet/repair_wear')
        self.assertIn('strain = min(strain, maxhealth - 1)', repair)
        travel = (ROOT / 'code/modules/persistence/region_travel_gear.dm').read_text()
        body = adapter.extract(travel, '/proc/region_travel_gear_kind')
        self.assertIn('H.component_wear) || istype(G, /obj/item/weapon/material/part/axehead/hatchet)) return null', body)
        self.assertIn('return region_travel_generic_kind(I)', travel)

    def test_interrupted_or_stale_chop_cannot_spend_wear(self):
        wild = (ROOT / 'code/game/objects/structures/wild.dm').read_text()
        body = adapter.extract(wild, '/obj/structure/wild/attackby')
        self.assertIn('WORK_CHOP, HT), src)', body)
        for guard in ('!QDELETED(src)', '!QDELETED(HT)', 'health > 0', 'Adjacent(user)', 'HT.loc == user'):
            self.assertIn(guard, body[:body.index('HT.apply_wear')])


if __name__ == '__main__':
    unittest.main()
