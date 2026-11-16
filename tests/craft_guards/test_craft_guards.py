"""Stack recipe build guards keep the order and phases produce_recipe() had.

Before the guard registry, produce_recipe() called each feature's check inline:
generation, exercise and telecom skill gates, trail marker, car workshop,
waterwheel and offshore rig refusals, then deep water, religious works and
tribe knowledge. The car workshop, waterwheel and rig (and, silently, the three
skill gates) were checked again after the build wait, and the recipe menu hid
recipes refused by the three skill gates. New guards get their own entry here.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
# name: (order, after_wait, hides_recipe)
EXPECTED = {
    'skill_gate/civ_generation': (10, True, True),
    'skill_gate/exercise': (20, True, True),
    'skill_gate/civ_telecom': (30, True, True),
    'region_trail': (40, False, False),
    'car_workshop': (50, True, False),
    'waterwheel': (60, True, False),
    'offshore_rig': (70, True, False),
    'land_permit': (70, True, False),
    'well_fitting': (75, True, False),
    'deep_water': (80, False, False),
    'religious_work': (90, False, False),
    'needs': (95, False, True),
    'tribe_knowledge': (100, False, False),
}
DECL = re.compile(r'^/datum/craft_guard/([\w/]+)\r?\n((?:\t[^\n]*\r?\n)*)', re.M)
FLAGS = {'skill_gate': {'after_wait': True, 'hides_recipe': True}}


def guards():
    found = {}
    for path in sorted((ROOT / 'code').rglob('*.dm')):
        text = path.read_text(encoding='utf-8', errors='replace')
        for name, body in DECL.findall(text):
            if name in FLAGS:
                continue
            values = dict(re.findall(r'^\t(order|after_wait|hides_recipe) = (\w+)', body, re.M))
            inherited = FLAGS.get(name.split('/')[0], {}) if '/' in name else {}
            found[name] = (int(values.get('order', 100)),
                           values.get('after_wait', 'TRUE' if inherited.get('after_wait') else 'FALSE') == 'TRUE',
                           values.get('hides_recipe', 'TRUE' if inherited.get('hides_recipe') else 'FALSE') == 'TRUE')
    return found


class CraftGuardTest(unittest.TestCase):
    def test_guards_keep_their_reviewed_order_and_phases(self):
        self.assertEqual(guards(), EXPECTED)

    def test_produce_recipe_asks_the_registry(self):
        stack = (ROOT / 'code/game/objects/items/stacks/stack.dm').read_text()
        body = stack[stack.index('/obj/item/stack/proc/produce_recipe('):stack.index('/obj/item/stack/proc/crafting_stack_accessible(')]
        start = body.index('craft_guard_refusal(H, recipe, CRAFT_GUARD_START)')
        self.assertLess(start, body.index('if (!can_use(required))'))
        self.assertLess(body.index('if (!do_after(user, buildtime)'), body.index('craft_guard_refusal(H, recipe, CRAFT_GUARD_FINISH)'))
        for old in ('civ_generation_can_build', 'exercise_can_build', 'civ_telecom_can_build',
                    'region_trail_build_refusal', 'car_workshop_build_refusal', 'waterwheel_build_refusal',
                    'offshore_rig_build_refusal', 'religion type doesn', 'Gorilla tribesman', 'beach/water/deep'):
            self.assertNotIn(old, body)
        menu = (ROOT / 'code/game/objects/items/stacks/stack_makeable.dm').read_text()
        self.assertIn('craft_guard_refusal(H, R, CRAFT_GUARD_MENU)', menu)

    def test_religious_rules_match_the_old_chain(self):
        text = (ROOT / 'code/game/objects/items/stacks/craft_guards.dm').read_text()
        rules = re.findall(r'^\tlist\(list\(([^)]*)\), list\(([^)]*)\)\),$', text, re.M)
        words = [re.findall(r'"([^"]+)"', w) for w, _ in rules]
        banned = [set(re.findall(r'"([^"]+)"', b)) for _, b in rules]
        self.assertEqual([w[0] for w in words], ['talisman', 'totem', 'monumental ominous statue of the deep-one',
                                                 'monumental stone buddha', 'monumental statue of a giant ape'])
        self.assertEqual(banned, [{'Priests', 'Monks', 'Clerics'}, {'Priests', 'Monks', 'Clerics', 'Cultists'},
                                  {'Shamans', 'Priests', 'Monks', 'Clerics'}, {'Shamans', 'Priests', 'Cultists', 'Clerics'},
                                  {'Monks', 'Priests', 'Cultists', 'Clerics'}])


if __name__ == '__main__':
    unittest.main()
