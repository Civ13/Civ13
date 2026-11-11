"""A body standing a few pixels off its tile can still start a pull.

Free movement stops wherever the key is released, so refusing a pull whenever
step_x/step_y is nonzero blocked pulling almost always (live Gaia 2026-11-11:
"Finish the current smooth step before starting a pull."). Only a step in
progress refuses; a standing offset settles onto the centre tile first.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
LIVING = (ROOT / 'code/game/mob/living/living.dm').read_text(encoding='utf-8')


def start_pulling():
    start = LIVING.index('/mob/living/start_pulling(')
    return LIVING[start:LIVING.index('\n/', start + 1)]


class StartPullOffset(unittest.TestCase):
    def test_only_a_step_in_progress_refuses(self):
        body = start_pulling()
        refuse = body.index('Finish the current smooth step before starting a pull.')
        guard = body.rindex('\n', 0, body.rindex('if (', 0, refuse))
        line = body[guard:refuse]
        self.assertIn('human_subtile_transaction', line)
        self.assertNotIn('step_x', line)

    def test_standing_offset_is_aligned_before_pulling(self):
        body = start_pulling()
        align = body.index('trench_climb_align(pull_actor)')
        self.assertLess(align, body.index("It won't budge!"))


if __name__ == '__main__':
    unittest.main()
