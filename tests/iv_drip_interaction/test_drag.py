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
        # Messages do not affect the attachment state under test.
        lines = source.splitlines()
        for i, line in enumerate(lines):
            if line.lstrip().startswith('visible_message('):
                lines[i] = line[:len(line) - len(line.lstrip('\t'))] + 'notice()'
        source = '\n'.join(lines) + '\n'
        self.floor = object()
        self.actor = SimpleNamespace(distance=1, z=1, stat=0, loc=self.floor,
                                     patient_in_touch=True, drip_in_touch=True,
                                     incapacitated=lambda flags: False)
        self.patient = SimpleNamespace(distance=1, actor_distance=1, z=1, loc=self.floor,
                                       drip_in_touch=True)
        self.patient.Adjacent = lambda actor: (
            self.patient.z == actor.z and self.patient.actor_distance <= 1 and actor.patient_in_touch
        )
        self.transfers = []
        env = {'usr': self.actor, 'parent_drop': lambda: None, 'notice': lambda: None,
               'in_range': lambda drip, actor: actor.distance <= 1,
               'ishuman': lambda obj: obj is self.patient,
               'istype': lambda obj, kind: obj is self.actor and kind == '/mob/living',
               'to_chat': lambda user, message: None,
               'get_dist': lambda first, second: self.patient.distance,
               'isturf': lambda loc: loc is self.floor,
               'transfer': lambda: self.transfers.append(self.patient)}
        old = source_adapter.FIELDS
        try:
            source_adapter.FIELDS += ('attached', 'update_icon', 'can_reach_patient', 'beaker',
                                      'CanMouseDrop', 'Adjacent', 'mode')
            self.can_drop = source_adapter.project(
                (ROOT / 'code/_onclick/drag_drop.dm').read_text(), '/atom/proc/CanMouseDrop',
                'src, over, user, incapacitation_flags=None', env,
            )
            self.reach = source_adapter.project(source, '/obj/structure/iv_drip/proc/can_reach_patient',
                                                'src, patient', env, method=True)
            drag = '/obj/structure/iv_drip/MouseDrop'
            drag_source = source_adapter.extract(source, drag).replace('\t..()\n', '\tparent_drop()\n')
            self.drag = source_adapter.project(
                drag + '(over_object, src_location, over_location)\n' + drag_source + '\n',
                drag, 'src, over_object, src_location, over_location', env, method=True,
            )
            # Assume BYOND has offered the visible verb. Simulate its messages and type check.
            toggle = '/obj/structure/iv_drip/verb/toggle_mode'
            toggle_source = source_adapter.extract(source, toggle)
            toggle_source = toggle_source.replace('\tset src in view(1)\n', '')
            toggle_source = toggle_source.replace('istype(usr, /mob/living)', 'istype(usr, "/mob/living")')
            toggle_source = re.sub(r'(?m)^(\t+)to_chat\(usr, .*$', r'\1to_chat(usr, "")', toggle_source)
            self.toggle_mode = source_adapter.project(
                toggle + '()\n' + toggle_source + '\n', toggle, 'src', env, method=True,
            )
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
        drip = SimpleNamespace(attached=attached, z=1, beaker=object(), mode=True,
                               update_icon=lambda: None)
        drip.can_reach_patient = lambda patient: self.reach(drip, patient)
        drip.Adjacent = lambda other: (
            drip.z == other.z and other.distance <= 1
            and other.drip_in_touch
        )
        drip.CanMouseDrop = lambda over: self.can_drop(drip, over, self.actor)
        return drip

    def test_contained_operator_cannot_attach(self):
        self.actor.loc = SimpleNamespace(loc=self.floor)
        drip = self.make_drip()
        # The common adjacency check resolves the closet to its floor tile.
        self.assertTrue(drip.CanMouseDrop(self.patient))
        self.drag(drip, self.patient, None, None)
        self.assertIsNone(drip.attached)

    def test_contained_operator_cannot_detach(self):
        self.actor.loc = SimpleNamespace(loc=self.floor)
        drip = self.make_drip(self.patient)
        self.assertTrue(drip.CanMouseDrop(drip))
        self.drag(drip, self.patient, None, None)
        self.assertIs(drip.attached, self.patient)

    def test_contained_operator_cannot_toggle_mode(self):
        self.actor.loc = SimpleNamespace(loc=self.floor)
        drip = self.make_drip()
        self.assertTrue(drip.Adjacent(self.actor))
        self.toggle_mode(drip)
        self.assertTrue(drip.mode)

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

    def test_operator_on_adjacent_floor_cannot_attach(self):
        self.actor.z += 1
        drip = self.make_drip()
        self.drag(drip, self.patient, None, None)
        self.assertIsNone(drip.attached)

    def test_operator_on_adjacent_floor_cannot_detach(self):
        self.actor.z += 1
        drip = self.make_drip(self.patient)
        self.drag(drip, self.patient, None, None)
        self.assertIs(drip.attached, self.patient)

    def test_operator_cannot_attach_to_patient_two_tiles_away(self):
        drip = self.make_drip()
        self.patient.actor_distance = 2
        self.drag(drip, self.patient, None, None)
        self.assertIsNone(drip.attached)

    def test_blocked_patient_touch_prevents_attachment_but_allows_local_detachment(self):
        self.actor.patient_in_touch = False
        drip = self.make_drip()
        self.drag(drip, self.patient, None, None)
        self.assertIsNone(drip.attached)

        drip = self.make_drip(self.patient)
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

    def test_border_between_drip_and_patient_prevents_attachment(self):
        # The operator can touch each endpoint from the side of the window.
        self.patient.drip_in_touch = False
        drip = self.make_drip()
        self.assertTrue(drip.CanMouseDrop(self.patient))
        self.drag(drip, self.patient, None, None)
        self.assertIsNone(drip.attached)

    def test_mode_toggle_requires_touch_even_when_drip_is_visible(self):
        drip = self.make_drip()
        self.actor.drip_in_touch = False
        self.toggle_mode(drip)
        self.assertTrue(drip.mode)

        self.actor.drip_in_touch = True
        self.toggle_mode(drip)
        self.assertFalse(drip.mode)

    def test_patient_moving_behind_border_detaches_before_transfer(self):
        drip = self.make_drip(self.patient)
        self.process(drip)
        self.assertEqual(self.transfers, [self.patient])

        self.patient.drip_in_touch = False
        self.process(drip)
        self.assertIsNone(drip.attached)
        self.assertEqual(self.transfers, [self.patient])


if __name__ == '__main__':
    unittest.main()
