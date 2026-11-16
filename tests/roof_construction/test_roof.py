"""Offline projections of production roof branches; no BYOND or game startup.

Only these straight-line/if DM procedures are projected. Engine calls are fake
boundaries, so this checks source control flow, not native constructors or GC.
Unsupported syntax fails preparation instead of being silently skipped.
"""
from pathlib import Path
import re
from types import SimpleNamespace as NS
import unittest

ROOT = Path(__file__).resolve().parents[2]
CORE = ROOT / 'code/game/objects/building_levels.dm'
ROOF = ROOT / 'code/game/objects/roof_stuff.dm'


def body(source, declaration):
    start = source.index(declaration) + len(declaration)
    return source[start:].split('\n/', 1)[0].strip('\n')


def project(source, declaration, name, args, namespace, builder=False):
    """Translate the small reviewed DM subset, preserving production branches."""
    lines = [f'def {name}({args}):']
    for raw in body(source, declaration).splitlines():
        code = raw.split('//', 1)[0].rstrip()
        if not code.strip():
            continue
        indent = len(code) - len(code.lstrip('\t'))
        code = code.strip()
        code = re.sub(r'var/(?:[\w]+/)*([\w]+)(?= =)', r'\1', code)
        code = code.replace('new roof_type(T)', 'make_roof(T, roof_type)')
        code = code.replace('new(above)', 'make_floor(above)')
        if builder:
            code = re.sub(r'\bdone\b', 'src.done', code)
            code = re.sub(r'\btarget_type\b', 'src.target_type', code)
        code = code.replace('locate(/obj/roof) in T', 'has_roof(T)')
        code = code.replace('locate(/obj/covers) in above', 'has_cover(above)')
        code = code.replace('/area/caribbean/no_mans_land', 'NO_MANS_LAND')
        code = code.replace('&&', ' and ').replace('||', ' or ')
        code = re.sub(r'!(?!=)', 'not ', code)
        code = re.sub(r'\bnull\b', 'None', code)
        code = re.sub(r'\bTRUE\b', 'True', code)
        code = re.sub(r'\bFALSE\b', 'False', code)
        if code.startswith('if (') and code.endswith(')'):
            code = 'if ' + code[4:-1] + ':'
        elif code == 'else':
            code = 'else:'
        lines.append('    ' * indent + code)
    compiled = '\n'.join(lines) + '\n'
    exec(compile(compiled, '<production roof projection>', 'exec'), namespace)
    return namespace[name]


class Site:
    def __init__(self, z=1, open=True, forbidden=False, supported=True):
        self.x = self.y = 4
        self.z = z
        self.open, self.forbidden, self.supported = open, forbidden, supported
        self.roofs, self.covers = [], []


class RoofProjection:
    def __init__(self, source=None, maxz=1, allocate=False):
        self.source = source or CORE.read_text(encoding='utf-8')
        self.world = NS(maxz=maxz)
        self.site = Site()
        self.upper = Site(2) if maxz > 1 else None
        self.allocate = allocate
        self.allocations = self.floor_creations = self.links = 0
        self.messages = []
        env = dict(world=self.world, building_allocating_z=0,
                   persistence_save_in_progress=False, NO_MANS_LAND=True,
                   get_area=lambda t: t.forbidden, istype=lambda a, b: a == b,
                   has_roof=lambda t: bool(t.roofs),
                   has_cover=lambda t: bool(t.covers),
                   building_supported_height=lambda t: t.supported,
                   building_open_turf=lambda t: bool(t and t.open),
                   locate=lambda x, y, z: self.upper if z == 2 else None,
                   building_allocate_level=self.allocate_level,
                   building_item_usable=lambda s, u: s.loc == u and not s.deleted,
                   get_dist=lambda u, t: u.distance,
                   to_chat=lambda u, m: self.messages.append(m),
                   SPAN_WARNING=lambda m: m,
                   make_roof=self.make_roof, make_floor=self.make_floor,
                   building_link=self.link)
        self.env = env
        env['building_roof_error'] = project(self.source, '/proc/building_roof_error(turf/T)',
                                            'roof_error', 'T', env)
        self.construct = project(self.source,
            '/proc/building_construct_roof(turf/T, roof_type, mob/user, obj/item/source)',
            'construct', 'T, roof_type, user=None, source=None', env)

    def allocate_level(self, z):
        self.allocations += 1
        if self.allocate:
            self.world.maxz = z
            self.upper = Site(z)
            if callable(self.allocate):
                self.allocate(self)
        return bool(self.allocate)

    def make_roof(self, t, roof_type):
        roof = NS(flammable=roof_type, floor=None, building_floor_z=0)
        roof.building_floor = lambda: roof.floor
        t.roofs.append(roof)
        return roof

    def make_floor(self, t):
        assert t is not None, 'floor created at null location'
        self.floor_creations += 1
        floor = NS()
        t.covers.append(floor)
        return floor

    def link(self, roof, floor):
        self.links += 1
        roof.floor = floor
        roof.building_floor_z = self.upper.z

    def use_builder(self, cancel=False):
        user = NS(loc=Site(), dir=1, z=1, distance=1)
        item = NS(loc=user, deleted=False, done=False, target_type=True, debits=0)

        def retire(source):
            source.debits += 1
            source.deleted = True
            source.loc = None

        self.env.update(src=item, get_turf=lambda u: u.loc,
                        get_step=lambda u, d: self.site, ishuman=lambda u: False,
                        building_confirm=lambda u, d: True,
                        building_wait=lambda u, t, start: not cancel,
                        SPAN_NOTICE=lambda m: m, visible_message=lambda m: None,
                        qdel=retire, building_construct_roof=self.construct)
        attack = project(ROOF.read_text(encoding='utf-8'),
            '/obj/item/weapon/roofbuilder/attack_self(mob/user)',
            'attack_self', 'user', self.env, builder=True)
        attack(user)
        return item


class RoofTests(unittest.TestCase):
    def test_denied_growth_returns_roof_without_upper_floor(self):
        f = RoofProjection()
        r = f.construct(f.site, True)
        self.assertIs(r, f.site.roofs[0])
        self.assertEqual((f.world.maxz, f.allocations, f.floor_creations, f.links), (1, 1, 0, 0))
        self.assertIsNone(r.floor)
        self.assertEqual(r.building_floor_z, 0)

    def test_allowed_growth_and_existing_level_link_floor_with_material(self):
        for maxz, allocate, calls in [(1, True, 1), (2, False, 0)]:
            for flammable in (True, False):
                with self.subTest(maxz=maxz, flammable=flammable):
                    f = RoofProjection(maxz=maxz, allocate=allocate)
                    r = f.construct(f.site, flammable)
                    self.assertEqual((f.world.maxz, f.allocations, f.links), (2, calls, 1))
                    self.assertEqual(r.floor.flammable, flammable)
                    self.assertEqual(r.floor.wood, flammable)
                    if not flammable:
                        self.assertEqual((r.floor.material, r.floor.amount), ('Stone', 0))

    def test_null_site_and_unusable_or_distant_builder_fail_without_construction(self):
        f = RoofProjection()
        self.assertIsNone(f.construct(None, True))
        user = NS(z=1, distance=1)
        for loc, deleted, z, distance in [(None, False, 1, 1), (user, True, 1, 1),
                                         (user, False, 2, 1), (user, False, 1, 2)]:
            user.z, user.distance = z, distance
            self.assertIsNone(f.construct(f.site, True, user, NS(loc=loc, deleted=deleted)))
        self.assertFalse(f.site.roofs)
        self.assertEqual(f.floor_creations, 0)

    def test_eligibility_and_existing_obstructions_still_reject(self):
        for kind in ('save', 'busy', 'unsupported', 'forbidden', 'duplicate',
                     'terrain', 'cover', 'upper-forbidden', 'missing-existing-turf'):
            with self.subTest(kind=kind):
                f = RoofProjection(maxz=2)
                if kind == 'save': f.env['persistence_save_in_progress'] = True
                if kind == 'busy': f.env['building_allocating_z'] = 2
                if kind == 'unsupported': f.site.supported = False
                if kind == 'forbidden': f.site.forbidden = True
                if kind == 'duplicate': f.site.roofs.append('existing')
                if kind == 'terrain': f.upper.open = False
                if kind == 'cover': f.upper.covers.append('existing')
                if kind == 'upper-forbidden': f.upper.forbidden = True
                if kind == 'missing-existing-turf': f.upper = None
                before = list(f.site.roofs)
                self.assertIsNone(f.construct(f.site, True))
                self.assertEqual(f.site.roofs, before)
                self.assertEqual((f.allocations, f.floor_creations), (0, 0))

    def test_yield_rechecks_support_occupancy_and_source(self):
        for change in (lambda f: setattr(f.site, 'supported', False),
                       lambda f: f.upper.covers.append('racing builder'),
                       lambda f: f.env.update(building_allocating_z=2)):
            f = RoofProjection(allocate=change)
            self.assertIsNone(f.construct(f.site, True))
            self.assertFalse(f.site.roofs)
            self.assertEqual(f.floor_creations, 0)

    def test_material_commit_is_once_after_success_with_failure_reset(self):
        # Production caller owns the already-paid roofing item. Check its exact
        # success/failure branch; projection above establishes returned outcomes.
        source = body(ROOF.read_text(encoding='utf-8'),
                      '/obj/item/weapon/roofbuilder/attack_self(mob/user)')
        self.assertEqual(source.count('qdel(src)'), 1)
        self.assertIn('\tdone = TRUE\n\tvar/obj/roof/R = building_construct_roof', source)
        self.assertIn('\tif (!R)\n\t\tdone = FALSE\n\t\treturn\n', source)
        self.assertLess(source.index('if (!R)'), source.index('qdel(src)'))
        self.assertIn('!building_wait(user, covers_time, start) || !building_item_usable', source)
        self.assertIn('if (R.building_floor())', source)
        self.assertIn('finishes building the roof."', source)

    def test_production_builder_consumes_one_on_fallback_and_linked_success(self):
        for maxz, allocate in [(1, False), (1, True), (2, False)]:
            with self.subTest(maxz=maxz, allocate=allocate):
                f = RoofProjection(maxz=maxz, allocate=allocate)
                item = f.use_builder()
                self.assertEqual((item.debits, item.done, item.loc), (1, True, None))
                self.assertEqual(len(f.site.roofs), 1)

    def test_failed_or_cancelled_production_builder_preserves_material(self):
        for failure in ('unsupported', 'obstructed', 'cancelled', 'racing-support'):
            with self.subTest(failure=failure):
                f = RoofProjection(maxz=2 if failure == 'obstructed' else 1)
                if failure == 'unsupported': f.site.supported = False
                if failure == 'obstructed': f.upper.covers.append('existing')
                if failure == 'racing-support':
                    f.allocate = lambda f: setattr(f.site, 'supported', False)
                item = f.use_builder(cancel=failure == 'cancelled')
                self.assertEqual((item.debits, item.done, item.deleted), (0, False, False))
                self.assertIsNotNone(item.loc)
                self.assertFalse(f.site.roofs)

    def test_allocator_still_reserves_claims_and_finishes_under_original_caps(self):
        allocator = body(CORE.read_text(encoding='utf-8'),
            '/proc/building_allocate_level(target_z, bootstrap = FALSE, datum/new_z_reservation/reservation)')
        for gate in ('persistence_save_in_progress', 'building_allocating_z',
                     'BUILDING_MAX_Z', 'BUILDING_EXTRA_LEVELS', 'BUILDING_MAX_LEVEL_CELLS'):
            self.assertIn(gate, allocator)
        self.assertLess(allocator.index('world_z_budget.reserve('), allocator.index('world_z_budget.claim_level('))
        self.assertLess(allocator.index('world_z_budget.claim_level('), allocator.index('world.maxz = target_z'))
        self.assertIn('throw allocation_error', allocator)

    def test_negative_controls_detect_old_abort_and_null_floor(self):
        source = CORE.read_text(encoding='utf-8')
        old = '\tif (T.z == world.maxz)\n\t\tbuilding_allocate_level(T.z + 1)'
        self.assertEqual(source.count(old), 1)
        abort = source.replace(old, '\tif (T.z == world.maxz and not building_allocate_level(T.z + 1))\n\t\treturn null')
        f = RoofProjection(abort)
        self.assertIsNone(f.construct(f.site, True), 'old allocation abort control must lose roof')
        guard = '\tif (!above)\n\t\treturn R // Allocation was refused: the paid roof still provides shelter.\n'
        self.assertEqual(source.count(guard), 1)
        f = RoofProjection(source.replace(guard, ''))
        with self.assertRaisesRegex(AssertionError, 'floor created at null location'):
            f.construct(f.site, True)


if __name__ == '__main__':
    unittest.main()
