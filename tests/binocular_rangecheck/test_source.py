"""Range-check locks on binoculars, periscopes and laser designators are runtime-only (issue 6983).

A save taken mid-check would otherwise restore checking = TRUE and lock the item forever.
Native check: python3 tests/ecology_spawning/run_linux.py . tests/binocular_rangecheck/probe.dm
"""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
ZOOM = (ROOT / 'code/modules/1713/weapons/zoom.dm').read_text(encoding='utf-8')


class RangeCheckLockTests(unittest.TestCase):
    def test_every_checking_lock_is_tmp(self):
        self.assertEqual(len(re.findall(r'(?m)^\tvar/tmp/checking = FALSE', ZOOM)), 3)
        self.assertIsNone(re.search(r'(?m)^\tvar/checking\b', ZOOM))


if __name__ == '__main__':
    unittest.main()
