"""A switched-off walkthrough metal detector must look off (issue 5484).

Offline source check; does not execute BYOND. It replays the shutdown and
alarm-reset sequence from the detector's own procs.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/modern_items.dm'


def detector(text):
    start = text.index('/obj/structure/metal_detector\n')
    end = re.compile(r'^\S', re.M).search(text, start + 1)
    return text[start:end.start()]


def procs(block):
    found, name = {}, None
    for line in block.splitlines():
        head = re.match(r'\t(?:proc/)?(\w+)\(', line)
        if head:
            name = head.group(1)
            found[name] = []
        elif name and line.startswith('\t\t'):
            found[name].append(line)
    return found


class Detector:
    """Tiny interpreter for the statements these procs use."""

    def __init__(self, code):
        self.code, self.on, self.icon, self.light = code, True, 'metal_detector1', 'green'
        self.pending = []

    def call(self, name):
        self.run(self.code[name], 2)

    def run(self, lines, depth):
        i = 0
        while i < len(lines):
            line = lines[i]
            indent = len(line) - len(line.lstrip('\t'))
            text = line.split('//', 1)[0].strip()
            body = []
            j = i + 1
            while j < len(lines) and len(lines[j]) - len(lines[j].lstrip('\t')) > indent:
                body.append(lines[j])
                j += 1
            if text.startswith('if (on)') or text.startswith('if(!on)') or text.startswith('if (!on)'):
                wanted = not text.startswith('if(!on)') and not text.startswith('if (!on)')
                branch_taken = self.on == wanted
                else_body = []
                if j < len(lines) and lines[j].strip() == 'else':
                    k = j + 1
                    while k < len(lines) and len(lines[k]) - len(lines[k].lstrip('\t')) > indent:
                        else_body.append(lines[k])
                        k += 1
                    j = k
                self.run(body if branch_taken else else_body, indent + 1)
            elif text.startswith('spawn('):
                self.pending.append(body)
            elif text.startswith('if(do_after('):
                self.run(body, indent + 1)
            elif text == 'on = FALSE':
                self.on = False
            elif text == 'on = TRUE':
                self.on = True
            elif text == 'on = !on':
                self.on = not self.on
            elif m := re.match(r'icon_state ?= ?"(\w+)"', text):
                self.icon = m.group(1)
            elif m := re.match(r'set_light\((.*)\)', text):
                args = m.group(1)
                self.light = None if args.strip() == '0' else ('red' if 'ce3535' in args else 'green')
            elif m := re.match(r'(\w+)\(\)$', text):
                if m.group(1) in self.code:
                    self.call(m.group(1))
            i = j

    def finish_timers(self):
        while self.pending:
            self.run(self.pending.pop(0), 0)


class MetalDetectorPower(unittest.TestCase):
    def setUp(self):
        self.code = procs(detector(SOURCE.read_text(encoding='utf-8')))
        self.code['attack_hand'] = [line for line in self.code['attack_hand']
                                    if 'ishuman' not in line and line.strip() != 'return']

    def test_shutdown_during_alarm_stays_off(self):
        d = Detector(self.code)
        d.call('bleep')
        self.assertEqual((d.icon, d.light), ('metal_detector2', 'red'))
        d.call('attack_hand')
        self.assertFalse(d.on)
        self.assertEqual((d.icon, d.light), ('metal_detector', None))
        d.finish_timers()
        self.assertFalse(d.on)
        self.assertEqual((d.icon, d.light), ('metal_detector', None))

    def test_alarm_reset_while_on_returns_to_ready(self):
        d = Detector(self.code)
        d.call('bleep')
        d.finish_timers()
        self.assertEqual((d.icon, d.light), ('metal_detector1', 'green'))

    def test_switching_back_on_relights(self):
        d = Detector(self.code)
        d.call('attack_hand')
        d.call('attack_hand')
        self.assertTrue(d.on)
        self.assertEqual((d.icon, d.light), ('metal_detector1', 'green'))
        d.call('toggle')
        self.assertEqual((d.on, d.icon, d.light), (False, 'metal_detector', None))

    def test_off_detector_does_not_scan(self):
        self.assertEqual(self.code['checkmob'][0].strip(), 'if (!on)')


if __name__ == '__main__':
    unittest.main()
