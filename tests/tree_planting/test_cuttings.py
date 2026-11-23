"""Source contracts for the new cutting path; these do not run BYOND."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
WEAPONS = (ROOT / 'code/game/objects/items/weapons/material/ooga_booga_weapons.dm').read_text()
WILD = (ROOT / 'code/game/objects/structures/wild.dm').read_text()


def definition(source, path):
    return re.search(r'^' + re.escape(path) + r'[^\n]*\n((?:\t[^\n]*\n|\n)*)', source, re.M).group(1)


class Cuttings(unittest.TestCase):
    def test_provenance_set_only_on_a_successful_living_broadleaf_drop(self):
        drop = definition(WILD, '/obj/structure/wild/attack_hand(')
        self.assertIn('else if (user.a_intent == I_HARM && branches >= 1)', drop)
        self.assertIn('if (do_after(user, 80, src))', drop)
        self.assertIn('if (src && branches >= 1)', drop)
        self.assertLess(drop.index('B = new /obj/structure/branch(get_turf(src))'), drop.index('B.cutting_viable ='))
        self.assertIn('B.cutting_viable = (type == /obj/structure/wild/tree/live_tree || type == /obj/structure/wild/tree/live_tree/snow) && health > 0 && radiation < 15', drop)
        self.assertIn('var/cutting_viable = FALSE', definition(WEAPONS, '/obj/structure/branch'))

    def test_pickup_consumes_original_only_after_inventory_accepts(self):
        click = definition(WEAPONS, '/obj/structure/branch/attack_hand(')
        self.assertIn('H.a_intent == I_HELP && cutting_viable', click)
        pickup = definition(WEAPONS, '/obj/structure/branch/proc/pick_up_cutting(')
        for gate in ('QDELETED(src)', '!cutting_viable', '!branched', 'H.get_active_hand()', '!H.Adjacent(src)', 'persistence_active_operation'):
            self.assertIn(gate, pickup)
        self.assertIn('C.leaves = leaves', pickup)
        self.assertRegex(pickup, r'if \(!H\.put_in_active_hand\(C\)\)\s+qdel\(C\)\s+return FALSE\s+qdel\(src\)')

    def test_planting_checks_existing_plot_before_creating_and_consuming(self):
        click = definition(WEAPONS, '/obj/item/tree_cutting/afterattack(')
        self.assertIn('if (proximity_flag && isturf(target))', click)
        self.assertIn('plant_cutting(target, user)', click)
        plant = definition(WEAPONS, '/obj/item/tree_cutting/proc/plant_cutting(')
        self.assertIn('!can_handle_cutting(user) || !T || !user.Adjacent(T)', plant)
        self.assertRegex(plant, r'tree_planting_error\(T\)\s+if \(site_error\)\s+to_chat\(user, SPAN_WARNING\(site_error\)\)\s+return FALSE\s+new /obj/structure/farming/plant/tree\(T\)')
        self.assertEqual(plant.count('qdel(src)'), 1)
        self.assertLess(plant.index('new /obj/structure/farming/plant/tree(T)'), plant.index('qdel(src)'))
        self.assertNotIn('/obj/item/stack/farming/seeds', plant)

    def test_setting_down_and_trimming_preserve_existing_leaf_and_tool_paths(self):
        set_down = definition(WEAPONS, '/obj/item/tree_cutting/attack_self(')
        self.assertIn('if (leaves)', set_down)
        self.assertIn('new /obj/structure/branch/cleared(user.loc)', set_down)
        self.assertIn('B.cutting_viable = TRUE\n\tqdel(src)', set_down)
        click = definition(WEAPONS, '/obj/structure/branch/attack_hand(')
        self.assertIn('H.a_intent == I_GRAB && leaves', click)
        self.assertIn('H.a_intent == I_HARM && !leaves && branched', click)
        self.assertIn('new /obj/item/weapon/branch(get_turf(src))', click)
        self.assertIn('new /obj/item/wand_part/pine_wood(get_turf(src))', click)
        self.assertIn('sharpened = TRUE', definition(WEAPONS, '/obj/item/weapon/branch/attackby('))
        self.assertNotIn('cutting', definition(WEAPONS, '/obj/item/weapon/branch/attackby('))

    def test_provenance_and_leaf_state_are_durable_fields_not_runtime_flags(self):
        self.assertIn('var/cutting_viable = FALSE', definition(WEAPONS, '/obj/structure/branch'))
        cutting = definition(WEAPONS, '/obj/item/tree_cutting')
        self.assertIn('var/leaves = TRUE', cutting)
        self.assertNotIn('should_save = FALSE', cutting)
        self.assertNotIn('/obj/item/tree_cutting/persistence_runtime_var', WEAPONS)
        self.assertNotIn('/obj/structure/branch/persistence_runtime_var', WEAPONS)
