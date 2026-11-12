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


class StoneWallExplosion(unittest.TestCase):
    # These families historically differed on WHITERUN, including the
    # horizontal stone wall and its crenelated child.
    unprotected = ('sandstone_h', 'sandstone_v', 'sandstone_h/crenelated',
                   'sandstone_v/crenelated', 'stone_h')
    protected = ('stone_v', 'stone_h/crenelated', 'stone_v/crenelated',
                 'jap_h', 'jap_h_l', 'jap_h_r', 'jap_v', 'jap_v_t',
                 'jap_v_b', 'jap')

    def exercise(self, kind, map_id, health, severity):
        source = read(BARRICADES)
        declaration = '/obj/structure/barricade/proc/stone_wall_explosion'
        body = extract(source, declaration)
        # Project the DM numeric switch as equivalent mutually exclusive tests.
        body = body.replace('\tswitch(severity)\n', '')
        for number in (1, 2, 3):
            keyword = 'if' if number == 1 else 'else if'
            body = body.replace(f'\t\tif ({number}.0)',
                                f'\t{keyword} (severity == {number}.0)')
        body = body.replace('\t\t\thealth -=', '\t\tsrc.health -=')
        body = body.replace('if (health <= 0)', 'if (src.health <= 0)')
        events = []
        wall = SimpleNamespace(health=health)
        helper_source = '/proc/stone_wall_explosion(severity)\n' + body + '\n'
        helper = project(helper_source, '/proc/stone_wall_explosion', 'severity',
                         {'src': wall, 'visible_message': lambda value: events.append(value),
                          'SPAN_DANGER': lambda value: value,
                          'qdel': lambda value: events.append('deleted')})
        entry = '/obj/structure/barricade/' + kind + '/ex_act'
        handler = project(source, entry, 'severity',
                          {'map': SimpleNamespace(ID=map_id),
                           'stone_wall_explosion': helper})
        handler(severity)
        return wall.health, events

    def test_damage_and_destruction_for_every_wall_family(self):
        for kind in self.unprotected + self.protected:
            for severity, damage in ((1, 150), (2, 100), (3, 50), (0, 0)):
                for health in (200, damage, 0):
                    with self.subTest(kind=kind, severity=severity, health=health):
                        remaining, events = self.exercise(kind, 'GAIA', health, severity)
                        self.assertEqual(remaining, health - damage)
                        self.assertEqual(len(events), 2 if remaining <= 0 else 0)
                        if events:
                            self.assertIn('is blown apart', events[0])
                            self.assertEqual(events[1], 'deleted')

    def test_whiterun_guard_remains_specific_to_each_family(self):
        for kind in self.protected:
            with self.subTest(kind=kind):
                self.assertEqual(self.exercise(kind, 'WHITERUN', 0, 1), (0, []))
        for kind in self.unprotected:
            with self.subTest(kind=kind):
                remaining, events = self.exercise(kind, 'WHITERUN', 100, 1)
                self.assertEqual(remaining, -50)
                self.assertEqual(len(events), 2)
