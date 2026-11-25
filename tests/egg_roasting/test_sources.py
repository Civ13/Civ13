"""Source contracts for whole eggs on the adjacent oven click path."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
FOOD = ROOT / 'code/modules/reagents/reagent_containers/food/snacks.dm'
BIRDS = ROOT / 'code/game/mob/living/simple_animal/friendly/birds.dm'
OVEN = ROOT / 'code/game/objects/structures/kitchen/oven.dm'
EGG_PATH = '/obj/item/weapon/reagent_containers/food/snacks/'


def proc_body(path, declaration):
    contents = path.read_text(encoding='utf-8-sig')
    body = re.search(r'^' + re.escape(declaration) + r'\([^\n]*\)\n(.*?)(?=^/[a-z_]|\Z)',
                     contents, re.MULTILINE | re.DOTALL)
    if body is None:
        raise AssertionError(f'Missing procedure: {declaration}')
    return body.group(1)


class EggRoasting(unittest.TestCase):
    def test_both_whole_eggs_leave_oven_clicks_to_the_cooker(self):
        for egg in ('egg', 'turkeyegg'):
            with self.subTest(egg=egg):
                body = proc_body(FOOD, EGG_PATH + egg + '/afterattack')
                skip = ('if (istype(O, /obj/structure/pot) || istype(O, /obj/structure/oven))'
                        '\n\t\treturn')
                self.assertIn(skip, body)
                # Occupied and open ovens use the same type exclusion. Open
                # glassware still receives raw egg through the original path.
                self.assertLess(body.index(skip), body.index('O.is_open_container()'))
                self.assertLess(body.index('O.is_open_container()'), body.index('reagents.trans_to('))
                self.assertLess(body.index('reagents.trans_to('), body.index('qdel(src)'))

    def test_oven_still_places_and_ejects_the_same_roasted_item(self):
        body = proc_body(OVEN, '/obj/structure/oven/attackby')
        reject = body.index('if (space <= 0 || space - I.w_class < 0)')
        removal = body.index('H.remove_from_mob(I)', reject)
        self.assertIn('\n\t\treturn\n', body[reject:removal])
        self.assertIn('I.loc = src', body[removal:])
        oven = OVEN.read_text(encoding='utf-8-sig')
        roasted = oven.index('F.roasted = TRUE')
        self.assertLess(roasted, oven.index('I.loc = get_turf(src)', roasted))

    def test_cooked_eggs_retire_incubation_before_advancing_or_rescheduling(self):
        for egg, species, delay in (('egg', 'chicken', 40), ('turkeyegg', 'turkey', 50)):
            with self.subTest(egg=egg):
                body = proc_body(BIRDS, EGG_PATH + egg + '/proc/grow')
                stop = 'if (roasted)\n\t\tgrowing = FALSE\n\t\tprocessing_objects -= src\n\t\treturn'
                self.assertIn(stop, body)
                self.assertLess(body.index(stop), body.index(f'if (isturf(loc) && {species}_count.len < 80)'))
                self.assertLess(body.index(stop), body.index('amount_grown += 1'))
                self.assertIn(f'spawn({delay})\n\t\tgrow()', body)


if __name__ == '__main__':
    unittest.main()
