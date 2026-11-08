"""Source checks for the chainsaw, the jackhammer's tree-felling counterpart.

No compiler, game or network. They pin the declarations that make the chainsaw
reachable (recipes, research gate, sprites) and fast at felling trees.
"""
from pathlib import Path
import re
import struct
import unittest
import zlib

ROOT = Path(__file__).resolve().parents[1]
CHAINSAW = '/obj/item/weapon/material/hatchet/chainsaw'
JACKHAMMER = '/obj/item/weapon/material/pickaxe/jackhammer'


def source(path):
    return (ROOT / path).read_text(encoding='utf-8')


def type_block(text, path):
    start = text.index('\n' + path + '\n') + 1
    end = re.search(r'\n(?=\S)', text[start + len(path) + 1:])
    return text[start:] if end is None else text[start:start + len(path) + 1 + end.start()]


def dmi_states(path):
    data = (ROOT / path).read_bytes()
    offset = 8
    while offset < len(data):
        length, kind = struct.unpack('>I4s', data[offset:offset + 8])
        chunk = data[offset + 8:offset + 8 + length]
        if kind == b'zTXt':
            keyword, rest = chunk.split(b'\0', 1)
            if keyword == b'Description':
                text = zlib.decompress(rest[1:]).decode()
                return {m[0]: int(m[1]) for m in re.findall(r'state = "([^"]*)"\n\tdirs = (\d+)', text)}
        offset += 12 + length
    return {}


class ChainsawTests(unittest.TestCase):
    def setUp(self):
        self.block = type_block(source('code/modules/1713/tools.dm'), CHAINSAW)

    def test_is_fastest_tree_felling_tool(self):
        speed = float(re.search(r'chopping_speed = ([\d.]+)', self.block)[1])
        others = [float(v) for path in ROOT.joinpath('code').rglob('*.dm')
                  for v in re.findall(r'^\tchopping_speed = ([\d.]+)', path.read_text(encoding='utf-8', errors='replace'), re.M)]
        others.remove(speed)
        self.assertLess(speed, min(others))

    def test_tree_chop_accepts_hatchet_subtypes(self):
        wild = source('code/game/objects/structures/wild.dm')
        attack = wild[wild.index('/obj/structure/wild/attackby('):]
        gate = attack[:attack.index('\n', attack.index('if (istype(W,'))]
        self.assertIn('istype(W,/obj/item/weapon/material/hatchet)', gate)
        self.assertIn('30*HT.chopping_speed', attack[:attack.index('/obj/structure/wild/proc/try_destroy')])

    def test_heavy_two_handed_power_tool_like_jackhammer(self):
        for line in ('w_class = ITEM_SIZE_GARGANTUAN', 'slot_flags = SLOT_BACK', 'health = 350'):
            self.assertIn(line, self.block)

    def test_recipe_follows_every_jackhammer_recipe(self):
        files = sorted((ROOT / 'config/crafting').glob('material_recipes_*.txt'))
        jack_files = [f for f in files if JACKHAMMER in f.read_text(encoding='utf-8', errors='replace')]
        self.assertTrue(jack_files)
        for path in files:
            text = path.read_text(encoding='utf-8', errors='replace')
            self.assertEqual(JACKHAMMER in text, CHAINSAW in text, path.name)
        recipe = 'RECIPE: /material/steel/,chainsaw,' + CHAINSAW + ',24,160,0,1,tools,178,0,0,8,null'
        for path in jack_files:
            self.assertIn(recipe, path.read_text(encoding='utf-8', errors='replace'), path.name)

    def test_research_gate_matches_jackhammer(self):
        nodes = source('code/modules/research_tree/research_node.dm')
        self.assertIn('"' + JACKHAMMER + '" = "power_tools"', nodes)
        self.assertIn('"' + CHAINSAW + '" = "power_tools"', nodes)

    def test_sprite_states_exist(self):
        states = dmi_states('icons/obj/chainsaw.dmi')
        self.assertEqual(states.get('chainsaw'), 1)
        for state in ('chainsaw_l', 'chainsaw_r', 'chainsaw_back'):
            self.assertEqual(states.get(state), 4, state)
            self.assertIn('"' + state + '"', self.block)


class TreeBumpChopping(unittest.TestCase):
    """Walking into a tree with a chopping tool held reuses the click chop."""

    def setUp(self):
        self.wild = source('code/game/objects/structures/wild.dm')

    def proc(self, name):
        start = self.wild.index(name)
        end = self.wild.index('\n\n', start)
        return self.wild[start:end]

    def test_bump_tool_list_matches_click_chop_gate(self):
        attack = self.wild[self.wild.index('/obj/structure/wild/attackby('):]
        gate = attack[:attack.index('\n', attack.index('if (istype(W,'))]
        click = set(re.findall(r'istype\(W, ?(/[\w/]+)\)', gate))
        bump = set(re.findall(r'istype\(W, ?(/[\w/]+)\)', self.proc('/proc/tree_chopping_tool(')))
        self.assertIn('/obj/item/weapon/material/hatchet', bump)
        self.assertEqual(click, bump)

    def test_human_bump_dispatches_after_mining(self):
        carbon = source('code/game/mob/living/carbon/carbon.dm')
        bump = carbon[carbon.index('/mob/living/human/Bump('):carbon.index('/mob/living/human/slip(')]
        self.assertLess(bump.index('try_bump_mining(AM)'), bump.index('try_bump_chopping(AM)'))
        self.assertLess(bump.index('try_bump_chopping(AM)'), bump.index('\t..()'))

    def test_bump_reuses_click_chop_and_reserves_before_spawn(self):
        body = self.proc('/mob/living/human/proc/try_bump_chopping(')
        self.assertIn('bump_mining_authority()', body)
        self.assertLess(body.index('bump_chop_target = A'), body.index('perform_bump_chop(A, HT)'))
        chop = self.proc('/mob/living/human/proc/perform_bump_chop(')
        self.assertIn('set waitfor = FALSE', chop)
        self.assertIn('T.attackby(HT, src)', chop)
        self.assertIn('bump_chop_target ||', body)
        held = self.proc('/mob/living/human/proc/held_chopping_tool(')
        self.assertLess(held.index('get_active_hand()'), held.index('get_inactive_hand()'))
        self.assertNotIn('swap_hand(', body + held)

    def test_reservation_is_runtime_only(self):
        self.assertIn('/mob/living/human/var/tmp/obj/structure/wild/bump_chop_target', self.wild)
        functions = source('code/modules/persistence/functions.dm')
        self.assertIn('key == "bump_chop_target"', functions)


if __name__ == '__main__':
    unittest.main()
