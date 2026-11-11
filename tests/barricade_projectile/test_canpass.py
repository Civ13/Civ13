"""Project barricade projectile admission with a recorded impact boundary."""
from pathlib import Path
from types import SimpleNamespace
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'save_movement'))
from source_adapter import extract, project, read

BARRICADES = 'code/game/objects/structures/barricades.dm'


def projectile_admission(target_is_barricade, probability_result):
    body = extract(read(BARRICADES), '/obj/structure/barricade/CanPass')
    branch = body.split('\tif (istype(mover, /obj/item/projectile))\n', 1)[1]
    branch = branch.split('\n\telse\n', 1)[0]
    lines = [line[2:] for line in branch.splitlines() if line.strip()]
    assert lines[-1].strip() == 'return prob(hitchance)'
    code = '\n'.join('\t' + line for line in lines)
    source = '/proc/admit(mover, target, loc, protection_chance)\n' + code + '\n'
    probabilities = []
    def prob(value):
        probabilities.append(value)
        return probability_result
    handler = project(source, '/proc/admit', 'mover, target, loc, protection_chance',
                      {'prob': prob, 'get_turf': lambda target: target})
    impacts = []
    projectile = SimpleNamespace(penetrating=12, on_impact=impacts.append)
    loc = object()
    target = loc if target_is_barricade else object()
    result = handler(projectile, target, loc, 85)
    return result, impacts, probabilities


class BarricadeProjectileAdmission(unittest.TestCase):
    def test_projectile_passes_without_premature_impact(self):
        result, impacts, probabilities = projectile_admission(True, True)
        self.assertTrue(result)
        self.assertEqual(probabilities, [63])
        self.assertEqual(impacts, [])

    def test_blocked_projectile_is_left_to_caller_to_impact(self):
        result, impacts, probabilities = projectile_admission(True, False)
        self.assertFalse(result)
        self.assertEqual(probabilities, [63])
        self.assertEqual(impacts, [])

    def test_other_target_preserves_chance_without_impact(self):
        result, impacts, probabilities = projectile_admission(False, True)
        self.assertTrue(result)
        self.assertEqual(probabilities, [37])
        self.assertEqual(impacts, [])
