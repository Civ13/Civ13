"""Offline check that add_side_effect() finds effect types by name (native probe: probe.dm)."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/mob/living/carbon/human/MedicalSideEffects.dm'

# The pre-fix lookup, frozen as a negative control.
OLD = '''/mob/living/human/add_side_effect(name, strength = FALSE)
	var/T = side_effects[name]
	if (!T)
		return
'''


def add_proc(source):
    start = source.index('/mob/living/human/add_side_effect(')
    end = source.find('\n/', start + 1)
    return source[start:end if end != -1 else None]


def effect_names(source):
    return re.findall(r'^/datum/medical_effect/\w+\n\tname = "([^"]+)"', source, re.M)


def registers(source, name, defined):
    """Whether a first trigger of `name` adds an active effect."""
    body = add_proc(source)
    if 'side_effects[name]' in body:
        return False  # active list used as a type registry: always empty
    return 'typesof(/datum/medical_effect)' in body and 'initial(E.name) == name' in body and name in defined


class SideEffectRegistrationTest(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding='utf-8')
        self.names = effect_names(self.source)

    def test_every_defined_effect_registers(self):
        self.assertEqual(sorted(self.names), ['Bad Stomach', 'Cramps', 'Headache', 'Itch'])
        for name in self.names:
            self.assertTrue(registers(self.source, name, self.names), name)

    def test_unknown_name_does_not_register(self):
        self.assertFalse(registers(self.source, 'Nonexistent', self.names))

    def test_negative_control_old_lookup_never_registers(self):
        self.assertFalse(registers(OLD, 'Headache', self.names))


if __name__ == '__main__':
    unittest.main()
