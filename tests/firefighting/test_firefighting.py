"""Offline source contracts for firefighting tools. Gameplay behaviour is
covered by the native probe:
python3 tests/ecology_spawning/run_linux.py . tests/firefighting/probe.dm
"""
from pathlib import Path
import re
import struct
import unittest
import zlib

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/firefighting.dm'
WATER = ROOT / 'code/modules/1713/firefighting_water.dm'
FIRE = ROOT / 'code/modules/1713/oil_fires.dm'
HOOK = ROOT / 'code/modules/1713/firefighting_hook.dm'
PUMP = ROOT / 'code/modules/1713/firefighting_pump.dm'
ICON = ROOT / 'icons/obj/firefighting.dmi'


def dmi_states(path):
    data = path.read_bytes()
    pos = 8
    while pos < len(data):
        length, kind = struct.unpack('>I4s', data[pos:pos + 8])
        chunk = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if kind == b'zTXt' and chunk.startswith(b'Description\0'):
            text = zlib.decompress(chunk[len(b'Description\0') + 1:]).decode('utf-8')
            return dict(re.findall(r'state = "([^"]*)"\n\tdirs = (\d+)', text))
    return {}


class FirefightingSourceTests(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding='utf-8')

    def test_included_after_the_code_it_extends(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8').splitlines()
        mine = dme.index('#include "code\\modules\\1713\\firefighting.dm"')
        # The stack overrides chain to the originals with ..().
        for original in ('code\\modules\\1713\\oil_fires.dm',
                         'code\\modules\\materials\\material_sheets.dm',
                         'code\\_onclick\\item_attack.dm'):
            self.assertLess(dme.index('#include "%s"' % original), mine)

    def test_every_icon_state_exists(self):
        states = dmi_states(ICON)
        for base in ('fire_beater', 'fire_flapper'):
            self.assertIn('"%s"' % base, self.source)
            self.assertEqual(states.get(base), '1')
            self.assertEqual(states.get(base + '_wet'), '1')
            for hand in ('_l', '_r'):
                self.assertIn('"%s%s"' % (base, hand), self.source)
                self.assertEqual(states.get(base + hand), '4')

    def test_overrides_fall_through(self):
        for proc in ('/obj/item/weapon/fire_beater/resolve_attackby',
                     '/obj/item/stack/material/pelt/resolve_attackby',
                     '/obj/item/stack/material/leather/resolve_attackby',
                     '/obj/item/stack/material/cloth/resolve_attackby'):
            start = self.source.index('\n' + proc + '(')
            end = self.source.find('\n/', start + 1)
            self.assertIn('return ..()', self.source[start:end], proc)

    def test_recipes_and_knowledge(self):
        recipes = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
        nodes = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
        for material, path in (('/material/wood/', '/obj/item/weapon/fire_beater'),
                               ('/material/leather/', '/obj/item/weapon/fire_beater/flapper')):
            lines = [line for line in recipes.splitlines()
                     if line.startswith('RECIPE: ') and line.split(',')[2] == path]
            self.assertEqual(len(lines), 1, path)
            fields = lines[0][len('RECIPE: '):].split(',')
            self.assertEqual(len(fields), 13)
            self.assertEqual(fields[0], material)
            self.assertIn('"%s" = "primitive_construction"' % path, nodes)

    def test_cooldown_is_runtime_state(self):
        self.assertIn('var/tmp/next_beat', self.source)
        self.assertIn('return key == "next_beat" || ..()', self.source)

    def test_water_and_blanket_hooks(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8').splitlines()
        mine = dme.index('#include "code\\modules\\1713\\firefighting_water.dm"')
        self.assertLess(dme.index('#include "code\\game\\objects\\structures\\bedsheet_bin.dm"'), mine)
        fire = FIRE.read_text(encoding='utf-8')
        self.assertIn('return douse_fire_with_container(src, W, user)', fire)
        # The old check always passed, whatever the amount of water.
        self.assertNotIn('prob(max(R.volume, 100))', fire)
        water = WATER.read_text(encoding='utf-8')
        start = water.index('\n/obj/item/weapon/bedsheet/resolve_attackby(')
        self.assertIn('return ..()', water[start:water.find('\n#undef', start)])
        self.assertIn('return key == "next_smother" || ..()', water)

    def test_fire_hook(self):
        hook = HOOK.read_text(encoding='utf-8')
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8').splitlines()
        mine = dme.index('#include "code\\modules\\1713\\firefighting_hook.dm"')
        for original in ('code\\game\\objects\\covers.dm', 'code\\game\\objects\\roof_stuff.dm',
                         'code\\game\\objects\\structures\\wild.dm'):
            self.assertLess(dme.index('#include "%s"' % original), mine)
        states = dmi_states(ICON)
        self.assertEqual(states.get('fire_hook'), '1')
        for hand in ('fire_hook_l', 'fire_hook_r'):
            self.assertIn('"%s"' % hand, hook)
            self.assertEqual(states.get(hand), '4')
        start = hook.index('\n/obj/item/weapon/fire_hook/resolve_attackby(')
        self.assertIn('return ..()', hook[start:hook.find('\n#undef', start)])
        # Trees are never a target: only the brush types are listed.
        self.assertNotIn('/obj/structure/wild/tree', hook)
        recipes = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
        lines = [line for line in recipes.splitlines()
                 if line.startswith('RECIPE: ') and line.split(',')[2] == '/obj/item/weapon/fire_hook']
        self.assertEqual(len(lines), 1)
        self.assertEqual(len(lines[0][len('RECIPE: '):].split(',')), 13)
        self.assertTrue(lines[0].startswith('RECIPE: /material/iron/,'))
        nodes = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
        self.assertIn('"/obj/item/weapon/fire_hook" = "iron_tools"', nodes)

    def test_hand_pump(self):
        pump = PUMP.read_text(encoding='utf-8')
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8').splitlines()
        mine = dme.index('#include "code\\modules\\1713\\firefighting_pump.dm"')
        self.assertLess(dme.index('#include "code\\modules\\1713\\oil_fires.dm"'), mine)
        states = dmi_states(ICON)
        for state in ('fire_pump', 'fire_nozzle'):
            self.assertIn('"%s"' % state, pump)
            self.assertEqual(states.get(state), '1')
        for hand in ('fire_nozzle_l', 'fire_nozzle_r'):
            self.assertIn('"%s"' % hand, pump)
            self.assertEqual(states.get(hand), '4')
        # The nozzle belongs to its engine: never saved, never a loose reference.
        self.assertIn('should_save = FALSE', pump)
        self.assertIn('var/tmp/obj/item/weapon/fire_nozzle/nozzle', pump)
        self.assertIn('return key == "nozzle" || ..()', pump)
        self.assertNotIn('spawn', pump)
        recipes = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
        lines = [line for line in recipes.splitlines()
                 if line.startswith('RECIPE: ') and line.split(',')[2] == '/obj/structure/fire_pump']
        self.assertEqual(len(lines), 1)
        self.assertEqual(len(lines[0][len('RECIPE: '):].split(',')), 13)
        self.assertTrue(lines[0].startswith('RECIPE: /material/wood/,'))
        self.assertFalse(any(line.split(',')[2] == '/obj/item/weapon/fire_nozzle'
                             for line in recipes.splitlines() if line.startswith('RECIPE: ')))
        nodes = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
        self.assertIn('"/obj/structure/fire_pump" = "wagons_ships"', nodes)

    def test_hose_reel_and_extinguisher(self):
        pump = PUMP.read_text(encoding='utf-8')
        states = dmi_states(ICON)
        for state in ('fire_hose_reel', 'fire_hose_reel_out'):
            self.assertIn('"%s"' % state, pump)
            self.assertEqual(states.get(state), '1')
        # The reel has no store of its own and never counts a puddle as plumbing.
        reel = pump[pump.index('\n/obj/structure/fire_pump/reel\n'):]
        self.assertIn('max_water = 0', reel)
        self.assertIn('/obj/structure/sink/puddle', reel)
        recipes = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
        lines = [line for line in recipes.splitlines()
                 if line.startswith('RECIPE: ') and line.split(',')[2] == '/obj/structure/fire_pump/reel']
        self.assertEqual(len(lines), 1)
        self.assertEqual(len(lines[0][len('RECIPE: '):].split(',')), 13)
        nodes = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
        self.assertIn('"/obj/structure/fire_pump/reel" = "machined_tools"', nodes)
        tools = (ROOT / 'code/game/objects/items/weapons/tools.dm').read_text(encoding='utf-8')
        start = tools.index('/obj/item/weapon/reagent_containers/glass/fire_extinguisher\n')
        ext = tools[start:tools.index(' * Screwdriver', start)]
        self.assertIn('fire_jet_blocked(T)', ext)
        self.assertIn('for (var/mob/living/L in T)', ext)
        self.assertIn('!isturf(target) && !isturf(target.loc)', ext)
        self.assertNotIn('spawn', ext)


if __name__ == '__main__':
    unittest.main()
