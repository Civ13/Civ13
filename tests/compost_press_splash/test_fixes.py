"""Compost stock survives saves (#5292), splashes water crops only with their
water (#5302) and unfastened tablet presses stop (#5303).

Offline structural checks on current source. No BYOND, network or saves.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


def block(text, header):
    lines = text.splitlines()
    start = lines.index(header)
    body = []
    for line in lines[start + 1:]:
        if line and not line.startswith('\t'):
            break
        body.append(line)
    return '\n'.join(body)


class CompostSaveTests(unittest.TestCase):
    def setUp(self):
        self.source = read('code/modules/1713/production.dm')

    def test_stock_is_a_saved_field(self):
        decl = block(self.source, '/obj/structure/compost')
        self.assertRegex(decl, r'(?m)^\tvar/current = 0$')
        self.assertNotIn('var/tmp/current', decl)
        self.assertIn('var/tmp/composting', decl)

    def test_save_does_not_zero_the_live_bin(self):
        self.assertNotIn('/obj/structure/compost/before_save()', self.source)

    def test_load_restarts_the_cycle(self):
        self.assertIn('initialize()', block(self.source, '/obj/structure/compost/after_load()'))


class SplashWaterTests(unittest.TestCase):
    def setUp(self):
        self.body = block(read('code/modules/reagents/Chemistry-Holder.dm'),
                          '/datum/reagents/proc/splash(var/atom/target, var/amount = TRUE, copy = FALSE)')

    def test_credit_is_the_water_share_measured_before_transfer(self):
        share = self.body.index('get_reagent_amount("water") * min(amount, total_volume) / total_volume')
        self.assertLess(share, self.body.index('trans_to(target, amount, 1, copy)'))

    def test_plants_get_only_the_water_share(self):
        self.assertIn('P.water = min(P.water+water_splashed,P.max_water)', self.body)
        self.assertNotIn('P.water+amount', self.body)

    def test_share_projection(self):
        def share(water, total, amount):
            return water * min(amount, total) / total if total > 0 else 0
        self.assertEqual(share(0, 30, 30), 0)        # ethanol only
        self.assertEqual(share(10, 30, 30), 10)      # mixed, whole spill
        self.assertEqual(share(10, 30, 15), 5)       # mixed, partial pour
        self.assertEqual(share(30, 30, 50), 30)      # pure water, oversized amount


class TabletPressAnchorTests(unittest.TestCase):
    def setUp(self):
        self.source = read('code/modules/1713/factory_packaging.dm')

    def test_can_press_requires_anchoring(self):
        body = block(self.source, '/obj/structure/fluid_tablet_press/proc/can_press()')
        self.assertRegex(body, r'if \(!anchored \|\| !isturf\(loc\)')

    def test_failed_press_releases_power(self):
        body = block(self.source, '/obj/structure/fluid_tablet_press/proc/press_step()')
        guard = body.index('if (!can_press())')
        self.assertLess(guard, body.index('press_release_power()'))
        self.assertLess(body.index('press_release_power()'), body.index('draw_cable_power()'))


if __name__ == '__main__':
    unittest.main()
