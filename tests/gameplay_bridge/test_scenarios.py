"""Inert acceptance-oracle controls. They do not execute Nomads mechanics."""
import unittest
from scenarios import evaluate


class SurvivalOracles(unittest.TestCase):
    def after(self, **kwargs):
        return dict(alive=True, normal_mechanics=True, admin_shortcuts=False, **kwargs)

    def test_supplied_food_water_requires_real_resource_and_body_changes(self):
        before = dict(nutrition=100, hydration=100, food_units=10, water_units=20)
        after = self.after(nutrition=110, hydration=110, food_units=8, water_units=15)
        self.assertEqual(evaluate("supplied_food_water", before, after), [])
        after.update(nutrition=100, hydration=100, model_claim="I ate and drank")
        self.assertEqual(evaluate("supplied_food_water", before, after), ["nutrition_increased", "hydration_increased"])

    def test_tool_shelter_requires_costs_timing_and_protection(self):
        before = dict(gathered_units=0, crafted_tools=0, shelter_parts=0, paid_materials=0, elapsed_ticks=0)
        after = self.after(gathered_units=4, crafted_tools=1, shelter_parts=2, paid_materials=3,
                           elapsed_ticks=100, shelter_protects_actor=True)
        self.assertEqual(evaluate("gather_tool_shelter", before, after), [])
        after["paid_materials"] = 0
        self.assertEqual(evaluate("gather_tool_shelter", before, after), ["paid_materials_increased"])

    def test_cooperation_conserves_identity_and_quantity(self):
        before = dict(item_owner="actor", item_identity="harness-private-id", total_items=1)
        after = self.after(item_owner="peer", item_identity="harness-private-id", total_items=1,
                           peer_received_coordinate_message=True)
        self.assertEqual(evaluate("peer_exchange", before, after), [])
        after["total_items"] = 2
        self.assertEqual(evaluate("peer_exchange", before, after), ["no_duplication"])

    def test_harness_state_is_required_model_claims_are_insufficient(self):
        with self.assertRaises(ValueError):
            evaluate("supplied_food_water", {}, {"model_claim": "success"})

    def test_missing_item_identity_cannot_count_as_cooperation(self):
        before = dict(item_owner="actor", total_items=1)
        after = self.after(item_owner="peer", total_items=1, peer_received_coordinate_message=True)
        self.assertEqual(evaluate("peer_exchange", before, after), ["item_identity_conserved"])

    def test_death_and_admin_shortcuts_never_count_as_success(self):
        before = dict(nutrition=100, hydration=100, food_units=10, water_units=20)
        after = self.after(nutrition=110, hydration=110, food_units=8, water_units=15)
        after.update(alive=False, admin_shortcuts=True)
        self.assertEqual(evaluate("supplied_food_water", before, after), ["actor_alive", "ordinary_mechanics"])


if __name__ == "__main__":
    unittest.main()
