"""Offline source contracts for jungle hiding; this does not execute DM."""
from pathlib import Path
import re
import unittest

SOURCE = (Path(__file__).resolve().parents[2] / "code/game/objects/structures/wild.dm").read_text(encoding="utf-8")


def proc(path):
    match = re.search(rf"(?m)^{re.escape(path)}[^\n]*\n(?:(?:\t[^\n]*|)\n)*", SOURCE)
    if not match:
        raise AssertionError(f"missing {path}")
    return match.group()


class JungleHiding(unittest.TestCase):
    def test_post_wait_claim_checks_and_move_failure(self):
        action = proc('/obj/structure/wild/jungle/MouseDrop_T')
        finish = proc('/obj/structure/wild/jungle/proc/finish_hiding')
        self.assertIn('if (dropping != user)', action)
        self.assertLess(action.index('if (dropping != user)'), action.index('do_after(user,100,src)'))
        self.assertIn('finish_hiding(H, save_identity)', action)
        for term in ('stored_unit', '!H.Adjacent(src)', '!isturf(H.loc)', 'H.restrained()',
                     'H.faction_text != "VIETNAMESE"', 'save_identity != persistence_admission_identity',
                     'persistence_save_in_progress', 'persistence_load_recovery_required',
                     '!H.forceMove(src)', 'H.loc != src', 'stored_unit != H'):
            self.assertIn(term, finish)
        self.assertLess(finish.index('stored_unit = H'), finish.index('H.forceMove(src)'))
        self.assertLess(finish.index('H.forceMove(src)'), finish.index('H.client.eye = src'))

    def test_release_does_not_require_a_client_and_destroy_releases(self):
        release = proc('/obj/structure/wild/proc/release_stored')
        destroy = proc('/obj/structure/wild/jungle/Destroy')
        self.assertIn('occupant.loc == src && T', release)
        self.assertLess(release.index('stored_unit = null'), release.index('occupant.forceMove(T)'))
        self.assertIn('\n\t\t\toccupant.forceMove(T)', release)
        self.assertIn('occupant.client && occupant.client.eye == src', release)
        self.assertLess(destroy.index('release_stored()'), destroy.index('return ..()'))


if __name__ == '__main__':
    unittest.main()
