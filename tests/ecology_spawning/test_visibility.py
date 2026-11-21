"""Offline source-projected visibility checks, not BYOND/client acceptance."""
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/ecology/ecology_spawning.dm').read_text(encoding='utf-8-sig')
SPEC = importlib.util.spec_from_file_location('source_adapter', ROOT / 'tests/save_movement/source_adapter.py')
ADAPTER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ADAPTER)
OLD = 'if (body && body.z == T.z && get_dist(body, T) <= margin)'
NEW = 'if (body && body != eye && body.z == T.z && get_dist(body, T) <= margin)'

def run(source, clients, target, margin=7):
    calls = []
    def distance(a, b):
        calls.append(a)
        return max(abs(a.x - b.x), abs(a.y - b.y))
    env = {'clients': clients, 'typed_iter': lambda values, kind: values,
           'get_turf': lambda value: value, 'get_dist': distance}
    proc = ADAPTER.project(source, '/proc/ecology_visible_to_players', 'T, margin', env)
    return proc(target, margin), calls

def turf(x, y, z=1):
    return SimpleNamespace(x=x, y=y, z=z)

class VisibilityTests(unittest.TestCase):
    def setUp(self):
        self.assertEqual(SOURCE.count(NEW), 1)
        self.old = SOURCE.replace(NEW, OLD)

    def test_eye_body_boundary_parity(self):
        target = turf(0, 0)
        near, far = turf(7, 0), turf(8, 0)
        body, off_level = turf(1, 0), turf(0, 0, 2)
        client = lambda eye, mob: SimpleNamespace(eye=eye, mob=mob)
        cases = [[], [client(None, None)], [client(near, near)],
                 [client(far, far)], [client(near, far)], [client(far, body)],
                 [client(None, body)], [client(off_level, body)],
                 [client(off_level, off_level)], [client(far, far), client(None, body)]]
        for clients in cases:
            with self.subTest(clients=clients):
                self.assertEqual(run(self.old, clients, target)[0], run(SOURCE, clients, target)[0])

    def test_same_far_turf_skips_duplicate_distance(self):
        target, far = turf(0, 0), turf(8, 0)
        clients = [SimpleNamespace(eye=far, mob=far)]
        before, old_calls = run(self.old, clients, target)
        after, new_calls = run(SOURCE, clients, target)
        self.assertFalse(before)
        self.assertEqual(after, before)
        self.assertEqual((len(old_calls), len(new_calls)), (2, 1))

    def test_remote_eye_must_not_hide_near_body(self):
        target, eye, body = turf(0, 0), turf(8, 0), turf(1, 0)
        clients = [SimpleNamespace(eye=eye, mob=body)]
        self.assertTrue(run(SOURCE, clients, target)[0])
        self.assertFalse(run(SOURCE.replace(NEW, 'if (FALSE)'), clients, target)[0])

if __name__ == '__main__':
    unittest.main()
