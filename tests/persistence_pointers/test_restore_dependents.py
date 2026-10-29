"""Regressions for constructor action graphs and discarded grab dependents."""
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
from inventory import ROOT
sys.path.insert(0, str(ROOT / 'tests/save_movement'))
from source_adapter import extract, project


def read(path):
    return (ROOT / path).read_text(encoding='utf-8-sig')


class RestoreDependents(unittest.TestCase):
    def test_actual_owner_filters_preserve_constructor_identity_on_legacy_import(self):
        for path, owner, names in (
            ('code/processes/abandoned_items.dm', '/obj/item', ('actions', 'action')),
            ('code/modules/1713/machinery/modular_vehicles/wheels.dm', '/obj/item/turret_controls', ('azoom',)),
        ):
            declaration = owner + '/persistence_runtime_var'
            body = extract(read(path), declaration).replace('..()', 'parent(key)')
            fn = project(declaration + '(key)\n' + body + '\n', declaration, 'key', {'parent': lambda key: False})
            constructor = {key: object() for key in names}
            restored = constructor.copy()
            for key, value in dict.fromkeys(names, None).items():
                if not fn(key):
                    restored[key] = value
            for key in names:
                self.assertIs(restored[key], constructor[key])
            self.assertFalse(fn('durable_item_state'))

    def test_item_constructor_action_fields_survive_null_legacy_graphs(self):
        body = extract(read('code/processes/abandoned_items.dm'), '/obj/item/persistence_runtime_var')
        self.assertIn('key == "actions"', body)
        self.assertIn('key == "action"', body)
        source = read('code/modules/1713/machinery/modular_vehicles/wheels.dm')
        body = extract(source, '/obj/item/turret_controls/persistence_runtime_var')
        self.assertIn('key == "azoom"', body)
        restored = extract(source, '/obj/item/turret_controls/after_load')
        self.assertIn('azoom.scope = optics', restored)
        self.assertIn('azoom.Grant(holder)', restored)
        self.assertIn('holder.l_hand == src || holder.r_hand == src', restored)

    def test_scope_inherited_exclusion_and_restored_grants(self):
        config = read('code/modules/1713/gunsmithing/gun_configuration.dm')
        body = extract(config, '/obj/item/weapon/attachment/persistence_runtime_var')
        for field in ('actions', 'azoom'):
            self.assertIn('"' + field + '"', body)
        self.assertIn('..()', body)
        scope = extract(read('code/modules/1713/weapons/zoom.dm'), '/obj/item/weapon/attachment/scope/after_load')
        self.assertIn('on_changed_slot()', scope)
        gun = extract(config, '/obj/item/weapon/gun/after_load')
        self.assertLess(gun.index('recompute_configuration()'), gun.index('update_attachment_actions(holder)'))

    def test_discarded_grab_and_garrote_state_is_transient(self):
        mob = extract(read('code/modules/persistence/functions.dm'), '/mob/persistence_runtime_var')
        self.assertIn('key == "mouth_covered"', mob)
        source = read('code/game/objects/items/weapons/swords_axes_etc.dm')
        runtime = extract(source, '/obj/item/garrote/persistence_runtime_var')
        for field in ('garroting', 'next_garrote'):
            self.assertIn('key == "' + field + '"', runtime)
        restore = extract(source, '/obj/item/garrote/after_load')
        self.assertIn('garroting = initial(garroting)', restore)
        self.assertIn('update_icon()', restore)
        for durable in ('handcuffed', 'legcuffed', 'buckled', 'canmove', 'paralysis', 'stunned'):
            self.assertNotIn(durable, restore)

    def test_restored_living_mob_recreates_generic_item_actions(self):
        body = extract(read('code/game/mob/living/living_defense.dm'), '/mob/living/after_load')
        self.assertIn('..()', body)
        self.assertIn('handle_actions()', body)


if __name__ == '__main__':
    unittest.main()
