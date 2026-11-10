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


def projected_heart_admission(source):
    start = source.index('\t\t\t\tvar/heartbeat = FALSE\n')
    end = source.index('\t\t\t\tif (M.stat == DEAD', start)
    lines = source[start:end].splitlines()
    body = '\n'.join(line[3:] for line in lines)
    fixture = '/fixture/check(M)\n' + body + '\n\treturn heartbeat\n'
    return adapter.project(fixture, '/fixture/check', 'M', {})


def patient(heart, has_heart=True):
    return SimpleNamespace(species=SimpleNamespace(has_organ={'heart': has_heart}),
                           internal_organs_by_name={'heart': heart})


class StethoscopeExaminationTests(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding='utf-8-sig')

    def test_heart_admission_requires_the_actual_organ(self):
        check = projected_heart_admission(self.source)
        self.assertFalse(check(patient(None)))
        self.assertTrue(check(patient(object())))
        self.assertFalse(check(patient(object(), has_heart=False)))

    def test_old_heart_admission_negative_control(self):
        old = self.source.replace('M.species.has_organ["heart"] && heart',
                                  'M.species.has_organ["heart"]', 1)
        self.assertNotEqual(old, self.source)
        self.assertTrue(projected_heart_admission(old)(patient(None)))

    def test_rate_is_only_reported_after_a_chest_examination(self):
        self.assertIn('var/heartrate = ""', self.source)
        self.assertIn('\t\t\t\t\t\tif ("chest")\n'
                      '\t\t\t\t\t\t\theartrate = "is asystolic."', self.source)
        self.assertIn('[heartrate ? " [M] [heartrate]" : ""]', self.source)
        self.assertEqual(self.source.count('heartrate = "is asystolic."'), 3)

    def test_dead_patient_still_reports_asystole(self):
        dead = self.source.index('if (M.stat == DEAD || (M.status_flags&FAKEDEATH))')
        living = self.source.index('\t\t\t\telse\n', dead)
        self.assertIn('heartrate = "is asystolic."', self.source[dead:living])


if __name__ == '__main__':
    unittest.main()
