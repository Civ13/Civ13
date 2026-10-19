import unittest
import ci


class HudRunnerTests(unittest.TestCase):
    def test_sources_match_reviewed_master_and_execute_actual_probe(self):
        generated = ci.sources()
        self.assertIn('#include "tests/hud_visual/probe.dm"', generated[ci.PREFIX + '.dme'])
        self.assertNotIn('/world/New()', generated[ci.PREFIX + '_world.dm'])
        self.assertNotIn('/world/Topic(', generated[ci.PREFIX + '_world.dm'])
        self.assertIn('/client/New(TopicData)\n\treturn FALSE', generated[ci.PREFIX + '_world.dm'])
        for index in range(2):
            self.assertNotIn('/client/New(', generated[ci.PREFIX + '_client_' + str(index) + '.dm'])
        self.assertNotIn('.dmm"', generated[ci.PREFIX + '.dme'])

    def test_verdict_rejects_missing_partial_failed_and_diagnostic_runs(self):
        cases = [{'assertion': 'unrelated appearance observed', 'pass': 1}] * 200
        result = 'PASS assertions=200 tagged_faults=3 headless_only=1\n'
        ci.verify(result, cases, '')
        for bad_result, bad_cases, logs in [('', cases, ''), (result, cases[:-1], ''),
                (result, cases, 'runtime error'), (result, cases, 'Bad ref'),
                (result, [{'assertion': 'other', 'pass': 1}] * 200, ''),
                (result, cases[:-1] + [{'pass': 0}], '')]:
            with self.assertRaises(ValueError):
                ci.verify(bad_result, bad_cases, logs)


if __name__ == '__main__':
    unittest.main()
