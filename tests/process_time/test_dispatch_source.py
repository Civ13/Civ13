"""Offline checks for the object-process interval dispatch; not a DM runtime test."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


class ObjectIntervalDispatchTests(unittest.TestCase):
    def test_inline_expression_matches_helper_and_is_inside_live_loop(self):
        loop = (ROOT / 'code/processes/obj.dm').read_text()
        helper = (ROOT / 'code/processes/_process.dm').read_text()
        expression = re.search(
            r'/process/proc/configured_interval_seconds\(\)\s*\n\s*return ([^\n]+)',
            helper,
        ).group(1).strip()
        self.assertEqual(expression, 'schedule_interval / (1 SECOND)')
        statement = 'if (O.process_interval(' + expression + ') == PROCESS_KILL)'
        self.assertIn('\t\t\t\t' + statement, loop)
        self.assertLess(loop.index('for (current in current_list)'), loop.index(statement))
        self.assertLess(loop.index('if (!isDeleted(O))'), loop.index(statement))
        self.assertLess(loop.index(statement), loop.index('PROCESS_LIST_CHECK'))
        self.assertRegex((ROOT / 'code/__defines/time.dm').read_text(),
                         r'(?m)^#define SECOND\s+\*\s*10\s*$')

    def test_interval_changes_are_read_each_callback(self):
        # Model the source expression and its former helper with the same inputs.
        # Hoisting the value before the loop is an intentionally incorrect control.
        def dispatch(mode):
            interval = 20
            cached = interval / 10
            seen = []
            for next_interval in (5, 30, None):
                value = cached if mode == 'hoisted' else interval / 10
                seen.append(value)
                if next_interval is not None:
                    interval = next_interval
            return seen

        self.assertEqual(dispatch('inline'), dispatch('helper'))
        self.assertEqual(dispatch('inline'), [2, 0.5, 3])
        self.assertNotEqual(dispatch('inline'), dispatch('hoisted'))

    def test_dispatch_negative_control_targets_current_source(self):
        source = (ROOT / 'code/processes/obj.dm').read_text()
        runner = (ROOT / 'tests/process_time/run.py').read_text()
        target = 'O.process_interval(schedule_interval / (1 SECOND))'
        self.assertEqual(source.count(target), 1)
        self.assertIn("source.replace('" + target + "', 'O.process()')", runner)
        self.assertNotEqual(source, source.replace(target, 'O.process()'))


if __name__ == '__main__':
    unittest.main()
