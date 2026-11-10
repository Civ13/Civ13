"""Offline projection of explosion panel selection; not a native combat test."""
from pathlib import Path
import importlib.util
import re
from types import SimpleNamespace
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
GRENADE = (ROOT/'code/game/objects/items/weapons/grenades/grenade.dm').read_text(encoding='utf-8')
DRONE = (ROOT/'code/game/objects/items/devices/drone.dm').read_text(encoding='utf-8')


def projected_selection():
    body = GRENADE.split('/proc/explosion_damage_hull_panel(', 1)[1].split('\n// grenades set off', 1)[0]
    lines = ['def damage(F, hit_origin, message_origin, heavy_armor_penetration):']
    for raw in body.splitlines()[1:]:
        if not raw.strip():
            continue
        depth = len(raw)-len(raw.lstrip('\t'))
        line = raw.strip()
        if line == 'var/penloc = F.CheckPenLoc(hit_origin)':
            line = 'penloc = F.CheckPenLoc(hit_origin)'
        elif line == 'switch(penloc)':
            continue
        elif depth == 2 and re.fullmatch(r'if \("[a-z]+"\)', line):
            line = 'if penloc == '+line[4:-1]+':'
            depth = 1
        else:
            depth -= 1
            if line.startswith('if ('):
                line = 'if '+line[4:-1].replace('&&', ' and ')+':'
            elif line == 'else':
                line = 'else:'
            elif line.startswith('message_origin.visible_message('):
                line = 'message_origin.visible_message(penloc)'
            elif not re.fullmatch(r'F\.w_\w+\[5\] -= heavy_armor_penetration', line):
                raise AssertionError('Unreviewed hull operation: '+line)
        lines.append('    '*depth+line)
    namespace = {}
    exec(compile('\n'.join(lines), '<production hull selection>', 'exec'), namespace)
    return namespace['damage']


class HullDamage(unittest.TestCase):
    def run_hit(self, direction, armor=None, health=None):
        armor = armor or {}
        health = health or {}
        frame = SimpleNamespace(**{'w_'+side: [None, 0, 0, 0, armor.get(side, 10), health.get(side, 100)]
                                   for side in ('left', 'right', 'front', 'back')})
        seen = []
        frame.CheckPenLoc = lambda origin: seen.append(origin) or direction
        message = SimpleNamespace(visible_message=lambda value: seen.append(value))
        origin = object()
        projected_selection()(frame, origin, message, 7)
        return {side: getattr(frame, 'w_'+side)[5] for side in ('left', 'right', 'front', 'back')}, seen, origin

    def test_cardinal_hits_and_destroyed_panel(self):
        for side in ('left', 'right', 'front', 'back'):
            with self.subTest(side=side):
                result, seen, origin = self.run_hit(side)
                self.assertEqual(result[side], 93)
                self.assertEqual(sum(result.values()), 393)
                self.assertIs(seen[0], origin)
                self.assertEqual(len(seen), 2)
                result, seen, _ = self.run_hit(side, health={side: 0})
                self.assertEqual(result[side], 0)
                self.assertEqual(len(seen), 1)
        result, seen, _ = self.run_hit('unknown')
        self.assertEqual(sum(result.values()), 400)
        self.assertEqual(len(seen), 1)

    def test_diagonal_armor_ties_and_destroyed_panels(self):
        for direction, lateral, longitudinal in [('frontleft', 'left', 'front'), ('frontright', 'right', 'front'),
                                                   ('backleft', 'left', 'back'), ('backright', 'right', 'back')]:
            for armor, selected in [({lateral: 11, longitudinal: 10}, lateral),
                                    ({lateral: 9, longitudinal: 10}, longitudinal),
                                    ({lateral: 10, longitudinal: 10}, longitudinal)]:
                with self.subTest(direction=direction, armor=armor):
                    result, _, _ = self.run_hit(direction, armor=armor)
                    self.assertEqual(result[selected], 93)
                    self.assertEqual(sum(result.values()), 393)
            for missing in (lateral, longitudinal):
                result, seen, _ = self.run_hit(direction, health={missing: 0})
                self.assertEqual(sum(result.values()), 300)
                self.assertEqual(len(seen), 1)

    def test_callers_keep_origins_and_distinct_effects(self):
        self.assertEqual(GRENADE.count('explosion_damage_hull_panel(F, src, src, heavy_armor_penetration)'), 3)
        self.assertIn('explosion_damage_hull_panel(F, T, src, heavy_armor_penetration)', DRONE)
        self.assertIn('shake_camera(M, 1, 1)', GRENADE)
        self.assertGreaterEqual(GRENADE.count('shake_camera(M, 3, 3)'), 2)
        self.assertIn('firer.awards["tank"]+=(heavy_armor_penetration/200)', GRENADE)
        self.assertIn('F.try_destroy()', DRONE)

    def test_ci_selection_keeps_conservative_fallback_and_shared_dependencies(self):
        spec = importlib.util.spec_from_file_location('hull_ci_baseline', ROOT/'scripts/ci_baseline.py')
        ci = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(ci)
        previous = {name: value for name, value in ci.SUITES.items() if name != 'vehicle_hull_damage'}
        for path in ('code/game/objects/items/weapons/grenades/grenade.dm',
                     'code/game/objects/items/devices/drone.dm'):
            with self.subTest(path=path):
                current = ci.impact([path])
                with patch.object(ci, 'SUITES', previous):
                    before = ci.impact([path])
                self.assertEqual(current['fallback_reasons'], before['fallback_reasons'])
                self.assertTrue(current['suites']['vehicle_hull_damage']['selected'])
                owner = dict(files=(), paths=(path,), shared_paths=())
                with patch.object(ci, 'SUITES', ci.SUITES | {'other_owner': owner}):
                    self.assertTrue(ci.impact([path])['suites']['vehicle_hull_damage']['selected'])


if __name__ == '__main__':
    unittest.main()
