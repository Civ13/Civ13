"""Offline source contracts; these do not execute DM or test save files."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "code/game/objects/structures/kitchen/stone_boiling.dm"
OVEN = ROOT / "code/game/objects/structures/kitchen/oven.dm"
PERSISTENCE = ROOT / "code/modules/persistence/functions.dm"
HOLDER = ROOT / "code/modules/reagents/Chemistry-Holder.dm"


def contract(source, oven, persistence):
    mixture = source.split("/proc/stone_boil_mixture()", 1)[1].split("\n/obj/", 1)[0]
    valid = source.split("/proc/stone_boil_valid(", 1)[1].split("\n/obj/", 1)[0]
    action = source.split("/verb/stone_boil_water()", 1)[1]
    assert 'list("water" = 0, "sodiumchloride" = 0, "cholera" = 0, "food_poisoning" = 0)' in mixture
    assert 'if (!(R.id in mixture))' in mixture
    assert 'get_reagent_amount("water") <= 0' in mixture
    for guard in ("persistence_save_in_progress", "persistence_active_operation", "persistence_load_recovery_required", "persistence_admission_identity != save_identity", "H.Adjacent(F)", "get_active_hand_owner(H)", "tool.loc != H", "F.loc != site", "S.loc != site", "S.amount < 1", "!F.stone_heat_ready()", "F.stone_heat_token() != epoch", "reagents != holder", "holder.my_atom != src", "stone_boil_reagent_identity != reagent_identity", "!is_open_container()", "current[id] != mixture[id]"):
        assert guard in valid, guard
    assert 'key == "stone_boil_busy" || key == "stone_boil_reagent_identity" || ..()' in source
    changed = source.split('/wood/on_reagent_change()', 1)[1].split('\n/obj/', 1)[0]
    assert 'if (stone_boil_busy)' in changed and 'stone_boil_reagent_identity = new /datum' in changed and '..()' in changed
    admission = persistence.split('/proc/begin_persistence_operation(', 1)[1].split('\n/datum/', 1)[0]
    assert admission.index('persistence_active_operation = operation') < admission.index('persistence_admission_identity = operation.admission_identity') < admission.index('return operation')
    constructor = persistence.split('/datum/persistence_world_operation/New()', 1)[1].split('\n/map_storage/', 1)[0]
    assert 'admission_identity = new /datum' in constructor
    assert 'key == "stone_boil_busy" || key == "stone_boil_epoch" || key == "stone_upgrade_busy" || ..()' in oven
    assert 'stone_boil_epoch++' in oven.split('/obj/structure/oven/fireplace/attack_hand', 1)[1].split('\n/obj/', 1)[0]
    assert 'stone_boil_busy || F.stone_heat_busy()' in action
    assert 'if (!F.stone_heat_claim())' in action and 'F.stone_heat_release()' in action
    fireplace = source.split('/obj/structure/oven/fireplace/stone_heat_ready()', 1)[1].split('\n/obj/item/', 1)[0]
    kiln = source.split('/obj/structure/furnace/kiln/stone/campfire/stone_heat_ready()', 1)[1].split('\n/obj/item/', 1)[0]
    assert 'return on && fuel >= 1' in fireplace and 'return stone_boil_epoch' in fireplace
    assert 'return on && stone_kiln_cycle && fuel >= 1' in kiln and 'return stone_kiln_cycle' in kiln
    assert 'for (var/obj/structure/furnace/kiln/stone/campfire/candidate in range(1, H))' in action
    assert 'do_after(H, 100, F)' in action
    assert 'if (completed && stone_boil_valid(H, F, S, tool, holder, site, epoch, save_identity, reagent_identity, mixture))' in action
    assert action.index('var/datum/save_identity = persistence_admission_identity') < action.index('stone_boil_busy = TRUE') < action.index('do_after(H, 100, F)')
    assert action.index('var/datum/reagent_identity = stone_boil_reagent_identity') < action.index('stone_boil_busy = TRUE')
    assert action.index('do_after(H, 100, F)') < action.index('F.burn_structure_fuel(1)') < action.index('holder.del_reagent("cholera")')
    assert 'holder.del_reagent("food_poisoning")' in action
    assert 'holder.del_reagent("water")' not in action and 'holder.del_reagent("sodiumchloride")' not in action
    assert 'add_reagent(' not in action and 'S.use(' not in action


def project_interleaving(source, persistence, events):
    """Project the two source guards and event hooks, not a DM execution."""
    valid = source.split('/proc/stone_boil_valid(', 1)[1].split('\n/obj/', 1)[0]
    changed = source.split('/wood/on_reagent_change()', 1)[1].split('\n/obj/', 1)[0]
    admission = persistence.split('/proc/begin_persistence_operation(', 1)[1].split('\n/datum/', 1)[0]
    save_token, liquid_token = object(), object()
    saved_save, saved_liquid = save_token, liquid_token
    mixture = {'water': 20, 'cholera': 1}
    original = mixture.copy()
    for event in events:
        if event == 'completed_save':
            if 'persistence_admission_identity = operation.admission_identity' in admission:
                save_token = object()
            # Both current save flags are clear again before the waiter wakes.
        elif event == 'empty_refill':
            mixture.clear()
            mixture.update(original)
            if 'stone_boil_reagent_identity = new /datum' in changed:
                liquid_token = object()
        else:
            raise AssertionError(event)
    if 'persistence_admission_identity != save_identity' in valid and save_token is not saved_save:
        return False
    if 'stone_boil_reagent_identity != reagent_identity' in valid and liquid_token is not saved_liquid:
        return False
    return mixture == original


class StoneBoilingSource(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding="utf-8")
        self.oven = OVEN.read_text(encoding="utf-8")
        self.persistence = PERSISTENCE.read_text(encoding="utf-8")

    def test_production_contract(self):
        contract(self.source, self.oven, self.persistence)

    def test_guard_omissions_are_detected(self):
        for guard in ("persistence_active_operation", "F.stone_heat_token() != epoch", "current[id] != mixture[id]", "reagents != holder", "S.loc != site", "!F.stone_heat_ready()", "if (!(R.id in mixture))"):
            with self.subTest(guard=guard), self.assertRaises(AssertionError):
                contract(self.source.replace(guard, "omitted_guard", 1), self.oven, self.persistence)

    def test_debit_and_contamination_controls_are_detected(self):
        for old, new in (("F.burn_structure_fuel(1)", "F.burn_structure_fuel(0)"), ('holder.del_reagent("cholera")', 'holder.del_reagent("water")'), ('holder.del_reagent("food_poisoning")', 'holder.del_reagent("sodiumchloride")')):
            with self.subTest(old=old), self.assertRaises((AssertionError, ValueError)):
                contract(self.source.replace(old, new, 1), self.oven, self.persistence)

    def test_save_completed_during_wait_and_causal_controls(self):
        self.assertTrue(project_interleaving(self.source, self.persistence, []))
        self.assertFalse(project_interleaving(self.source, self.persistence, ['completed_save']))
        no_hook = self.persistence.replace('persistence_admission_identity = operation.admission_identity', 'persistence_admission_identity = persistence_admission_identity', 1)
        self.assertTrue(project_interleaving(self.source, no_hook, ['completed_save']))
        no_guard = self.source.replace('persistence_admission_identity != save_identity', 'FALSE', 1)
        self.assertTrue(project_interleaving(no_guard, self.persistence, ['completed_save']))

    def test_empty_and_identical_refill_during_wait_and_causal_controls(self):
        self.assertFalse(project_interleaving(self.source, self.persistence, ['empty_refill']))
        no_hook = self.source.replace('stone_boil_reagent_identity = new /datum\n\t..()', 'stone_boil_reagent_identity = stone_boil_reagent_identity\n\t..()', 1)
        self.assertTrue(project_interleaving(no_hook, self.persistence, ['empty_refill']))
        no_guard = self.source.replace('stone_boil_reagent_identity != reagent_identity', 'FALSE', 1)
        self.assertTrue(project_interleaving(no_guard, self.persistence, ['empty_refill']))

    def test_kiln_hot_stone_requires_running_owned_cycle_and_extra_fuel(self):
        kiln = self.source.split('/obj/structure/furnace/kiln/stone/campfire/stone_heat_ready()', 1)[1].split('\n/obj/item/', 1)[0]
        self.assertIn('return on && stone_kiln_cycle && fuel >= 1', kiln)
        self.assertIn('return stone_kiln_cycle', kiln)
        self.assertIn('if (stone_boil_busy || !stone_heat_ready())', kiln)
        self.assertIn('stone_boil_busy = TRUE', kiln)
        self.assertIn('stone_boil_busy = FALSE', kiln)
        action = self.source.split('/verb/stone_boil_water()', 1)[1]
        self.assertIn('F.burn_structure_fuel(1)', action)
        self.assertNotIn('loc = F', action)
        self.assertNotIn('forceMove(F', action)

    def test_kiln_cycle_change_rejects_old_wait_source_projection(self):
        valid = self.source.split('/proc/stone_boil_valid(', 1)[1].split('\n/obj/', 1)[0]
        saved_cycle, current_cycle = object(), object()
        def allowed(body):
            return not ('F.stone_heat_token() != epoch' in body and current_cycle is not saved_cycle)
        self.assertFalse(allowed(valid))
        self.assertTrue(allowed(valid.replace('F.stone_heat_token() != epoch', 'FALSE', 1)))

    def test_holder_notifies_owner_for_normal_and_safety_mutations(self):
        holder = HOLDER.read_text(encoding="utf-8")
        for proc, successor in (('add_reagent', 'multiply_reagent'), ('remove_reagent', 'del_reagent'), ('del_reagent', 'del_reagents')):
            body = holder.split('/proc/' + proc + '(', 1)[1].split('/proc/' + successor + '(', 1)[0]
            self.assertIn('my_atom.on_reagent_change()', body)
        add = holder.split('/proc/add_reagent(', 1)[1].split('/proc/multiply_reagent(', 1)[0]
        self.assertEqual(add.count('my_atom.on_reagent_change()'), 2)
        self.assertEqual(add.count('if (!safety)\n\t\t\t\thandle_reactions()\n\t\t\tif (my_atom)\n\t\t\t\tmy_atom.on_reagent_change()'), 1)
        clear = holder.split('/proc/clear_reagents()', 1)[1].split('/proc/get_reagent_amount(', 1)[0]
        self.assertIn('del_reagent(current.id)', clear)
        transfer = holder.split('/proc/trans_to_holder(', 1)[1].split('/proc/trans_to(', 1)[0]
        self.assertIn('target.add_reagent(current.id, amount_to_transfer * multiplier, current.get_data(), safety = TRUE)', transfer)
        self.assertIn('remove_reagent(current.id, amount_to_transfer, TRUE)', transfer)

    def test_actual_recipe_and_unlock_chain(self):
        recipes = (ROOT / "config/crafting/material_recipes_global.txt").read_text(encoding="utf-8")
        nodes = (ROOT / "code/modules/research_tree/research_node.dm").read_text(encoding="utf-8")
        for line in ("/material/wood/,wood mug,/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/wood,1,", "/material/wood/,campfire,/obj/structure/oven/fireplace,4,", "/material/wood/soft/,wood handle,/obj/item/weapon/material/handle,1,"):
            self.assertIn(line, recipes)
        for row in ('"/obj/structure/oven/fireplace" = "basic_furniture"', '"/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/wood" = "pottery_storage"', '"/obj/item/weapon/material/handle" = "basic_tools"'):
            self.assertIn(row, nodes)
        sifting = (ROOT / "code/modules/1713/resource_sifting.dm").read_text(encoding="utf-8")
        self.assertIn('tool ? 1200 : 1800', sifting)
        self.assertIn('/turf/floor/beach/sand', sifting)


if __name__ == "__main__":
    unittest.main()
