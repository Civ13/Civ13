"""Offline source projections and wiring. Native tests live in crafting/woolcloth.dm."""
import importlib.util
from pathlib import Path
import re
from types import SimpleNamespace as NS
import unittest

ROOT = Path(__file__).resolve().parents[2]
SHEETS = 'code/game/objects/items/stacks/cloth_crafting.dm'
PAYMENT = 'code/game/objects/items/stacks/cloth_crafting.dm'
spec = importlib.util.spec_from_file_location('cloth_source_adapter', ROOT/'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)

def read(path):
    return (ROOT/path).read_text()

def quote_paths(source):
    # Type annotations are stripped by the projector. Only literal expression
    # typepaths are quoted here; all executable statements remain selected.
    return re.sub(r'(?<=[ ,=(])(/(?:obj|material)(?:/\w+)+)(?=[,) ])', r'"\1"', source)

def cloth_predicate(source=None):
    return adapter.project(quote_paths(source or read(SHEETS)), '/proc/is_cloth_sheet', 'I', {
        'QDELETED': lambda o: o is None or getattr(o, 'deleted', False),
        'istype': lambda o, p: o is not None and (o.type == p or o.type.startswith(p+'/')),
    })

def stock(kind, material=None):
    return NS(type='/obj/item/stack/material/'+kind,
              get_material=lambda: NS(type='/material/'+(material or kind)))

class ClothTests(unittest.TestCase):
    def test_production_predicate_accepts_only_finished_matching_textiles(self):
        accepts=cloth_predicate()
        for kind in ('cloth','woolcloth'):
            self.assertTrue(accepts(stock(kind)))
            self.assertFalse(accepts(stock(kind,'cotton')))
        for kind in ('wool','cotton','rags','leather','steel','rettedfabric'):
            self.assertFalse(accepts(stock(kind)))
        self.assertFalse(accepts(None))
        dead=stock('woolcloth'); dead.deleted=True
        self.assertFalse(accepts(dead))

    def test_omitting_wool_is_detected(self):
        original=read(SHEETS)
        bad=original.replace('M.type == /material/woolcloth', 'M.type == /material/cotton')
        self.assertFalse(cloth_predicate(bad)(stock('woolcloth')))
        self.assertTrue(cloth_predicate(original)(stock('woolcloth')))

    def test_no_type_or_stack_conversion(self):
        for kind in ('cloth','woolcloth'):
            body=read('code/modules/materials/material_sheets.dm').split('/obj/item/stack/material/'+kind+'\n',1)[1].split('\n/',1)[0]
            self.assertNotIn('parent_type',body)
            self.assertIn('default_type = "'+kind+'"',body)
        body=adapter.extract(read(SHEETS), '/proc/is_cloth_sheet')
        self.assertNotIn('stacktype =', body)
        self.assertNotIn('material =', body)

    def test_catalog_fallback_preserves_gates_and_distinct_wool_rows(self):
        s=read('code/game/objects/items/stacks/civ_recipes.dm')
        self.assertIn('type == /material/woolcloth && i[1] == "/material/cloth/"',s)
        self.assertIn('!native_textile_rows[jointext(i.Copy(2), ",")]',s)
        self.assertIn('material_allowed && research_allowed && map && recipe_age_allowed',s)
        self.assertIn('native_textile_rows[jointext(row.Copy(2), ",")] = TRUE',s)
        # The feature is driven by the selected faction catalog, not a global
        # union that could expose other species' or modes' recipes.
        self.assertIn('var/chosen_list = craftlist_lists[faction]',s)

    def test_project_ledgers_and_private_persisted_inputs_match(self):
        self.assertIn('stack_matches_recipe_material(S, need[1])',read('code/modules/persistence/party_train.dm'))
        self.assertIn('is_cloth_sheet(I)',read('code/modules/1713/machinery/modular_vehicles/car_workshop.dm'))
        self.assertIn('I.type == /obj/item/stack/material/woolcloth',read('code/modules/1713/extraction/private_car_workshop.dm'))
        self.assertIn('if ("/obj/item/stack/material/cloth", "/obj/item/stack/material/woolcloth") key = "cloth"',read('code/modules/1713/extraction/vehicle_purchase.dm'))
        self.assertIn('/obj/item/stack/material/woolcloth,',read('code/modules/1713/extraction/equipment.dm'))
        office=adapter.extract(read('code/modules/persistence/party_train.dm'), '/obj/structure/region_gate/railway_station/attackby')
        self.assertLess(office.index('!S.use(amount)'),office.index('delivered[kind] ='))
        self.assertIn('min(missing, S.amount)',office)

    def test_armor_uses_requirement_key_not_supplied_identity(self):
        s=read('code/game/objects/structures/blacksmithing/armor_workbench.dm')
        self.assertIn('requirements[input_requirement(I, requirements)]',s)
        self.assertNotIn('requirements[I.type]',s)
        self.assertIn('input_requirement(stored, requirements) == input_type',s)
        self.assertIn('epoch != persistence_admission_identity',s)
        self.assertIn('I:amount != amounts[I]',s)

    def test_painting_debits_are_batched_retained_and_after_wait(self):
        s=read('code/game/objects/items/stacks/stack.dm')
        branch=s.split('else if (findtext(recipe.title, "stormy sea")',1)[1].split('else if (findtext(recipe.title, "monumental marble statue',1)[0]
        self.assertIn('new(src, H, recipe, quantity, 3)',branch)
        self.assertNotIn('amount -=',branch)
        self.assertLess(s.index('!do_after(user, buildtime)'),s.rindex('!cloth_payment.valid()'))
        self.assertLess(s.rindex('!cloth_payment.valid()'),s.index('if (use(required,'))
        self.assertLess(s.index('if (use(required,'),s.index('cloth_payment.consume_secondary()'))
        self.assertLess(s.index('cloth_payment.consume_secondary()'),s.index('O = new recipe.result_type'))
        p=read(PAYMENT)
        for required in ('secondary_cost = quantity * extra_cloth', 'save_epoch != persistence_admission_identity',
                         'stock.loc != stock_loc', 'C.loc != actor', '!actor.item_is_in_hands(C)',
                         '!C.can_use(secondary[C])', 'return paid == secondary_cost', 'C.use(secondary[C])'):
            self.assertIn(required,p)
        self.assertIn('should_save = FALSE',p)

    def test_duplicate_helmet_handlers_and_medical_gate_regressions(self):
        s=read('code/modules/1713/apparel_medieval.dm')
        for base,metal in (('nomads/templar','gold'),('baltic','silver')):
            declaration='/obj/item/clothing/head/helmet/medieval/'+base+'/attackby'
            self.assertEqual(s.count(declaration),1)
            body=adapter.extract(s,declaration)
            self.assertIn('cloth_stock.use(3)',body)
            self.assertIn('/obj/item/stack/material/'+metal,body)
        stack=read('code/game/objects/items/stacks/stack.dm')
        combined=stack.split('else if (findtext(recipe.title, "plague doctor mask") ||',1)[1].split('else if',1)[0]
        self.assertIn('H.getStatCoeff("medical") < 1.0',combined)
        self.assertNotIn('select_secondary',combined)
        mask=stack.split('else if (findtext(recipe.title, "plague doctor mask"))',1)[1].split('else if',1)[0]
        self.assertIn('select_secondary(/obj/item/stack/medical/advanced/herbs, 2 * quantity)',mask)

    def test_workshop_refund_provenance_survives_ordinary_first_debit(self):
        s=read('code/modules/1713/machinery/modular_vehicles/car_workshop.dm')
        self.assertIn('stock["woolcloth"] = (stock["woolcloth"] || 0) + payment',s)
        unload=adapter.extract(s,'/obj/structure/car_workshop/proc/unload')
        self.assertIn('stock["cloth"] -= stock["woolcloth"]',unload)
        self.assertIn('"woolcloth" = /obj/item/stack/material/woolcloth',unload)
        commit=adapter.extract(s,'/obj/structure/car_workshop/proc/complete_assembly')
        self.assertLess(commit.index('stock[key] -= required[key]'),commit.index('stock["woolcloth"] = min'))
        self.assertIn('stock["woolcloth"] || 0',commit)

    def test_native_fixture_is_included_and_focus_is_explicit(self):
        runner=read('scripts/check-recipes.py')
        self.assertIn('tests/crafting/woolcloth.dm',runner)
        self.assertIn('"run_cloth_checks" if args.cloth_only',runner)
        self.assertIn('cloth_crafting.dm',read('civ13.dme'))
        self.assertIn('Woolcloth sheets also accepted.',read('scripts/build-crafting-atlas.py'))

if __name__ == '__main__': unittest.main()
