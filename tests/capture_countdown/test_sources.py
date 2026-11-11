"""Source wiring of the shared objective-capture countdown.

run.py proves tick-by-tick parity natively; these offline checks keep the
three migrated maps on the shared routine and the runner's fixtures intact.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
MAPS = ROOT / 'code/game/objects/map_metadata'
HERE = Path(__file__).resolve().parent
MIGRATED = {'camp': 'Castle', 'oasis': 'Oasis', 'twotribes': 'Shrine'}


def body(source, header):
    match = re.search(r'(?m)^' + re.escape(header) + r'\n(.*?)(?=^/|\Z)', source, re.S)
    if not match:
        raise AssertionError(f'missing {header}')
    return match.group(1)


class CaptureCountdownWiring(unittest.TestCase):
    def test_migrated_maps_keep_deadline_and_use_shared_routine(self):
        for name, objective in MIGRATED.items():
            with self.subTest(map=name):
                source = (MAPS / f'{name}.dm').read_text(encoding='utf-8')
                proc = body(source, f'/obj/map_metadata/{name}/update_win_condition()')
                self.assertNotIn('win_condition.check', proc)
                self.assertIn('if (world.time >= victory_time)', proc)
                self.assertIn('show_global_battle_report(null)', proc)
                self.assertTrue(proc.rstrip().endswith(
                    '\tif (capture_countdown_elapsed())\n\t\treturn FALSE\n\tupdate_capture_state()\n\treturn TRUE'))
                self.assertIn(f'\tcapture_objective_name = "{objective}"\n', source)
                self.assertIn('\tcapture_verb = "has"\n', source)
                self.assertIn('\tcapture_notice_in_font = TRUE\n', source)

    def test_base_uses_shared_routine(self):
        source = (MAPS / '_map_metadata.dm').read_text(encoding='utf-8')
        proc = body(source, '/obj/map_metadata/proc/update_win_condition()')
        self.assertIn('capture_countdown_elapsed()', proc)
        self.assertIn('update_capture_state()', proc)
        self.assertNotIn('win_condition.check', proc)
        for header in ('/obj/map_metadata/proc/capture_countdown_elapsed()',
                       '/obj/map_metadata/proc/update_capture_state()',
                       '/obj/map_metadata/proc/capture_branch(attacker, defender, threshold, long_timer)'):
            body(source, header)

    def test_frozen_original_fixture_covers_all_four_bodies(self):
        fixture = (HERE / 'original_update_win_condition.dm.txt').read_text(encoding='utf-8')
        for header in ['/obj/map_metadata/proc/update_win_condition()'] + [
                f'/obj/map_metadata/{name}/update_win_condition()' for name in MIGRATED]:
            self.assertEqual(fixture.count(header + '\n'), 1, header)
        self.assertEqual(fixture.count('win_condition.check('), 32)


if __name__ == '__main__':
    unittest.main()
