"""Offline source contract for the SR-3 suppressor (#6363).

Behaviour is covered natively by tests/sr3_suppressor/probe.dm.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
ATTACH = (ROOT / 'code/modules/1713/weapons/attachment.dm').read_text(encoding='utf-8-sig')
SMG = (ROOT / 'code/modules/1713/weapons/guns/mg/smg.dm').read_text(encoding='utf-8-sig')


def body(source, header):
    return source.split(header + '\n', 1)[1].split('\n/', 1)[0]


class SR3Suppressor(unittest.TestCase):
    def test_suppressor_fits_the_sr3_class(self):
        srm = body(ATTACH, '/obj/item/weapon/attachment/silencer/rifle/srm')
        self.assertIn('"machinegun"', srm.split('fits = list(', 1)[1].split(')', 1)[0])
        self.assertIn('caliber = "a9x39"', srm)

    def test_sr3_installs_it(self):
        self.assertIn('silencer/rifle/srm', body(SMG, '/obj/item/weapon/gun/projectile/submachinegun/srm/New()'))


if __name__ == '__main__':
    unittest.main()
