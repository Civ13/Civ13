"""Offline source contract for railing dismantling (#4413); does not execute DM."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
RAILING = ROOT / "code/game/objects/structures/railing.dm"


def dismantle_body(source):
    body = source.split('/obj/structure/railing/attackby(', 1)[1]
    return body.split('// Install', 1)[0]


def project(body, anchored_after_wait, deleted_after_wait=False):
    """Whether the hammer completion produces salvage and deletes the railing."""
    after_wait = body.split('if (do_after(user, 20, src))', 1)[1]
    salvage_at = after_wait.index('qdel(src)')
    guard = 'if (QDELETED(src) || anchored)'
    if guard in after_wait and after_wait.index(guard) < salvage_at:
        return not (deleted_after_wait or anchored_after_wait)
    return True


class RailingDismantleSource(unittest.TestCase):
    def setUp(self):
        self.body = dismantle_body(RAILING.read_text(encoding="utf-8"))

    def test_fastened_during_wait_is_not_dismantled(self):
        self.assertFalse(project(self.body, anchored_after_wait=True))
        self.assertFalse(project(self.body, anchored_after_wait=False, deleted_after_wait=True))

    def test_unfastened_railing_still_dismantles(self):
        self.assertTrue(project(self.body, anchored_after_wait=False))

    def test_regression_without_guard(self):
        old = self.body.replace('if (QDELETED(src) || anchored)', 'if (FALSE)', 1)
        self.assertTrue(project(old, anchored_after_wait=True))


if __name__ == "__main__":
    unittest.main()
