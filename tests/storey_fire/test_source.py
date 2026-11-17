"""Shooting down from an upper storey: source contracts. Behaviour is in probe.dm:

    python3 tests/storey_fire/test_source.py
    python3 tests/ecology_spawning/run_linux.py . tests/storey_fire/probe.dm
"""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


class StoreyFireSource(unittest.TestCase):
    def test_included_after_projectile(self):
        dme = read('civ13.dme')
        self.assertLess(dme.index('code\\modules\\projectiles\\projectile.dm"'), dme.index('code\\modules\\projectiles\\storey_fire.dm"'))

    def test_hook(self):
        fire = read('code/modules/projectiles/storey_fire.dm')
        self.assertIn('if (!forced && storey_drop_shot(T))', fire)
        self.assertIn('return ..()', fire)
        # Lobbed arrows and shots aimed past the open air are left alone.
        self.assertIn('if (lobbed ||', fire)
        self.assertIn('get_turf(original) != T', fire)


if __name__ == '__main__':
    unittest.main()
