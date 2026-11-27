"""Offline checks for gem science uses (code/modules/1713/gem_science.dm)."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/gem_science.dm'
STATES = ('jewel_bearing', 'jewel_bearing_garnet', 'diamond_grit', 'diamond_drill_bit', 'lapping_wheel',
          'quartz_uncut', 'quartz', 'galena', 'crystal_radio', 'quartz_crystal_unit', 'quartz_watch',
          'emery_powder', 'garnet_paper', 'rock_crystal_lens', 'jewel_lens', 'ruby_boule', 'ruby_rod',
          'loupe', 'gem_scale', 'refractometer')


def dmi_states(path):
    from PIL import Image
    return re.findall(r'state = "([^"]+)"', Image.open(path).info['Description'])


class GemScienceTest(unittest.TestCase):
    def setUp(self):
        self.text = SOURCE.read_text(encoding='utf-8')

    def test_used_states_exist(self):
        states = dmi_states(ROOT / 'icons/obj/gem_science.dmi')
        self.assertEqual(tuple(states), STATES)
        for used in re.findall(r'\ticon_state = "([^"]+)"', self.text):
            self.assertIn(used, states)

    def test_jewel_bearings(self):
        # Ruby and sapphire give four jewels, garnet two cheaper ones.
        for stone, kind, count in (('ruby', '/obj/item/stack/jewel_bearing', 4),
                                   ('sapphire', '/obj/item/stack/jewel_bearing', 4),
                                   ('garnet', '/obj/item/stack/jewel_bearing/garnet', 2)):
            self.assertRegex(self.text, rf'/obj/item/stack/gemstone/{stone}\n\tbearing_type = {re.escape(kind)}\n\tbearing_yield = {count}')
        self.assertIn('crafting_node_allowed_or_warn(H, "optics_instruments")', self.text)
        for target in ('/obj/item/weapon/watch/pocket/attackby', '/obj/item/clothing/gloves/watch/attackby',
                       '/obj/item/weapon/compass/attackby'):
            self.assertIn(target, self.text)
        self.assertIn('C.max_offset = min(C.max_offset, 2)', self.text)

    def test_watches_read_through_watch_reading(self):
        for path in ('code/modules/1713/apparel_industrial.dm', 'code/game/objects/items/clothing/gloves/color.dm'):
            text = (ROOT / path).read_text(encoding='utf-8')
            self.assertIn('watch_reading(src)', text)
            self.assertNotIn('It is now [clock_time()]', text)
        self.assertIn('min = round(min / 15) * 15', self.text)

    def test_diamond_grit_and_lap(self):
        gems = (ROOT / 'code/modules/1713/gemstones.dm').read_text(encoding='utf-8')
        self.assertIn('gem_lap_near(H, cut_type)', gems)
        self.assertIn('lap.use_charge(cut_type)', gems)
        self.assertIn('gem_flaw_leftovers(T, cut_type)', gems)
        self.assertIn('/obj/item/stack/ore/diamond/attackby', self.text)
        self.assertIn('crafting_node_allowed_or_warn(H, "machined_tools")', self.text)
        # Diamond goes on the rotary drill, never the percussive jackhammer.
        self.assertNotIn('jackhammer', self.text)
        self.assertIn('type == /obj/structure/drill', self.text)
        recipes = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
        nodes = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
        self.assertIn(',lapping wheel,/obj/structure/lapping_wheel,', recipes)
        self.assertIn('"/obj/structure/lapping_wheel" = "workshops",', nodes)

    def test_quartz_and_crystal_set(self):
        gems = (ROOT / 'code/modules/1713/gemstones.dm').read_text(encoding='utf-8')
        self.assertIn('/obj/item/stack/ore/gem/quartz = 30,', gems)
        # The crystal set's detector is galena from lead ore, not quartz.
        self.assertIn('/obj/item/stack/ore/lead/attackby', self.text)
        self.assertRegex(self.text, r'/obj/item/weapon/radio/crystal_set\n(?:\t.*\n)*?\ttransmitter = FALSE')
        self.assertIn('crafting_node_allowed_or_warn(H, "electricity")', self.text)
        # Quartz holds a radio frequency (1920s) and keeps a watch's time (1969).
        self.assertIn('crafting_node_allowed_or_warn(H, "assembly_line")', self.text)
        self.assertIn('crafting_node_allowed_or_warn(H, "digital_computing")', self.text)
        self.assertIn('R.crystal_freq == source_freq', self.text)
        self.assertNotIn('/obj/item/weapon/hammer)', self.text)
        self.assertIn('watch.jewelled || watch.quartz_movement', self.text)

    def test_reading_stone_emery_and_garnet_paper(self):
        gems = (ROOT / 'code/modules/1713/gemstones.dm').read_text(encoding='utf-8')
        self.assertIn('/obj/item/stack/garnet_paper/attack_self(mob/user)', self.text)
        self.assertIn('istype(M.material, /material/wood)', self.text)
        self.assertIn('/mob/living/human/reading_light_problem()', self.text)
        self.assertIn('crafting_node_allowed_or_warn(H, "glassworking")', self.text)
        self.assertIn('crafting_node_allowed_or_warn(H, "factories")', self.text)
        # Emery is corundum, so it cannot cut ruby, sapphire or diamond.
        self.assertIn('/proc/gem_needs_diamond(cut_type)', self.text)
        self.assertIn('lap.use_charge(cut_type)', gems)
        self.assertIn('gem_lap_near(H, cut_type)', gems)

    def test_synthetic_ruby_and_laser_rod(self):
        # Flame fusion (1902) needs a lit furnace; the rod (1960) a diamond lap.
        self.assertIn('candidate.is_open_flame()', self.text)
        self.assertIn('crafting_node_allowed_or_warn(H, "consumer_electronics")', self.text)
        self.assertIn('J.amount = BOULE_BEARINGS', self.text)
        self.assertIn('binoculars/binoculars/rangefinder(T)', self.text)
        # A boule is not a gemstone, so it has no trade value as a stone.
        self.assertNotIn('/obj/item/stack/gemstone/ruby_boule', self.text)

    def test_flame_fusion_skips_blocked_furnaces_and_rechecks_the_selected_one(self):
        ruby = self.text.split('/obj/item/stack/emery_powder/attack_self(mob/user)', 1)[1].split('/obj/item/ruby_boule', 1)[0]
        before, after = ruby.split('do_after(H, 100, F)', 1)
        self.assertIn('if (candidate.is_open_flame() && candidate.Adjacent(H))', before)
        self.assertIn('!F.is_open_flame() || !F.Adjacent(H) || loc != H || !use(BOULE_EMERY)', after)
        self.assertNotIn(' in range(', after)

    def test_ruby_bearings_recheck_both_tools_and_reach_before_output(self):
        bearing = self.text.split('/obj/item/ruby_boule/attackby', 1)[1].split('/obj/structure/lapping_wheel/proc/make_ruby_rod', 1)[0]
        before, after = bearing.split('do_after(H, 80, src)', 1)
        self.assertIn('var/obj/item/hammer = H.get_inactive_hand()', before)
        for condition in ('H.get_active_hand() != W', '!is_tool(W, TOOL_CHISEL)', 'H.get_inactive_hand() != hammer',
                          '!is_tool(hammer, TOOL_HAMMER)', '!ruby_workpiece_reachable(src, H)'):
            self.assertIn(condition, after)
            self.assertLess(after.index(condition), after.index('new(get_turf(src))'))

    def test_ruby_rod_checks_wheel_reach_before_charging(self):
        rod = self.text.split('/obj/structure/lapping_wheel/proc/make_ruby_rod', 1)[1].split('/obj/item/ruby_rod\n', 1)[0]
        before, after = rod.split('do_after(H, 100, src)', 1)
        self.assertIn('!Adjacent(H)', before)
        self.assertIn('QDELETED(src) || !Adjacent(H) || QDELETED(B) || B.loc != H', after)
        self.assertLess(after.index('!Adjacent(H)'), after.index('charges -= ROD_CHARGES'))

    def test_ruby_targets_keep_held_route_but_require_floor_reach(self):
        helper = self.text.split('/proc/ruby_workpiece_reachable', 1)[1].split('/obj/item/stack/emery_powder/attack_self', 1)[0]
        self.assertIn('target.loc == H || (isturf(target.loc) && target.Adjacent(H))', helper)
        retrofit = self.text.split('binoculars/binoculars/attackby', 1)[1].split('// ---- Gem testing:', 1)[0]
        before, after = retrofit.split('do_after(H, 60, src)', 1)
        self.assertIn('W.loc != H || !ruby_workpiece_reachable(src, H)', before)
        self.assertIn('QDELETED(W) || W.loc != H || !ruby_workpiece_reachable(src, H)', after)
        self.assertLess(after.index('!ruby_workpiece_reachable(src, H)'), after.index('qdel(W)'))
        self.assertIn('if (was_held)\n\t\t\tH.put_in_hands(R)', after)

    def test_gem_testing(self):
        recipes = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
        nodes = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
        gems = (ROOT / 'code/modules/1713/gemstones.dm').read_text(encoding='utf-8')
        for path, node in (('/obj/item/gem_tester', 'optics_instruments'), ('/obj/item/gem_tester/scale', 'optics_instruments'),
                           ('/obj/item/gem_tester/refractometer', 'electricity')):
            self.assertIn(f',{path},', recipes)
            self.assertIn(f'"{path}" = "{node}",', nodes)
        # A mapped stone splits half as often; a refractometer cannot read diamond.
        self.assertIn('(inclusions_mapped ? 2 : 1)', gems)
        self.assertIn('list("diamond", 10, 3.52, 0, FALSE)', self.text)
        self.assertIn('list("ruby", 9, 4.0, 1.77, TRUE)', self.text)

    def test_included_after_lanyards(self):
        dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        self.assertLess(dme.index('lanyards.dm'), dme.index('gem_science.dm'))


if __name__ == '__main__':
    unittest.main()
