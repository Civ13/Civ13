"""Offline source regressions for tray reservoir guidance and anchoring."""
from pathlib import Path
import re
import unittest

SOURCE = Path(__file__).resolve().parents[2] / 'code/modules/1713/hydroponics.dm'


class HydroponicsTrayTests(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding='utf-8')

    def test_drain_hint_matches_top_up_room(self):
        examine = self.source.split('/obj/structure/hydroponics_tray/examine(', 1)[1]
        decision, _ = examine.split('The reservoir is too full', 1)
        lines = decision.splitlines()[3:-1]
        env = {name: int(value) for name, value in
               re.findall(r'^#define (HYDROPONICS_[A-Z_]+) (\d+)', self.source, re.M)}
        for water, nutrient, expected in (
            (1, 57, False), (0, 58, False), (0, 58.5, True), (0.5, 58, False),
            (0, 59, True), (58, 0, True), (57, 0, False), (2, 58, False),
        ):
            with self.subTest(water=water, nutrient=nutrient):
                fixture = dict(env, water_units=water, nutrient_units=nutrient, warn=False,
                               reservoir_free=lambda: env['HYDROPONICS_RESERVOIR'] - water - nutrient,
                               can_pay_cycle=lambda: water >= env['HYDROPONICS_CYCLE_WATER'] and
                                   nutrient >= env['HYDROPONICS_CYCLE_NUTRIENT'])
                snippet = '\n'.join(line[1:] for line in lines)
                snippet = snippet.replace('var/', '').replace('!can_pay_cycle()', 'not can_pay_cycle()').replace('&&', 'and')
                snippet = re.sub(r'if \((.*)\)$', r'if (\1):', snippet, flags=re.M)
                exec(snippet + '\n\twarn = True', fixture)
                self.assertEqual(fixture['warn'], expected)

    def test_wrench_releases_power_only_after_a_successful_anchor_change(self):
        body = self.source.split('if (is_tool(W, TOOL_WRENCH))\n', 1)[1]
        body = body.split('\n\tif (is_tool(W, TOOL_HAMMER))', 1)[0]
        source_lines = body.splitlines()
        self.assertEqual(source_lines.pop(), '\t\treturn TRUE')
        snippet = '\n'.join(line[2:] for line in source_lines).replace('var/', '')
        snippet = re.sub(r'if \((.*)\)$', r'if (\1):', snippet, flags=re.M)
        for connected, movable, anchored in ((True, True, True), (False, False, True),
                                               (False, True, True), (False, True, False)):
            with self.subTest(connected=connected, movable=movable, anchored=anchored):
                calls = []
                state = dict(anchored=anchored, H=None)

                def wrench_action(_):
                    calls.append('wrench')
                    if not connected and movable:
                        state['anchored'] = not state['anchored']

                state.update(wrench_action=wrench_action, release_power=lambda: calls.append('release'))
                exec(snippet, state)
                changed = not connected and movable
                self.assertEqual(state['anchored'], anchored != changed)
                self.assertEqual(calls, ['wrench', 'release'] if changed else ['wrench'])


if __name__ == '__main__':
    unittest.main()
