"""Production admission contracts and eye-relative arithmetic, not native pixels."""
from fractions import Fraction as Q
import unittest
import importlib.util
from pathlib import Path
_spec = importlib.util.spec_from_file_location("production_los_offline", Path(__file__).with_name("test_offline.py"))
_offline = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_offline)
CORE, fragment, projected_geometry, reference_footprint_hit, reference_entry = (_offline.CORE, _offline.fragment, _offline.projected_geometry, _offline.reference_footprint_hit, _offline.reference_entry)


class ProductionGeometry(unittest.TestCase):
    def test_fractional_eye_and_large_map_translation(self):
        functions = projected_geometry()
        footprint = functions['los_footprint_hits_cell']
        ray = functions['los_ray_entry']
        # Native smooth steps use 2px = 1/16 of a tile. Production feeds relative
        # coordinates, so the same oracle applies near x=1000 and x=30000.
        count = 0
        for step in range(0, 16, 3):
            eye = Q(step, 16)
            for target in [(3, 0), (3, 2), (-3, -2), (0, 4)]:
                for cell in [(1, 0), (2, 1), (-1, -1), (0, 2)]:
                    tx, ty = target[0] - eye, Q(target[1])
                    cx, cy = cell[0] - eye, Q(cell[1])
                    actual = footprint(0, 0, float(tx), float(ty), .25, float(cx), float(cy))
                    expected = reference_footprint_hit(0, 0, tx, ty, cx, cy)
                    self.assertEqual(actual, expected)
                    result = ray(0, 0, float(tx), float(ty), float(cx), float(cy))
                    expected_ray = reference_entry(0, 0, tx, ty, cx, cy)
                    self.assertEqual(None if result is None else Q(result[1]) / Q(result[2]), expected_ray)
                    for origin in [1000, 30000]:
                        self.assertEqual(float(Q(origin) + target[0] - (Q(origin) + eye)), float(tx))
                    count += 1
        self.assertEqual(count, 96)

    def broadphase_helpers(self):
        import math
        source = CORE.read_text()
        env = projected_geometry(source)
        env['round'] = math.floor  # BYOND round(A), NOT Python banker's round.
        for name in ['los_bucket_index', 'los_bucket_lower', 'los_bucket_upper', 'los_target_blocked']:
            _offline.project(source, '/proc/' + name + '(', env)
        return env

    def test_spatial_bins_preserve_every_blocking_pair(self):
        env = self.broadphase_helpers()
        index, lower, upper, blocked = [env[n] for n in [
            'los_bucket_index', 'los_bucket_lower', 'los_bucket_upper', 'los_target_blocked']]
        self.assertEqual([index(x) for x in [-4.0625, -4, -.0625, 0, 3.9375, 4]], [-2, -1, -1, 0, 0, 1])
        cases = 0
        for eye in [0, .125, .875]:
            # Include offset blockers with distinct native tile coordinates.
            blockers = [(x-eye+offset, y, x-eye, y)
                        for x in range(-8, 9, 2) for y in range(-8, 9, 2)
                        for offset in [0, .5]]
            bins = {}
            for b in blockers:
                bins.setdefault((index(b[0]), index(b[1])), []).append(b)
            for tx0, ty in [(x, y) for x in [-7, -3, 0, 3, 7] for y in [-7, -3, 0, 3, 7]]:
                for offset in [0, .125]:
                    tx, tile_x = tx0-eye+offset, tx0-eye
                    for opaque in [False, True]:
                        half = 0 if opaque else .25
                        keys = {(bx, by) for bx in range(lower(tx, half), upper(tx, half)+1)
                                for by in range(lower(ty, half), upper(ty, half)+1)}
                        candidates = [b for key in keys for b in bins.get(key, [])]
                        flat_result = False
                        for cx, cy, native_x, native_y in blockers:
                            hit = blocked(tx, ty, cx, cy, tile_x, ty, native_x, native_y, opaque)
                            if hit:
                                self.assertIn((index(cx), index(cy)), keys)
                                flat_result = True
                            cases += 1
                        bucket_result = any(blocked(tx, ty, cx, cy, tile_x, ty, native_x, native_y, opaque)
                                            for cx, cy, native_x, native_y in candidates)
                        self.assertEqual(flat_result, bucket_result)
        self.assertEqual(cases, 48600)
        # Exact upper contact falls on the next bucket boundary; omitting it
        # would miss a cell touching the footprint at x=3.5.
        self.assertEqual(upper(3.25, .25), 1)
        self.assertTrue(blocked(3.25, 0, 4, 0, 3, 0, 4, 0, False))
        self.assertFalse(index(4) < upper(3.25, .25))  # exclusive-upper mutation loses it

    def test_dense_candidate_counts_and_sparse_source_path(self):
        env = self.broadphase_helpers()
        index, lower, upper = [env[n] for n in ['los_bucket_index', 'los_bucket_lower', 'los_bucket_upper']]
        blockers = [(x, y) for x in range(-8, 9) for y in range(-8, 9)]
        bins = {}
        for b in blockers:
            bins.setdefault((index(b[0]), index(b[1])), []).append(b)
        total, lookups = 0, 0
        for tx in range(-7, 8):
            for ty in range(-7, 8):
                for bx in range(lower(tx, .25), upper(tx, .25)+1):
                    for by in range(lower(ty, .25), upper(ty, .25)+1):
                        total += len(bins.get((bx, by), []))
                        lookups += 1
        self.assertEqual(total, 23104)
        self.assertEqual(lookups, 1444)
        self.assertLess(total, len(blockers)*225/2)
        source = CORE.read_text()
        build = fragment(source, '/datum/los_snapshot/proc/index_blockers(')
        query = fragment(source, '/datum/los_snapshot/proc/blocks_target(')
        self.assertIn('if(blockers.len <= 16)', build)
        self.assertIn('blocker_bins = null', build)
        self.assertIn('bin += B', build)
        self.assertIn('los_bucket_index(B.cell_x)', build)
        self.assertIn('los_bucket_index(B.cell_y)', build)
        self.assertIn('if(!blocker_bins)', query)
        self.assertIn('for(var/datum/los_cell/B in blockers)', query)
        self.assertIn('bx <= max_x', query)
        self.assertIn('by <= max_y', query)
        self.assertIn('blocker_bins["[bx],[by]"]', query)
        self.assertIn('if(!bin)\n\t\t\t\tcontinue', query)
        self.assertEqual(query.count('los_target_blocked(tx, ty, B.cell_x, B.cell_y, target_tile_x, target_tile_y, B.tile_x, B.tile_y, opaque_target)'), 2)
        self.assertNotIn('list()', query)
        self.assertIn('S.index_blockers()', fragment(source, '/datum/los_context/proc/capture('))

    def test_viewport_cache_reparses_only_changed_scalar(self):
        from types import SimpleNamespace
        import re
        source = CORE.read_text()
        fields = ['viewport_cache_ready', 'viewport_cached_view', 'viewport_cached_dimensions']
        for field in fields:
            source = re.sub(r'(?<!\.)\b' + field + r'\b', 'self.' + field, source)
        source = source.replace('dimensions.len', 'len(dimensions)')
        calls = []
        def getviewsize(view):
            calls.append(view)
            if isinstance(view, int):
                return _offline.DMList([view*2+1, view*2+1])
            return _offline.DMList([int(x) for x in view.split('x')])
        env = {'getviewsize': getviewsize, 'len': len}
        viewport = _offline.project(source, '/datum/los_context/proc/viewport(', env, True)
        context = SimpleNamespace(owner=SimpleNamespace(view=7), viewport_cache_ready=False,
                                  viewport_cached_view=None, viewport_cached_dimensions=None)
        first = viewport(context)
        self.assertEqual(first, [15, 15])
        self.assertIs(viewport(context), first)
        context.owner.view = '23x15'
        self.assertEqual(viewport(context), [23, 15])
        context.owner.view = '65x15'
        self.assertIsNone(viewport(context))
        self.assertIsNone(viewport(context))
        context.owner.view = 7
        self.assertEqual(viewport(context), [15, 15])
        self.assertEqual(calls, [7, '23x15', '65x15', 7])
        context.owner = None
        self.assertIsNone(viewport(context))
        retire = fragment(CORE.read_text(), '/datum/los_context/proc/retire(')
        for field in fields:
            self.assertIn(field + ' = ', retire)
        # Fresh policy guard remains on EVERY decision, not bypassed by bins.
        decision = fragment(CORE.read_text(), '/datum/los_context/proc/decision_snapshot(')
        self.assertIn('S.policy != policy_key()', decision)

    def test_bbox_rejection_matches_unpruned_geometry(self):
        source = CORE.read_text()
        gate = ('\tif (max(ex, tx+half_size) < cx-0.5 || min(ex, tx-half_size) > cx+0.5 || '
                'max(ey, ty+half_size) < cy-0.5 || min(ey, ty-half_size) > cy+0.5)\n\t\treturn FALSE\n')
        self.assertIn(gate, source)
        candidate = projected_geometry(source)['los_footprint_hits_cell']
        triangle = projected_geometry(source)['los_triangle_hits_cell']
        def unpruned(ex, ey, tx, ty, h, cx, cy):
            corners = [(tx-h,ty-h),(tx+h,ty-h),(tx+h,ty+h),(tx-h,ty+h)]
            return any(triangle(ex,ey,*corners[j],*corners[(j+1)%4],cx,cy) for j in range(4))
        count = 0
        for ex, ey in [(0, 0), (.125, -.875)]:
            for tx, ty in [(3, 0), (-3, -2), (0, 4)]:
                for cx in [-4, -1, 0, .5, 2.5, 3.75, 5]:
                    for cy in [-3, -.75, -.5, 0, .5, .75, 4.75]:
                        args = (ex, ey, tx, ty, .25, cx, cy)
                        self.assertEqual(candidate(*args), unpruned(*args))
                        count += 1
        self.assertEqual(count, 294)
        # A separated cell does no triangle work. Touching endpoints still hit.
        env = projected_geometry(source)
        def unexpected_triangle(*args):
            raise AssertionError('disjoint bounding box reached triangle checks')
        env['los_hull_axis_separates'] = unexpected_triangle
        self.assertFalse(env['los_footprint_hits_cell'](0, 0, 3, 0, .25, 5, 0))
        self.assertTrue(candidate(0, 0, 3, 0, .25, 3.75, 0))

    def test_hull_sat_matches_legacy_triangles_and_bounded_segments(self):
        import random
        env = projected_geometry()
        candidate = env['los_footprint_hits_cell']
        triangle = env['los_triangle_hits_cell']
        ray = env['los_ray_entry']
        rng = random.Random(20261030)
        counts = {'hull': 0, 'legacy': 0}
        for name, key in [('los_hull_axis_separates', 'hull'), ('los_axis_separates', 'legacy')]:
            original = env[name]
            def counted(*args, original=original, key=key):
                counts[key] += 1
                return original(*args)
            env[name] = counted
        for i in range(20000):
            ex, ey = rng.randrange(-32, 33)/32, rng.randrange(-32, 33)/32
            tx, ty = rng.randrange(-512, 513)/32, rng.randrange(-512, 513)/32
            cx, cy = rng.randrange(-17, 18), rng.randrange(-17, 18)
            h = [0, .25, .5][i % 3]
            corners = [(tx-h,ty-h),(tx+h,ty-h),(tx+h,ty+h),(tx-h,ty+h)]
            legacy = any(triangle(ex,ey,*corners[j],*corners[(j+1)%4],cx,cy) for j in range(4))
            self.assertEqual(candidate(ex,ey,tx,ty,h,cx,cy), legacy)
            if h == 0:
                self.assertEqual(candidate(ex,ey,tx,ty,0,cx,cy), ray(ex,ey,tx,ty,cx,cy) is not None)
        self.assertLess(counts['hull'], counts['legacy'])
        # Closed contact, points and bounded segments: not an infinite ray.
        self.assertTrue(candidate(0,0,3,0,0,3.5,0))
        self.assertFalse(candidate(0,0,3,0,0,4,0))
        self.assertTrue(candidate(0,0,0,0,0,.5,.5))
        self.assertFalse(candidate(0,0,0,0,0,1,1))

    def test_empty_ground_does_not_allocate_cell(self):
        capture = fragment(CORE.read_text(), '/datum/los_context/proc/capture(')
        self.assertIn('if (owner_count)\n\t\t\t\tvar/datum/los_cell/B = new', capture)
        self.assertIn('B.owners = owner_count', capture)
        self.assertIn('B.surface_owner = cell_owner', capture)
        self.assertIn('moving_blocker.cell_x = cx - S.eye_x + AM.step_x / 32', capture)
        self.assertEqual(capture.count('var/datum/los_cell/B = new'), 1)

    def test_same_native_tile_exemption_with_offset_objects_and_opaque_owners(self):
        source = CORE.read_text()
        env = projected_geometry(source)
        blocked = _offline.project(source, '/proc/los_target_blocked(', env)
        for eye_offset in [0, .125, .5, .875]:
            tile = 3 - eye_offset
            for target_offset in [0, .125, -.5]:
                tx = tile + target_offset
                for blocker_offset in [0, .125, -.5]:
                    cx = tile + blocker_offset
                    for opaque in [False, True]:
                        # Ground, objects and opaque objects share native turf
                        # even if their geometric centers differ during motion.
                        self.assertFalse(blocked(tx, 0, cx, 0, tile, 0, tile, 0, opaque))
                        # Every intervening native tile retains occlusion.
                        self.assertTrue(blocked(tx, 0, 1-eye_offset, 0, tile, 0, 1-eye_offset, 0, opaque))
                        self.assertTrue(blocked(5-eye_offset, 0, cx, 0, 5-eye_offset, 0, tile, 0, opaque))
            # Two distinct opaque owners on target's native turf are both exempt;
            # insertion order and surface_owner selection cannot change result.
            self.assertFalse(any(blocked(tile, 0, center, 0, tile, 0, tile, 0, True)
                                 for center in [tile, tile+.125]))
            # Equal geometric centers on DIFFERENT native tiles are not exempt.
            self.assertTrue(blocked(tile, 0, tile, 0, tile, 0, tile-1, 0, False))
            # Other y-coordinate also means another tile, regardless of x.
            self.assertTrue(blocked(tile, 0, tile, 0, tile, 0, tile, -1, False))
        broken = source.replace('target_tile_x == blocker_tile_x && target_tile_y == blocker_tile_y', 'FALSE', 1)
        old = _offline.project(broken, '/proc/los_target_blocked(', projected_geometry(broken))
        self.assertTrue(old(3.125, 0, 3, 0, 3, 0, 3, 0, False))
        self.assertTrue(old(3, 0, 3, 0, 3, 0, 3, 0, True))
        decision = fragment(source, '/datum/los_context/proc/decision_snapshot(')
        self.assertIn('"[target.opacity]|[target_tile_x],[target_tile_y]|[tx],[ty]"', decision)
        self.assertIn('S.blocks_target(tx, ty, target_tile_x, target_tile_y, target.opacity)', decision)
        capture = fragment(source, '/datum/los_context/proc/capture(')
        for prefix in ['B', 'moving_blocker']:
            self.assertIn(prefix + '.tile_x = cx - S.eye_x', capture)
            self.assertIn(prefix + '.tile_y = cy - S.eye_y', capture)

    def test_save_allows_read_only_capture_but_load_suspends(self):
        from types import SimpleNamespace
        import re
        policy = fragment(CORE.read_text(), '/datum/los_context/proc/policy_key(')
        condition = re.search(r'\((persistence_active_operation && persistence_active_operation.kind != "save")\)', policy)
        self.assertIsNotNone(condition)
        expression = condition[1].replace('&&', 'and')
        for operation, blocked in [(None, False), (SimpleNamespace(kind='save'), False),
                                   (SimpleNamespace(kind='load'), True), (SimpleNamespace(kind='restore'), True)]:
            self.assertEqual(bool(eval(expression, {'__builtins__': {}}, {'persistence_active_operation': operation})), blocked)
        # Historical unconditional gate denied saves as well; keep that witness.
        self.assertTrue(bool(SimpleNamespace(kind='save')))

    def test_production_policy_and_snapshot_contracts(self):
        source = CORE.read_text()
        capture = fragment(source, '/datum/los_context/proc/capture(')
        decision = fragment(source, '/datum/los_context/proc/decision_snapshot(')
        eligible = fragment(source, '/datum/los_context/proc/eligible(')
        policy = fragment(source, '/datum/los_context/proc/policy_key(')
        self.assertIn('A.opacity && A != body', capture)
        self.assertNotIn('A.type', capture)
        self.assertNotIn('T.type', capture)
        self.assertIn('body.step_x / 32', capture)
        self.assertIn('AM.step_x / 32', capture)
        self.assertIn('locate(cx, cy, S.eye_z)', capture)
        self.assertIn('cx - S.eye_x', capture)
        self.assertNotIn('view(', decision)
        self.assertIn('los_footprint_hits_cell(0, 0, tx, ty, 0,', fragment(source, '/proc/los_target_blocked('))
        self.assertIn('S.clear_footprints[footprint_key]', decision)
        self.assertIn('owner.eye == body', eligible)
        self.assertNotIn('is_blind', eligible)
        self.assertIn('is_blind(body)', policy)
        self.assertIn('persistence_active_operation', policy)
        self.assertIn('owner.los_presenter.retire()', source)
        self.assertIn('owner.los_presenter.invalidate()', source)


if __name__ == '__main__':
    unittest.main()
