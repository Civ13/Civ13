"""Bone setting does not re-break a fracture that heals mid-operation (#6759).

Behaviour is covered natively (healed mid-operation stays whole, a broken
bone is set, a whole bone set on purpose still breaks):

    python3 tests/ecology_spawning/run_linux.py . tests/bone_setting_race/probe.dm
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
BONES = (ROOT / 'code/modules/surgery/bones.dm').read_text(encoding='utf-8')
ORGAN = (ROOT / 'code/modules/organs/organ_external.dm').read_text(encoding='utf-8')


class BoneSettingRace(unittest.TestCase):
    def step(self):
        return BONES.split('/datum/surgery_step/set_bone', 1)[1].split('\n/datum/', 1)[0]

    def test_begin_records_fracture(self):
        step = self.step()
        begin = step.index('begin_step(')
        self.assertLess(begin, step.index('affected.bone_set_on_fracture = !!(affected.status & ORGAN_BROKEN)'))

    def test_end_skips_refracture_after_heal(self):
        step = self.step()
        end = step[step.index('end_step('):]
        guard = end.index('if (!(affected.status & ORGAN_BROKEN) && started_on_fracture)')
        self.assertLess(guard, end.index('affected.fracture()'))
        self.assertIn('return', end[guard:end.index('if (affected.status & ORGAN_BROKEN)\n')])

    def test_marker_never_saves(self):
        self.assertIn('var/tmp/bone_set_on_fracture', ORGAN)
        self.assertIn('key == "bone_set_on_fracture"', ORGAN)


if __name__ == '__main__':
    unittest.main()
