"""Stack recipe build guards keep the order and phases produce_recipe() had.

Before the guard registry, produce_recipe() called each feature's check inline:
generation, exercise and telecom skill gates, trail marker, car workshop,
waterwheel and offshore rig refusals, then deep water, religious works and
tribe knowledge. The car workshop, waterwheel and rig (and, silently, the three
skill gates) were checked again after the build wait, and the recipe menu hid
recipes refused by the three skill gates. Deep-water footing now also gets
a finish check so a missing deck cannot complete construction.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
# name: (order, after_wait, hides_recipe)
EXPECTED = {
    'skill_gate/civ_generation': (10, True, True),
    'skill_gate/exercise': (20, True, True),
    'skill_gate/cast_steel_anvil': (35, True, True),
    'skill_gate/civ_telecom': (30, True, True),
    'region_trail': (40, False, False),
    'car_workshop': (50, True, False),
    'waterwheel': (60, True, False),
    'offshore_rig': (70, True, False),
    'land_permit': (70, True, False),
    'well_fitting': (75, True, False),
    'deep_water': (80, True, False),
    'religious_work': (90, False, False),
    'handle': (94, False, True),
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

    def test_deep_water_accepts_real_decks_and_preserves_map_exceptions(self):
        text = (ROOT / 'code/game/objects/items/stacks/craft_guards.dm').read_text()
        start = text.index('/datum/craft_guard/deep_water/refusal(')
        refusal, deck = text[start:].split('/proc/vessel_building_deck_at(turf/T)', 1)
        deck = deck.split('// Religious works:', 1)[0]
        self.assertIn('!istype(T, /turf/floor/beach/water/deep) || map.ID == MAP_VOYAGE || map.ID == MAP_BATTLE_SHIPS', refusal)
        self.assertIn('if (bridge_deck_at(T) || vessel_building_deck_at(T))', refusal)
        self.assertTrue(refusal.split("\n\n", 1)[0].strip().endswith("You can't build here!</span>\""))
        # The footprint alone still includes holes. Use the actual live,
        # non-wall plank filed on the tile, not any cover or nearby overlap.
        self.assertIn('!QDELETED(L) && !L.sinking', deck)
        self.assertIn('if (hull_floor_plank(C, T))', deck)
        ledger = (ROOT / 'code/modules/naval/hull_ledger.dm').read_text()
        self.assertIn('return C.loc == T && !C.wall && !QDELETED(C)', ledger)
        # A loose frame, rudder on its own, ladder or raft is not a deck.
        self.assertIn('var/obj/structure/vehicleparts/frame/ship/F in T', deck)
        self.assertIn('F.loc != T || F.broken || QDELETED(F)', deck)
        self.assertIn('var/obj/structure/vehicleparts/axis/ship/A = F.axis', deck)
        self.assertIn('istype(A) && !QDELETED(A)', deck)
        self.assertIn('helm.z == T.z', deck)
        self.assertIn('get_dist(helm, T) <= 7', deck)
        self.assertIn('(F in A.components)', deck)
        self.assertNotIn('iscovered()', deck)
        self.assertTrue(deck.strip().endswith('return FALSE'))

    def test_timed_build_rechecks_footing_before_consumption_or_placement(self):
        stack = (ROOT / 'code/game/objects/items/stacks/stack.dm').read_text()
        body = stack.split('/obj/item/stack/proc/produce_recipe(', 1)[1]
        finish = body.index('var/late_refusal = craft_guard_refusal(H, recipe, CRAFT_GUARD_FINISH)')
        self.assertLess(body.index('if (!do_after(user, buildtime)'), finish)
        self.assertIn('secondary_refund(H)\n\t\t\treturn', body[finish:body.index('if (press_construction && !press_construction.valid())', finish)])
        self.assertLess(finish, body.index('if (use(required, (joinery || carving) ? null : H))'))
        self.assertLess(finish, body.index('O = new recipe.result_type(build_loc)'))
        # Cover the reported consumer, not just a synthetic instant recipe.
        recipes = (ROOT / 'config/crafting/material_recipes_global.txt').read_text()
        self.assertRegex(recipes, r'(?m)^RECIPE: /material/iron/,lever pump,/obj/structure/cellar_pump/lever,6,[1-9]\d*,')

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

    def test_only_well_recipes_need_a_puddle(self):
        # "jeweller's post" holds the word "well"; it once had to go over a
        # puddle and needed well-building skill. Wells are told by result type.
        stack = (ROOT / 'code/game/objects/items/stacks/stack.dm').read_text()
        self.assertNotIn('findtext(recipe.title, "well")', stack)
        self.assertIn('if (craft_recipe_builds_well(recipe))', stack)
        self.assertIn('!findtext(recipe.title, "wallet")', stack)
        wells = (ROOT / 'code/modules/1713/dug_wells.dm').read_text()
        self.assertIn('ispath(R.result_type, /obj/structure/sink/well)', wells)
        titles = {}
        for path in (ROOT / 'config/crafting').glob('*.txt'):
            for line in path.read_text(encoding='utf-8', errors='replace').splitlines():
                if line.startswith('RECIPE:'):
                    fields = [f.strip() for f in line[7:].split(',')]
                    if len(fields) > 2 and 'well' in fields[1]:
                        titles.setdefault(fields[1], set()).add(fields[2])
        # The jeweller's post is no longer buildable (players trade only with players).
        self.assertNotIn("jeweller's post", titles)
        for title in ('well', 'sandstone well', 'timber well lining'):
            self.assertTrue(all(t.startswith('/obj/structure/sink/well') for t in titles[title]), title)


if __name__ == '__main__':
    unittest.main()
