"""Riding on top of vehicles: offline seam checks.

The native probe (probe.dm, run.py) checks the behaviour in a real build:
getting up from outside and through a hatch, walking across the roof, riding
along when the vehicle drives and turns, sight over walls, melee only between
riders on top, aimed shots, jumping off and falling. These checks keep the
hooks that the probe cannot reach in place.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


DECKS = read('code/modules/1713/machinery/modular_vehicles/vehicle_decks.dm')
TERRAIN = read('code/modules/visibility/los_terrain.dm')
CONTEXT = read('code/modules/visibility/los_context.dm')
CLICK = read('code/_onclick/other_mobs.dm')
MOVE = read('code/game/mob/mob_movement.dm')
CLIMB = read('code/game/objects/structures/tree_climbing.dm')
PROJECTILE = read('code/modules/projectiles/projectile.dm')
HUMAN = read('code/game/mob/living/carbon/human/human.dm')
DME = read('civ13.dme')
BUS = read('code/modules/1713/machinery/modular_vehicles/carparts/bus.dm')
WORKS = read('code/modules/craft/vehicle_works.dm')


def proc(text, name):
    start = text.index(name)
    end = re.search(r'\n(?=/|#define|\Z)', text[start + 1:])
    return text[start:start + 1 + end.start()] if end else text[start:]


class VehicleDeckSources(unittest.TestCase):
    def test_included(self):
        self.assertIn('modular_vehicles\\vehicle_decks.dm', DME)

    def test_one_level_only(self):
        # A raised deck on the street's own level: nothing changes z.
        self.assertNotIn('multiz_level_above', DECKS)
        self.assertNotIn('GetAbove', DECKS)
        self.assertNotIn('spawn(', DECKS)

    def test_sight(self):
        self.assertIn('return LOS_EYE_DECK', proc(TERRAIN, '/proc/los_eye_level('))
        self.assertIn('los_on_vehicle_deck(body)', proc(TERRAIN, '/proc/los_canopy_field_for('))
        self.assertIn('los_on_vehicle_deck(body)', proc(CONTEXT, '/datum/los_context/proc/policy_key('))
        self.assertIn('if (vehicle_deck)', proc(HUMAN, '/mob/living/human/proc/look_into_distance('))

    def test_click_move_and_climb_down(self):
        unarmed = proc(CLICK, '/mob/living/human/UnarmedAttack(')
        self.assertLess(unarmed.index('grab_climb_tree(A)'), unarmed.index('grab_climb_vehicle(A)'))
        self.assertLess(unarmed.index('grab_climb_vehicle(A)'), unarmed.index('A.attack_hand('))
        move = proc(MOVE, '/client/Move(')
        self.assertLess(move.index('vehicle_deck_step(direct)'), move.index('start_climb_down()'))
        self.assertIn('move_delay = world.time + mob.movement_delay()', move[move.index('if (mob.vehicle_deck'):move.index('vehicle_deck_step(direct)')])
        self.assertIn('start_vehicle_deck_down()', proc(CLIMB, '/mob/living/human/verb/climb_down_tree_verb('))

    def test_melee_and_animals(self):
        self.assertIn('return !vehicle_deck_same_roof(attacker, target)', proc(CLIMB, '/proc/tree_melee_blocked('))
        self.assertIn('los_on_vehicle_deck(M)', proc(CLIMB, '/mob/living/simple_animal/proc/can_reach_tree_climber('))

    def test_shots(self):
        self.assertIn('fired_from_deck_axis = vehicle_deck_axis(user)', PROJECTILE)
        self.assertIn('in projectile_tile_order(T)', PROJECTILE)
        self.assertIn('if (fired_from_deck_axis && fired_from_deck_axis == F.axis)', PROJECTILE)


    def test_projectile_deck_order_matches_original_for_all_small_cases(self):
        # This is an offline model of the pure predicate and the unchanged
        # riders-first ordering, not native BYOND projectile execution.
        order = proc(PROJECTILE, '/obj/item/projectile/proc/projectile_tile_order(')
        self.assertIn('if ((L == original || fired_from_deck_axis) && los_on_vehicle_deck(L))', order)
        self.assertIn('return T.contents', order)
        self.assertIn('return riders + (T.contents - riders)', order)
        deck = proc(TERRAIN, '/proc/los_on_vehicle_deck(')
        self.assertIn('return ismob(M) && M.vehicle_deck && M.vehicle_deck.loc == M.loc && isturf(M.loc)', deck)

        def result(target, shot_from_deck, deck_flags, condition):
            living = ('a', 'b', 'c')
            contents = ('wall', 'a', 'b', 'c', 'other')
            calls = []
            def on_deck(mob):
                calls.append(mob)
                return deck_flags[living.index(mob)]
            riders = [mob for mob in living if condition(mob, target, shot_from_deck, on_deck)]
            return tuple(riders + [item for item in contents if item not in riders]), calls

        old = lambda mob, target, fired, deck: deck(mob) and (mob == target or fired)
        new = lambda mob, target, fired, deck: (mob == target or fired) and deck(mob)
        wrong = lambda mob, target, fired, deck: (mob == target and deck(mob)) or fired
        from itertools import product
        for target, fired, flags in product((None, 'a', 'b', 'c', 'other'), (False, True), product((False, True), repeat=3)):
            old_order, old_calls = result(target, fired, flags, old)
            new_order, new_calls = result(target, fired, flags, new)
            self.assertEqual(old_order, new_order, (target, fired, flags))
            self.assertLessEqual(len(new_calls), len(old_calls))
        # A stray, ground-fired shot skips every predicate call; a deck-fired
        # shot still checks every body, including non-riders.
        self.assertEqual(result(None, False, (True, False, True), new)[1], [])
        self.assertEqual(result(None, True, (True, False, True), new)[1], ['a', 'b', 'c'])
        self.assertNotEqual(result(None, True, (True, False, True), new)[0],
                            result(None, True, (True, False, True), wrong)[0])

    def test_double_decker_bus(self):
        self.assertIn('carparts\\bus.dm', DME)
        self.assertIn('upper_deck = TRUE', BUS)
        self.assertIn('/obj/structure/vehicle_stairs', proc(DECKS, '/proc/vehicle_deck_hatch('))
        self.assertIn('"Double-decker bus" = list(', WORKS)
        self.assertNotIn('spawn(', BUS)


    def test_train_roofs(self):
        life = read('code/game/mob/living/carbon/human/human_life.dm')
        self.assertIn('process_train_roofs()', life)
        trains = read('code/modules/1713/train_platforms.dm')
        self.assertIn('train_deck_clearance(cargo, OPPOSITE_DIR(way))', trains)
        self.assertIn('hang_roof_images()', trains)
        self.assertIn('train_deck_segment(D)', proc(DECKS, '/proc/vehicle_deck_walkable('))


if __name__ == '__main__':
    unittest.main()
