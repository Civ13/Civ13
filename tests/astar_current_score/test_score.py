'''Offline source projection of A* scoring; this does not execute BYOND.'''
from itertools import product
from pathlib import Path
from types import SimpleNamespace
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).parent


def proc_source():
    source = (ROOT / 'code/pathfinding.dm').read_text(encoding='utf-8')
    return source[source.index('/proc/cirrAstar('):source.index('/proc/heuristic(')]


def scoring(source):
    start = source.index('\t\t\tvar/terrain_cost = ')
    end = source.index('\n\t\t\tif(!inOpen[neighbor])', start)
    body = source[start:end]
    body = body.replace('(neighbor.move_delay ? neighbor.move_delay / 10 : 0)',
                        '(neighbor.move_delay / 10 if neighbor.move_delay else 0)')
    body = body.replace('((current.x == neighbor.x || current.y == neighbor.y) ? 1 : 1.414)',
                        '(1 if current.x == neighbor.x or current.y == neighbor.y else 1.414)')
    body = body.replace('kestrel_gaia && kestrel_gaia.enabled', 'kestrel_gaia and kestrel_gaia.enabled')
    body = re.sub(r'\bvar/(\w+)', r'\1', body)
    body = body.replace('tentativeGScore\n', 'tentativeGScore = None\n')
    lines = []
    for line in body.splitlines():
        depth = len(line) - len(line.lstrip('\t')) - 3
        line = line.strip()
        if line.startswith('if(') and line.endswith(')'):
            line = 'if ' + line[3:-1] + ':'
        elif line == 'else':
            line = 'else:'
        lines.append('    ' * (depth + 1) + line)
    env = {}
    exec('def score(current, neighbor, gScore, current_score, kestrel_gaia):\n' +
         '\n'.join(lines) + '\n    return tentativeGScore\n', env)
    return env['score']



def expansion(source):
    start = source.index('\t\tvar/list/neighbors = getNeighbors')
    end = source.index('\n\t\t\tif(!inOpen[neighbor])', start)
    body = source[start:end]
    body = body.replace('var/list/neighbors = getNeighbors(current, alldirs, passableCache)',
                        'neighbors = neighbors')
    body = body.replace('for(var/turf/neighbor in neighbors)', 'for neighbor in neighbors:')
    body = body.replace('(neighbor.move_delay ? neighbor.move_delay / 10 : 0)',
                        '(neighbor.move_delay / 10 if neighbor.move_delay else 0)')
    body = body.replace('((current.x == neighbor.x || current.y == neighbor.y) ? 1 : 1.414)',
                        '(1 if current.x == neighbor.x or current.y == neighbor.y else 1.414)')
    body = body.replace('kestrel_gaia && kestrel_gaia.enabled', 'kestrel_gaia and kestrel_gaia.enabled')
    body = re.sub(r'\bvar/(\w+)', r'\1', body)
    body = body.replace('tentativeGScore\n', 'tentativeGScore = None\n')
    lines = []
    for line in body.splitlines():
        depth = len(line) - len(line.lstrip('\t')) - 2
        line = line.strip().replace('FALSE', 'False')
        if line.startswith('if(') and line.endswith(')'):
            line = 'if ' + line[3:-1] + ':'
        elif line == 'else':
            line = 'else:'
        lines.append('    ' * (depth + 1) + line)
    env = {}
    exec('def expand(current, neighbors, gScore, closedSet, kestrel_gaia):\n'
         '    results = []\n' + '\n'.join(lines) +
         '\n        results.append(tentativeGScore)\n    return results\n', env)
    return env['expand']


class Node:
    def __init__(self, x, y, move_delay=0):
        self.x, self.y, self.move_delay = x, y, move_delay


class TrackedScores(dict):
    def __init__(self, current, score):
        super().__init__({current: score})
        self.current, self.current_reads = current, 0

    def __getitem__(self, key):
        if key is self.current:
            self.current_reads += 1
        return super().__getitem__(key)


class ScoreTests(unittest.TestCase):
    def test_only_current_score_lookup_changes(self):
        before = (HERE / 'before.dm.txt').read_text(encoding='utf-8')
        expected = before.replace(
            '\t\tvar/list/neighbors = getNeighbors(current, alldirs, passableCache)\n',
            '\t\tvar/list/neighbors = getNeighbors(current, alldirs, passableCache)\n'
            '\t\tvar/current_score = gScore[current]\n', 1)
        expected = expected.replace('path_score(gScore[current], step_scale, terrain_cost)',
                                    'path_score(current_score, step_scale, terrain_cost)', 1)
        expected = expected.replace('tentativeGScore = gScore[current] + dist',
                                    'tentativeGScore = current_score + dist', 1)
        self.assertNotEqual(before, expected)
        self.assertEqual(proc_source().rstrip(), expected.rstrip())
        self.assertLess(expected.index('closedSet[current] = TRUE'),
                        expected.index('if(closedSet[neighbor])'))
        self.assertLess(expected.index('if(closedSet[neighbor])'),
                        expected.index('gScore[neighbor] = tentativeGScore'))

    def test_neighbor_expansion_executes_cache_and_closed_guard(self):
        before = (HERE / 'before.dm.txt').read_text(encoding='utf-8')
        after = proc_source()
        implementations = [
            expansion(before), expansion(after),
            expansion(after.replace('var/current_score = gScore[current]',
                                    'var/current_score = gScore[current] + 1', 1)),
            expansion(after.replace('if(closedSet[neighbor])', 'if(FALSE)', 1)),
        ]
        current, a, b = Node(4, 7), Node(5, 7, 2), Node(5, 8, 10)
        neighbors = [a, current, b, a]
        for initial, mode in product((0, 2.5, 100), ('absent', 'disabled', 'enabled')):
            outcomes = []
            for impl in implementations:
                calls = []
                kestrel = None if mode == 'absent' else SimpleNamespace(
                    enabled=mode == 'enabled',
                    path_score=lambda *args: calls.append(args) or args[0] + args[1] * args[2])
                scores = TrackedScores(current, initial)
                results = impl(current, neighbors, scores, {current: True, a: False, b: False}, kestrel)
                outcomes.append((results, calls, scores.current_reads))
            self.assertEqual(outcomes[0][:2], outcomes[1][:2])
            self.assertEqual(outcomes[0][2], 3)
            self.assertEqual(outcomes[1][2], 1)
            self.assertNotEqual(outcomes[1][:2], outcomes[2][:2])
            self.assertNotEqual(outcomes[1][:2], outcomes[3][:2])
        for empty_neighbors in ([], [current]):
            counts = []
            for impl in implementations[:2]:
                scores = TrackedScores(current, 7)
                self.assertEqual(impl(current, empty_neighbors, scores, {current: True}, None), [])
                counts.append(scores.current_reads)
            self.assertEqual(counts, [0, 1])

    def test_scoring_and_callback_trace_match_with_negative_control(self):
        before = scoring((HERE / 'before.dm.txt').read_text(encoding='utf-8'))
        after = scoring(proc_source())
        current = SimpleNamespace(x=4, y=7)
        different = 0
        for score, dx, dy, delay, enabled in product((0, 2.5, 100), (0, 1), (0, 1),
                                                       (0, 3, 10), (False, True)):
            neighbor = SimpleNamespace(x=current.x + dx, y=current.y + dy, move_delay=delay)
            outputs = []
            for implementation, cached in ((before, score), (after, score), (after, score + 1)):
                calls = []
                kestrel = SimpleNamespace(enabled=enabled,
                    path_score=lambda *args: calls.append(args) or args[0] + args[1] * args[2])
                result = implementation(current, neighbor, IdentityScore(current, score), cached, kestrel)
                outputs.append((result, calls))
            self.assertEqual(outputs[0], outputs[1])
            different += outputs[1] != outputs[2]
        self.assertGreater(different, 0)


class IdentityScore:
    def __init__(self, current, score):
        self.current, self.score = current, score

    def __getitem__(self, key):
        if key is not self.current:
            raise KeyError(key)
        return self.score


if __name__ == '__main__':
    unittest.main()
