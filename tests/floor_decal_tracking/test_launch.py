"""Offline contracts bound to the actual launcher source; no native calls."""
import ast
from pathlib import Path
import subprocess
import unittest
from z_budget_evidence import validate_compile


HERE = Path(__file__).resolve().parent


def flag_value(node):
    if isinstance(node, ast.Constant) and type(node.value) is int:
        return node.value
    if isinstance(node, ast.BinOp) and isinstance(node.op, ast.BitOr):
        return flag_value(node.left) | flag_value(node.right)
    raise ValueError('Only literal flags may define the launch contract')


def launch_tree():
    tree = ast.parse((HERE / 'windows.py').read_text())
    return next(node for node in ast.walk(tree) if isinstance(node, ast.FunctionDef) and node.name == 'launch')


class LaunchTests(unittest.TestCase):
    def test_actual_createprocess_is_detached_suspended_unicode_extended(self):
        calls = [node for node in ast.walk(launch_tree()) if isinstance(node, ast.Call)
                 and isinstance(node.func, ast.Attribute) and node.func.attr == 'CreateProcessW']
        self.assertEqual(len(calls), 1)
        flags = flag_value(calls[0].args[5])
        self.assertEqual(flags, 0x4 | 0x400 | 0x8 | 0x80000)
        self.assertFalse(flags & 0x08000000)
        self.assertFalse(flags & 0x10)  # No new visible console or fallback.

    def test_actual_command_uses_argv_quoting_and_fixed_hidden_handles(self):
        source = ast.unparse(launch_tree())
        self.assertIn('subprocess.list2cmdline(argv)', source)
        self.assertIn('startup.startup.flags = 257', source)
        self.assertIn('startup.startup.show = 0', source)
        self.assertIn('inherited = (w.HANDLE * len(logs))(*logs)', source)
        self.assertIn('startup.startup.stdin, startup.startup.stdout, startup.startup.stderr = (null, logs[0], logs[1])', source)
        self.assertIn("for suffix in ('stdout', 'stderr')", source)
        self.assertEqual(subprocess.list2cmdline(['C:/Program Files/BYOND/dm.exe', '-max_errors', '0',
                                                 'D:/fixture with spaces/probe.dme']),
                         '"C:/Program Files/BYOND/dm.exe" -max_errors 0 "D:/fixture with spaces/probe.dme"')

    def test_redirected_compiler_log_must_be_complete_clean_and_bounded(self):
        good = 'DM compiler version 516.1681\nprobe.dmb - 0 errors, 0 warnings\n'
        validate_compile(0, good)
        for log in ('', good + good, good + 'runtime error:', good + 'x' * 1024**2):
            with self.assertRaises(RuntimeError):
                validate_compile(0, log)


if __name__ == '__main__':
    unittest.main()
