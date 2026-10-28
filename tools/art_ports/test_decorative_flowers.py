"""Offline source projections and real asset checks, not BYOND acceptance."""
import hashlib
import json
from pathlib import Path
import unittest

import flower_projection as dm
import humanity_wild_herbs as art


ROOT = Path(__file__).resolve().parents[2]
WILD = (ROOT / 'code/game/objects/structures/wild.dm').read_text(encoding='utf-8')
RADIATION = (ROOT / 'code/modules/1713/radiation.dm').read_text(encoding='utf-8')
TYPES = [dm.FLOWERS + '/' + state + '_scenery' for state in art.STATES]


class DecorativeFlowerTests(unittest.TestCase):
    def make(self, typename, wild=WILD, roll=3):
        return dm.Projection(wild, RADIATION, typename, roll)

    def assert_fixed(self, projected):
        self.assertEqual(projected.fields['icon'], projected.initial['icon'])
        self.assertEqual(projected.fields['icon_state'], projected.initial['icon_state'])

    def test_original_assets_and_all_four_type_contracts(self):
        manifest, pictures = art.sources()
        art.verify(ROOT / manifest['target'], pictures)
        required = json.loads((ROOT / 'tests/sprites/required-types.json').read_text())
        for typename, state in zip(TYPES, art.STATES):
            with self.subTest(typename=typename):
                p = self.make(typename)
                self.assertIn(typename, required)
                self.assertEqual(p.initial['icon'], manifest['target'])
                self.assertEqual(p.initial['icon_state'], state)
                self.assertTrue(p.initial['fixed_flower_appearance'])
                self.assertEqual((p.initial['health'], p.initial['maxhealth']), (5, 5))
                for key in ('density', 'opacity', 'edible', 'sways', 'amount', 'leaves',
                            'max_leaves', 'branches', 'max_branches'):
                    self.assertFalse(p.initial[key], key)
                self.assertTrue(p.initial['anchored'])

    def test_fixed_constructors_never_request_generic_or_invented_states(self):
        for typename in TYPES:
            p = self.make(typename)
            p.invoke('New')
            self.assert_fixed(p)
            self.assertEqual(p.draws, [])
            self.assertEqual(p.parent_calls, [(dm.FLOWERS, 'New')])

    def test_existing_generic_constructor_draws_remain_exact(self):
        for roll in range(1, 15):
            p = self.make(dm.FLOWERS, roll=roll)
            p.invoke('New')
            self.assertEqual(p.fields['icon_state'], f'flower{roll}')
            self.assertEqual(p.draws, [(1, 14)])
        # The existing flower3 bug is deliberately handled by another branch.

    def test_radiation_numeric_and_name_effects_match_actual_parent_source(self):
        for typename in TYPES:
            for initial in (0, 5, 14.9, 15):
                for amount in (-1, 0, .1, 5, 15, 1000):
                    with self.subTest(typename=typename, initial=initial, amount=amount):
                        child = self.make(typename)
                        parent = self.make(typename)
                        child.fields['radiation'] = parent.fields['radiation'] = initial
                        child.invoke('rad_act', amount)
                        parent.invoke('rad_act', amount, parent_only=True)
                        for key in ('radiation', 'health', 'maxhealth', 'name'):
                            self.assertEqual(child.fields[key], parent.fields[key], key)
                        self.assert_fixed(child)

    def test_repeated_radiation_is_not_repeated_damage_or_immunity(self):
        for typename in TYPES:
            p = self.make(typename)
            for amount in (15, 15, 0, -1, 100):
                p.invoke('rad_act', amount)
                self.assert_fixed(p)
            self.assertEqual(p.fields['health'], 2.5)
            self.assertEqual(p.fields['maxhealth'], 2.5)
            self.assertEqual(p.fields['radiation'], 130)
            self.assertEqual(p.fields['name'].count('irradiated'), 1)

    def test_subthreshold_and_nonpositive_radiation_do_not_erase_seasonal_icon(self):
        for amount in (-1, 0, 1):
            p = self.make(TYPES[0])
            p.fields['icon'] = 'injected-seasonal-native-icon'
            p.invoke('rad_act', amount)
            self.assertEqual(p.fields['icon'], 'injected-seasonal-native-icon')
            self.assertEqual(p.fields['health'], 5)

    def test_generic_radiation_and_load_are_unchanged(self):
        child = self.make(dm.FLOWERS)
        parent = self.make(dm.FLOWERS)
        child.fields['icon_state'] = parent.fields['icon_state'] = 'flower14'
        child.invoke('rad_act', 15)
        parent.invoke('rad_act', 15, parent_only=True)
        self.assertEqual(child.fields, parent.fields)
        child.fields['icon_state'] = 'flower8'
        child.invoke('after_load')
        self.assertEqual(child.fields['icon_state'], 'flower8')

    def test_actual_allowlist_projection_and_after_load_restore_fixed_identity(self):
        source = (ROOT / 'code/modules/persistence/functions.dm').read_text()
        self.assertIn('istype(src, /obj/structure/wild)', source)
        fields = source.split('map_storage_saved_vars = "density;', 1)[1].split('"', 1)[0]
        fields = ['density', *fields.split(';')]
        self.assertIn('icon_state', fields)
        self.assertNotIn('icon', fields)
        for typename in TYPES:
            original = self.make(typename)
            original.invoke('New')
            original.invoke('rad_act', 15)
            saved = {key: original.fields.get(key) for key in fields}
            restored = self.make(typename)
            restored.invoke('New')
            restored.fields.update(json.loads(json.dumps(saved)))
            restored.invoke('after_load')
            self.assert_fixed(restored)
            self.assertEqual(restored.fields['name'], original.fields['name'])
            # This does not emulate actual savefiles or change the parent's
            # unsaved health/radiation policy.
            restored.fields['icon'] = 'wrong-resource'
            restored.fields['icon_state'] = 'flower1'
            restored.invoke('after_load')
            self.assert_fixed(restored)

    def test_constructor_parent_radiation_and_load_omission_controls(self):
        mutations = [
            (WILD.replace('if (fixed_flower_appearance)\n\t\t\trestore_fixed_flower_appearance()',
                          'if (!fixed_flower_appearance)\n\t\t\trestore_fixed_flower_appearance()', 1), 'New'),
            (WILD.replace('/rad_act(amount)\n\t. = ..()', '/rad_act(amount)\n\t// omitted parent', 1), 'rad_act'),
            (WILD.replace('/after_load()\n\t. = ..()\n\t// Wild saves retain icon_state, but not a changed icon resource.\n\trestore_fixed_flower_appearance()',
                          '/after_load()\n\t. = ..()', 1), 'after_load'),
        ]
        for wild, method in mutations:
            self.assertNotEqual(wild, WILD)
            p = self.make(TYPES[0], wild)
            if method == 'New':
                p.invoke(method)
                self.assertNotEqual(p.fields['icon_state'], p.initial['icon_state'])
            elif method == 'rad_act':
                p.invoke(method, 15)
                self.assertEqual(p.fields['health'], 5)  # Detect missing inherited damage.
            else:
                p.fields['icon_state'] = 'flower1'
                p.invoke(method)
                self.assertNotEqual(p.fields['icon_state'], p.initial['icon_state'])

    def test_radiation_deadicon_shortcut_control_exposes_accidental_immunity(self):
        p = self.make(TYPES[0])
        p.fields['deadicon'] = p.fields['icon']
        p.fields['deadicon_state'] = p.fields['icon_state']
        p.invoke('rad_act', 15)
        self.assertEqual(p.fields['health'], 5)
        self.assertNotIn('irradiated', p.fields['name'])

    def test_gameplay_placement_and_shared_policies_are_unchanged(self):
        pins = json.loads((Path(__file__).parent / 'decorative-flower-protected-sources.json').read_text())
        for filename, expected in pins.items():
            data = (ROOT / filename).read_text(encoding='utf-8').encode()
            self.assertEqual(hashlib.sha256(data).hexdigest(), expected, filename)
        for typename in TYPES:
            body = dm.block(WILD, typename)
            self.assertNotIn('New()', body)
            self.assertNotIn('attack', body)
            self.assertNotIn('harvest', body)
            self.assertNotIn('spawn', body)

    def test_projection_refuses_unreviewed_source_syntax(self):
        p = self.make(TYPES[0])
        with self.assertRaises(ValueError):
            p.execute('\tspawn(1)\n\t\tmedical_effect()', dm.FLOWERS, 'unknown', {})


if __name__ == '__main__':
    unittest.main()
