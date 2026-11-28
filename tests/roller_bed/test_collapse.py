"""Exercise the roller-bed collapse drag with projected DM and fake engine effects."""
from pathlib import Path
import sys
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests/save_movement'))
from source_adapter import extract, project, read


class RollerBedCollapseTests(unittest.TestCase):
    def drag_bed(self, *, distance=1, open_reach=True, occupied=False):
        events = []
        actor = SimpleNamespace(
            Adjacent=lambda other: other is actor,
            contents=SimpleNamespace(Find=lambda obj: False),
            MouseDrop_T=lambda obj, user: None,
        )
        floor = object()
        bed = SimpleNamespace(loc=floor, Adjacent=lambda other: distance <= 1 and open_reach)
        env = {
            'usr': actor, 'Adjacent': bed.Adjacent, 'deferred': lambda delay: True,
            'buckled_mob': occupied, 'ishuman': lambda obj: obj is actor,
            'in_range': lambda obj, user: distance <= 1,
            'visible_message': lambda message: None, 'get_turf': lambda obj: obj.loc,
            'create_roller': lambda loc: events.append(('folded', loc)),
            'qdel': lambda obj: events.append(('deleted', obj)),
        }
        shared = read('code/_onclick/drag_drop.dm')
        parent = project(shared, '/atom/MouseDrop', 'src, over', env)
        env['parent_drop'] = lambda: parent(bed, actor)

        declaration = '/obj/structure/bed/roller/MouseDrop'
        body = extract(read('code/game/objects/structures/stool_bed_chair_nest/bed.dm'), declaration)
        body = body.replace('..()', 'parent_drop()')
        body = body.replace('new/obj/item/roller(get_turf(src))', 'create_roller(get_turf(src))')
        drag = project(declaration + '()\n' + body, declaration, 'src, over_object', env)
        drag(bed, actor)
        return events, floor, bed

    def test_window_blocks_collapse(self):
        events, _, _ = self.drag_bed(open_reach=False)
        self.assertEqual(events, [])

    def test_reachable_empty_bed_can_collapse(self):
        events, floor, bed = self.drag_bed()
        self.assertEqual(events, [('folded', floor), ('deleted', bed)])

    def test_distant_or_occupied_bed_does_not_collapse(self):
        for settings in ({'distance': 2}, {'occupied': True}):
            with self.subTest(settings=settings):
                events, _, _ = self.drag_bed(**settings)
                self.assertEqual(events, [])
