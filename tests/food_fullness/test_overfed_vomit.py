"""Force-feeding someone past capacity makes them throw up (Val, 2026-11-15).

Feeding another person no longer stops at the fullness limit: the food or
drink goes down, and if the stomach is then past what it holds, they vomit.
Eating for yourself keeps its refusal. The native behaviour (stomach
fullness, purge, toxin relief) is checked in tests/chemistry/biochemistry.dm.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SNACKS = ROOT / 'code/modules/reagents/reagent_containers/food/snacks.dm'
KITCHEN = ROOT / 'code/game/objects/items/weapons/material/kitchen.dm'
CONTAINERS = ROOT / 'code/modules/reagents/reagent_containers.dm'
HUMAN = ROOT / 'code/game/mob/living/carbon/human/human.dm'
HUMAN_HELPERS = HUMAN.with_name('human_helpers.dm')


def proc_body(text, signature):
    start = text.index(signature)
    rest = text[start + len(signature):]
    end = re.search(r'\n(?=\S)', rest)
    return rest[: end.start() if end else len(rest)]


class OverfedVomitTest(unittest.TestCase):
    def test_snacks_feed_other_vomits_instead_of_refusing(self):
        body = proc_body(SNACKS.read_text(encoding='utf-8'),
                         '/obj/item/weapon/reagent_containers/food/snacks/attack(')
        feed_other = body[body.index('//If you\'re feeding somebody'):]
        self.assertNotIn('cannot force anymore', feed_other)
        self.assertIn('C != user && C.is_overfed()', body)
        self.assertIn('C.overfed_vomit(user)', body)
        # Eating for yourself still refuses past the limit.
        self.assertIn('You cannot force any more of [src] to go down your throat.', body)

    def test_utensil_feeds_after_checks_and_vomits(self):
        body = proc_body(KITCHEN.read_text(encoding='utf-8'),
                         '/obj/item/weapon/material/kitchen/utensil/attack(')
        self_part, other_part = body.split('else\n\t\t\tuser.visible_message', 1)
        self.assertLess(self_part.index('food_fullness_limit()'), self_part.index('trans_to_mob'))
        self.assertLess(other_part.index('do_mob'), other_part.index('trans_to_mob'))
        self.assertIn('M.overfed_vomit(user)', other_part)

    def test_edged_scoop_utensils_reach_scooping_without_cutting(self):
        scoop = proc_body(SNACKS.read_text(encoding='utf-8'),
                          '/obj/item/weapon/reagent_containers/food/snacks/attackby(')
        self.assertIn('if (W.edge && !(istype(U) && U.scoop_food))', scoop)
        self.assertIn('var/obj/item/weapon/reagent_containers/food/snacks/slice = new slice_path(loc)', scoop)
        self.assertLess(scoop.index('if (istype(U) && U.scoop_food)'), scoop.index('reagents.trans_to_obj(U'))

    def test_voluntary_solid_food_diet_is_shared_and_scoop_remembers_classification(self):
        snacks = SNACKS.read_text(encoding='utf-8')
        scoop = proc_body(snacks, '/obj/item/weapon/reagent_containers/food/snacks/attackby(')
        self.assertIn('U.loaded_non_vegetarian = non_vegetarian', scoop)
        self.assertLess(scoop.index('reagents.trans_to_obj(U'), scoop.index('U.loaded_non_vegetarian = non_vegetarian'))
        self_direct, force_direct = proc_body(snacks, '/obj/item/weapon/reagent_containers/food/snacks/attack(').split(
            "//If you're feeding somebody", 1)
        self.assertIn('C.can_eat_solid_food_diet(non_vegetarian)', self_direct)
        self.assertNotIn('can_eat_solid_food_diet', force_direct)
        kitchen = KITCHEN.read_text(encoding='utf-8')
        self_utensil, force_utensil = proc_body(kitchen, '/obj/item/weapon/material/kitchen/utensil/attack(').split(
            'else\n\t\t\tuser.visible_message', 1)
        self.assertLess(self_utensil.index('M.can_eat_solid_food_diet(loaded_non_vegetarian)'),
                        self_utensil.index('trans_to_mob'))
        self.assertNotIn('can_eat_solid_food_diet', force_utensil)
        reset = proc_body(kitchen, '/obj/item/weapon/material/kitchen/utensil/on_reagent_change(')
        self.assertIn('if (!reagents?.total_volume && !isnull(loaded))', reset)
        self.assertIn('loaded = null', reset)
        self.assertIn('loaded_non_vegetarian = FALSE', reset)
        self.assertIn('overlays.Cut()', reset)
        diet = proc_body(HUMAN_HELPERS.read_text(encoding='utf-8'),
                         '/mob/living/human/proc/can_eat_solid_food_diet(')
        self.assertIn('gorillaman || find_trait("Vegan")', diet)
        self.assertIn('wolfman || crab || find_trait("Carnivore")', diet)

    def test_last_scoop_returns_container_to_scooper(self):
        snacks = SNACKS.read_text(encoding='utf-8')
        scoop = proc_body(snacks, '/obj/item/weapon/reagent_containers/food/snacks/attackby(')
        self.assertRegex(scoop, r'if \(!reagents\.total_volume\)\s+over\(user\)')
        finish = proc_body(snacks, '/obj/item/weapon/reagent_containers/food/snacks/proc/over(')
        self.assertRegex(finish, r'if \(loc == handler\)\s+handler\.drop_from_inventory\(src\)')
        self.assertLess(finish.index('handler.put_in_hands(empty_container)'), finish.index('qdel(src)'))
        self.assertNotIn('usr', finish)

    def test_drinks_force_fed_vomit(self):
        body = proc_body(CONTAINERS.read_text(encoding='utf-8'),
                         '/obj/item/weapon/reagent_containers/proc/standard_feed_mob(')
        self.assertLess(body.index('trans_to_mob'), body.index('overfed.is_overfed()'))
        self.assertIn('target != user', body)

    def test_all_vomiting_purges_the_stomach(self):
        text = HUMAN.read_text(encoding='utf-8')
        throw_up = proc_body(text, '/mob/living/human/proc/throw_up(')
        self.assertIn('ingested.remove_any', throw_up)
        self.assertIn('stomach_holds_poison()', throw_up)
        for name in ('vomit()', 'vomit_blood()'):
            self.assertIn('throw_up(', proc_body(text, '/mob/living/human/proc/' + name))


if __name__ == '__main__':
    unittest.main()
