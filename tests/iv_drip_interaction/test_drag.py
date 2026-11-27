"""Exercise IV attachment and detachment using projected DM and fake engine effects."""
import re
import sys
import unittest
from pathlib import Path
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests' / 'save_movement'))
import source_adapter


class IVDragTests(unittest.TestCase):
    def setUp(self):
        source = (ROOT / 'code/game/objects/structures/iv_drip.dm').read_text()
        source = source.replace('/obj/structure/iv_drip/MouseDrop(over_object, src_location, over_location)\n\t..()',
                                '/obj/structure/iv_drip/MouseDrop(over_object, src_location, over_location)\n\tparent_drop()')
        # Messages do not affect the attachment state under test.
        lines = source.splitlines()
        for i, line in enumerate(lines):
            if line.lstrip().startswith('visible_message('):
                lines[i] = line[:len(line) - len(line.lstrip('\t'))] + 'notice()'
        source = '\n'.join(lines) + '\n'
        self.actor = SimpleNamespace(distance=1)
        self.floor = object()
        self.patient = SimpleNamespace(distance=1, z=1, loc=self.floor)
        self.transfers = []
        env = {'usr': self.actor, 'parent_drop': lambda: None, 'notice': lambda: None,
               'in_range': lambda drip, actor: actor.distance <= 1,
               'ishuman': lambda obj: obj is self.patient,
               'get_dist': lambda first, second: self.patient.distance,
               'isturf': lambda loc: loc is self.floor,
               'transfer': lambda: self.transfers.append(self.patient)}
        old = source_adapter.FIELDS
        try:
            source_adapter.FIELDS += ('attached', 'update_icon', 'can_reach_patient', 'beaker')
            self.reach = source_adapter.project(source, '/obj/structure/iv_drip/proc/can_reach_patient',
                                                'src, patient', env, method=True)
            self.drag = source_adapter.project(source, '/obj/structure/iv_drip/MouseDrop',
                                               'src, over_object, src_location, over_location',
                                               env, method=True)
            # Keep the real detachment code and replace the reagent effects after its guard.
            process = '/obj/structure/iv_drip/process'
            transfer_guard = '\n\tif (attached && beaker)\n'
            process_source = source[source.index(process):].split(transfer_guard, 1)[0]
            process_source = re.sub(r'/\*.*?\*/', '', process_source, flags=re.S)
            self.process = source_adapter.project(process_source + transfer_guard + '\t\ttransfer()\n',
                                                  process, 'src', env, method=True)
        finally:
            source_adapter.FIELDS = old

    def make_drip(self, attached=None):
        drip = SimpleNamespace(attached=attached, z=1, beaker=object(), update_icon=lambda: None)
        drip.can_reach_patient = lambda patient: self.reach(drip, patient)
        return drip

    def test_remote_drag_cannot_detach_patient(self):
        drip = self.make_drip(self.patient)
        self.actor.distance = 3
        self.drag(drip, self.patient, None, None)
        self.assertIs(drip.attached, self.patient)

    def test_nearby_drag_detaches_and_attaches_only_nearby_patient(self):
        drip = self.make_drip(self.patient)
        self.drag(drip, self.patient, None, None)
        self.assertIsNone(drip.attached)
        self.patient.distance = 2
        self.drag(drip, self.patient, None, None)
        self.assertIsNone(drip.attached)
        self.patient.distance = 1
        self.drag(drip, self.patient, None, None)
        self.assertIs(drip.attached, self.patient)

    def test_adjacent_floor_is_out_of_reach_when_attaching(self):
        drip = self.make_drip()
        self.patient.z += 1
        self.drag(drip, self.patient, None, None)
        self.assertIsNone(drip.attached)

    def test_patient_changing_floors_detaches_before_transfer(self):
        drip = self.make_drip(self.patient)
        self.process(drip)
        self.assertEqual(self.transfers, [self.patient])

        # Model BYOND reporting distance one on the adjoining floor as well.
        self.patient.z += 1
        self.process(drip)
        self.assertIsNone(drip.attached)
        self.assertEqual(self.transfers, [self.patient])


if __name__ == '__main__':
    unittest.main()
