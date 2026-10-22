"""Actual main/cmd/receipt/Git parsing, with every external effect injected."""
import io
import json
import unittest
from unittest.mock import patch

import prepare
import v4_prepare_control


class ParsedFirstHead(Exception):
    pass


class Receipt(io.BytesIO):
    def __init__(self, rows, name):
        super().__init__(); self.rows = rows; self.name = name

    def fileno(self):
        return 99

    def close(self):
        if not self.closed:
            self.rows[self.name] = self.getvalue()
        super().close()


class FakePath:
    def __init__(self, name, rows):
        self.name = str(name); self.rows = rows

    def __truediv__(self, name):
        return type(self)(self.name + '/' + name, self.rows)

    def __str__(self):
        return self.name

    def mkdir(self):
        # The actual main reaches the next checkout only after .decode(),
        # .strip() and exact HEAD equality succeed on the first checkout.
        if self.name.endswith('/game-checkout'):
            raise ParsedFirstHead()

    def open(self, mode):
        assert mode == 'xb'
        return Receipt(self.rows, self.name)


def acquire_first_head(module):
    rows = {}; commands = []

    def command(argv, cwd, check, deadline):
        check(); commands.append(argv)
        return 0, (module.ENGINE + '\n').encode() if argv[-2:] == ['rev-parse', 'HEAD'] else b'', b''

    with patch.object(module, 'Path', side_effect=lambda value: FakePath(value, rows)), \
         patch.object(module, 'guarded_command', side_effect=command), \
         patch.object(module.os, 'fsync') as sync, \
         patch.object(module.time, 'monotonic', return_value=1), \
         patch.object(module.time, 'time', return_value=1):
        try:
            module.main(['--root', '/owned', '--deadline', '10', '--expires', '10'])
        except ParsedFirstHead:
            parsed = True
        except AttributeError as exc:
            assert 'decode' in str(exc)
            parsed = False
        else:
            raise AssertionError('Expected injected stop after first parsed HEAD')
        assert sync.call_count == 5
    return parsed, rows, commands


class PreparationReceiptTests(unittest.TestCase):
    def test_actual_preparation_stdout_reaches_git_parser_after_receipt_close(self):
        parsed, rows, commands = acquire_first_head(prepare)
        self.assertTrue(parsed)
        self.assertEqual(len(commands), 5)
        last = json.loads(rows['/owned/receipts/command-4.json'])
        self.assertEqual(bytes.fromhex(last['stdout_hex']), (prepare.ENGINE + '\n').encode())
        self.assertEqual(last['exit'], 0)
        self.assertEqual(last['argv'][-2:], ['rev-parse', 'HEAD'])

    def test_frozen_v4_fails_same_first_head_parse_oracle(self):
        old, _, _ = acquire_first_head(v4_prepare_control)
        fixed, _, _ = acquire_first_head(prepare)
        self.assertFalse(old)
        self.assertTrue(fixed)


if __name__ == '__main__':
    unittest.main()
