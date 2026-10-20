"""Execute the runner's actual BUG guard, including an omission control. No BYOND."""
import ast
import copy
from pathlib import Path
from types import SimpleNamespace
import unittest

RUNNER = Path(__file__).with_name('run-durable-world.py')


def diagnostic_guard():
    tree = ast.parse(RUNNER.read_text(encoding='utf-8'))
    matches = [node for node in ast.walk(tree) if isinstance(node, ast.If)
               and any(isinstance(child, ast.Constant) and child.value ==
                       'Native lighting/wound engine diagnostic invalidated fixture'
                       for child in ast.walk(node))]
    # Pick the innermost if, rather than its enclosing main/mode branches.
    return min(matches, key=lambda node: sum(1 for _ in ast.walk(node)))


def rejected(guard, *, wounds=True, lighting=False, diagnostic='BUG: native failure'):
    import re
    module = ast.fix_missing_locations(ast.Module(body=[guard], type_ignores=[]))
    try:
        exec(compile(module, str(RUNNER), 'exec'),
             {'args': SimpleNamespace(wounds=wounds, lighting=lighting),
              'diagnostics': diagnostic.lower(), 're': re})
    except RuntimeError as error:
        return str(error) == 'Native lighting/wound engine diagnostic invalidated fixture'
    return False


class WoundDiagnostics(unittest.TestCase):
    def test_actual_runner_rejects_bug_in_both_modes(self):
        guard = diagnostic_guard()
        self.assertTrue(rejected(guard))
        self.assertTrue(rejected(guard, wounds=False, lighting=True))
        self.assertFalse(rejected(guard, diagnostic='ordinary completed output'))

    def test_omitting_wounds_reproduces_diagnostic_acceptance(self):
        guard = copy.deepcopy(diagnostic_guard())
        self.assertIsInstance(guard.test, ast.BoolOp)
        self.assertIsInstance(guard.test.values[0], ast.BoolOp)
        # Restore the previous lighting-only guard in an in-memory source copy.
        guard.test.values[0] = ast.Attribute(value=ast.Name(id='args', ctx=ast.Load()),
                                           attr='lighting', ctx=ast.Load())
        self.assertFalse(rejected(guard))
        self.assertTrue(rejected(guard, wounds=False, lighting=True))


if __name__ == '__main__':
    unittest.main()
