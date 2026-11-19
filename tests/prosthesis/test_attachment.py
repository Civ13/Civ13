"""Offline source projection with fake engine effects; no BYOND runtime is run."""
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/surgery/prosthesis.dm'
spec = importlib.util.spec_from_file_location('source_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)


class Limb:
    def __init__(self, stump=False, fitted=False):
        self.stump = stump
        self.prosthesis = fitted
        self.prosthesis_type = 'none'

    def is_stump(self):
        return self.stump


class Patient:
    def __init__(self, **organs):
        self.organs = {'groin': Limb(), 'l_leg': Limb(), 'r_leg': Limb(),
                       'l_foot': Limb(), 'r_foot': Limb()}
        self.organs.update(organs)
        self.mutations = []

    def get_organ(self, name):
        return self.organs[name]

    def update_mutations(self, value):
        self.mutations.append(value)


class User:
    def __init__(self, shaman=False):
        self.religious_clergy = 'Shamans' if shaman else ''
        self.experience = []

    def getStatCoeff(self, name):
        assert name == 'medical'
        return 2

    def adaptStat(self, name, amount):
        self.experience.append((name, amount))


class Fixture:
    def __init__(self, source, limb_type='leg', completed=True):
        self.item = SimpleNamespace()
        self.messages = []
        self.waits = []
        self.deleted = []
        self.finishes = []
        self.completed = completed
        env = {'src': self.item, 'icon_state': 'pegleg' if limb_type == 'leg' else 'woodfoot',
               'visible_message': lambda *messages: self.messages.append(messages),
               'to_chat': lambda *args: self.messages.append(args),
               'qdel': self.deleted.append, 'do_after': self.wait, 'limb_type': limb_type}
        self.finish = adapter.project(source, '/obj/item/weapon/prosthesis/proc/finish_attachment',
                                      'patient, user, limb, limb_description, medical_experience', env)
        env['finish_attachment'] = self.finish_recorded

        # Project both complete switch branches. Rewriting only the DM switch
        # syntax leaves each branch's executable conditions and actions intact.
        attack = adapter.extract(source, '/obj/item/weapon/prosthesis/attack')
        selection = attack[attack.index('\tvar/mod = 1'):]
        lines = []
        for line in selection.splitlines():
            if line == '\tswitch (limb_type)':
                continue
            if line == '\t\tif ("leg")':
                lines.append('\tif (limb_type == "leg")')
            elif line == '\t\tif ("foot")':
                lines.append('\telse if (limb_type == "foot")')
            elif line.startswith('\t\t\t'):
                lines.append(line[1:])
            else:
                lines.append(line)
        projected = '/fixture/select(C, user)\n' + '\n'.join(lines) + '\n'
        self.select = adapter.project(projected, '/fixture/select', 'C, user', env)

    def wait(self, user, delay, patient):
        self.waits.append((user, delay, patient))
        return self.completed

    def finish_recorded(self, patient, user, limb, description, experience):
        self.finishes.append((limb, description, experience))
        self.finish(patient, user, limb, description, experience)


class AttachmentTests(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding='utf-8-sig')

    def test_null_completion_guard_and_negative_control(self):
        fixture = Fixture(self.source)
        patient, user = Patient(), User()
        fixture.finish(patient, user, None, 'right leg', 4)
        self.assertEqual((fixture.messages, fixture.deleted, patient.mutations, user.experience),
                         ([], [], [], []))
        old = self.source.replace('\tif (!limb)\n\t\treturn\n', '', 1)
        self.assertNotEqual(old, self.source)
        with self.assertRaises(AttributeError):
            Fixture(old).finish(patient, user, None, 'right leg', 4)

    def test_both_leg_sides_complete_and_preserve_left_priority(self):
        for left, right, selected in ((Limb(True), Limb(True), 'l_leg'),
                                      (Limb(), Limb(True), 'r_leg')):
            with self.subTest(selected=selected):
                patient = Patient(l_leg=left, r_leg=right)
                user, fixture = User(), Fixture(self.source)
                fixture.select(patient, user)
                self.assertEqual(fixture.waits, [(user, 300, patient)])
                self.assertEqual(fixture.finishes, [(patient.organs[selected],
                                                     'left leg' if selected == 'l_leg' else 'right leg', 4)])
                self.assertTrue(patient.organs[selected].prosthesis)
                self.assertEqual(patient.organs[selected].prosthesis_type, 'pegleg')
                self.assertEqual(patient.mutations, [1])
                self.assertEqual(user.experience, [('medical', 4)])
                self.assertEqual(fixture.deleted, [fixture.item])
                self.assertEqual(len(fixture.messages), 2)
                self.assertFalse(patient.organs['r_leg' if selected == 'l_leg' else 'l_leg'].prosthesis)

    def test_absent_leg_waits_but_does_not_complete_or_fall_through(self):
        for left, right in ((None, Limb(True)), (Limb(), None)):
            patient, user, fixture = Patient(l_leg=left, r_leg=right), User(), Fixture(self.source)
            fixture.select(patient, user)
            self.assertEqual(fixture.waits, [(user, 300, patient)])
            self.assertEqual((patient.mutations, user.experience, fixture.deleted), ([], [], []))
            self.assertEqual(len(fixture.messages), 1)
            if right is not None:
                self.assertFalse(right.prosthesis)

    def test_interruption_has_no_completion_effects(self):
        for kind, organs in (('leg', {'l_leg': Limb(True)}), ('foot', {'l_foot': Limb(True)})):
            patient, user, fixture = Patient(**organs), User(), Fixture(self.source, kind, completed=False)
            fixture.select(patient, user)
            self.assertEqual(fixture.waits, [(user, 300 if kind == 'leg' else 260, patient)])
            self.assertEqual(fixture.finishes, [])
            self.assertEqual((patient.mutations, user.experience, fixture.deleted), ([], [], []))
            self.assertFalse(patient.organs['l_' + kind].prosthesis)

    def test_foot_priority_parent_eligibility_and_shaman_award(self):
        for left_leg, left_foot, selected in ((Limb(), Limb(True), 'l_foot'),
                                               (Limb(True), Limb(True), 'r_foot'),
                                               (Limb(), Limb(True, True), 'r_foot')):
            with self.subTest(selected=selected, leg_stump=left_leg.stump, fitted=left_foot.prosthesis):
                right_foot = Limb(True)
                patient = Patient(l_leg=left_leg, l_foot=left_foot, r_foot=right_foot)
                user, fixture = User(shaman=True), Fixture(self.source, 'foot')
                fixture.select(patient, user)
                self.assertEqual(fixture.waits, [(user, 260, patient)])
                self.assertEqual(fixture.finishes, [(patient.organs[selected],
                                                     'left foot' if selected == 'l_foot' else 'right foot', 6)])
                self.assertTrue(patient.organs[selected].prosthesis)
                self.assertEqual(patient.organs[selected].prosthesis_type, 'woodfoot')
                self.assertEqual((patient.mutations, user.experience, fixture.deleted),
                                 ([1], [('medical', 6)], [fixture.item]))
                if selected == 'l_foot':
                    self.assertFalse(right_foot.prosthesis)

    def test_missing_lower_body_and_both_missing_legs_are_rejected(self):
        for kind, patient in (('leg', Patient(groin=Limb(True), l_leg=Limb(True))),
                              ('foot', Patient(l_leg=None, r_leg=None))):
            user, fixture = User(), Fixture(self.source, kind)
            fixture.select(patient, user)
            self.assertEqual((fixture.waits, fixture.deleted, patient.mutations, user.experience),
                             ([], [], [], []))
            self.assertEqual(len(fixture.messages), 1)


if __name__ == '__main__':
    unittest.main()
