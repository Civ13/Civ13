"""Offline limits checks do not prove actual container isolation or runtime."""
import copy
import unittest
import runner_limits as limits


class LimitControls(unittest.TestCase):
    def test_exact_admission_and_insufficient_budget(self):
        limits.admission('bump05', 10, 370)
        for now, end in ((10, 369.99), (float('nan'), 500), (0, float('inf'))):
            with self.subTest(now=now, end=end), self.assertRaises(ValueError):
                limits.admission('bump05', now, end)
        with self.assertRaises(ValueError):
            limits.admission('transition05', 0, 490)
        limits.remaining(1, 10, 10, 270)
        with self.assertRaises(ValueError):
            limits.remaining(1, 10, 10, 269.99)
        with self.assertRaises(ValueError):
            limits.remaining(5, 10, 10, 500)

    def test_each_real_phase_and_setup_are_bounded(self):
        phases = [dict(name=name, seconds=1, returncode=0, timed_out=False, oversized_log=False, deadline=limit)
                  for name, limit in limits.PHASES]
        self.assertTrue(limits.validate_accounting(phases, 5, 1))
        for mutation in ('missing', 'extra', 'timeout', 'nonzero', 'duration', 'unaccounted', 'log', 'deadline'):
            bad = copy.deepcopy(phases)
            elapsed = 5
            if mutation == 'missing': bad.pop()
            elif mutation == 'extra': bad.append(dict(bad[-1]))
            elif mutation == 'timeout': bad[1]['timed_out'] = True
            elif mutation == 'nonzero': bad[1]['returncode'] = 1
            elif mutation == 'duration': bad[0]['seconds'] = 91
            elif mutation == 'log': bad[0]['oversized_log'] = True
            elif mutation == 'deadline': bad[0]['deadline'] = 91
            else: elapsed = 6
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                limits.validate_accounting(bad, elapsed, 1)


if __name__ == '__main__':
    unittest.main()
