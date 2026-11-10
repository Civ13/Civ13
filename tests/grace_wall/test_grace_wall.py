"""Source parity of the opt-in map grace-wall helper and its callers.

The fixture is the pre-extraction decision body, not a second implementation.
These tests do not run BYOND or establish gameplay behavior.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
MAPS = ROOT / 'code/game/objects/map_metadata'
HERE = Path(__file__).resolve().parent
NAMES = ('barbarossa', 'caloocan', 'camp', 'east_los_santos', 'hill203',
         'holdmadrid', 'hotel', 'marco_polo_bridge', 'oasis', 'omaha',
         'pavlov_house', 'reichstag', 'rizal_stadium', 'siberiad',
         'twotribes', 'warsaw')


def body(source, header):
    match = re.search(r'(?m)^' + re.escape(header) + r'\n(.*?)(?=^/|\Z)', source, re.S)
    if not match:
        raise AssertionError(f'missing {header}')
    return match.group(1).strip('\n')


def parity_errors(base, maps):
    errors = []
    helper = '/obj/map_metadata/proc/check_two_sided_grace_wall(var/mob/living/human/H, var/turf/T)'
    expected = (HERE / 'original_body.dm.txt').read_text(encoding='utf-8').strip('\n')
    if body(base, helper) != expected:
        errors.append('helper differs from pre-extraction behavior')
    for name in NAMES:
        header = f'/obj/map_metadata/{name}/check_caribbean_block(var/mob/living/human/H, var/turf/T)'
        if body(maps[name], header) != '\treturn check_two_sided_grace_wall(H, T)':
            errors.append(f'{name} must call the shared helper')
    return errors


class GraceWallParity(unittest.TestCase):
    def setUp(self):
        self.base = (MAPS / '_map_metadata.dm').read_text(encoding='utf-8')
        self.maps = {name: (MAPS / f'{name}.dm').read_text(encoding='utf-8') for name in NAMES}

    def test_all_opted_in_maps_preserve_exact_decision_body(self):
        self.assertEqual(parity_errors(self.base, self.maps), [])

    def test_detects_changed_faction_and_grace_rules(self):
        for original, replacement in (('H.faction_text == faction1', 'H.faction_text == faction2'),
                                      ('return !faction1_can_cross_blocks()', 'return FALSE')):
            with self.subTest(original=original):
                altered = self.base.replace(original, replacement, 1)
                self.assertNotEqual(altered, self.base)
                self.assertTrue(parity_errors(altered, self.maps))

    def test_detects_wrong_dispatch(self):
        changed = dict(self.maps)
        changed['oasis'] = changed['oasis'].replace('return check_two_sided_grace_wall(H, T)', 'return FALSE', 1)
        self.assertTrue(parity_errors(self.base, changed))


if __name__ == '__main__':
    unittest.main()
