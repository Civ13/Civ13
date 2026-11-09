"""Offline source contracts for spray bottles (#4269, #4270); these do not execute DM."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "code/modules/reagents/reagent_containers/spray.dm"


def afterattack(source):
    return source.split('/obj/item/weapon/reagent_containers/spray/afterattack(', 1)[1].split('\n/obj/', 1)[0]


def project(source, safety, contents):
    """Returns (sound_played, logged) for one spray click."""
    body = afterattack(source)
    pepper = source.split('/obj/item/weapon/reagent_containers/spray/pepper/Spray_at(', 1)[1].split('\n/obj/', 1)[0]
    snapshot = 'var/has_sacid = reagents.has_reagent("sacid")' in body and \
        body.index('var/has_sacid') < body.index('Spray_at(A, user, proximity)')
    gated = 'if (!Spray_at(A, user, proximity))' in body
    refuses = 'return FALSE' in pepper.split('if (safety)', 1)[1].split('return ..()', 1)[0]
    held = set(contents)
    before = set(held)
    accepted = not (safety and refuses)
    if not safety:
        held.clear()  # the last adjacent dose empties the holder
    if gated and not accepted:
        return False, set()
    seen = before if snapshot else held
    return True, seen & {'sacid', 'pacid', 'lube'}


class SpraySource(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding="utf-8")

    def test_every_spray_at_reports_acceptance(self):
        base = self.source.split('/obj/item/weapon/reagent_containers/spray/proc/Spray_at(', 1)[1].split('\n/obj/', 1)[0]
        chem = self.source.split('/obj/item/weapon/reagent_containers/spray/chemsprayer/Spray_at(', 1)[1].split('\n/obj/', 1)[0]
        pepper = self.source.split('/obj/item/weapon/reagent_containers/spray/pepper/Spray_at(', 1)[1].split('\n/obj/', 1)[0]
        self.assertTrue(base.rstrip().endswith('return TRUE'))
        self.assertTrue(chem.rstrip().endswith('return TRUE'))
        self.assertIn('return FALSE', pepper)
        self.assertIn('return ..()', pepper)

    def test_last_dose_still_logged(self):
        # #4269
        self.assertEqual(project(self.source, False, ['sacid']), (True, {'sacid'}))
        no_snapshot = self.source.replace('var/has_sacid = reagents.has_reagent("sacid")', 'var/has_sacid = FALSE', 1)
        self.assertEqual(project(no_snapshot, False, ['sacid']), (True, set()))

    def test_safety_refusal_gives_no_feedback_or_log(self):
        # #4270
        self.assertEqual(project(self.source, True, ['lube']), (False, set()))
        ungated = self.source.replace('if (!Spray_at(A, user, proximity))\n\t\treturn', 'Spray_at(A, user, proximity)', 1)
        self.assertEqual(project(ungated, True, ['lube']), (True, {'lube'}))


if __name__ == "__main__":
    unittest.main()
