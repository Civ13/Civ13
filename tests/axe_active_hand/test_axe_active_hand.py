"""Offline projection of the production placement guard, without starting BYOND."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
BRANCH = (ROOT / 'code/game/objects/items/weapons/material/ooga_booga_weapons.dm').read_text()
STACK = (ROOT / 'code/game/objects/items/stacks/stack.dm').read_text()


def production_refuses(source=BRANCH, **state):
    """Evaluate each production DM disjunct against synthetic actor/item state."""
    start = source.index('/proc/offer_crafted_axe_to_active_hand(')
    guard = source[start:].splitlines()[1].strip()
    assert guard.startswith('if (') and guard.endswith(')'), guard
    expressions = guard[4:-1].split(' || ')
    values = {
        'QDELETED(user)': state.get('user_deleted', False),
        'QDELETED(axe)': state.get('axe_deleted', False),
        'user.stat != CONSCIOUS': state.get('unconscious', False),
        'user.incapacitated()': state.get('incapacitated', False),
        '!isturf(user.loc)': state.get('inside_container', False),
        'axe.loc != user.loc': state.get('not_on_actor_tile', False),
        'user.get_active_hand()': state.get('active_occupied', False),
    }
    assert set(expressions) == set(values), expressions
    return any(values[expression] for expression in expressions)


class PlacementContract(unittest.TestCase):
    def test_empty_active_hand_is_eligible(self):
        self.assertFalse(production_refuses())

    def test_unavailable_actor_or_output_leaves_ground_fallback(self):
        for state in ('user_deleted', 'axe_deleted', 'unconscious', 'incapacitated',
                      'inside_container', 'not_on_actor_tile', 'active_occupied'):
            with self.subTest(state=state):
                self.assertTrue(production_refuses(**{state: True}))

    def test_inactive_hand_does_not_block_current_active_hand(self):
        self.assertFalse(production_refuses(inactive_occupied=True))
        self.assertTrue(production_refuses(active_occupied=True))

    def test_missing_active_hand_guard_is_detected(self):
        modified = BRANCH.replace(' || user.get_active_hand()', '', 1)
        self.assertNotEqual(modified, BRANCH)
        with self.assertRaises(AssertionError):
            production_refuses(source=modified)

    def test_missing_incapacity_guards_are_detected(self):
        for check in (' || user.stat != CONSCIOUS', ' || user.incapacitated()'):
            with self.subTest(check=check):
                altered = BRANCH.replace(check, '', 1)
                self.assertNotEqual(altered, BRANCH)
                with self.assertRaises(AssertionError):
                    production_refuses(source=altered)

    def test_calls_happen_after_payment_and_output(self):
        assembly = BRANCH.split('/obj/item/weapon/branch/proc/assemble_flint_axe(', 1)[1].split('\n/obj/', 1)[0]
        self.assertLess(assembly.index('binding.use(1)'), assembly.index('new(get_turf(user))'))
        self.assertLess(assembly.index('qdel(src)'), assembly.index('offer_crafted_axe_to_active_hand(user, axe)'))
        build = STACK.split('/obj/item/stack/proc/produce_recipe(', 1)[1].split('\n/obj/item/stack/Topic', 1)[0]
        self.assertIn('istype(src, /obj/item/stack/material/stone) && recipe.result_type == /obj/item/weapon/material/hatchet/tribal', build)
        self.assertLess(build.index('if (use(required,'), build.index('offer_crafted_axe_to_active_hand(user, O)'))


if __name__ == '__main__':
    unittest.main()
