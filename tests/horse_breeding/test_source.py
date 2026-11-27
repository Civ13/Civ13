"""Horse breaking, breeding and shoeing: source contracts. Behaviour is in probe.dm:

    python3 tests/horse_breeding/test_source.py
    python3 tests/ecology_spawning/run_linux.py . tests/horse_breeding/probe.dm
"""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = (ROOT / 'code/modules/1713/horse_breeding.dm').read_text(encoding='utf-8')


def dmi_states(path):
    from PIL import Image
    meta = Image.open(ROOT / path).info['Description']
    return {line.split('"')[1] for line in meta.splitlines() if line.startswith('state = ')}


class HorseSource(unittest.TestCase):
    def test_states(self):
        states = dmi_states('icons/mob/animal_64.dmi')
        for n in ('', '2', '3', '4'):
            self.assertIn(f'foal{n}', states)
            self.assertIn(f'foal{n}_dead', states)
        self.assertTrue({'horseshoe', 'horseshoe_worn'} <= dmi_states('icons/obj/horseshoes.dmi'))

    def test_agent_ride_delay_includes_hitch_drag(self):
        agent = (ROOT / 'code/modules/agent_control/agent_movement.dm').read_text(encoding='utf-8')
        self.assertIn('delay = H.riding_mob.ride_delay() + H.riding_mob.hitch_drag()', agent)

    def test_cart_cost_enters_shared_deadline_before_dispatch(self):
        move = (ROOT / 'code/game/mob/mob_movement.dm').read_text(encoding='utf-8')
        client_move = move.split("/client/Move(", 1)[1].split("\n/mob/proc/lastMovedRecently(", 1)[0]
        apply_drag = "if (mob_is_human)\n\t\t\tmove_delay += H.ridden_handcart_drag()"
        self.assertEqual(client_move.count("ridden_handcart_drag()"), 1)
        before, after = client_move.split(apply_drag)
        self.assertIn("move_delay = world.time + mob.movement_delay()//set move delay", before)
        self.assertIn("H.human_subtile_deadline(move_delay, world.time, ordinal)", after)
        self.assertIn("mob.SelfMove(n, direct)", after)
        self.assertIn("move_delay /= t_movement_speed_multiplier", after)
        self.assertNotIn("istype(src, /mob/living/human)", client_move)

    def test_only_the_current_rider_pays_handcart_drag(self):
        hitch = (ROOT / 'code/game/objects/structures/cart_hitch.dm').read_text(encoding='utf-8')
        rider = hitch.split("/mob/living/human/proc/ridden_handcart_drag()", 1)[1].split("// ----", 1)[0]
        self.assertIn("!riding || QDELETED(riding_mob) || riding_mob.rider != src", rider)
        self.assertIn("return 0\n\treturn riding_mob.handcart_hitch_drag()", rider)
        self.assertNotIn("ride_delay()", rider)
        self.assertNotIn("hitched_train", rider)
        cart = hitch.split("/mob/living/simple_animal/proc/handcart_hitch_drag()", 1)[1].split("\n/mob/", 1)[0]
        self.assertIn("cart.hitched_to != src", cart)
        self.assertIn("cart.drag_delay(src) / max(1, draft_animal_pull(src))", cart)


    def test_shoeing_rechecks_the_horse_before_consuming_equipment(self):
        shoe = SRC.split('/obj/item/horseshoes/proc/shoe(', 1)[1].split('\n/', 1)[0]
        completion = shoe.split('do_after(user, 50, H)', 1)[1]
        guard = completion.split('return FALSE', 1)[0]
        self.assertIn('QDELETED(src) || QDELETED(H) || H.stat == DEAD || H.shod', guard)
        self.assertLess(completion.index('return FALSE'), completion.index('H.shod = TRUE'))
        self.assertLess(completion.index('H.shod = TRUE'), completion.index('qdel(src)'))

    def test_recipe_and_battle_maps(self):
        recipes = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
        research = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
        self.assertIn('RECIPE: /material/iron/,horseshoes,/obj/item/horseshoes,', recipes)
        self.assertIn('"/obj/item/horseshoes" = "iron_smithing",', research)
        self.assertIn('if (!map || !map.persistence)\n\t\treturn FALSE', SRC)


if __name__ == '__main__':
    unittest.main()
