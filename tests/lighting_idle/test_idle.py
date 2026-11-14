"""Offline projection of the lighting overlay idle guard; no BYOND or network."""
import ast
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/processes/lighting/overlays.dm'
DECL = '/process/lighting_overlays/fire()\n'
GUARD = re.compile(
    r'^\tif \(processing_batch\)\n\t\treturn PROCESS_TICK_CHECK_RETURNED_EARLY\n'
    r'\tif \(([^\n]+)\)\n\t\tcurrent_list = null\n\t\tbatch_index = (\d+)\n\t\tprocessing_batch = FALSE\n\t\treturn\n', re.M)

class DMList:
    def __init__(self, values=()):
        self.values = list(values)
    @property
    def len(self):
        return len(self.values)
    def __bool__(self):
        return True  # BYOND list references are truthy, including empty lists.

def guard_result(body, batch, queue, processing, index):
    match = GUARD.match(body)
    if not match:
        raise AssertionError('Expected processing and idle guards in production order')
    if processing:
        return ('early', index)
    expr = match[1].replace('&&', ' and ').replace('||', ' or ')
    expr = re.sub(r'!(?!=)', ' not ', expr).strip()
    tree = ast.parse(expr, mode='eval')
    allowed = (ast.Expression, ast.BoolOp, ast.And, ast.Or, ast.UnaryOp,
               ast.Not, ast.Name, ast.Load, ast.Attribute)
    if any(not isinstance(node, allowed) for node in ast.walk(tree)):
        raise AssertionError('Unexpected guard expression')
    scope = {'current_list': batch, 'lighting_update_overlays': queue}
    if eval(compile(tree, '<overlay idle guard>', 'eval'), {'__builtins__': {}}, scope):
        return ('idle', int(match[2]), None, False)
    return ('continue', index)

class LightingIdleGuardTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        source = SOURCE.read_text(encoding='utf-8')
        cls.body = source.split(DECL, 1)[1].split('\n/process/lighting_overlays/reset_current_list()', 1)[0]
        cls.guard = GUARD.match(cls.body)
        if cls.guard is None:
            raise AssertionError('Idle guard missing')
        # The queue-processing body follows the idle guard.
        suffix = cls.body[cls.guard.end():]
        assert suffix.startswith('\tprocessing_batch = TRUE\n\tif (!current_list)\n')

    def test_idle_matches_original_final_state(self):
        # Original: empty Copy and Cut, then reset the detached list and flag.
        for index in (0, 1, 17):
            for batch in (None, 0, ''):
                for processing in (False, None):
                    self.assertEqual(guard_result(self.body, batch, DMList(), processing, index), ('idle', 1, None, False))

    def test_live_batch_queue_and_null_queue_take_original_path(self):
        states = ((DMList(), DMList()), (DMList([1]), DMList()),
                  (None, DMList([1])), (None, None))
        for batch, queue in states:
            with self.subTest(batch=batch, queue=queue):
                self.assertEqual(guard_result(self.body, batch, queue, False, 7), ('continue', 7))

    def test_reentry_still_returns_early_before_idle_guard(self):
        self.assertEqual(guard_result(self.body, None, DMList(), True, 8), ('early', 8))

    def test_negative_controls_detect_index_and_live_batch_regressions(self):
        wrong_index = self.body.replace('batch_index = 1\n\t\tprocessing_batch = FALSE', 'batch_index = 2\n\t\tprocessing_batch = FALSE', 1)
        self.assertNotEqual(guard_result(wrong_index, None, DMList(), False, 7), ('idle', 1, None, False))
        wrong_guard = self.body.replace('!current_list && ', '', 1)
        self.assertNotEqual(guard_result(wrong_guard, DMList([1]), DMList(), False, 7), ('continue', 7))

if __name__ == '__main__':
    unittest.main()