"""Source-bound checks only; no native world or gameplay is run."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
UPGRADE = ROOT / 'code/game/objects/structures/kitchen/stone_kiln_upgrade.dm'
OVEN = ROOT / 'code/game/objects/structures/kitchen/oven.dm'
HEAT = ROOT / 'code/modules/1713/machinery/engines/heatsource.dm'
POT = ROOT / 'code/modules/reagents/reagent_containers/glass.dm'
MATERIAL = ROOT / 'code/modules/materials/material_sheets.dm'


def guard_contract(source, oven):
    valid = source.split('/proc/stone_kiln_upgrade_valid(', 1)[1].split('\n/obj/', 1)[0]
    upgrade = source.split('/proc/upgrade_to_stone_kiln(', 1)[1].split('\n/obj/', 1)[0]
    for guard in ('persistence_admission_identity != save_identity', 'persistence_active_operation', 'map.is_node_done(H.civilization, "basic_furniture")', 'S.type != /obj/item/stack/material/stone', 'H.get_active_hand() != S', 'S.amount < 10', 'stone_boil_epoch != epoch', 'stone_boil_busy', 'contents.len', 'P.on_stove'):
        assert guard in valid, guard
    for required in ('stone_upgrade_busy = TRUE', 'do_after(H, 150, src)', 'stone_kiln_upgrade_valid(S, H, site, epoch, save_identity)', 'S.can_use(10)', 'stone_before = S.amount', 'S.use(10)', 'S.amount != stone_before - 10', 'K.fuel = fuel', 'fuel = 0', 'K.wood_residue = account', 'wood_residue = null', 'qdel(src)'):
        assert required in upgrade, required
    assert upgrade.index('S.use(10)') < upgrade.index('K.fuel = fuel') < upgrade.index('fuel = 0') < upgrade.index('qdel(src)')
    assert upgrade.index('do_after(H, 150, src)') < upgrade.index('if (!completed || !stone_kiln_upgrade_valid') < upgrade.index('S.use(10)')
    assert 'if (QDELETED(src))\n\t\t\t\treturn' in oven.split('spawn (cooking_time)', 1)[1]
    assert 'key == "stone_upgrade_busy"' in oven


def project_wait(source, *, save=False, fire_toggled=False, stack_short=False, occupied=False, pot=False):
    """Project source guard decisions after a wait; does not execute DM."""
    body = source.split('/proc/stone_kiln_upgrade_valid(', 1)[1].split('\n/obj/', 1)[0]
    checks = ((save, 'persistence_admission_identity != save_identity'),
              (fire_toggled, 'stone_boil_epoch != epoch'),
              (stack_short, 'S.amount < 10'), (occupied, 'contents.len'), (pot, 'P.on_stove'))
    return not any(event and guard in body for event, guard in checks)


def metallurgy_contract(source):
    loading = source.split('/campfire/attackby(', 1)[1].split('\n/obj/', 1)[0]
    firing = source.split('/campfire/attack_hand(', 1)[1]
    assert 'istype(I, /obj/item/weapon/clay/mold)' in loading
    assert 'map.is_node_done(H.civilization, "bronze_working")' in loading
    assert 'for (var/obj/item/weapon/clay/mold/M in contents)' in firing
    assert 'map.is_node_done(H.civilization, "bronze_working")' in firing


def project_filled_vessel_route(source, *, filled, flammable, intent, glass=False, liquid_fuel=False, holder_owned=True, holder_empty=True):
    """Project the source dispatch order; this is not an execution of DM."""
    body = source.split('/campfire/attackby(', 1)[1].split('\n/obj/', 1)[0]
    liquid = body.index('for (var/id in heat_source_liquid_fuels())')
    guard = body.rfind('if (filled_flammable_vessel && !deliberate_burn)')
    solid = body.index('var/energy = heat_source_solid_fuel_energy(I)')
    deliberate = filled and flammable and intent == 'harm'
    if intent != 'help' and not deliberate:
        return 'hint' if filled and flammable else 'fallback'
    empty_exempt = ('!empty_flammable_glass && istype(I, /obj/item/weapon/reagent_containers/glass)' in body and
                    not filled and flammable and holder_owned and holder_empty)
    if glass and not deliberate and not empty_exempt:
        if liquid_fuel and liquid < solid and 'if (amount > 0)' in body:
            return 'liquid'
        return 'hint' if filled and flammable else 'fallback'
    if filled and flammable and not deliberate and guard > liquid and guard < solid:
        return 'hint'
    if flammable and (intent == 'help' or deliberate):
        return 'solid'
    return 'fallback'


class KilnSourceTests(unittest.TestCase):
    def setUp(self):
        self.source = UPGRADE.read_text(encoding='utf-8')
        self.oven = OVEN.read_text(encoding='utf-8')
        self.heat = HEAT.read_text(encoding='utf-8')

    def test_upgrade_ownership_and_causal_guard_controls(self):
        guard_contract(self.source, self.oven)
        for guard in ('persistence_admission_identity != save_identity', 'S.amount < 10', 'stone_boil_epoch != epoch', 'P.on_stove', 'K.wood_residue = account', 'fuel = 0'):
            with self.subTest(guard=guard), self.assertRaises(AssertionError):
                guard_contract(self.source.replace(guard, 'omitted_guard', 1), self.oven)

    def test_stone_stack_use_and_actual_debit_are_checked(self):
        source = MATERIAL.read_text(encoding='utf-8')
        method = source.split('/obj/item/stack/material/use(var/used)', 1)[1].split('\n/obj/', 1)[0]
        self.assertIn('. = ..()', method)
        self.assertIn('\n\treturn\n', method)
        self.assertNotIn('if (!S.use(10))', self.source)

    def test_interruption_and_save_aba_projection_with_controls(self):
        self.assertTrue(project_wait(self.source))
        for event, guard in (('save', 'persistence_admission_identity != save_identity'), ('fire_toggled', 'stone_boil_epoch != epoch'), ('stack_short', 'S.amount < 10'), ('occupied', 'contents.len'), ('pot', 'P.on_stove')):
            with self.subTest(event=event):
                self.assertFalse(project_wait(self.source, **{event: True}))
                self.assertTrue(project_wait(self.source.replace(guard, 'FALSE', 1), **{event: True}))

    def test_shared_heat_source_energy_and_fuel_contract(self):
        body = self.heat.split('/proc/heat_source_solid_fuel_energy(', 1)[1].split('\n/obj/', 1)[0]
        for path, value in (('/obj/item/stack/ore/coal', 'return 240 * I.amount'), ('/obj/item/stack/ore/charcoal', 'return 80 * I.amount'), ('/obj/item/stack/material/leaf', 'return 30 * I.amount')):
            self.assertIn(path, body)
            self.assertIn(value, body)
        for path in ('/obj/item/stack/material/wood', '/obj/item/stack/material/woodplank', '/obj/item/weapon/branch', '/obj/item/stack/material/bamboo', '/obj/item/stack/dung'):
            self.assertIn(path, body)
        self.assertIn('return 60 * I.amount', body)
        self.assertIn('if (I.flammable)', body)
        self.assertIn('return 25 * S.amount', body)
        self.assertIn('return 25\n', body)
        self.assertIn('return 30 * amount', self.heat)
        for fuel in ('petroleum', 'gasoline', 'diesel', 'pethanol', 'biodiesel', 'olive_oil', 'fat_oil'):
            self.assertIn('"' + fuel + '"', self.heat.split('/proc/heat_source_liquid_fuels()', 1)[1].split('\n/proc/', 1)[0])
        self.assertGreaterEqual(self.heat.count('heat_source_solid_fuel_energy(W)'), 8)
        self.assertIn('heat_source_solid_fuel_energy(I)', self.source)
        self.assertIn('heat_source_liquid_fuel_energy(available) / 60', self.source)
        self.assertIn('record_wood_fuel(I, credit)', self.source)
        self.assertNotIn('holder.clear_reagents()', self.source)

    def test_kiln_preserves_pot_and_biological_only_treatment(self):
        self.assertIn('P.flammable', self.source)
        self.assertIn('if (!(R.id in amounts))', self.source)
        self.assertIn('H.transfer_held_item_to(P, src) || QDELETED(P) || P.loc != src', self.source)
        self.assertIn('P.on_stove = FALSE', self.source)
        self.assertIn('P.stone_kiln_reagent_identity == identity', self.source)
        self.assertIn('P.stone_kiln_owner == cycle', self.source)
        self.assertIn('stone_kiln_cycle != cycle', self.source)
        self.assertIn('key == "stone_kiln_cycle"', self.source)
        self.assertIn('key == "stone_boil_busy"', self.source)
        self.assertIn('persistence_admission_identity != save_identity', self.source)
        self.assertIn('holder.del_reagent("cholera")', self.source)
        self.assertIn('holder.del_reagent("food_poisoning")', self.source)
        self.assertNotIn('holder.del_reagent("water")', self.source)
        self.assertNotIn('holder.del_reagent("sodiumchloride")', self.source)
        pot = POT.read_text(encoding='utf-8')
        self.assertIn('key == "stone_kiln_reagent_identity"', pot)
        self.assertIn('key == "stone_kiln_owner"', pot)
        self.assertIn('stone_kiln_reagent_identity = new /datum', pot)

    def test_primitive_upgrade_does_not_unlock_kiln_metallurgy(self):
        admission = self.source.split('/proc/stone_kiln_upgrade_valid(', 1)[1].split('\n/obj/', 1)[0]
        self.assertIn('map.is_node_done(H.civilization, "basic_furniture")', admission)
        self.assertNotIn('"bronze_working"', admission)
        metallurgy_contract(self.source)
        gate = 'map.is_node_done(H.civilization, "bronze_working")'
        self.assertEqual(self.source.count(gate), 2)
        for index, mutation in enumerate((self.source.replace(gate, 'TRUE', 1), 'TRUE'.join(self.source.rsplit(gate, 1))), 1):
            with self.subTest(missing_gate=index), self.assertRaises(AssertionError):
                metallurgy_contract(mutation)

    def test_filled_vessels_are_not_implicitly_burned(self):
        mugs = (ROOT / 'code/modules/reagents/reagent_containers/food/drinks/drinkingglass.dm').read_text(encoding='utf-8')
        mug = mugs.split('/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/wood\n', 1)[1].split('\n/obj/', 1)[0]
        self.assertIn('flammable = TRUE', mug)
        body = self.source.split('/campfire/attackby(', 1)[1].split('\n/obj/', 1)[0]
        self.assertIn('var/filled_flammable_vessel = istype(I, /obj/item/weapon/reagent_containers) && I.flammable && I.reagents && I.reagents.total_volume > 0', body)
        last_guard = body.rfind('\n\tif (filled_flammable_vessel && !deliberate_burn)')
        protected = body[last_guard:body.index('\n\tvar/energy = heat_source_solid_fuel_energy(I)', last_guard)]
        self.assertIn('\n\t\treturn filled_vessel_hint(H)', protected)
        hint = self.source.split('/proc/filled_vessel_hint(', 1)[1].split('\n/obj/', 1)[0]
        self.assertIn('hot-stone action', hint)
        self.assertIn('\n\treturn TRUE', hint)
        self.assertIn('H.a_intent != I_HELP && !deliberate_burn', body)
        self.assertEqual(project_filled_vessel_route(self.source, filled=True, flammable=True, intent='help'), 'hint')
        self.assertEqual(project_filled_vessel_route(self.source, filled=True, flammable=True, intent='grab'), 'hint')
        self.assertEqual(project_filled_vessel_route(self.source, filled=True, flammable=True, intent='harm'), 'solid')
        self.assertEqual(project_filled_vessel_route(self.source, filled=False, flammable=True, intent='help'), 'solid')
        # Simulate omission of the final normal-intent guard: the old defect returns.
        mutated = 'if (FALSE)'.join(self.source.rsplit('if (filled_flammable_vessel && !deliberate_burn)', 1))
        self.assertEqual(project_filled_vessel_route(mutated, filled=True, flammable=True, intent='help'), 'solid')

    def test_liquid_fuel_precedes_vessel_protection_and_preserves_other_contents(self):
        self.assertEqual(project_filled_vessel_route(self.source, filled=True, flammable=True, intent='help', glass=True, liquid_fuel=True), 'liquid')
        self.assertEqual(project_filled_vessel_route(self.source, filled=True, flammable=False, intent='help', glass=True, liquid_fuel=True), 'liquid')
        self.assertEqual(project_filled_vessel_route(self.source, filled=True, flammable=True, intent='help', glass=True, liquid_fuel=False), 'hint')
        body = self.source.split('/campfire/attackby(', 1)[1].split('\n/obj/', 1)[0]
        self.assertLess(body.index('for (var/id in heat_source_liquid_fuels())'), body.rfind('if (filled_flammable_vessel && !deliberate_burn)'))
        self.assertIn('holder.remove_reagent(id, available, TRUE)', body)
        self.assertNotIn('holder.clear_reagents()', body)
        self.assertIn('var/deliberate_burn = filled_flammable_vessel && H.a_intent == I_HARM', body)
        self.assertIn('if (!deliberate_burn && !empty_flammable_glass && istype(I, /obj/item/weapon/reagent_containers/glass)', body)
        fuel_list = self.heat.split('/proc/heat_source_liquid_fuels()', 1)[1].split('\n/proc/', 1)[0]
        allowed_ids = set(re.findall(r'"([^"\n]+)"', fuel_list))
        # Project the loop's per-ID removal for a mixed container, including an
        # unsupported chemical; source above pins the actual targeted removal.
        contents = {'gasoline': 6, 'water': 10, 'unknown_chemical': 2}
        removed = {key: contents.pop(key) for key in list(contents) if key in allowed_ids}
        self.assertEqual(removed, {'gasoline': 6})
        self.assertEqual(contents, {'water': 10, 'unknown_chemical': 2})

    def test_actual_empty_wooden_bucket_reaches_solid_fuel(self):
        pot = POT.read_text(encoding='utf-8')
        bucket = pot.split('/obj/item/weapon/reagent_containers/glass/bucket\n', 1)[1].split('\n/obj/', 1)[0]
        steel = pot.split('/obj/item/weapon/reagent_containers/glass/bucket/steel\n', 1)[1].split('\n/obj/', 1)[0]
        self.assertIn('flammable = TRUE', bucket)
        self.assertIn('flammable = FALSE', steel)
        body = self.source.split('/campfire/attackby(', 1)[1].split('\n/obj/', 1)[0]
        self.assertIn('I.reagents.my_atom == I && I.reagents.total_volume == 0', body)
        empty_guard = body.split('var/empty_flammable_glass = ', 1)[1].split('\n', 1)[0]
        self.assertNotIn('is_open_container', empty_guard)  # Both open and closed empty buckets qualify.
        self.assertIn('!QDELETED(I.reagents)', empty_guard)
        self.assertIn('islist(I.reagents.reagent_list) && !I.reagents.reagent_list.len', empty_guard)
        self.assertLess(body.index('!empty_flammable_glass && istype(I, /obj/item/weapon/reagent_containers/glass)'), body.index('var/energy = heat_source_solid_fuel_energy(I)'))
        self.assertEqual(project_filled_vessel_route(self.source, filled=False, flammable=True, intent='help', glass=True), 'solid')
        self.assertEqual(project_filled_vessel_route(self.source, filled=False, flammable=True, intent='help', glass=True, holder_owned=False), 'fallback')
        self.assertEqual(project_filled_vessel_route(self.source, filled=False, flammable=True, intent='help', glass=True, holder_empty=False), 'fallback')
        self.assertEqual(project_filled_vessel_route(self.source, filled=False, flammable=False, intent='help', glass=True), 'fallback')
        self.assertEqual(project_filled_vessel_route(self.source, filled=True, flammable=True, intent='help', glass=True), 'hint')
        self.assertEqual(project_filled_vessel_route(self.source, filled=True, flammable=True, intent='help', glass=True, liquid_fuel=True), 'liquid')
        # The pre-fix branch captured every glass vessel and returned to parent.
        old_dispatch = self.source.replace('!empty_flammable_glass && istype(I, /obj/item/weapon/reagent_containers/glass)', 'istype(I, /obj/item/weapon/reagent_containers/glass)', 1)
        self.assertEqual(project_filled_vessel_route(old_dispatch, filled=False, flammable=True, intent='help', glass=True), 'fallback')


if __name__ == '__main__':
    unittest.main()
