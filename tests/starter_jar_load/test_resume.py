"""Offline check that a loaded starter jar resumes the loop its saved state needs (native probe: probe.dm)."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/production.dm'

# Pre-fix load hook, frozen as a negative control.
OLD = '''/obj/item/weapon/starterjar/after_load()
	. = ..()
	restore_from_icon_state()
'''


def block(source, header):
    start = source.index(header)
    end = source.find('\n/', start + 1)
    return source[start:end if end != -1 else None]


def resumes(source, fermenting):
    """Whether after_load() schedules work for a saved jar in state `fermenting` (1 or 2)."""
    load = block(source, '/obj/item/weapon/starterjar/after_load()')
    if 'resume_fermentation()' not in load:
        return False  # restore_from_icon_state() only acts when fermenting == 0
    resume = block(source, '/obj/item/weapon/starterjar/proc/resume_fermentation()')
    if fermenting == 1:
        return 'fermenting == 1' in resume and 'fermenting_timer = world.time' in resume and 'fermenting_process()' in resume
    return 'fermenting == 2' in resume and 'yeast_growth()' in resume


class StarterJarResumeTest(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding='utf-8')

    def test_fermenting_and_growing_jars_resume(self):
        self.assertTrue(resumes(self.source, 1))
        self.assertTrue(resumes(self.source, 2))

    def test_loops_are_single_and_runtime_only(self):
        ferment = block(self.source, '/obj/item/weapon/starterjar/proc/fermenting_process()')
        growth = block(self.source, '/obj/item/weapon/starterjar/proc/yeast_growth()')
        self.assertIn('if (ferment_loop || fermenting != 1)', ferment)
        self.assertIn('if (growth_loop || fermenting_contents <= 0)', growth)
        self.assertIn('var/tmp/ferment_loop', self.source)
        saved = block(self.source, '/obj/item/weapon/starterjar/get_saved_vars()')
        self.assertIn('"ferment_loop", "growth_loop"', saved)

    def test_negative_control_old_hook_never_resumes(self):
        self.assertFalse(resumes(OLD, 1))
        self.assertFalse(resumes(OLD, 2))


if __name__ == '__main__':
    unittest.main()
