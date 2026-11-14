"""Part slots on machines (docs/material-roles.md, "Machine slots").

code/modules/materials/machine_slots.dm gives the mills, the saw mills and
the loom wearing slots for the standard parts.

- No machine has more than four slots: the packed wear number holds four.
- Every slot names a real part type and a standard material that can do the
  job; a machine built the usual way stores nothing and runs at 100%.
- The packed number round-trips every wear level in every slot.
- The speed, refusal, wear, examine and fitting hooks are all in place, and
  a slotted machine keeps no list of its own.
- Only a part someone fitted comes back out when it is replaced.
"""
from pathlib import Path
import importlib.util
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, ROOT / path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


roles = load('material_roles', 'tests/material_roles/test_material_roles.py')
SOURCE = (ROOT / 'code/modules/materials/machine_slots.dm').read_text(encoding='utf-8')
PRODUCTION = (ROOT / 'code/modules/1713/production.dm').read_text(encoding='utf-8', errors='ignore')
DEFINES = (ROOT / 'code/__defines/material_roles.dm').read_text(encoding='utf-8')
DME = (ROOT / 'civ13.dme').read_text(encoding='utf-8', errors='ignore')

PART_ROLES = {'/obj/item/machine_part/gear': 'gear', '/obj/item/machine_part/shaft': 'shaft',
              '/obj/item/machine_part/bearing': 'bearing'}
EXPECTED = {
    '/obj/structure/mill': {'shaft': 'wood', 'bearing': 'wood'},
    '/obj/structure/mill/large': {'gears': 'wood', 'shaft': 'wood', 'bearing': 'wood'},
    '/obj/structure/sawmill/large': {'gears': 'wood', 'shaft': 'wood', 'bearing': 'wood'},
    '/obj/structure/sawmill/powered': {'gears': 'iron', 'shaft': 'iron', 'bearing': 'iron'},
    '/obj/structure/loom': {'shaft': 'wood', 'bearing': 'wood'},
}


def number(name):
    found = re.search(r'#define %s (\S+)' % name, SOURCE) or re.search(r'#define %s (\S+)' % name, DEFINES)
    return float(found[1])


def tables():
    body = SOURCE[SOURCE.index('var/global/list/machine_slot_tables = list('):SOURCE.index('var/global/list/machine_precision_types')]
    found = {}
    for machine, rows in re.findall(r'^\t(/obj/structure/[\w/]+) = list\(\n((?:\t\t[^\n]*\n?)+)', body, re.M):
        found[machine] = re.findall(r'"(\w+)" = list\((/obj/item/machine_part/\w+), "(\w+)"\)', rows)
    return found


def proc(name):
    start = SOURCE.index(name)
    end = SOURCE.find('\n/', start + 1)
    return SOURCE[start:end if end > 0 else len(SOURCE)]


class MachineSlots(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.materials = roles.load_materials()
        cls.roles, cls.consts = roles.load_roles()

    def test_tables(self):
        found = tables()
        self.assertEqual({m: {slot: material for slot, _, material in rows} for m, rows in found.items()}, EXPECTED)
        for machine, rows in found.items():
            self.assertLessEqual(len(rows), int(number('MACHINE_MAX_SLOTS')), machine)
            self.assertEqual(len({slot for slot, _, _ in rows}), len(rows), machine)
            # one slot per part type, so a part item has exactly one place to go
            self.assertEqual(len({part for _, part, _ in rows}), len(rows), machine)
            for slot, part, material in rows:
                rated = roles.rate(self.roles[PART_ROLES[part]], self.materials[material], self.materials, self.consts)
                self.assertIsNotNone(rated, (machine, slot))
                self.assertGreater(rated[1], 0)

    def test_packed_wear_holds_four_slots_exactly(self):
        self.assertEqual(number('MACHINE_MAX_SLOTS'), 4)
        worn_out = int(number('MACHINE_PART_WORN_OUT'))
        self.assertEqual(worn_out, 63)
        # BYOND numbers are single floats: whole numbers are exact below 2**24.
        self.assertLess(sum(worn_out * 64 ** i for i in range(4)), 2 ** 24)
        get = proc('/proc/machine_slot_wear(')
        self.assertIn('round(M.part_wear / (64 ** (index - 1))) % 64', get)
        put = proc('/proc/machine_set_slot_wear(')
        self.assertIn('max(0, min(MACHINE_PART_WORN_OUT, round(wear)))', put)
        self.assertIn('M.part_wear += (wear - machine_slot_wear(M, slot)) * place', put)
        packed = 0
        wanted = [63, 0, 41, 7]
        for index, wear in enumerate(wanted):
            packed += (wear - (packed // 64 ** index) % 64) * 64 ** index
        self.assertEqual([(packed // 64 ** i) % 64 for i in range(4)], wanted)

    def test_thresholds(self):
        self.assertLess(number('MACHINE_PART_WORN'), number('MACHINE_PART_FAILING'))
        self.assertLess(number('MACHINE_PART_FAILING'), number('MACHINE_PART_WORN_OUT'))
        self.assertEqual(number('MACHINE_ROUGH_CAP'), 0.6)
        self.assertGreaterEqual(number('MACHINE_PART_BASE_LIFE'), 100)

    def test_a_usual_build_stores_nothing_and_runs_at_full_speed(self):
        base = re.search(r'^/obj/structure\n((?:\t[^\n]*\n)+)', SOURCE, re.M)[1]
        self.assertEqual(base, '\tvar/part_key\n\tvar/part_wear = 0\n')
        self.assertNotIn('list/', base)
        fill = proc('/proc/machine_slot_fill(')
        self.assertIn('return list(slots[slot][2], FALSE, FALSE)', fill)
        performance = proc('/proc/machine_slot_performance(')
        # the cap is only for a rough part someone fitted, never the built-in one
        self.assertIn('if (fill[3] && !fill[2] && machine_needs_precision(M))', performance)
        self.assertIn('performance = min(performance, MACHINE_ROUGH_CAP)', performance)
        self.assertIn('part_performance(role, fill[1]) / standard', performance)
        self.assertIn('if (!slots)\n\t\treturn 1', proc('/proc/machine_performance('))

    def test_precision_machines(self):
        listed = re.findall(r'^\t(/obj/structure/[\w/]+),$',
                            SOURCE[SOURCE.index('var/global/list/machine_precision_types'):SOURCE.index('var/global/list/machine_slot_cache')], re.M)
        self.assertEqual(listed, ['/obj/structure/sawmill/powered'])
        for machine in listed:
            self.assertIn(machine, EXPECTED)

    def test_wear_follows_the_material(self):
        wear = proc('/proc/machine_wear(')
        self.assertIn('rated[2] / standard[2]', wear)
        self.assertIn('jobs * MACHINE_PART_WORN_OUT / (MACHINE_PART_BASE_LIFE * max(0.05, life))', wear)
        refusal = proc('/proc/machine_work_refusal(')
        self.assertIn('machine_broken_slot(M)', refusal)
        self.assertIn('>= MACHINE_PART_FAILING && prob(MACHINE_JAM_CHANCE)', refusal)

    def test_only_a_fitted_part_comes_back(self):
        install = proc('/proc/machine_install_part(')
        self.assertIn('if (old[3])', install)
        self.assertIn('out.wear = old_wear', install)
        self.assertIn('machine_set_slot_wear(M, target, P.wear)', install)
        self.assertLess(install.index('do_after('), install.index('M.part_key = '))
        self.assertIn('P.wear >= MACHINE_PART_WORN_OUT', install)
        self.assertIn('if (!P.rating())', install)

    def test_machines_are_hooked(self):
        for machine in ('/obj/structure/mill', '/obj/structure/sawmill', '/obj/structure/loom'):
            self.assertIn('%s/examine(mob/user, distance)\n\t..(user, distance)\n\tmachine_examine_parts(src, user)' % machine, SOURCE)
            self.assertRegex(SOURCE, re.escape(machine) + r'/attackby\([^\n]*\n\tif \(istype\(W, /obj/item/machine_part\) && machine_install_part\(src, W, H\)\)\n\t\treturn\n\t\.\.\(')
            self.assertRegex(SOURCE, re.escape(machine) + r'/produce\([^\n]*\n\tif \(machine_work_refusal\(src, H\)\)\n\t\treturn\n\t\.\.\(W, H, P\)')
            self.assertIn('%s/finish_work()\n\tif (current_work)\n\t\tmachine_wear(src)\n\t..()' % machine, SOURCE)
        self.assertEqual(PRODUCTION.count('work_time_amount = machine_work_time(src, work_time_amount)'), 2)
        self.assertEqual(PRODUCTION.count(') * machine_performance(src)'), 1)
        self.assertLess(DME.index('modules\\1713\\production.dm'), DME.index('modules\\materials\\machine_slots.dm'))


if __name__ == '__main__':
    unittest.main()
