"""Stone Age traps: source contract checks.

Every trap state has a sprite, every kit has a recipe and a research node,
the times are stored as text and the pit hold is not saved.

    python3 tests/stone_age_traps/test_source.py
"""
import re
import unittest
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/stone_age_traps.dm'
DMI = ROOT / 'icons/obj/stone_age_traps.dmi'

STATES = {
    'snare', 'snare_set', 'snare_sprung', 'deadfall', 'deadfall_set', 'deadfall_sprung',
    'pit_cover', 'pit_open', 'pit_staked', 'pit_covered', 'weir_stakes', 'fish_weir', 'fish_weir_full',
}
RECIPES = {
    '/obj/item/weapon/trap_kit/snare': ('/material/rope/', 'basic_tools'),
    '/obj/item/weapon/trap_kit/deadfall': ('/material/stone/', 'basic_tools'),
    '/obj/item/weapon/trap_kit/weir': ('/material/wood/soft/', 'basic_tools'),
    '/obj/item/weapon/pit_cover': ('/material/wood/', 'field_defenses'),
}


def dmi_description(path):
    data = path.read_bytes()
    i = data.find(b'zTXtDescription')
    if i > 0:
        length = int.from_bytes(data[i - 4:i], 'big')
        chunk = data[i + 4:i + 4 + length]
        return zlib.decompress(chunk[len(b'Description') + 2:]).decode('latin1')
    i = data.find(b'tEXtDescription')
    length = int.from_bytes(data[i - 4:i], 'big')
    return data[i + 4 + len(b'Description') + 1:i + 4 + length].decode('latin1')


def dmi_states(path):
    return set(re.findall(r'state = "([^"]*)"', dmi_description(path)))


def proc_body(text, header):
    start = text.index(header + '\n')
    rest = text[start + len(header) + 1:]
    end = re.search(r'^\S', rest, re.M)
    return rest[:end.start()] if end else rest


class StoneAgeTrapsSource(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = SOURCE.read_text(encoding='utf-8')
        cls.research = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
        cls.recipes = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')

    def test_included(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertIn('#include "code\\modules\\1713\\stone_age_traps.dm"', dme)

    def test_sprite_states(self):
        self.assertEqual(dmi_states(DMI), STATES)
        used = set(re.findall(r'icon_state = "([a-z_]+)"', self.text))
        used |= {'%s_set' % b for b in re.findall(r'base_state = "([a-z_]+)"', self.text) if b not in ('pit', 'fish_weir')}
        used |= {'%s_sprung' % b for b in re.findall(r'base_state = "([a-z_]+)"', self.text) if b not in ('pit', 'fish_weir')}
        self.assertTrue(used <= STATES, used - STATES)

    def test_recipes_and_research(self):
        for path, (material, node) in RECIPES.items():
            self.assertRegex(self.recipes, r'RECIPE: %s,[^,]+,%s,\d+,\d+,0,1,\w+,0,0,0,8,null' % (re.escape(material), re.escape(path)))
            self.assertIn('"%s" = "%s",' % (path, node), self.research)

    def test_times_are_text(self):
        self.assertIn('num2text(round(value), 12)', self.text)
        self.assertIn('round(world.realtime / 600)', self.text)
        settle = proc_body(self.text, '/obj/structure/stone_age_trap/proc/settle(now = trap_now_minutes())')
        self.assertIn('TRAP_MAX_ROLLS', settle)
        self.assertNotIn('addtimer', settle)

    def test_takeup_settles_after_wait_before_creating_kit(self):
        takeup = proc_body(self.text, '/obj/structure/stone_age_trap/attack_hand(mob/user)')
        self.assertIn(
            '\tif (!do_after(user, 30, src) || QDELETED(src))\n'
            '\t\treturn TRUE\n'
            '\tsettle()\n',
            takeup,
        )

    def test_takeup_preserves_catch_or_sprung_trap_and_still_recovers_empty_kit(self):
        takeup = proc_body(self.text, '/obj/structure/stone_age_trap/attack_hand(mob/user)')
        completion = takeup.split('do_after(user, 30, src)', 1)[1]
        self.assertRegex(
            completion,
            r'\n\tif \(catch_type \|\| !armed\)\n'
            r'\t\tto_chat\(user, [^\n]+\)\n'
            r'\t\treturn TRUE\n'
            r'\tvar/obj/item/K = new kit_type\(get_turf\(src\)\)\n'
            r'\tuser.put_in_hands\(K\)\n'
            r'\tqdel\(src\)',
        )

    def test_pit_hold_not_saved(self):
        self.assertIn('key == "buckled_mob" || ..()', self.text)
        self.assertIn('unbuckle_mob()', proc_body(self.text, '/obj/structure/stone_age_trap/pit/after_load()'))
        self.assertIn('..()', proc_body(self.text, '/obj/structure/stone_age_trap/pit/after_load()'))

    def test_tribe_never_falls(self):
        crossed = proc_body(self.text, '/obj/structure/stone_age_trap/pit/Crossed(atom/movable/AM)')
        self.assertIn('knows_pit(H)', crossed)
        self.assertIn('L.mob_size < MOB_MEDIUM', crossed)
        self.assertIn('PIT_NOTICE_CHANCE', crossed)

    def test_no_forbidden_patterns(self):
        for pattern in ('spawn(', 'input(', ' in world'):
            self.assertNotIn(pattern, self.text)


if __name__ == '__main__':
    unittest.main()
