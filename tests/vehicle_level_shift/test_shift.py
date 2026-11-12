"""Complete-procedure source projections with fake DM lists/engine boundaries.

The frozen pre-extraction callers provide differential evidence. These tests do
not compile DM or establish native movement, deletion or client behavior.
"""
from pathlib import Path
import re
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'save_movement'))
from source_adapter import extract, project, read

BASE = 'code/modules/1713/machinery/modular_vehicles/'
AXIS = '/obj/structure/vehicleparts/axis'
AIR = AXIS + '/aircraft/proc/aircraft_shift'
SUB = AXIS + '/ship/submarine/proc/shift_level'
SHIFT = AXIS + '/proc/shift_vehicle_level'
RELEASE = AXIS + '/proc/release_transform_tiles'
VISION = AXIS + '/proc/refresh_passenger_vision'
FIELDS = ('transforming_vehicle', 'add_transporting', 'transporting', 'components',
          'transform_tiles', 'release_transform_tiles', 'refresh_passenger_vision',
          'shift_vehicle_level')
LEGACY = Path(__file__).with_name('legacy_shifts.dm').read_text()


class DMList(list):
    """Only the ordered union, append and associative lookup used by the procs."""
    def __init__(self, values=()):
        super().__init__(values)
        self.associated = {}

    def __or__(self, other):
        result = DMList(self)
        result |= other
        return result

    def __ior__(self, other):
        for value in other if isinstance(other, DMList) else [other]:
            if value not in self:
                self.append(value)
        return self

    def __iadd__(self, value):
        self.extend(value if isinstance(value, DMList) else [value])
        return self

    def __setitem__(self, key, value):
        self.associated[key] = value

    def __getitem__(self, key):
        return self.associated[key]


class Turf:
    def __init__(self, x, y, z):
        self.x, self.y, self.z = x, y, z
        self.vehicle_transforming = None


def get_turf(atom):
    while atom is not None and not isinstance(atom, Turf):
        atom = atom.loc
    return atom


class Movable:
    def __init__(self, scene, name, loc):
        self.scene, self.name, self.loc = scene, name, loc
        self.deleted = False
        self.destroyed = False
        self.before_move = None
        self.refuse_move = False
        scene.objects.append(self)

    @property
    def x(self):
        return self.loc.x if isinstance(self.loc, Turf) else 0

    @property
    def y(self):
        return self.loc.y if isinstance(self.loc, Turf) else 0

    def forceMove(self, destination):
        axis = self.scene.axis
        self.scene.events.append(('move', self.name, coords(destination),
                                  axis.transforming_vehicle,
                                  all(t.vehicle_transforming is axis for t in axis.transform_tiles)))
        if self.before_move:
            self.before_move(self, destination)
        if self.refuse_move:
            return False
        self.loc = destination
        return True


class Obj(Movable):
    def update_icon(self):
        self.scene.events.append(('icon', self.name, self.scene.axis.transforming_vehicle))
        if self.scene.icon_error:
            raise self.scene.error


class Frame(Obj):
    pass


class Mob(Movable):
    def update_vision_cone(self):
        self.scene.events.append(('vision', self.name, self.scene.axis.transforming_vehicle))
        if self.scene.vision_error:
            raise self.scene.error


class Axis(Obj):
    def __init__(self, scene):
        super().__init__(scene, 'axis', None)
        self.transporting, self.components = DMList(), DMList()
        self.transforming_vehicle = False
        self.transform_tiles = None

    def add_transporting(self, trigger_mines):
        self.scene.events.append(('collect', trigger_mines))
        if self.scene.collect_error:
            raise self.scene.error


def coords(turf):
    return (turf.x, turf.y, turf.z) if turf else None


TYPES = {'/atom/movable': Movable, '/obj': Obj, '/turf': Turf,
         '/obj/structure/vehicleparts/frame': Frame, '/mob/living': Mob}


def projected(source, declaration, arguments, scene):
    body = extract(source, declaration)
    # Qualify only unqualified axis fields, preserving local names and types.
    for field in FIELDS:
        body = re.sub(r'(?<![\w./])' + field + r'\b', 'src.' + field, body)
    body = body.replace('istype(M, /obj/structure/vehicleparts/frame)', 'istype(M, FRAME)')
    env = {'list': DMList, 'locate': scene.locate, 'get_turf': get_turf,
           'QDELETED': lambda atom: atom is None or atom.deleted or atom.destroyed,
           'isturf': lambda atom: isinstance(atom, Turf), 'FRAME': Frame,
           'istype': isinstance,
           'typed_iter': lambda items, path: (item for item in (items or ())
                                            if isinstance(item, TYPES[path])
                                            and not getattr(item, 'destroyed', False))}
    return project(declaration + '()\n' + body, declaration, arguments, env)


class Scene:
    def __init__(self, *, legacy=False, helper_source=None):
        self.events, self.objects = [], []
        self.tiles = {(x, y, z): Turf(x, y, z)
                      for x in range(1, 7) for y in range(1, 7) for z in range(1, 4)}
        self.error = RuntimeError('injected boundary error')
        self.collect_error = self.icon_error = self.vision_error = False
        self.axis = Axis(self)
        self.frame1 = Frame(self, 'frame1', self.locate(2, 2, 1))
        self.frame2 = Frame(self, 'frame2', self.locate(3, 2, 1))
        self.cargo = Obj(self, 'cargo', self.frame2.loc)
        self.passenger = Mob(self, 'passenger', self.frame1.loc)
        self.nested = Obj(self, 'nested', self.cargo)
        self.wheel = Obj(self, 'wheel', self.frame1)
        self.deleted = Obj(self, 'deleted', self.locate(6, 6, 1))
        self.deleted.deleted = True
        self.offworld = Obj(self, 'offworld', None)
        self.axis.loc = self.frame1
        self.axis.transporting = DMList([self.cargo, self.passenger, self.frame2,
                                        self.nested, self.deleted, self.offworld])
        self.axis.components = DMList([self.frame1, self.frame2, self.cargo, self.axis, self.wheel])
        axis_source = read(BASE + 'axis.dm')
        shift = projected(helper_source or axis_source, SHIFT, 'src, target_z, dx=0, dy=0', self)
        release = projected(axis_source, RELEASE, 'src, tiles', self)
        vision = projected(axis_source, VISION, 'src', self)
        self.axis.shift_vehicle_level = lambda target_z, dx=0, dy=0: shift(self.axis, target_z, dx, dy)
        self.axis.release_transform_tiles = lambda tiles: release(self.axis, tiles)
        self.axis.refresh_passenger_vision = lambda: vision(self.axis)
        air = projected(LEGACY if legacy else read(BASE + 'aircraft/aircraft.dm'),
                        AIR, 'src, target_z, dx=0, dy=0', self)
        sub = projected(LEGACY if legacy else read(BASE + 'ships/submarine.dm'), SUB, 'src, target_z', self)
        self.air = lambda target_z, dx=0, dy=0: air(self.axis, target_z, dx, dy)
        self.sub = lambda target_z: sub(self.axis, target_z)

    def locate(self, x, y, z):
        return self.tiles.get((x, y, z))

    def snapshot(self):
        return (self.events, [(obj.name, coords(get_turf(obj))) for obj in self.objects],
                self.axis.transforming_vehicle, self.axis.transform_tiles,
                [key for key, tile in self.tiles.items() if tile.vehicle_transforming is not None])


class LevelShift(unittest.TestCase):
    def assert_clean(self, scene):
        self.assertFalse(scene.axis.transforming_vehicle)
        self.assertIsNone(scene.axis.transform_tiles)
        self.assertFalse(any(t.vehicle_transforming for t in scene.tiles.values()))

    def test_frozen_extraction_preserves_complete_executable_body(self):
        shared = extract(read(BASE + 'axis.dm'), SHIFT).strip()
        self.assertEqual(shared, extract(LEGACY, AIR).strip())
        self.assertEqual(shared.replace('M.x + dx, M.y + dy', 'M.x, M.y'),
                         extract(LEGACY, SUB).strip())

    def test_offsets_levels_and_boundaries_match_both_old_callers(self):
        for caller in ('air', 'sub'):
            offsets = [(0, 0), (1, 2), (-1, -1), (3, 4), (-2, 0), (4, 0), (0, -2), (0, 5)]
            for target in (None, 0, -1, 1, 2, 3, 4):
                for dx, dy in offsets if caller == 'air' else [(0, 0)]:
                    with self.subTest(caller=caller, target=target, offset=(dx, dy)):
                        old, new = Scene(legacy=True), Scene()
                        args = (target, dx, dy) if caller == 'air' else (target,)
                        self.assertEqual(getattr(old, caller)(*args), getattr(new, caller)(*args))
                        self.assertEqual(old.snapshot(), new.snapshot())

    def test_frames_first_union_once_nested_cargo_and_refresh_after_cleanup(self):
        s = Scene()
        self.assertTrue(s.air(2, 1, 2))
        moves = [event for event in s.events if event[0] == 'move']
        self.assertEqual([e[1] for e in moves], ['frame2', 'frame1', 'cargo', 'passenger'])
        self.assertTrue(all(e[3:] == (True, True) for e in moves))
        self.assertEqual(coords(get_turf(s.nested)), (4, 4, 2))
        self.assertEqual(coords(get_turf(s.axis)), (3, 4, 2))
        self.assertEqual(coords(get_turf(s.wheel)), (3, 4, 2))
        self.assertEqual(s.events[-4:], [('icon', 'cargo', False), ('icon', 'frame2', False),
                                        ('icon', 'frame1', False), ('vision', 'passenger', False)])
        self.assertEqual(s.events[0], ('collect', False))
        self.assert_clean(s)

    def test_last_destination_out_of_world_rejects_before_any_guard_or_move(self):
        s = Scene()
        s.axis.components.append(Obj(s, 'edge', s.locate(6, 6, 1)))
        self.assertFalse(s.air(2, 1, 0))
        self.assertEqual(s.events, [('collect', False)])
        self.assertEqual(coords(get_turf(s.frame1)), (2, 2, 1))
        self.assert_clean(s)

    def test_initial_and_reentrant_guards_preserve_active_operation(self):
        s = Scene()
        s.axis.transforming_vehicle = True
        held = s.axis.transform_tiles = DMList([s.frame1.loc])
        s.frame1.loc.vehicle_transforming = s.axis
        self.assertFalse(s.sub(2))
        self.assertFalse(s.air(2))
        self.assertEqual(s.events, [])
        self.assertIs(s.axis.transform_tiles, held)
        self.assertIs(s.frame1.loc.vehicle_transforming, s.axis)
        s.axis.release_transform_tiles(held)
        def retry(obj, destination):
            self.assertFalse(s.air(3))
        s.frame2.before_move = retry
        self.assertTrue(s.air(2))
        self.assertEqual([e for e in s.events if e[0] == 'collect'], [('collect', False)])
        self.assert_clean(s)

    def test_stale_and_callback_deleted_nonframes_are_skipped(self):
        s = Scene()
        def delete_cargo(obj, destination):
            s.cargo.deleted = True
            s.passenger.destroyed = True
        s.frame2.before_move = delete_cargo
        self.assertTrue(s.air(2))
        self.assertEqual([e[1] for e in s.events if e[0] == 'move'], ['frame2', 'frame1'])
        self.assertFalse(any(e[0] == 'vision' for e in s.events))
        self.assert_clean(s)

    def test_exceptions_release_guards_rethrow_identity_and_do_not_roll_back(self):
        for failing in ('frame1', 'cargo', 'passenger'):
            old, new = Scene(legacy=True), Scene()
            for s in (old, new):
                def fail(obj, destination, s=s):
                    raise s.error
                getattr(s, failing).before_move = fail
                with self.assertRaises(RuntimeError) as raised:
                    s.air(2)
                self.assertIs(raised.exception, s.error)
                self.assert_clean(s)
                self.assertEqual(coords(get_turf(s.frame2)), (3, 2, 2))
                self.assertFalse(any(e[0] in ('icon', 'vision') for e in s.events))
            self.assertEqual(old.snapshot(), new.snapshot())

    def test_collection_and_refresh_errors_keep_original_propagation(self):
        for field in ('collect_error', 'icon_error', 'vision_error'):
            old, new = Scene(legacy=True), Scene()
            for s in (old, new):
                setattr(s, field, True)
                with self.assertRaises(RuntimeError) as raised:
                    s.sub(2)
                self.assertIs(raised.exception, s.error)
                self.assert_clean(s)
            self.assertEqual(old.snapshot(), new.snapshot())

    def test_cleanup_does_not_clear_a_replacement_tile_owner(self):
        s = Scene()
        other = object()
        source = s.frame1.loc
        def replace_owner(obj, destination):
            source.vehicle_transforming = other
            raise s.error
        s.cargo.before_move = replace_owner
        with self.assertRaises(RuntimeError):
            s.air(2)
        self.assertIs(source.vehicle_transforming, other)
        self.assertFalse(s.axis.transforming_vehicle)
        self.assertIsNone(s.axis.transform_tiles)
        self.assertEqual(sum(t.vehicle_transforming is not None for t in s.tiles.values()), 1)

    def test_empty_set_and_false_force_move_return_preserve_legacy_contract(self):
        for empty in (False, True):
            old, new = Scene(legacy=True), Scene()
            for s in (old, new):
                if empty:
                    s.axis.transporting = DMList()
                    s.axis.components = DMList()
                else:
                    s.cargo.refuse_move = True
                self.assertTrue(s.sub(2))
                self.assert_clean(s)
            self.assertEqual(old.snapshot(), new.snapshot())

    def test_negative_controls_detect_lost_offsets_union_order_cleanup_and_refresh(self):
        source = read(BASE + 'axis.dm')
        mutations = (
            ('M.x + dx, M.y + dy, target_z', 'M.x, M.y, target_z'),
            ('(transporting | components)', '(transporting + components)'),
            ('\t\t\tF.forceMove(destinations[F])', '\t\t\tcontinue'),
            ('\t\trelease_transform_tiles(tiles)\n\t\tthrow e', '\t\tthrow e'),
            ('\trefresh_passenger_vision()\n\treturn TRUE\n\n/obj/structure/vehicleparts/axis/Destroy',
             '\treturn TRUE\n\n/obj/structure/vehicleparts/axis/Destroy'),
        )
        for before, after in mutations:
            with self.subTest(mutation=before):
                self.assertIn(before, source)
                good, bad = Scene(), Scene(helper_source=source.replace(before, after))
                for s in (good, bad):
                    if 'throw e' in before:
                        def fail(obj, destination, s=s):
                            raise s.error
                        s.cargo.before_move = fail
                    try:
                        s.air(2, 1, 2)
                    except RuntimeError:
                        pass
                self.assertNotEqual(good.snapshot(), bad.snapshot())


if __name__ == '__main__':
    unittest.main()
