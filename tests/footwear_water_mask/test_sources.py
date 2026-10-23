"""Offline composition/refresh contracts. These do not establish rendered pixels."""
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

from prepare import ROOT, SOURCE, PROCS, procedure, stage

DEPLOYED = '77c14940584bedfa6241ecf1e0642a53ca6df0c7'


def source(path):
    return (ROOT / path).read_text(encoding='utf-8')


def composition_contract(text):
    helper = procedure(text, 'proc/apply_footwear_water_mask')
    assert 'var/image/footwear = overlays_standing[SHOES_LAYER]' in helper
    assert 'if (!footwear)\n\t\treturn' in helper
    assert 'footwear.filters = null\n\tif (mask_icon)' in helper
    assert 'footwear.appearance_flags |= KEEP_TOGETHER' in helper
    assert 'footwear.filters += filter(type="alpha", icon=mask_icon, flags=MASK_INVERSE)' in helper
    assert 'else\n\t\tfootwear.appearance_flags &= ~KEEP_TOGETHER' in helper
    shoes = procedure(text, 'update_inv_shoes')
    assert 'apply_footwear_water_mask(get_water_mask_icon())' in shoes
    assert shoes.index('apply_footwear_water_mask(get_water_mask_icon())') < shoes.index('if (update_icons)')
    fire = procedure(text, 'update_fire')
    assert 'apply_footwear_water_mask(mask_icon)' in fire
    assert fire.index('apply_footwear_water_mask(mask_icon)') < fire.index('if (update_icons)')


class FootwearMaskContracts(unittest.TestCase):
    def test_composite_mask_and_both_refresh_boundaries(self):
        composition_contract(source(SOURCE))

    def test_each_bug_control_is_rejected(self):
        text = source(SOURCE)
        for old, new in (
            ('footwear.appearance_flags |= KEEP_TOGETHER', '// missing composite'),
            ('apply_footwear_water_mask(get_water_mask_icon())', '// stale replacement'),
            ('apply_footwear_water_mask(mask_icon)', '// stale depth/exit'),
            ('footwear.appearance_flags &= ~KEEP_TOGETHER', '// sticky grouping'),
            ('flags=MASK_INVERSE)', 'flags=0)'),
        ):
            with self.subTest(control=old), self.assertRaises(AssertionError):
                composition_contract(text.replace(old, new))

    def test_deployed_source_exhibits_ungrouped_nested_stain(self):
        old = subprocess.check_output(['git', 'show', DEPLOYED + ':' + SOURCE], cwd=ROOT, text=True)
        shoes = procedure(old, 'update_inv_shoes')
        self.assertIn('standing.overlays += bloodsies', shoes)
        self.assertNotIn('KEEP_TOGETHER', shoes)
        with self.assertRaises(AssertionError):
            composition_contract(old)
        # Depth decisions and art are unchanged, including 0, 30 and 100 boundaries.
        start = old.index('\tif (drowning || water_overlay)', old.index('/mob/living/human/update_fire('))
        end = old.index('\t\tvar/icon/mask_icon =', start)
        selection = old[start:end]
        selection = re.sub(r'\t\t\telse\n[\s\S]*?\t\telse if \(drowning\)',
                           '\t\t\telse\n\t\t\t\treturn null\n\t\telse if (drowning)', selection)
        current = procedure(source(SOURCE), 'proc/get_water_mask_icon')
        self.assertIn(selection, current)
        self.assertIn("return icon('icons/turf/beach.dmi', mask_state)", current)

    def test_mud_and_blood_share_worn_stain_but_dirtyness_is_text(self):
        shoes = procedure(source(SOURCE), 'update_inv_shoes')
        self.assertIn('"icon_state" = "shoeblood"', shoes)
        self.assertIn('bloodsies.color = shoes.blood_color', shoes)
        self.assertNotIn('dirtyness', shoes)
        self.assertNotIn('blood_overlay', shoes)  # item/inventory decal is not copied to the mob
        movement = source('code/game/mob/mob_movement.dm')
        self.assertIn('S.blood_color = "#70543E"', movement)
        self.assertIn('S.blood_DNA = list()', movement)
        blood = source('code/game/objects/effects/decals/Cleanable/humans.dm')
        self.assertIn('S.blood_color = basecolor', blood)
        self.assertIn('perp.update_inv_shoes(1)', blood)

    def test_no_stain_state_writes_or_plane_layer_direction_changes(self):
        text = source(SOURCE)
        helpers = ''.join(procedure(text, p) for p in PROCS[3:])
        for field in ('blood_DNA', 'feet_blood_DNA', 'blood_color', 'dirtyness', 'track_blood',
                      'plane', 'layer', 'dir', 'transform', 'overlays'):
            self.assertNotRegex(helpers, r'\b' + field + r'\s*(?:=(?!=)|\+=|-=|\.Cut\()')
        # The sole grouping target is the shoe image, never the human or plane master.
        self.assertEqual(text.count('appearance_flags |= KEEP_TOGETHER'), 1)

    def test_constructor_keeps_original_icons_tint_and_barefoot_fallback(self):
        old = subprocess.check_output(['git', 'show', DEPLOYED + ':' + SOURCE], cwd=ROOT, text=True)
        shoes = procedure(source(SOURCE), 'update_inv_shoes')
        addition = ('\t// Equipment/stain refreshes can replace this image between water updates.\n'
                    '\tapply_footwear_water_mask(get_water_mask_icon())\n')
        self.assertEqual(shoes.replace(addition, ''), procedure(old, 'update_inv_shoes'))

    def test_prepared_packet_uses_exact_production_bodies_and_assets(self):
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp) / 'packet'
            manifest = stage(output)
            prepared = (output / 'production.dm').read_text(encoding='utf-8')
            for name in PROCS:
                self.assertIn(procedure(source(SOURCE), name), prepared)
            self.assertIn('icons/turf/beach.dmi', manifest['sha256'])
            self.assertFalse((output / 'probe.dmb').exists())


if __name__ == '__main__':
    unittest.main()
