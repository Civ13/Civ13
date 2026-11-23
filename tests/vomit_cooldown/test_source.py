"""The vomit cooldown is runtime-only state (issue 6892).

Its timers never survive a restart, so a saved TRUE would block vomiting forever.
Native check: python3 tests/ecology_spawning/run_linux.py . tests/vomit_cooldown/probe.dm
"""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
DEFINES = (ROOT / 'code/game/mob/living/carbon/carbon_defines.dm').read_text(encoding='utf-8')


class VomitCooldownTests(unittest.TestCase):
    def test_lastpuke_is_tmp(self):
        self.assertRegex(DEFINES, r'(?m)^\tvar/tmp/lastpuke = FALSE')
        self.assertIsNone(re.search(r'(?m)^\tvar/lastpuke\b', DEFINES))


if __name__ == '__main__':
    unittest.main()
