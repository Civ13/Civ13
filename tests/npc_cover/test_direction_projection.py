"""Offline source projection of NPC cover flank scoring, not native gameplay."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/mob/living/simple_animal/hostile/tactical_ai.dm'
START = '// Flanking bonus: prefer positions that are at a different angle from current'
END = '// Check LOS from cover to enemy'

BASELINE = """\
var/current_dir = get_dir(src, enemy)
var/new_dir = get_dir(T, enemy)
if(new_dir != current_dir)
    score += 40
"""


def project(block, initial_direction, candidates):
    """Interpret only the flank block; fail closed on unknown statements."""
    translations = {
        'var/current_dir = get_dir(src, enemy)': 'current_dir = get_dir(src, enemy)',
        'if(cover_count == 1)': 'if cover_count == 1:',
        'current_dir = get_dir(src, enemy)': 'current_dir = get_dir(src, enemy)',
        'var/new_dir = get_dir(T, enemy)': 'new_dir = get_dir(T, enemy)',
        'if(new_dir != current_dir)': 'if new_dir != current_dir:',
        'score += 40': 'score += 40',
        'score += 0': 'score += 0',
    }
    lines = []
    for line in block.splitlines():
        if not line.strip() or line.strip().startswith('//'):
            continue
        statement = line.strip()
        if statement not in translations:
            raise AssertionError('Unknown flank statement: ' + statement)
        depth = len(line) - len(line.lstrip('\t '))
        # Extracted production source uses tabs; frozen baseline uses spaces.
        indent = depth if '\t' in line[:depth] else depth // 4
        lines.append('    ' * indent + translations[statement])
    common = min((len(line) - len(line.lstrip())) for line in lines)
    code = compile('\n'.join(line[common:] for line in lines), '<flank projection>', 'exec')
    src, enemy = object(), object()
    calls = []
    state = {'src': src, 'enemy': enemy, 'current_dir': None}
    def get_dir(first, second):
        calls.append('source' if first is src else 'candidate')
        return initial_direction if first is src else first
    state['get_dir'] = get_dir
    scores = []
    for index, (direction, score) in enumerate(candidates, 1):
        state.update(T=direction, score=score, cover_count=index)
        exec(code, {'__builtins__': {}}, state)
        scores.append(state['score'])
    winner = max(range(len(scores)), key=scores.__getitem__) if scores else None
    return scores, winner, calls.count('source')


class CoverDirection(unittest.TestCase):
    def setUp(self):
        source = SOURCE.read_text(encoding='utf-8')
        body = source.split('/mob/living/simple_animal/hostile/human/proc/find_best_cover(atom/enemy)', 1)[1]
        body = body.split('// Checks if there is a friendly unit', 1)[0]
        self.assertIn('var/current_dir', body)
        self.assertIn('if(is_good_cover(T, enemy))\n\t\t\tcover_count++', body)
        self.block = body.split(START, 1)[1].split(END, 1)[0]

    def test_scores_ties_zero_direction_and_call_counts(self):
        cases = [[], [(0, 10)], [(0, 0), (1, 0)], [(2, 0), (1, 40), (2, -5)]]
        for direction in (0, 1, 2, 4, 8):
            for candidates in cases:
                with self.subTest(direction=direction, candidates=candidates):
                    old = project(BASELINE, direction, candidates)
                    new = project(self.block, direction, candidates)
                    self.assertEqual(new[:2], old[:2])
                    self.assertEqual(new[2], min(1, len(candidates)))
                    self.assertEqual(old[2], len(candidates))

    def test_missing_flank_bonus_mutation_is_detected(self):
        mutant = self.block.replace('score += 40', 'score += 0')
        self.assertNotEqual(mutant, self.block)
        self.assertNotEqual(project(mutant, 1, [(2, 0)])[:2],
                            project(BASELINE, 1, [(2, 0)])[:2])


if __name__ == '__main__':
    unittest.main()
