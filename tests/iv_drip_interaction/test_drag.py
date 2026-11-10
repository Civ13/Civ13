"""Exercise IV drag behavior with fake distance and engine message effects."""
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
        self.patient = SimpleNamespace(distance=1)
        env = {'usr': self.actor, 'parent_drop': lambda: None, 'notice': lambda: None,
               'in_range': lambda drip, actor: actor.distance <= 1,
               'ishuman': lambda obj: obj is self.patient,
               'get_dist': lambda obj, drip: obj.distance}
        old = source_adapter.FIELDS
        try:
            source_adapter.FIELDS += ('attached', 'update_icon')
            self.drag = source_adapter.project(source, '/obj/structure/iv_drip/MouseDrop',
                                               'src, over_object, src_location, over_location',
                                               env, method=True)
        finally:
            source_adapter.FIELDS = old

    def test_remote_drag_cannot_detach_patient(self):
        drip = SimpleNamespace(attached=self.patient, update_icon=lambda: None)
        self.actor.distance = 3
        self.drag(drip, self.patient, None, None)
        self.assertIs(drip.attached, self.patient)

    def test_nearby_drag_detaches_and_attaches_only_nearby_patient(self):
        drip = SimpleNamespace(attached=self.patient, update_icon=lambda: None)
        self.drag(drip, self.patient, None, None)
        self.assertIsNone(drip.attached)
        self.patient.distance = 2
        self.drag(drip, self.patient, None, None)
        self.assertIsNone(drip.attached)
        self.patient.distance = 1
        self.drag(drip, self.patient, None, None)
        self.assertIs(drip.attached, self.patient)


if __name__ == '__main__':
    unittest.main()
