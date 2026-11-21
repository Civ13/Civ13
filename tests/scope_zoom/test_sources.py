"""Offline source contract for the scope adjustment lock (#6219).

Behaviour is covered natively by tests/scope_zoom/probe.dm.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/1713/weapons/zoom.dm').read_text(encoding='utf-8-sig')


def proc(name):
    return SOURCE.split(name + '\n', 1)[1].split('\n/', 1)[0]


class ScopeAdjustmentLock(unittest.TestCase):
    def test_lock_released_on_every_wait_outcome(self):
        body = proc('/obj/item/weapon/attachment/scope/adjustable/proc/adjust_scope(mob/living/human/user)')
        lock = body.index('looking = TRUE')
        wait = body.index('var/adjusted = do_after(user, 7, src)')
        release = body.index('looking = FALSE')
        branch = body.index('if (adjusted)')
        self.assertLess(lock, wait)
        self.assertLess(wait, release)
        self.assertLess(release, branch)
        self.assertNotIn('if (do_after(', body)

    def test_lock_is_never_saved(self):
        self.assertIn('var/tmp/looking = FALSE', SOURCE)


if __name__ == '__main__':
    unittest.main()
