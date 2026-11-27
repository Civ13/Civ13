"""Offline source checks and projection; no BYOND gameplay or rendering is run."""
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/objects/items/clothing/under/accessories/stethoscope.dm'
spec = importlib.util.spec_from_file_location('source_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)


def projected_heart_admission(source, result='heartbeat'):
    start = source.rindex('\n', 0, source.index('var/obj/item/organ/heart/heart = ')) + 1
    stop = 'var/heartbeat = ' if result == 'heart_present' else 'if (M.stat == DEAD'
    end = source.index('\t\t\t\t' + stop, start)
    lines = source[start:end].splitlines()
    body = '\n'.join(line[3:] for line in lines)
    fixture = '/fixture/check(M)\n' + body + '\n\treturn ' + result + '\n'
    return adapter.project(fixture, '/fixture/check', 'M', {'PULSE_NONE': 0})


def patient(heart, has_heart=True):
    return SimpleNamespace(species=SimpleNamespace(has_organ={'heart': has_heart}),
                           internal_organs_by_name={'heart': heart})


class StethoscopeExaminationTests(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding='utf-8-sig')

    def test_heart_admission_requires_the_actual_organ(self):
        check = projected_heart_admission(self.source)
        self.assertFalse(check(patient(None)))
        self.assertTrue(check(patient(SimpleNamespace(pulse=2))))
        self.assertFalse(check(patient(SimpleNamespace(pulse=2), has_heart=False)))

    def test_old_heart_admission_negative_control(self):
        old = self.source.replace('M.species.has_organ["heart"] && heart',
                                  'M.species.has_organ["heart"]', 1)
        self.assertNotEqual(old, self.source)
        self.assertTrue(projected_heart_admission(old, 'heart_present')(patient(None)))

    def test_positive_readings_require_a_beating_heart(self):
        stopped = patient(SimpleNamespace(pulse=0))
        self.assertFalse(projected_heart_admission(self.source)(stopped))
        old = self.source.replace('heart_present && heart.pulse != PULSE_NONE',
                                  'heart_present', 1)
        self.assertNotEqual(old, self.source)
        self.assertTrue(projected_heart_admission(old)(stopped))

    def test_readout_separates_absent_and_stopped_hearts(self):
        chest, after_chest = self.source.split('if ("chest")', 1)[1].split('if ("eyes","mouth")', 1)
        defaults, beating = chest.split('if (heartbeat)', 1)
        self.assertIn('sound = "no heartbeat"', defaults)
        self.assertNotIn('heartrate = "is asystolic."', beating)
        self.assertIn('sound += " and healthy respiration"', beating)
        self.assertIn('\t\t\t\t\t\t\tif (heartbeat)\n'
                      '\t\t\t\t\t\t\t\tsound_strength = "hear a weak"\n'
                      '\t\t\t\t\t\t\t\tsound = "pulse"\n'
                      '\t\t\t\t\t\t\telse if (heart_present)\n'
                      '\t\t\t\t\t\t\t\tsound_strength = "hear"\n'
                      '\t\t\t\t\t\t\t\tsound = "no pulse"', after_chest)

    def test_rate_is_only_reported_after_a_chest_examination(self):
        self.assertIn('var/heartrate = ""', self.source)
        self.assertIn('\t\t\t\t\t\tif ("chest")\n'
                      '\t\t\t\t\t\t\theartrate = "is asystolic."', self.source)
        self.assertIn('[heartrate ? " [M] [heartrate]" : ""]', self.source)

    def test_dead_patient_still_reports_asystole(self):
        dead = self.source.index('if (M.stat == DEAD || (M.status_flags&FAKEDEATH))')
        living = self.source.index('\t\t\t\telse\n', dead)
        self.assertIn('heartrate = "is asystolic."', self.source[dead:living])


if __name__ == '__main__':
    unittest.main()
