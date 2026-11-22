"""Region travel relinks one Dream Seeker through several worlds in a row.

Each world used to switch hardware graphics off and on at connect, and after a
few trips the window came back blank black. Connecting must leave hardware
mode alone when it is already on.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
PROCS = ROOT / 'code/modules/client/client_procs.dm'


def proc_body(text, header):
    start = text.index(header)
    rest = text[start + len(header):]
    end = re.search(r'\n(?=\S)', rest)
    return rest[:end.start()] if end else rest


class HardwareGraphicsOnConnect(unittest.TestCase):
    def setUp(self):
        self.text = PROCS.read_text(encoding='utf-8', errors='replace')

    def test_connect_uses_the_guarded_proc(self):
        new = proc_body(self.text, '/client/New(TopicData)')
        self.assertIn('ensure_hardware_graphics()', new)
        self.assertNotIn('graphics-hwmode', new)

    def test_already_on_is_left_alone(self):
        body = proc_body(self.text, '/client/proc/ensure_hardware_graphics()')
        self.assertIn('set waitfor = FALSE', body)
        first_check = body.index('winget(src, null, "hwmode") == "true"')
        self.assertLess(first_check, body.index('graphics-hwmode on'))
        self.assertLess(first_check, body.index('graphics-hwmode off'))

    def test_off_only_after_on_plainly_failed(self):
        body = proc_body(self.text, '/client/proc/ensure_hardware_graphics()')
        on_first = body.index('graphics-hwmode on')
        failed = body.index('!= "false"')
        self.assertLess(on_first, failed)
        self.assertLess(failed, body.index('graphics-hwmode off'))
        self.assertEqual(self.text.count('graphics-hwmode off'), 1)


if __name__ == '__main__':
    unittest.main()
