"""Focused source contracts for admission, visual ownership and update budgets."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
MODULE = ROOT / 'code/game/mob/living/carbon/human/subtile_movement.dm'


class DiagonalContracts(unittest.TestCase):
    def test_native_diagonal_pulses_bypass_only_legacy_split(self):
        source = (ROOT / 'code/game/mob/mob_movement.dm').read_text()
        self.assertIn('if (!subtile_pulse && (direct & (direct - 1)))', source)
        self.assertIn('..(newloc, direct, subtile_pulse.sx, subtile_pulse.sy)', source)
        self.assertIn('human_subtile_deadline(move_delay, world.time, ordinal)', source)
        source = MODULE.read_text()
        self.assertIn('(direction & EAST) ? min(2, remaining_x) : (direction & WEST) ? -min(2, remaining_x) : 0', source)
        self.assertIn('(direction & NORTH) ? min(2, remaining_y) : (direction & SOUTH) ? -min(2, remaining_y) : 0', source)
        self.assertIn('i <= 16', source)
        self.assertIn('start_time + (i - 1) * duration / 16', source)

    def test_default_waits_for_geometry_ownership_and_setter(self):
        source = MODULE.read_text()
        start = source.index('/mob/living/human/proc/human_subtile_initialize_default')
        end = source.index('/mob/living/human/proc/human_subtile_unlinked')
        default = source[start:end]
        self.assertIn('human_subtile_ready(direction)', default)
        self.assertIn('(!step_x && !step_y) || human_subtile_offset_owned', default)
        self.assertIn('return set_human_subtile(TRUE)', default)
        self.assertNotIn('human_subtile_enabled =', default)
        self.assertIn('human_subtile_default_pending = FALSE', source)

    def test_interpolation_uses_physics_and_restorable_client_settings(self):
        source = MODULE.read_text()
        self.assertIn('32 * world.tick_lag / max(duration, world.tick_lag)', source)
        self.assertIn('!(appearance_flags & LONG_GLIDE)', source)
        self.assertIn('owner.fps = max(owner.human_subtile_previous_fps, world.fps + 1, 60)', source)
        self.assertIn('fps = human_subtile_previous_fps', source)
        self.assertIn('glide_size = human_subtile_previous_glide', source)
        self.assertNotIn('world.fps =', source)
        self.assertNotIn('pixel_x =', source)
        self.assertNotIn('pixel_y =', source)
        for path in ('code/game/mob/living/logout.dm', 'code/modules/client/client_procs.dm', 'code/game/mob/death.dm'):
            self.assertIn('human_subtile_release_visuals()', (ROOT / path).read_text())

    def test_new_engine_adapter_keeps_containment_bytes(self):
        directory = ROOT / 'tests/human_subtile/native_1688'
        for name in ('windows.py', 'owned_job.py'):
            self.assertEqual((directory / name).read_bytes(), (ROOT / 'tests/floor_decal_tracking' / name).read_bytes())
        source = (directory / 'guard_config.py').read_text()
        self.assertIn('f29b3041c46df453b3f999583bef0bb0ff79fe2b53ee1b8686bb46ce18c7df77', source)
        self.assertIn('abb21de26047724bf64411e17da5e17cacc74221817c3e049a79626156b44866', source)


if __name__ == '__main__':
    unittest.main(verbosity=2)
