"""A body between whole pixels is snapped back before movement input is judged.

BYOND keeps fractional step offsets (step_y = 0.5 survives a loc change), and
human_subtile_shape() refuses any fractional offset, so such a body could never
move again. The native check runs the production proc when a compiler is on PATH.
"""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
MODULE = (ROOT / 'code/game/mob/living/carbon/human/subtile_movement.dm').read_text()
MOVE = (ROOT / 'code/game/mob/mob_movement.dm').read_text()


def snap_proc():
    start = MODULE.index('/mob/living/human/proc/human_subtile_snap_fraction()')
    return MODULE[start:MODULE.index('\n\n', start)]


class FractionSnap(unittest.TestCase):
    def test_shape_still_requires_whole_pixels(self):
        self.assertIn('step_x == round(step_x) && step_y == round(step_y)', MODULE)

    def test_client_move_snaps_before_any_shape_check(self):
        move = MOVE[MOVE.index('/client/Move('):]
        snap = move.index('fraction_actor.human_subtile_snap_fraction()')
        self.assertLess(move.index('if (!mob)\n\t\treturn'), snap)
        self.assertLess(snap, move.index('human_subtile_fine_ready(direct)'))
        self.assertLess(snap, move.index('human_subtile_input_supported(direct)'))

    def test_snap_rounds_both_axes_and_refiles(self):
        body = snap_proc()
        self.assertIn('round(step_x, 1)', body)
        self.assertIn('round(step_y, 1)', body)
        self.assertIn('human_subtile_anchor()', body)
        self.assertIn('human_subtile_offset_owned = !!(step_x || step_y)', body)

    def test_native_snap_restores_whole_pixels(self):
        maker = shutil.which('DreamMaker')
        daemon = shutil.which('DreamDaemon')
        if not maker or not daemon:
            self.skipTest('no BYOND compiler on PATH')
        with tempfile.TemporaryDirectory() as temp:
            out = Path(temp) / 'out.txt'
            (Path(temp) / 'snap.dme').write_text(
                'world\n\ticon_size = 32\n\tmaxx = 5\n\tmaxy = 5\n\tmaxz = 1\nturf\n'
                '/mob/living/human\n\tvar/human_subtile_offset_owned = FALSE\n'
                '/mob/living/human/proc/human_subtile_anchor()\n\treturn FALSE\n'
                + snap_proc() + '\n'
                '/world/New()\n\t..()\n\tvar/mob/living/human/H = new(locate(2,2,1))\n'
                '\tvar/list/r = list()\n'
                '\tH.step_x = 4\n\tH.step_y = 0.5\n\tr += "[H.step_y == round(H.step_y)]"\n'
                '\tr += "[H.human_subtile_snap_fraction()]"\n\tr += "[H.step_x],[H.step_y],[H.human_subtile_offset_owned]"\n'
                '\tr += "[H.human_subtile_snap_fraction()]"\n'
                '\tH.step_x = 0\n\tH.step_y = 0.4\n\tH.human_subtile_snap_fraction()\n\tr += "[H.step_x],[H.step_y],[H.human_subtile_offset_owned]"\n'
                '\ttext2file(jointext(r, "|"), "' + out.as_posix() + '")\n\tshutdown()\n')
            subprocess.run([maker, 'snap.dme'], cwd=temp, check=True, capture_output=True, timeout=120)
            subprocess.run([daemon, 'snap.dmb', '-trusted', '-invisible'], cwd=temp, capture_output=True, timeout=120)
            # fractional before | snapped | 4,1 owned | no-op on whole pixels | 0,0 not owned
            self.assertEqual(out.read_text().strip(), '0|1|4,1,1|0|0,0,0')


if __name__ == '__main__':
    unittest.main()
