"""Offline checks for tests/view_lag/report.py: python3 tests/view_lag/selftest.py"""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('view_lag_report', Path(__file__).with_name('report.py'))
report = importlib.util.module_from_spec(spec)
spec.loader.exec_module(report)


def smooth(start, end, hz, share=0.5):
    n = int((end - start) * hz)
    return [(start + i / hz, share) for i in range(n)]


class FrameStats(unittest.TestCase):
    def test_smooth_walk_has_no_hitches(self):
        frames = smooth(0, 4, 60)
        stats = report.frame_stats(frames, holds=[(0.0, 4.0)])
        self.assertEqual(stats['hitches_per_min'], 0)
        self.assertLess(stats['gap_p95_ms'], 30)
        self.assertAlmostEqual(stats['scroll_hz'], 60, delta=2)

    def test_pause_between_steps_counts_as_hitch(self):
        # Glide ends early: 150 ms of a still picture after each 250 ms glide.
        frames = []
        t = 0.0
        while t < 6:
            frames += smooth(t, t + 0.25, 60)
            frames += [(t + 0.25 + i / 60, 0.0) for i in range(9)]
            t += 0.4
        stats = report.frame_stats(frames, holds=[(0.0, 6.0)])
        self.assertGreater(stats['hitches_per_min'], 100)
        self.assertGreaterEqual(stats['gap_max_ms'], 140)

    def test_animation_is_not_scrolling(self):
        frames = smooth(0, 3, 60, share=0.01)
        stats = report.frame_stats(frames, holds=[(0.0, 3.0)])
        self.assertEqual(stats['scroll_hz'], 0)
        self.assertAlmostEqual(stats['change_hz'], 60, delta=2)

    def test_tap_latency(self):
        frames = [(i / 60, 0.0) for i in range(120)]
        frames[30] = (frames[30][0], 0.4)  # 0.5 s, tap at 0.4 s
        stats = report.frame_stats(frames, taps=[0.4, 1.9])
        self.assertEqual(stats['taps_missed'], 1)
        self.assertAlmostEqual(stats['tap_ms_p50'], 100, delta=1)


class Attribution(unittest.TestCase):
    def test_gap_closed(self):
        rows = {
            'ghost_walk': {'role': 'ghost', 'tick_usage_avg': 10},
            'human_walk': {'role': 'human', 'tick_usage_avg': 30},
            'human_repeat_walk': {'role': 'human_repeat', 'tick_usage_avg': 30},
            'human_no_los_walk': {'role': 'human_no_los', 'tick_usage_avg': 15},
        }
        table = report.attribution(rows)
        entry = next(e for e in table if e['metric'] == 'server tick % walking')
        self.assertEqual(entry['closed']['human_no_los'], 0.75)

    def test_glide_match(self):
        # 8 px per 0.5 ds tick: 4 ticks = 200 ms glide for a 200 ms step.
        self.assertEqual(report.glide_match({'glide_avg': 8, 'step_ms_p50': 200, 'tick_lag': 0.5}), 1.0)
        self.assertEqual(report.glide_match({'glide_avg': 16, 'step_ms_p50': 200, 'tick_lag': 0.5}), 0.5)


if __name__ == '__main__':
    unittest.main()
